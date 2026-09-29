package id.steveimm.pocketpilot.ui.chat

import androidx.compose.runtime.snapshots.SnapshotStateList
import id.steveimm.pocketpilot.history.model.MessageConverter
import id.steveimm.pocketpilot.history.model.appendTextDelta
import id.steveimm.pocketpilot.history.model.appendReasoningDelta
import id.steveimm.pocketpilot.protocol.ActionExecuted
import id.steveimm.pocketpilot.protocol.ActionOutcome
import id.steveimm.pocketpilot.protocol.ActionProposed
import id.steveimm.pocketpilot.protocol.AgentEvent
import id.steveimm.pocketpilot.protocol.MessageDelta
import id.steveimm.pocketpilot.protocol.SessionError
import id.steveimm.pocketpilot.protocol.SupplementReceived
import id.steveimm.pocketpilot.protocol.TaskCompleted
import id.steveimm.pocketpilot.protocol.TaskStarted
import id.steveimm.pocketpilot.protocol.ReasoningDelta
import id.steveimm.pocketpilot.protocol.TurnPhaseChanged
import id.steveimm.pocketpilot.ui.chat.model.ActionCardData
import id.steveimm.pocketpilot.ui.chat.model.ActionState
import id.steveimm.pocketpilot.ui.chat.model.AgentMessageState
import id.steveimm.pocketpilot.ui.chat.model.ChatMessage
import id.steveimm.pocketpilot.ui.chat.model.ChatUiState
import id.steveimm.pocketpilot.ui.chat.model.ContentBlock
import id.steveimm.pocketpilot.ui.chat.model.RowState
import id.steveimm.pocketpilot.ui.common.formatToolName
import java.util.UUID
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.update

