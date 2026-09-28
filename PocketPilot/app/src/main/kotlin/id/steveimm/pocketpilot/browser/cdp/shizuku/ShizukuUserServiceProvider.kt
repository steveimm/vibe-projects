package id.steveimm.pocketpilot.browser.cdp.shizuku

import android.content.ComponentName
import android.content.Context
import android.content.ServiceConnection
import android.os.IBinder
import java.io.Closeable
import java.io.IOException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.withTimeout
import rikka.shizuku.Shizuku

/** Owns the lifecycle of the Shizuku-backed [DevtoolsSocketTransport]. The bridge calls [obtain] lazily on the first httpGet so we
 * don't spawn a Shizuku helper process before `browser_script` is actually invoked. */
interface UserServiceProvider {
    /** Lazily produce a transport. Idempotent: subsequent calls return the same instance. */
    suspend fun obtain(): DevtoolsSocketTransport

    /** Tear down any binding owned by this provider. Safe to call multiple times. */
    fun close()
}

/** Real Shizuku-backed [UserServiceProvider]. Binds [ChromeDevtoolsUserService] through `Shizuku.bindUserService` and wraps the
 * resulting binder as a [UserServiceTransport]. */
class ShizukuUserServiceProvider internal constructor(
    private val binder: Binder,
    private val bindTimeoutMs: Long = DEFAULT_BIND_TIMEOUT_MS,
) : UserServiceProvider, Closeable {

    constructor(
        context: Context,
        versionCode: Int = USER_SERVICE_VERSION,
        processNameSuffix: String = DEFAULT_PROCESS_SUFFIX,
        debuggable: Boolean = false,
        bindTimeoutMs: Long = DEFAULT_BIND_TIMEOUT_MS,
    ) : this(
        binder = ShizukuBinder(context, versionCode, processNameSuffix, debuggable),
        bindTimeoutMs = bindTimeoutMs,
    )

    private val lock = Any()

    /** Active [ServiceConnection] across both phases (in-flight and delivered). */
    private var connection: ServiceConnection? = null

    /** Cached transport once `onServiceConnected` has delivered the binder. */
    private var transport: DevtoolsSocketTransport? = null

    /** Single in-flight bind cycle. Null when no bind is in progress. */
    private var inflight: InflightBind? = null

    /** Number of [obtain] callers awaiting the current [inflight]. */
    private var inflightAwaiters: Int = 0

    /** Monotonically increases on every new bind attempt and on every terminal event (failure callback, refcount-zero teardown,
     * [close]). A captured value identifies a single bind cycle: callbacks that no longer match the current generation are stale. */
    private var bindGeneration: Long = 0L
    private var closed = false

    override suspend fun obtain(): DevtoolsSocketTransport {
        val (flight, isOwner) = synchronized(lock) {
            transport?.let { return it }
            if (closed) throw closedError()
            val existing = inflight
            if (existing != null) {
                inflightAwaiters++
                existing to false
            } else {
                val gen = ++bindGeneration
                val d = CompletableDeferred<DevtoolsSocketTransport>()
                val newFlight = InflightBind(d)
                val c = createConnection(gen)
                connection = c
                inflight = newFlight
                inflightAwaiters = 1
                newFlight to true
            }
        }
        if (isOwner) startBind(flight)
        return awaitBind(flight)
    }

    private fun startBind(flight: InflightBind) {
        val conn = synchronized(lock) { connection } ?: return
        try {
            binder.bind(conn)
        } catch (t: Throwable) {
            // Synchronous bind failure: tear down state and fail the shared deferred so
            // every awaiter wakes up with the same error. No unbind — bind() never took.
            val ours = synchronized(lock) {
                if (inflight === flight) {
                    inflight = null
                    inflightAwaiters = 0
                    connection = null
                    bindGeneration++
                    true
                } else {
                    false
                }
            }
            if (ours) {
                flight.deferred.completeExceptionally(
                    DevtoolsSetupError.UserServiceSocketInaccessible(t)
                )
            }
        }
    }

    private suspend fun awaitBind(flight: InflightBind): DevtoolsSocketTransport {
        return try {
            try {
                withTimeout(bindTimeoutMs) { flight.deferred.await() }
            } catch (e: TimeoutCancellationException) {
                throw DevtoolsSetupError.UserServiceSocketInaccessible(
                    IOException("Shizuku UserService bind timed out after ${bindTimeoutMs}ms", e)
                )
            }
        } finally {
            // releaseAwaiter is a no-op when [flight] is no longer the current inflight (success path cleared it, or a failure callback /
            // close already tore it down), so it is safe to call on every exit path including normal completion.
            releaseAwaiter(flight)
        }
    }

    /** Decrement the awaiter count for [flight]. */
    private fun releaseAwaiter(flight: InflightBind) {
        val (shouldUnbind, conn) = synchronized(lock) {
            if (inflight !== flight) return
            inflightAwaiters--
            if (inflightAwaiters > 0) return
            inflight = null
            val c = connection
            connection = null
            bindGeneration++
            true to c
        }
        if (shouldUnbind) {
            // Complete the deferred so any in-flight callback that races with us wakes up cleanly (idempotent —
            // onServiceConnected/handleFailure may have already completed it). The IOException records why the bind was abandoned.
            flight.deferred.completeExceptionally(
                DevtoolsSetupError.UserServiceSocketInaccessible(
                    IOException("Shizuku UserService bind abandoned by all callers")
                )
            )
            if (conn != null) runCatching { binder.unbind(conn, true) }
        }
    }

    private fun createConnection(generation: Long): ServiceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            if (service == null) {
                handleFailure(
                    generation,
                    IllegalStateException("UserService connected with null binder"),
                )
                return
            }
            val tr = UserServiceTransport(IChromeDevtoolsUserService.Stub.asInterface(service))
            val deferred = synchronized(lock) {
                if (closed || bindGeneration != generation) return
                transport = tr
                val flight = inflight
                inflight = null
                inflightAwaiters = 0
                // Do NOT bump bindGeneration: a future onServiceDisconnected for this same connection should still be allowed to clear
                // `transport` so a dead-after-delivery service doesn't masquerade as live.
                flight?.deferred
            } ?: return
            deferred.complete(tr)
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            handleFailure(
                generation,
                IOException("UserService disconnected before binder was delivered"),
            )
        }

        override fun onBindingDied(name: ComponentName?) {
            handleFailure(
                generation,
                IOException("UserService binding died before binder was delivered"),
            )
        }

        override fun onNullBinding(name: ComponentName?) {
            handleFailure(
                generation,
                IllegalStateException("UserService.onBind returned null"),
            )
        }
    }

    /** Process a terminal failure for a specific bind cycle. */
    private fun handleFailure(generation: Long, cause: Throwable) {
        val (flight, conn) = synchronized(lock) {
            if (closed || bindGeneration != generation) return
            val f = inflight
            val c = connection
            inflight = null
            inflightAwaiters = 0
            connection = null
            transport = null
            bindGeneration++
            f to c
        }
        if (conn != null) runCatching { binder.unbind(conn, true) }
        flight?.deferred?.completeExceptionally(
            DevtoolsSetupError.UserServiceSocketInaccessible(cause)
        )
    }

    override fun close() {
        val (flight, conn) = synchronized(lock) {
            if (closed) return
            closed = true
            bindGeneration++
            val f = inflight
            val c = connection
            inflight = null
            inflightAwaiters = 0
            connection = null
            transport = null
            f to c
        }
        flight?.deferred?.completeExceptionally(
            DevtoolsSetupError.UserServiceSocketInaccessible(
                IOException("UserService provider closed while bind was pending")
            )
        )
        if (conn != null) runCatching { binder.unbind(conn, true) }
    }

    private fun closedError(): DevtoolsSetupError =
        DevtoolsSetupError.UserServiceSocketInaccessible(
            IllegalStateException("ShizukuUserServiceProvider is closed")
        )

    /** Indirection so tests don't depend on the real Shizuku static. */
    internal interface Binder {
        fun bind(conn: ServiceConnection)
        fun unbind(conn: ServiceConnection, remove: Boolean)
    }

    private class InflightBind(
        val deferred: CompletableDeferred<DevtoolsSocketTransport>,
    )

    companion object {
        // Bump whenever IChromeDevtoolsUserService.aidl changes shape.
        const val USER_SERVICE_VERSION = 5
        const val DEFAULT_PROCESS_SUFFIX = "chrome_devtools"
        const val DEFAULT_BIND_TIMEOUT_MS = 10_000L
    }
}

private class ShizukuBinder(
    context: Context,
    versionCode: Int,
    processNameSuffix: String,
    debuggable: Boolean,
) : ShizukuUserServiceProvider.Binder {

    private val args: Shizuku.UserServiceArgs = Shizuku.UserServiceArgs(
        ComponentName(context, ChromeDevtoolsUserService::class.java)
    )
        .daemon(false)
        .processNameSuffix(processNameSuffix)
        .debuggable(debuggable)
        .version(versionCode)

    override fun bind(conn: ServiceConnection) {
        Shizuku.bindUserService(args, conn)
    }

    override fun unbind(conn: ServiceConnection, remove: Boolean) {
        Shizuku.unbindUserService(args, conn, remove)
    }
}
