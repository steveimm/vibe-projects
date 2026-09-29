package id.steveimm.pocketpilot.history.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** A message in a session, can be user or agent. */
@Serializable
sealed interface MessageRecord {
    val id: String
    val timestamp: Long

    /** User message. */
    @Serializable
    @SerialName("user")
    data class User(
        override val id: String,
        override val timestamp: Long,
        val text: String
    ) : MessageRecord

    /** Agent message with content blocks. */
    @Serializable
    @SerialName("agent")
    data class Agent(
        override val id: String,
        override val timestamp: Long,
        val contentBlocks: List<ContentBlockRecord>,
        val isComplete: Boolean,
        /** Wall-clock when the row sealed (TaskCompleted / SessionError). Null while the message is still streaming. Persisted so
         * resumed history rows can compute elapsed time per Track A spec §4.5/§5.2. */
        val completedTimestamp: Long? = null,
        /** Persisted row-level state ("live" / "waiting" / "complete" / "error"). Null on legacy records — derived from [isComplete] on
         * read. */
        val rowState: String? = null
    ) : MessageRecord
}

/** Persisted content block (text or action). */
@Serializable
sealed interface ContentBlockRecord {
    /** Text content from the LLM response. */
    @Serializable
    @SerialName("text")
    data class Text(val text: String) : ContentBlockRecord

    /** Concluding answer (per Turn.kt:205-209 stop criteria) — promoted from [Text] by the chat reducer when the row sealed. */
    @Serializable
    @SerialName("final_text")
    data class FinalText(val text: String) : ContentBlockRecord

    /** Reasoning received from the model server. */
    @Serializable
    @SerialName("reasoning")
    data class Reasoning(val text: String) : ContentBlockRecord

    /** Read older captions as ordinary text; new sessions never write this type. */
    @Serializable
    @SerialName("thought")
    data class LegacyStepCaption(val text: String) : ContentBlockRecord

    /** An action card (tool execution). */
    @Serializable
    @SerialName("action")
    data class Action(
        val id: String,
        val toolName: String,
        val description: String,
        /** Action state: "proposed", "executing", "success", "failed", "skipped" */
        val state: String,
        val resultSummary: String? = null
    ) : ContentBlockRecord
}