internal class ChatEventReducer(
    private val uiState: MutableStateFlow<ChatUiState>,
    private val messages: SnapshotStateList<ChatMessage>,
    private val stateLock: Any,
) {
    fun handle(event: AgentEvent) {
        synchronized(stateLock) {
            when (event) {
                is TaskStarted -> handleTaskStarted(event)
                is TurnPhaseChanged -> Unit
                is MessageDelta -> handleMessageDelta(event)
                is ReasoningDelta -> handleReasoningDelta(event)
                is ActionProposed -> handleActionProposed(event)
                is ActionExecuted -> handleActionExecuted(event)
                is TaskCompleted -> handleTaskCompleted(event)
                is SessionError -> handleError(event)
                is SupplementReceived -> handleSupplement(event)
                else -> Unit
            }
        }
    }

    private fun handleTaskStarted(event: TaskStarted) {
        uiState.update { it.copy(showEmptyState = false) }
        insertUserTurn(event.input, event.timestamp, agentId = event.taskId)
    }

    private fun handleMessageDelta(event: MessageDelta) {
        if (event.delta.isEmpty()) return
        updateLastAgentMessage { msg ->
            val blocks = MessageConverter.toContentRecords(msg.contentBlocks).appendTextDelta(event.turnId, event.delta)
            msg.copy(contentBlocks = MessageConverter.fromContentRecords(blocks), state = AgentMessageState.Streaming)
        }
    }

    private fun handleReasoningDelta(event: ReasoningDelta) {
        if (event.delta.isEmpty()) return
        updateLastAgentMessage { msg ->
            val blocks = MessageConverter.toContentRecords(msg.contentBlocks).appendReasoningDelta(event.turnId, event.delta)
            msg.copy(contentBlocks = MessageConverter.fromContentRecords(blocks), state = AgentMessageState.Streaming)
        }
    }

    private fun handleActionProposed(event: ActionProposed) {
        val newAction =
            ActionCardData(
                id = event.actionId,
                toolName = formatToolName(event.toolName),
                description = event.description,
                state = ActionState.Proposed,
                resultSummary = null
            )

        updateLastAgentMessage { msg ->
            msg.copy(contentBlocks = msg.contentBlocks + ContentBlock.Action(newAction))
        }
    }

    private fun handleActionExecuted(event: ActionExecuted) {
        val newState = when (event.outcome) {
            ActionOutcome.SUCCESS -> ActionState.Success
            ActionOutcome.FAILED -> ActionState.Failed
            ActionOutcome.SKIPPED -> ActionState.Skipped
        }
        updateLastAgentMessage { msg ->
            val (updatedExisting, found) =
                updateActionBlockForExecution(
                    blocks = msg.contentBlocks,
                    actionId = event.actionId,
                    newState = newState,
                    resultSummary = event.result
                )

            val updatedBlocks =
                if (found) {
                    updatedExisting
                } else {
                    val newAction =
                        ActionCardData(
                            id = event.actionId,
                            toolName = formatToolName(event.toolName),
                            description = event.result ?: event.toolName,
                            state = newState,
                            resultSummary = event.result
                        )
                    msg.contentBlocks + ContentBlock.Action(newAction)
                }
            msg.copy(contentBlocks = updatedBlocks)
        }
    }

    private fun handleTaskCompleted(event: TaskCompleted) {
        val isError = event.outcome == id.steveimm.pocketpilot.protocol.TaskOutcome.ERROR
        appendCompletionToMessages(
            messages = messages,
            rawResult = event.result,
            timestamp = event.timestamp,
            taskId = event.taskId,
            isError = isError,
            handoff = event.handoff,
        )
    }

    private fun handleError(event: SessionError) {
        val errorText = "⚠️ ${event.message}"
        val index = messages.indexOfLast { it is ChatMessage.Agent }
        if (index >= 0) {
            val current = messages[index] as ChatMessage.Agent
            messages[index] = current.copy(
                contentBlocks = current.contentBlocks + ContentBlock.Text(errorText),
                state = AgentMessageState.Complete,
                rowState = RowState.Error,
                completedTimestamp = event.timestamp
            )
        } else {
            messages.add(
                ChatMessage.Agent(
                    id = "error-${event.timestamp}",
                    timestamp = event.timestamp,
                    contentBlocks = listOf(ContentBlock.Text(errorText)),
                    state = AgentMessageState.Complete,
                    rowState = RowState.Error,
                    completedTimestamp = event.timestamp
                )
            )
            uiState.update { it.copy(showEmptyState = false) }
        }
    }

    private fun handleSupplement(event: SupplementReceived) {
        insertUserTurn(event.text, event.timestamp)
    }

    /** Universal "user message splits the conversation" operation. */
    private fun insertUserTurn(text: String, timestamp: Long, agentId: String? = null) {
        // 1. Close current agent message (idempotent if already Complete or absent)
        updateLastAgentMessage { msg ->
            val sealing = msg.state != AgentMessageState.Complete
            msg.copy(
                state = AgentMessageState.Complete,
                rowState = if (msg.rowState == RowState.Error) RowState.Error else RowState.Complete,
                // Only stamp on the Live/Waiting → terminal transition; preserve existing values (including null on legacy rows that never
                // had their completion timestamp persisted).
                completedTimestamp = if (sealing) msg.completedTimestamp ?: timestamp else msg.completedTimestamp
            )
        }

        // 2. Insert user message
        messages.add(
            ChatMessage.User(
                id = UUID.randomUUID().toString(),
                timestamp = timestamp,
                text = text
            )
        )

        // 3. New agent message for subsequent actions
        val id = agentId ?: "supplement-$timestamp"
        messages.add(
            ChatMessage.Agent(
                id = id,
                timestamp = timestamp,
                contentBlocks = emptyList(),
                state = AgentMessageState.Thinking,
                rowState = RowState.Live,
                userPrompt = text,
            )
        )
    }

    private inline fun updateLastAgentMessage(transform: (ChatMessage.Agent) -> ChatMessage.Agent) {
        val index = messages.indexOfLast { it is ChatMessage.Agent }
        if (index >= 0) {
            val current = messages[index] as ChatMessage.Agent
            // Drop late streaming events that arrive after the row sealed (e.g. ReasoningDelta emitted after TaskCompleted). Sealed rows
            // are immutable per Track A spec §5.
            if (current.state == AgentMessageState.Complete) return
            messages[index] = transform(current)
        }
    }
}
