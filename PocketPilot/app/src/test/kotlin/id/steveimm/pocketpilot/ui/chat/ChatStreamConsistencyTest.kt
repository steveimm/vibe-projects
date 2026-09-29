package id.steveimm.pocketpilot.ui.chat

import androidx.compose.runtime.mutableStateListOf
import com.google.common.truth.Truth.assertThat
import id.steveimm.pocketpilot.history.AgentMessageBuffer
import id.steveimm.pocketpilot.history.model.ContentBlockRecord
import id.steveimm.pocketpilot.history.model.MessageConverter
import id.steveimm.pocketpilot.history.model.MessageRecord
import id.steveimm.pocketpilot.protocol.*
import id.steveimm.pocketpilot.ui.chat.model.*
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Test

class ChatStreamConsistencyTest {
    private val session = SessionId("chat")

    @Test
    fun `interleaved streams and canonical completion agree live and after reload`() {
        val messages = mutableStateListOf<ChatMessage>()
        val reducer = ChatEventReducer(MutableStateFlow(ChatUiState()), messages, Any())
        val recorder = AgentMessageBuffer()
        reducer.handle(TaskStarted(session, 1L, "task", "hello"))
        recorder.start("task", 1L)

        fun text(turn: String, delta: String) {
            reducer.handle(MessageDelta(session, 2L, turn, delta))
            recorder.appendText(turn, delta)
        }
        fun reasoning(turn: String, delta: String) {
            reducer.handle(ReasoningDelta(session, 2L, turn, delta))
            recorder.appendReasoning(turn, delta)
        }
        fun assertMatchingStreams() {
            val saved = recorder.buildPartialSnapshot()!!.blocks
            assertThat((messages.last() as ChatMessage.Agent).contentBlocks)
                .containsExactlyElementsIn(MessageConverter.fromContentRecords(saved)).inOrder()
        }

        reasoning("t1", "Inspect")
        text("t1", "I'll check")
        reasoning("t1", ".\n")
        text("t1", " the screen.")
        assertMatchingStreams()
        reducer.handle(ActionProposed(session, 3L, "action", "read_screen", "Read screen"))
        recorder.recordAction(ContentBlockRecord.Action("action", "read_screen", "Read screen", "proposed"))
        text("t2", "Hello")
        reasoning("t2", "Reply")
        text("t2", ", world")
        reasoning("t2", ".\n")
        assertMatchingStreams()

        val partial = recorder.buildPartialSnapshot()!!
        messages[messages.lastIndex] = MessageConverter.fromRecord(MessageRecord.Agent("task", 1L, partial.blocks, false))
        val rebound = ChatEventReducer(MutableStateFlow(ChatUiState()), messages, Any())
        rebound.handle(MessageDelta(session, 4L, "t2", "!"))
        recorder.appendText("t2", "!")
        assertMatchingStreams()
        assertThat(partial.blocks.filterIsInstance<ContentBlockRecord.Text>().last().text).isEqualTo("Hello, world")

        val answer = "Hello, world! This is the complete answer."
        rebound.handle(TaskCompleted(session, 5L, "task", result = answer, outcome = TaskOutcome.FINISHED))
        recorder.recordFinalAnswer(answer)
        val recorded = recorder.finalizeSnapshot()!!
        val restored = MessageConverter.fromRecord(MessageRecord.Agent("task", 1L, recorded.blocks, true)) as ChatMessage.Agent
        val live = messages.last() as ChatMessage.Agent
        assertThat(live.contentBlocks).containsExactlyElementsIn(restored.contentBlocks).inOrder()
        assertThat(live.contentBlocks.filterIsInstance<ContentBlock.Text>().map { it.text })
            .containsExactly("I'll check the screen.")
        assertThat(live.contentBlocks.filterIsInstance<ContentBlock.Reasoning>().map { it.text })
            .containsExactly("Inspect.\n", "Reply.\n").inOrder()
        assertThat(live.contentBlocks.last()).isEqualTo(ContentBlock.FinalText(answer))
    }

    @Test
    fun `stopped and failed responses keep partial text without inventing a final answer`() {
        for (outcome in listOf(TaskOutcome.USER_STOPPED, TaskOutcome.ERROR)) {
            val messages = mutableStateListOf<ChatMessage>()
            val reducer = ChatEventReducer(MutableStateFlow(ChatUiState()), messages, Any())
            reducer.handle(TaskStarted(session, 1L, "task", "go"))
            reducer.handle(MessageDelta(session, 2L, "t1", "A partial reply"))
            reducer.handle(TaskCompleted(session, 3L, "task", result = null, outcome = outcome))
            val restored = MessageConverter.fromRecord(MessageConverter.toRecord(messages.last())) as ChatMessage.Agent
            assertThat(restored.contentBlocks.filterIsInstance<ContentBlock.FinalText>()).isEmpty()
            assertThat(restored.contentBlocks.filterIsInstance<ContentBlock.Text>().first().text).isEqualTo("A partial reply")
        }
    }
}
