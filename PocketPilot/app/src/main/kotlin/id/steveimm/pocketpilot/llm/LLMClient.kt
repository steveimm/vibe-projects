package id.steveimm.pocketpilot.llm

import com.openai.models.responses.FunctionTool
import com.openai.models.responses.ResponseInputItem
import kotlinx.coroutines.flow.Flow

/** LLMClient - Abstract base class for LLM clients. */
abstract class LLMClient {

    companion object {
        const val TAG = "LLMClient"

        // Rate limit configuration (shared defaults)
        const val MAX_RETRIES = 5
        const val INITIAL_BACKOFF_MS = 1000L
        const val MAX_BACKOFF_MS = 60000L
        const val BACKOFF_MULTIPLIER = 2.0
    }

    /** Call the LLM with tool/function calling support (non-streaming). */
    abstract suspend fun chatWithTools(
        systemPrompt: String,
        inputItems: List<ResponseInputItem>,
        tools: List<FunctionTool>,
        model: String,
        maxOutputTokens: Long? = null,
    ): ResponsesResult

    /** Streaming version of chatWithTools. */
    abstract fun chatWithToolsStreaming(
        systemPrompt: String,
        inputItems: List<ResponseInputItem>,
        tools: List<FunctionTool>,
        model: String
    ): Flow<LLMStreamEvent>

    /** Check if the client is ready to process requests. */
    open fun isReady(): Boolean = true

    /** Cleanup resources held by the client. */
    open suspend fun cleanup() {}
}

/** Unified streaming events for LLM responses. */
sealed interface LLMStreamEvent {
    /** Response creation started, contains response ID */
    data class Created(val responseId: String) : LLMStreamEvent

    /** Incremental text delta */
    data class TextDelta(val delta: String) : LLMStreamEvent

    data class ReasoningDelta(val delta: String, val field: String = "reasoning") : LLMStreamEvent

    /** A complete tool call has been received */
    data class ToolCallDone(val toolCall: LLMToolCall) : LLMStreamEvent

    /** Response completed successfully */
    data object Completed : LLMStreamEvent

    /** Response failed */
    data class Failed(val error: String) : LLMStreamEvent
}

/** Result from an LLM call (non-streaming). */
data class ResponsesResult(
    /** Text content from the model (may be null if only tool calls) */
    val textContent: String?,
    /** Tool calls requested by the model */
    val toolCalls: List<LLMToolCall>,
    /** Response ID for multi-turn conversation tracking */
    val responseId: String,
    val reasoning: ModelReasoning? = null,
)

/** A tool call from the LLM. */
data class LLMToolCall(
    /** The call ID - use this for tool result correlation */
    val callId: String,
    /** The name of the tool/function to call */
    val name: String,
    /** The arguments as a JSON string */
    val arguments: String
)

/** Exception thrown when rate limited by the API. */
class RateLimitException(
    message: String,
    val retryAfterMs: Long? = null
) : Exception(message)

/** Exception for transient errors that may succeed on retry. */
class TransientException(
    message: String,
    cause: Throwable? = null
) : Exception(message, cause)
