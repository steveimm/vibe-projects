package ai.closepaw.llm

import java.net.URI
import java.net.URISyntaxException

/** Validates HTTP(S) custom endpoints and rejects URL segments that could expose credentials. */
object OtherBaseUrlValidator {

    fun validate(input: String): Result<String> {
        val trimmed = input.trim()
        if (trimmed.isEmpty()) {
            return Result.failure(IllegalArgumentException("Base URL must not be blank"))
        }

        val uri = try {
            URI(trimmed)
        } catch (e: URISyntaxException) {
            return Result.failure(IllegalArgumentException("Base URL is not a valid URI: ${e.message}"))
        }

        val scheme = uri.scheme?.lowercase()
        if (scheme != "http" && scheme != "https") {
            return Result.failure(
                IllegalArgumentException("Base URL must use http or https (got '${uri.scheme ?: ""}')")
            )
        }

        val host = uri.host
        if (host.isNullOrBlank()) {
            return Result.failure(IllegalArgumentException("Base URL must include a host"))
        }

        // Reject sensitive segments WITHOUT echoing them back. Even encoded
        // (raw*) forms count — a user-info segment is a secret regardless of
        // url-encoding, and we don't want it persisted to the disco cache.
        if (!uri.rawUserInfo.isNullOrEmpty()) {
            return Result.failure(
                IllegalArgumentException("Base URL must not contain credentials (user:pass@…)")
            )
        }
        if (!uri.rawQuery.isNullOrEmpty()) {
            return Result.failure(
                IllegalArgumentException("Base URL must not contain a query string")
            )
        }
        if (!uri.rawFragment.isNullOrEmpty()) {
            return Result.failure(
                IllegalArgumentException("Base URL must not contain a fragment")
            )
        }

        val normalized = if (trimmed.endsWith('/')) trimmed.trimEnd('/') else trimmed
        return Result.success(normalized)
    }
}
