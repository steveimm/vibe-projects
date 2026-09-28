package id.steveimm.pocketpilot.tool

/** ToolCallResult - Final result of a tool call through the ToolRouter. */
sealed class ToolCallResult {
    /** Unique identifier for this tool call */
    abstract val callId: String

    /** Tool call executed successfully. */
    data class Success(
        override val callId: String,
        val output: String,
        /** Post-action observation (screen state after tool execution) */
        val observation: ToolObservation? = null
    ) : ToolCallResult()

    /** Tool call failed. */
    data class Error(
        override val callId: String,
        val error: String,
        val exception: Throwable? = null
    ) : ToolCallResult()

    /** Tool call was cancelled. */
    data class Cancelled(
        override val callId: String,
        val reason: String
    ) : ToolCallResult()

    /** Convert to a string suitable for including in LLM context. */
    fun toContextString(): String {
        return when (this) {
            is Success -> output
            is Error -> "Error: $error"
            is Cancelled -> "Cancelled: $reason"
        }
    }
}

