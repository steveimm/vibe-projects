package id.steveimm.pocketpilot.browser.cdp.shizuku

import java.io.IOException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runInterruptible

/** Adapter wrapping an [IChromeDevtoolsUserService] binder as a [DevtoolsSocketTransport]. */
class UserServiceTransport(
    // Public so [AdbWirelessManager] can share the same Shizuku binder for IAdbManager calls
    // without spawning a second user service.
    val binder: IChromeDevtoolsUserService,
) : DevtoolsSocketTransport {

    override val label: TransportLabel = TransportLabel.USER_SERVICE

    /** Start the local relay with its per-session auth token. Reuse that token on retries because the binder rejects rotation. */
    suspend fun ensureRelayPortSuspend(authToken: String): Int = runInterruptible(Dispatchers.IO) {
        require(authToken.isNotEmpty()) { "authToken must not be empty" }
        val port = binder.startTcpRelay(authToken)
        if (port <= 0) throw IOException("UserService.startTcpRelay returned invalid port=$port")
        port
    }

    override suspend fun exchange(request: ByteArray, timeoutMs: Int): ByteArray =
        runInterruptible(Dispatchers.IO) {
            val response: ByteArray? = binder.exchange(request, timeoutMs)
            response ?: throw IOException(
                "UserService exchange returned null; check logcat for the remote exception"
            )
        }
}
