package id.steveimm.pocketpilot.llm

/** Thrown when the provider rejects a request because the prompt would exceed the model's context window (HTTP 413, `prompt_too_long`,
 * `request_too_long`, `request_too_large`, Ollama "prompt too long; exceeded max context length"). */
class ContextWindowExceededException(
    message: String,
    cause: Throwable? = null,
) : RuntimeException(message, cause)
