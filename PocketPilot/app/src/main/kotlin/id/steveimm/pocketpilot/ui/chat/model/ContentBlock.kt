package id.steveimm.pocketpilot.ui.chat.model

/** ContentBlock - A unit of content in an agent message. */
sealed interface ContentBlock {
    /** Streaming text from the LLM mid-turn (narrative, may be interrupted). */
    data class Text(val text: String) : ContentBlock

    /** The row's concluding answer. Promoted from [Text] by the reducer. */
    data class FinalText(val text: String) : ContentBlock

    /** Agent reasoning emitted via `ThoughtUpdate`. One block per update. */
    data class Thought(val text: String) : ContentBlock

    /** An action card (tool execution). */
    data class Action(val data: ActionCardData) : ContentBlock
}
