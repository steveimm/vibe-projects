package id.steveimm.pocketpilot.llm

import java.net.URI
import java.net.URISyntaxException

/** Validates HTTP(S) custom endpoints and rejects URL segments that could expose credentials. */
object ServerBaseUrlValidator {

    fun validate(input: String): Result<String> {
        val trimmed = input.trim()
        if (trimmed.isEmpty()) {
            return Result.failure(IllegalArgumentException("Base URL must not be blank"))
        }

        val uri = try {
            URI(trimmed)
        } catch (e: URISyntaxException) {
            return Result.failure(IllegalArgumentException("Server URL is not a valid HTTP URL"))
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

        // Reject sensitive segments WITHOUT echoing them back. Even encoded (raw*) forms count — a user-info segment is a secret
        // regardless of url-encoding, and we don't want it persisted to the disco cache.
        if (!uri.rawUserInfo.isNullOrEmpty()) {
            return Result.failure(
                IllegalArgumentException("Base URL must not contain credentials (user:pass@…)")
            )
        }
        if (uri.rawQuery != null) {
            return Result.failure(
                IllegalArgumentException("Base URL must not contain a query string")
            )
        }
        if (uri.rawFragment != null) {
            return Result.failure(
                IllegalArgumentException("Base URL must not contain a fragment")
            )
        }

        if (uri.port != -1 && uri.port !in 1..65535) {
            return Result.failure(IllegalArgumentException("Server port must be between 1 and 65535"))
        }

        val normalized = trimmed.trimEnd('/').removeSuffix("/chat/completions")
        return Result.success(normalized)
    }
}
