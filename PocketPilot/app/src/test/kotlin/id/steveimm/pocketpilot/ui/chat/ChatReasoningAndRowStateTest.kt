package id.steveimm.pocketpilot.ui.chat

import androidx.compose.runtime.mutableStateListOf
import com.google.common.truth.Truth.assertThat
import id.steveimm.pocketpilot.protocol.ActionExecuted
import id.steveimm.pocketpilot.protocol.ActionOutcome
import id.steveimm.pocketpilot.protocol.ActionProposed
import id.steveimm.pocketpilot.protocol.MessageDelta
import id.steveimm.pocketpilot.protocol.SessionError
import id.steveimm.pocketpilot.protocol.SessionId
import id.steveimm.pocketpilot.protocol.TaskCompleted
import id.steveimm.pocketpilot.protocol.TaskOutcome
import id.steveimm.pocketpilot.protocol.TaskStarted
import id.steveimm.pocketpilot.protocol.ReasoningDelta
import id.steveimm.pocketpilot.ui.chat.model.ChatMessage
import id.steveimm.pocketpilot.ui.chat.model.ChatUiState
import id.steveimm.pocketpilot.ui.chat.model.ContentBlock
import id.steveimm.pocketpilot.ui.chat.model.RowState
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Test

/** Track A spec §3 + §5: ReasoningDelta routing into ContentBlock.Reasoning, plus the four-state RowState machine (Live → Complete /
 * Error). */
class ChatReasoningAndRowStateTest {

    private val sessionId = SessionId("s1")

    private class Fixture {
        val uiState = MutableStateFlow(ChatUiState())
        val messages = mutableStateListOf<ChatMessage>()
        val reducer = ChatEventReducer(
            uiState = uiState,
            messages = messages,
            stateLock = Any(),
        )
    }

    @Test
    fun `reasoning chunks merge within a turn and stay separate from answers`() {
        val f = Fixture()
        f.reducer.handle(TaskStarted(sessionId, 100L, taskId = "task-1", input = "go"))
        f.reducer.handle(ReasoningDelta(sessionId, 110L, turnId = "t1", delta = "First "))
        f.reducer.handle(ReasoningDelta(sessionId, 111L, turnId = "t1", delta = "inspect."))
        f.reducer.handle(MessageDelta(sessionId, 112L, turnId = "t1", delta = "Done."))
        f.reducer.handle(ReasoningDelta(sessionId, 113L, turnId = "t2", delta = "New turn."))
        val blocks = (f.messages.last() as ChatMessage.Agent).contentBlocks
        assertThat(blocks).containsExactly(
            ContentBlock.Reasoning("First inspect.", "t1"), ContentBlock.Text("Done.", "t1"), ContentBlock.Reasoning("New turn.", "t2"),
        ).inOrder()
    }

    @Test
    fun `reasoning update appends a reasoning block`() {
        val f = Fixture()
        f.reducer.handle(TaskStarted(sessionId, 100L, taskId = "task-1", input = "go"))

        f.reducer.handle(ReasoningDelta(sessionId, 110L, turnId = "t110", delta = "I should open Settings"))

        val agent = f.messages.last() as ChatMessage.Agent
        val thought = agent.contentBlocks.single() as ContentBlock.Reasoning
        assertThat(thought.text).isEqualTo("I should open Settings")
    }

    @Test
    fun `reasoning from different turns produces separate blocks`() {
        val f = Fixture()
        f.reducer.handle(TaskStarted(sessionId, 100L, taskId = "task-1", input = "go"))

        f.reducer.handle(ReasoningDelta(sessionId, 110L, turnId = "t110", delta = "step one"))
        f.reducer.handle(ReasoningDelta(sessionId, 111L, turnId = "t111", delta = "step two"))
        f.reducer.handle(ReasoningDelta(sessionId, 112L, turnId = "t112", delta = "step three"))

        val agent = f.messages.last() as ChatMessage.Agent
        val thoughts = agent.contentBlocks.filterIsInstance<ContentBlock.Reasoning>()
        assertThat(thoughts.map { it.text })
            .containsExactly("step one", "step two", "step three")
            .inOrder()
    }

    @Test
    fun `thought interleaved with action preserves chronological order`() {
        val f = Fixture()
        f.reducer.handle(TaskStarted(sessionId, 100L, taskId = "task-1", input = "go"))

        f.reducer.handle(ReasoningDelta(sessionId, 110L, turnId = "t110", delta = "open Settings"))
        f.reducer.handle(
            ActionProposed(sessionId, 111L, actionId = "a1", toolName = "click", description = "tap")
        )
        f.reducer.handle(ReasoningDelta(sessionId, 112L, turnId = "t112", delta = "now find Accessibility"))

        val agent = f.messages.last() as ChatMessage.Agent
        val kinds = agent.contentBlocks.map { it::class.simpleName }
        assertThat(kinds).containsExactly("Reasoning", "Action", "Reasoning").inOrder()
    }

