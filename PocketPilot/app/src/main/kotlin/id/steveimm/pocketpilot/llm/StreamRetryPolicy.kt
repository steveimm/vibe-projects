package id.steveimm.pocketpilot.llm

import android.util.Log

internal sealed interface StreamRetryAction {
    data class Retry(val waitMs: Long, val nextBackoffMs: Long) : StreamRetryAction

    data class FailAndStop(val message: String) : StreamRetryAction

    data object Stop : StreamRetryAction
}

/** Shared retry decision policy for streaming clients. */
internal object StreamRetryPolicy {
    fun decide(
            tag: String,
            classified: Exception,
            attempt: Int,
            emittedEvent: Boolean,
            backoffMs: Long,
            maxRetries: Int = LLMClient.MAX_RETRIES
    ): StreamRetryAction {
        val retryable = classified is RateLimitException || classified is TransientException

        if (retryable && emittedEvent) {
            Log.w(tag, "Stream error after output; skipping retry: ${classified.message}")
            return StreamRetryAction.FailAndStop(
                    "Stream interrupted after partial output: ${classified.message}"
            )
        }

        if (retryable && attempt < maxRetries) {
            val waitMs =
                    when (classified) {
                        is RateLimitException -> classified.retryAfterMs ?: backoffMs
                        else -> backoffMs
                    }
            Log.w(
                    tag,
                    "Retryable stream error (attempt $attempt/$maxRetries), waiting ${waitMs}ms"
            )
            return StreamRetryAction.Retry(
                    waitMs = waitMs,
                    nextBackoffMs = LlmRetry.advanceBackoff(backoffMs)
            )
        }

        Log.e(tag, "Streaming failed after $attempt attempts", classified)
        return StreamRetryAction.Stop
    }
}
