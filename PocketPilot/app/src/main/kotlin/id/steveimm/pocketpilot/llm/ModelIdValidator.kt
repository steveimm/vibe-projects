package id.steveimm.pocketpilot.llm

/** Single validation rule for user-supplied or discovered model identifiers. */
object ModelIdValidator {
    fun validate(input: String): Result<String> {
        val trimmed = input.trim()
        if (trimmed.isEmpty()) {
            return Result.failure(IllegalArgumentException("Model id must not be blank"))
        }
        if (trimmed.any { it.isWhitespace() }) {
            return Result.failure(IllegalArgumentException("Model id must not contain whitespace"))
        }
        if (trimmed.startsWith('/') || trimmed.startsWith(':')) {
            return Result.failure(IllegalArgumentException("Model id must not start with '/' or ':'"))
        }
        return Result.success(trimmed)
    }
}
