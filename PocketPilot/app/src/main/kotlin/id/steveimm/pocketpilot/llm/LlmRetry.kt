package id.steveimm.pocketpilot.llm

import android.util.Log
import kotlinx.coroutines.delay

/** Shared retry/backoff policy for LLM clients. */
internal object LlmRetry {
    fun advanceBackoff(currentMs: Long): Long =
            (currentMs * LLMClient.BACKOFF_MULTIPLIER).toLong()
                    .coerceAtMost(LLMClient.MAX_BACKOFF_MS)

    suspend fun <T> executeWithRetry(
            tag: String,
            operationName: String,
            maxAttempts: Int = LLMClient.MAX_RETRIES,
            block: suspend () -> T
    ): T {
        var lastException: Exception? = null
        var backoffMs = LLMClient.INITIAL_BACKOFF_MS

        for (attempt in 1..maxAttempts) {
            try {
                return block()
            } catch (e: RateLimitException) {
                lastException = e
                if (attempt == maxAttempts) {
                    Log.e(tag, "Max retries ($maxAttempts) exceeded for $operationName (rate limit)")
                    throw e
                }

                val waitMs = e.retryAfterMs ?: backoffMs
                if (waitMs > 5_000) throw e
                Log.w(tag, "Rate limited (attempt $attempt/$maxAttempts), waiting ${waitMs}ms")
                delay(waitMs)
                backoffMs = advanceBackoff(backoffMs)
            } catch (e: TransientException) {
                lastException = e
                if (attempt == maxAttempts) {
                    Log.e(tag, "Max retries ($maxAttempts) exceeded for $operationName (transient error)")
                    throw e.cause ?: e
                }

                Log.w(
                        tag,
                        "Transient error (attempt $attempt/$maxAttempts): ${e.message}, retrying in ${backoffMs}ms"
                )
                delay(backoffMs)
                backoffMs = advanceBackoff(backoffMs)
            }
        }

        throw lastException ?: RuntimeException("Unexpected error in retry loop for $operationName")
    }
}
