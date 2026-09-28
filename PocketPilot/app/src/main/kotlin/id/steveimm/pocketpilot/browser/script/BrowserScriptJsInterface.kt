package id.steveimm.pocketpilot.browser.script

import id.steveimm.pocketpilot.trace.TraceRecorder
import android.util.Base64
import android.util.Log
import android.webkit.JavascriptInterface
import java.util.concurrent.atomic.AtomicLong

internal class BrowserScriptJsInterface(
    private val bridge: BrowserScriptBridge,
    private val traceRecorder: TraceRecorder,
    private val maxBytesPerCall: Int = MAX_BYTES_PER_CALL,
    private val maxBytesPerSession: Long = MAX_BYTES_PER_SESSION,
    /** Cumulative decoded-byte counter shared with the session-scoped owner (BrowserSessionManager). */
    private val sessionDecodedBytes: AtomicLong = AtomicLong(0L),
) {

    @JavascriptInterface
    fun send(message: String) {
        bridge.handleSend(message)
    }

    @JavascriptInterface
    fun done(message: String) {
        bridge.handleDone(message)
    }

    /** Decode base64 [base64], hand the bytes to [TraceRecorder.storeBytes], and return the resulting on-device absolute path so
     * callers can reference the artifact without piping 100+KB of base64 through the agent's context. */
    @JavascriptInterface
    fun storeArtifact(kind: String, filenameHint: String, base64: String, mimeType: String?): String? {
        if (base64.length > maxBytesPerCall) {
            Log.w(
                TAG,
                "storeArtifact rejected: base64 length ${base64.length} exceeds per-call cap $maxBytesPerCall",
            )
            return null
        }
        return runCatching {
            val bytes = Base64.decode(base64, Base64.DEFAULT)
            val byteCount = bytes.size.toLong()
            // Atomic reserve: getAndAccumulate retries the lambda under contention so the read-and-add is one indivisible step.
            val before = sessionDecodedBytes.getAndAccumulate(byteCount) { current, requested ->
                if (current + requested > maxBytesPerSession) current else current + requested
            }
            if (before + byteCount > maxBytesPerSession) {
                Log.w(
                    TAG,
                    "storeArtifact rejected: session decoded bytes would reach ${before + byteCount}, cap $maxBytesPerSession",
                )
                return@runCatching null
            }
            val ref = try {
                traceRecorder.storeBytes(
                    kind = kind.ifBlank { "browser-script" },
                    filenameHint = filenameHint.ifBlank { "artifact.bin" },
                    bytes = bytes,
                    mimeType = mimeType,
                    description = null,
                )
            } catch (t: Throwable) {
                sessionDecodedBytes.addAndGet(-byteCount)
                throw t
            }
            if (ref == null) {
                sessionDecodedBytes.addAndGet(-byteCount)
                return@runCatching null
            }
            traceRecorder.runDirAbsolutePath?.let { "$it/${ref.path}" } ?: ref.path
        }.onFailure { Log.w(TAG, "storeArtifact failed: ${it.message}") }.getOrNull()
    }

    companion object {
        private const val TAG = "BrowserScriptJsInterface"

        /** Per-call cap on the base64 input string length. 50 MiB encoded ≈ 37 MiB decoded. */
        const val MAX_BYTES_PER_CALL: Int = 50 * 1024 * 1024

        /** Cumulative cap on decoded bytes admitted during a single session. */
        const val MAX_BYTES_PER_SESSION: Long = 500L * 1024L * 1024L
    }
}
