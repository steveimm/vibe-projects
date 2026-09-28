package id.steveimm.pocketpilot.platform

import android.util.Log
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull

private const val TAG = "BoundedCallback"

/** Bounded callback-to-suspend bridge. */
internal suspend fun <T : Any> boundedCallback(
    timeoutMs: Long,
    label: String,
    onCancel: (() -> Unit)? = null,
    register: (CancellableContinuation<T?>) -> Unit
): T? {
    val result = withTimeoutOrNull(timeoutMs) {
        suspendCancellableCoroutine { cont ->
            if (onCancel != null) {
                cont.invokeOnCancellation { onCancel() }
            }
            register(cont)
        }
    }
    if (result == null) {
        Log.w(TAG, "$label: timed out after ${timeoutMs}ms or cancelled")
    }
    return result
}
