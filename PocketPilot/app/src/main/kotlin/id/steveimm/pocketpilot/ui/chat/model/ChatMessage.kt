package id.steveimm.pocketpilot.ui.chat.model

import id.steveimm.pocketpilot.protocol.CompletionHandoff

/** ChatMessage - UI data classes for the chat conversation. */
sealed interface ChatMessage {
    val id: String
    val timestamp: Long

    /** User message bubble. */
    data class User(
        override val id: String,
        override val timestamp: Long,
        val text: String
    ) : ChatMessage

    /** Agent message bubble with streaming support and interleaved content. */
    data class Agent(
        override val id: String,
        override val timestamp: Long,
        val contentBlocks: List<ContentBlock>,
        val state: AgentMessageState,
        val rowState: RowState = RowState.Live,
        /** Wall-clock time when this response ended. */
        val completedTimestamp: Long? = null,
        /** VD completion handoff metadata — populated only when [TaskCompleted] carries one (i.e. the row finished on the Virtual
         * Display). Drives the explicit "Open <App>" CTA in the final region. Null for accessibility completions and historical rows. */
        val handoff: CompletionHandoff? = null,
    ) : ChatMessage
}

enum class RowState { Live, Waiting, Complete, Stopped, Error }

/** AgentMessageState - The visual state of an agent message. */
enum class AgentMessageState {
    /** Agent is processing before first delta (shows thinking indicator) */
    Thinking,

    /** Agent is streaming text (shows blinking cursor) */
    Streaming,

    /** Message is complete (no cursor) */
    Complete
}

/** ActionCardData - Data for displaying a tool execution in the chat. */
data class ActionCardData(
    val id: String,
    val toolName: String,
    val description: String,
    val state: ActionState,
    val resultSummary: String? = null,
    val expandedContent: String? = null
)

/** ActionState - The execution state of an action. */
enum class ActionState {
    /** Action has been proposed but not yet executed */
    Proposed,

    /** Action is currently executing */
    Executing,

    /** Action completed successfully */
    Success,

    /** Action failed */
    Failed,

    /** Action was skipped (e.g., denied by user or policy) */
    Skipped
}

/** ChatUiState - Overall UI state for the chat screen. */
data class ChatUiState(
    val showEmptyState: Boolean = true
)
