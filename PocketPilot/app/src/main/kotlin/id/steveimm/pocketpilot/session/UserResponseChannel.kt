package id.steveimm.pocketpilot.session

import kotlinx.coroutines.CompletableDeferred
import java.util.concurrent.atomic.AtomicReference

/** UserResponseChannel — suspension bridge between ask_user tool and UI. */
class UserResponseChannel {

    private data class PendingRequest(
        val callId: String,
        val deferred: CompletableDeferred<String>
    )

    private val pending = AtomicReference<PendingRequest?>(null)

    /** Suspend until the user responds. Called by the ask_user tool. */
    suspend fun awaitResponse(callId: String): String {
        val deferred = CompletableDeferred<String>()
        val request = PendingRequest(callId = callId, deferred = deferred)
        check(pending.compareAndSet(null, request)) { "Only one pending ask_user request allowed" }
        return try {
            deferred.await()
        } finally {
            pending.compareAndSet(request, null)
        }
    }

    /** Deliver the user's response. Called by AgentSession on Op.UserResponse. */
    fun deliver(callId: String, response: String): Boolean {
        val request = pending.get() ?: return false
        if (request.callId != callId) return false
        if (!pending.compareAndSet(request, null)) return false
        return request.deferred.complete(response)
    }

    /** Cancel any pending request (called on stop/shutdown). */
    fun cancel() {
        pending.getAndSet(null)?.deferred?.cancel()
    }

    val hasPending: Boolean get() = pending.get() != null
}
