package id.steveimm.pocketpilot.history

import id.steveimm.pocketpilot.history.model.ContentBlockRecord
import id.steveimm.pocketpilot.history.model.appendTextDelta
import id.steveimm.pocketpilot.history.model.appendReasoningDelta
import id.steveimm.pocketpilot.history.model.withFinalAnswer

internal data class AgentMessageSnapshot(
    val id: String,
    val startTimestamp: Long,
    val blocks: List<ContentBlockRecord>
)

internal class AgentMessageBuffer {
    private var messageId: String? = null
    private var startTimestamp: Long = 0L
    private var contentBlocks = emptyList<ContentBlockRecord>()

    fun hasActiveMessage(): Boolean = messageId != null

    fun start(id: String, timestamp: Long) {
        messageId = id
        startTimestamp = timestamp
        contentBlocks = emptyList()
    }

    fun clear() {
        messageId = null
        startTimestamp = 0L
        contentBlocks = emptyList()
    }

    fun appendText(turnId: String, delta: String) {
        contentBlocks = contentBlocks.appendTextDelta(turnId, delta)
    }

    fun appendReasoning(turnId: String, delta: String) {
        contentBlocks = contentBlocks.appendReasoningDelta(turnId, delta)
    }

    fun recordFinalAnswer(text: String) {
        contentBlocks = contentBlocks.withFinalAnswer(text)
    }

    /** Append an inline error/warning text block (SessionError, "⚠ …"). */
    fun recordErrorText(text: String) {
        contentBlocks = contentBlocks + ContentBlockRecord.Text(text)
    }

    fun recordAction(action: ContentBlockRecord.Action) {
        contentBlocks = contentBlocks + action
    }

    fun updateActionState(actionId: String, state: String, result: String?) {
        val updated = contentBlocks.map { block ->
            if (block is ContentBlockRecord.Action && block.id == actionId) {
                block.copy(state = state, resultSummary = result)
            } else {
                block
            }
        }
        contentBlocks = updated
    }

    fun buildPartialSnapshot(): AgentMessageSnapshot? {
        val id = messageId ?: return null
        if (contentBlocks.isEmpty()) return null
        return AgentMessageSnapshot(id, startTimestamp, contentBlocks)
    }

    fun finalizeSnapshot(): AgentMessageSnapshot? {
        val id = messageId ?: return null
        if (contentBlocks.isEmpty()) {
            clear()
            return null
        }
        val snapshot = AgentMessageSnapshot(id, startTimestamp, contentBlocks.toList())
        clear()
        return snapshot
    }

}
