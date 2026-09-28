package id.steveimm.pocketpilot.onboarding

/** Validates an API key against the LLM provider endpoint. */
interface LlmCredentialValidator {
    sealed interface Result {
        data object Valid : Result
        data class InvalidKey(val message: String) : Result
        data class TransientError(val message: String) : Result
    }

    suspend fun validate(key: String): Result
}