    @Test
    fun `interleaved reasoning does not split the answer`() {
        val f = Fixture()
        f.reducer.handle(TaskStarted(sessionId, 100L, taskId = "task-1", input = "go"))
        f.reducer.handle(MessageDelta(sessionId, 105L, turnId = "t1", delta = "Hello"))
        f.reducer.handle(ReasoningDelta(sessionId, 110L, turnId = "t1", delta = "A greeting."))
        f.reducer.handle(MessageDelta(sessionId, 115L, turnId = "t1", delta = ", world."))

        val agent = f.messages.last() as ChatMessage.Agent
        assertThat(agent.contentBlocks).containsExactly(
            ContentBlock.Reasoning("A greeting.", "t1"), ContentBlock.Text("Hello, world.", "t1"),
        ).inOrder()
    }

    @Test
    fun `empty thought is ignored`() {
        val f = Fixture()
        f.reducer.handle(TaskStarted(sessionId, 100L, taskId = "task-1", input = "go"))

        f.reducer.handle(ReasoningDelta(sessionId, 110L, turnId = "t110", delta = ""))

        val agent = f.messages.last() as ChatMessage.Agent
        assertThat(agent.contentBlocks.filterIsInstance<ContentBlock.Reasoning>()).isEmpty()
    }

    @Test
    fun `task started opens row in Live state`() {
        val f = Fixture()
        f.reducer.handle(TaskStarted(sessionId, 100L, taskId = "task-1", input = "go"))

        val agent = f.messages.last() as ChatMessage.Agent
        assertThat(agent.rowState).isEqualTo(RowState.Live)
    }

    @Test
    fun `task completion transitions row to Complete`() {
        val f = Fixture()
        f.reducer.handle(TaskStarted(sessionId, 100L, taskId = "task-1", input = "go"))

        f.reducer.handle(
            TaskCompleted(
                sessionId = sessionId,
                timestamp = 200L,
                taskId = "task-1",
                result = "done",
                outcome = TaskOutcome.FINISHED
            )
        )

        val agent = f.messages.last() as ChatMessage.Agent
        assertThat(agent.rowState).isEqualTo(RowState.Complete)
    }

    @Test
    fun `session error transitions row to Error`() {
        val f = Fixture()
        f.reducer.handle(TaskStarted(sessionId, 100L, taskId = "task-1", input = "go"))

        f.reducer.handle(SessionError(sessionId, 150L, message = "boom"))

        val agent = f.messages.last() as ChatMessage.Agent
        assertThat(agent.rowState).isEqualTo(RowState.Error)
    }

    @Test
    fun `error followed by next task keeps prior row in Error not Complete`() {
        // Locked-open invariant: an Error row stays Error even when the next
        // user turn closes it.
        val f = Fixture()
        f.reducer.handle(TaskStarted(sessionId, 100L, taskId = "task-1", input = "go"))
        f.reducer.handle(SessionError(sessionId, 150L, message = "boom"))

        f.reducer.handle(TaskStarted(sessionId, 200L, taskId = "task-2", input = "again"))

        val firstAgent = f.messages.first { it is ChatMessage.Agent } as ChatMessage.Agent
        assertThat(firstAgent.rowState).isEqualTo(RowState.Error)
    }

    @Test
    fun `reasoning after an action creates a separate block`() {
        val f = Fixture()
        f.reducer.handle(TaskStarted(sessionId, 100L, taskId = "task-1", input = "go"))
        f.reducer.handle(
            ActionProposed(sessionId, 101L, actionId = "a1", toolName = "click", description = "tap")
        )
        f.reducer.handle(
            ActionExecuted(
                sessionId = sessionId,
                timestamp = 102L,
                actionId = "a1",
                toolName = "click",
                outcome = ActionOutcome.SUCCESS,
                result = "ok"
            )
        )
        f.reducer.handle(ReasoningDelta(sessionId, 103L, turnId = "t103", delta = "now what"))

        val agent = f.messages.last() as ChatMessage.Agent
        assertThat(agent.contentBlocks).hasSize(2)
        assertThat(agent.contentBlocks[0]).isInstanceOf(ContentBlock.Action::class.java)
        assertThat((agent.contentBlocks[1] as ContentBlock.Reasoning).text).isEqualTo("now what")
    }
}
