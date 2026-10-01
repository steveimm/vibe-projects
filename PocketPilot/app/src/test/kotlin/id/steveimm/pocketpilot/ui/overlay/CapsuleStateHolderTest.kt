package id.steveimm.pocketpilot.ui.overlay

import com.google.common.truth.Truth.assertThat
import id.steveimm.pocketpilot.protocol.AskUserType
import id.steveimm.pocketpilot.protocol.SessionEndReason
import id.steveimm.pocketpilot.protocol.TaskOutcome
import id.steveimm.pocketpilot.ui.overlay.model.CapsuleMode
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class CapsuleStateHolderTest {

    private lateinit var scope: TestScope
    private lateinit var holder: CapsuleStateHolder

    @Before
    fun setUp() {
        scope = TestScope()
        holder = CapsuleStateHolder()
    }

    @Test
    fun `clearing conversation removes floating results drafts and task controls`() {
        holder.onTaskStarted("old", "private request")
        holder.inputDraft.value = "unsent request"
        holder.responseDraft.value = "private answer"
        holder.onStopRequested()
        holder.onTaskCompleted(TaskOutcome.FINISHED, "private result")

        holder.clearConversation()
        assertThat(holder.mode.value).isEqualTo(CapsuleMode.Hidden)
        assertThat(holder.inputDraft.value).isEmpty()
        assertThat(holder.responseDraft.value).isEmpty()
        assertThat(holder.isStopPending.value).isFalse()
        assertThat(holder.hasActiveTask).isFalse()
    }

    @Test
    fun `initial mode is Hidden`() {
        assertThat(holder.mode.value).isEqualTo(CapsuleMode.Hidden)
    }

    @Test
    fun `progress starts empty until assistant content arrives`() {
        holder.onTaskStarted("task1", "Open Settings")
        val mode = holder.mode.value as CapsuleMode.Running
        assertThat(mode.thought).isEmpty()
        assertThat(id.steveimm.pocketpilot.ui.overlay.model.CapsuleRenderSpec.from(mode).thought.text).isEqualTo("Thinking")
    }

    @Test
    fun `commentary survives phase changes while tools remain separate`() {
        holder.onTaskStarted("task1", "Open Settings")
        holder.onMessageDelta("turn1", "I will open ")
        holder.onMessageDelta("turn1", "Settings.")
        holder.onActionProposed("open_app Settings")
        holder.setTurnPhase(id.steveimm.pocketpilot.protocol.TurnPhase.EXECUTION)
        assertThat((holder.mode.value as CapsuleMode.Running).thought).isEqualTo("I will open Settings.")
        assertThat(holder.lastToolCall.value).isEqualTo("open_app Settings")
        holder.setTurnPhase(id.steveimm.pocketpilot.protocol.TurnPhase.PLANNING)
        assertThat((holder.mode.value as CapsuleMode.Running).thought).isEqualTo("I will open Settings.")
        holder.onMessageDelta("turn2", "Now checking Display.")
        assertThat((holder.mode.value as CapsuleMode.Running).thought).isEqualTo("Now checking Display.")
    }

    @Test
    fun `new conversation drops commentary tools and late output`() {
        holder.onTaskStarted("old", "old request")
        holder.onMessageDelta("turn1", "Previous commentary")
        holder.onActionProposed("tap [400, 600]")
        holder.clearConversation()
        holder.onMessageDelta("turn1", "late output")
        holder.onActionProposed("late tool")
        assertThat(holder.mode.value).isEqualTo(CapsuleMode.Hidden)
        assertThat(holder.lastToolCall.value).isNull()
        holder.onTaskStarted("new", "new request")
        assertThat((holder.mode.value as CapsuleMode.Running).thought).isEmpty()
        assertThat(holder.lastToolCall.value).isNull()
    }

    @Test
    fun `onTaskStarted resets from any state`() {
        holder.onError("some error")
        assertThat(holder.mode.value).isInstanceOf(CapsuleMode.Error::class.java)
        holder.onTaskStarted("task2", "new task")
        assertThat(holder.mode.value).isInstanceOf(CapsuleMode.Running::class.java)
    }

    @Test
    fun `phase changes keep the Thinking fallback without synthetic action text`() {
        holder.onTaskStarted("task1", "input")
        holder.setTurnPhase(id.steveimm.pocketpilot.protocol.TurnPhase.PLANNING)
        assertThat((holder.mode.value as CapsuleMode.Running).thought).isEmpty()
    }

    @Test
    fun `setTurnPhase ignored when not in Running mode`() {
        holder.onTaskStarted("task1", "input")
        holder.onTakeoverRequested()
        val modeBefore = holder.mode.value
        holder.setTurnPhase(id.steveimm.pocketpilot.protocol.TurnPhase.PLANNING)
        assertThat(holder.mode.value).isEqualTo(modeBefore)
    }

    @Test
    fun `onTakeoverRequested transitions from Running to TakeoverPending`() {
        holder.onTaskStarted("task1", "input")
        holder.setTurnPhase(id.steveimm.pocketpilot.protocol.TurnPhase.PLANNING)
        holder.onTakeoverRequested()
        val mode = holder.mode.value
        assertThat(mode).isInstanceOf(CapsuleMode.TakeoverPending::class.java)
        assertThat((mode as CapsuleMode.TakeoverPending).lastThought).isEmpty()
    }

    @Test
    fun `onTakeoverRequested ignored when not Running`() {
        // Hidden state
        holder.onTakeoverRequested()
        assertThat(holder.mode.value).isEqualTo(CapsuleMode.Hidden)
    }

    @Test
    fun `onTakeoverConfirmed transitions from TakeoverPending to Takeover`() {
        holder.onTaskStarted("task1", "input")
        holder.setTurnPhase(id.steveimm.pocketpilot.protocol.TurnPhase.PLANNING)
        holder.onTakeoverRequested()
        holder.onTakeoverConfirmed()
        val mode = holder.mode.value
        assertThat(mode).isInstanceOf(CapsuleMode.Takeover::class.java)
        assertThat((mode as CapsuleMode.Takeover).lastThought).isEmpty()
    }

    @Test
    fun `onResumed transitions from Takeover to Running`() {
        holder.onTaskStarted("task1", "input")
        holder.onTakeoverRequested()
        holder.onTakeoverConfirmed()
        holder.onResumed()
        val mode = holder.mode.value
        assertThat(mode).isInstanceOf(CapsuleMode.Running::class.java)
        assertThat((mode as CapsuleMode.Running).thought).isEmpty()
    }

    @Test
    fun `onResumed ignored when not in takeover state`() {
        holder.onTaskStarted("task1", "input")
        val modeBefore = holder.mode.value
        holder.onResumed()
        assertThat(holder.mode.value).isEqualTo(modeBefore)
    }

    @Test
    fun `onAskUser QUESTION sets WaitingForInput`() {
        holder.onAskUser(AskUserType.QUESTION, "Which one?", "call1")
        val mode = holder.mode.value
        assertThat(mode).isInstanceOf(CapsuleMode.WaitingForInput::class.java)
        assertThat((mode as CapsuleMode.WaitingForInput).question).isEqualTo("Which one?")
        assertThat(mode.callId).isEqualTo("call1")
    }

    @Test
    fun `onAskUser ACTION sets WaitingForAction`() {
        holder.onAskUser(AskUserType.ACTION, "Open Settings", "call2")
        val mode = holder.mode.value
        assertThat(mode).isInstanceOf(CapsuleMode.WaitingForAction::class.java)
        assertThat((mode as CapsuleMode.WaitingForAction).instruction).isEqualTo("Open Settings")
        assertThat(mode.callId).isEqualTo("call2")
    }

    @Test
    fun `onUserResponseSent transitions to Running from WaitingForInput`() {
        holder.onAskUser(AskUserType.QUESTION, "Which one?", "call1")
        holder.onUserResponseSent("call1")
        val mode = holder.mode.value
        assertThat(mode).isInstanceOf(CapsuleMode.Running::class.java)
        assertThat((mode as CapsuleMode.Running).thought).isEmpty()
    }

    @Test
    fun `onUserResponseSent ignored when callId mismatches waiting call`() {
        holder.onAskUser(AskUserType.QUESTION, "Which one?", "call1")
        val modeBefore = holder.mode.value
        holder.onUserResponseSent("wrong-call")
        assertThat(holder.mode.value).isEqualTo(modeBefore)
    }

    @Test
    fun `onUserResponseSent ignored when no pending ask`() {
        holder.onTaskStarted("task1", "input")
        val modeBefore = holder.mode.value
        holder.onUserResponseSent("call1")
        assertThat(holder.mode.value).isEqualTo(modeBefore)
    }

    @Test
    fun `onStopRequested marks stop pending in running mode`() {
        holder.onTaskStarted("task1", "input")
        val accepted = holder.onStopRequested()
        assertThat(accepted).isTrue()
        assertThat(holder.isStopPending.value).isTrue()
    }

    @Test
    fun `onStopRequested ignored when stop already pending`() {
        holder.onTaskStarted("task1", "input")
        assertThat(holder.onStopRequested()).isTrue()
        assertThat(holder.onStopRequested()).isFalse()
        assertThat(holder.isStopPending.value).isTrue()
    }

    @Test
    fun `stop pending is cleared on terminal events`() {
        holder.onTaskStarted("task1", "input")
        holder.onStopRequested()
        holder.onTaskCompleted(TaskOutcome.USER_STOPPED)
        assertThat(holder.isStopPending.value).isFalse()
    }

    @Test
    fun `stop pending is cleared on new task start`() {
        holder.onTaskStarted("task1", "input")
        holder.onStopRequested()
        holder.onTaskStarted("task2", "next")
        assertThat(holder.isStopPending.value).isFalse()
    }

    @Test
    fun `onTaskCompleted FINISHED sets Done`() {
        holder.onTaskStarted("task1", "input")
        holder.onTaskCompleted(TaskOutcome.FINISHED, "All done")
        val mode = holder.mode.value
        assertThat(mode).isInstanceOf(CapsuleMode.Done::class.java)
        assertThat((mode as CapsuleMode.Done).message).isEqualTo("All done")
    }

    @Test
    fun `onTaskCompleted FINISHED uses default message when result missing`() {
        holder.onTaskStarted("task1", "input")
        holder.onTaskCompleted(TaskOutcome.FINISHED, null)
        val mode = holder.mode.value
        assertThat(mode).isInstanceOf(CapsuleMode.Done::class.java)
        assertThat((mode as CapsuleMode.Done).message).isEqualTo("Task completed")
    }

    @Test
    fun `onTaskCompleted FINISHED uses default message when result blank`() {
        holder.onTaskStarted("task1", "input")
        holder.onTaskCompleted(TaskOutcome.FINISHED, "   ")
        val mode = holder.mode.value
        assertThat(mode).isInstanceOf(CapsuleMode.Done::class.java)
        assertThat((mode as CapsuleMode.Done).message).isEqualTo("Task completed")
    }

    @Test
    fun `onTaskCompleted ERROR sets Error`() {
        holder.onTaskStarted("task1", "input")
        holder.onTaskCompleted(TaskOutcome.ERROR)
        val mode = holder.mode.value
        assertThat(mode).isInstanceOf(CapsuleMode.Error::class.java)
    }

    @Test
    fun `onTaskCompleted ignored when already Hidden`() {
        holder.onTaskCompleted(TaskOutcome.FINISHED)
        assertThat(holder.mode.value).isEqualTo(CapsuleMode.Hidden)
    }

    @Test
    fun `stopping the session keeps a stopped result`() {
        holder.onTaskStarted("task1", "input")
        holder.onSessionEnded(SessionEndReason.USER_STOPPED)
        assertThat(holder.mode.value).isEqualTo(CapsuleMode.Done("Stopped", stopped = true))
    }

    @Test
    fun `idle session expiry preserves the completed result`() {
        holder.onTaskStarted("task1", "input")
        holder.onTaskCompleted(TaskOutcome.FINISHED, "Summary")
        holder.onSessionEnded(SessionEndReason.IDLE_TIMEOUT)
        assertThat(holder.mode.value).isEqualTo(CapsuleMode.Done("Summary"))
    }

    @Test
    fun `completed result remains available after the old hide delay`() {
        holder.onTaskStarted("task1", "input")
        holder.onTaskCompleted(TaskOutcome.FINISHED)
        assertThat(holder.mode.value).isInstanceOf(CapsuleMode.Done::class.java)

        scope.advanceTimeBy(3001)
        assertThat(holder.mode.value).isEqualTo(CapsuleMode.Done("Task completed"))
    }

    @Test
    fun `new task replaces the completed result`() {
        holder.onTaskStarted("task1", "input")
        holder.onTaskCompleted(TaskOutcome.FINISHED)
        holder.onTaskStarted("task2", "new task")

        scope.advanceTimeBy(3001)
        assertThat(holder.mode.value).isInstanceOf(CapsuleMode.Running::class.java)
    }

    @Test
    fun `onError sets Error mode`() {
        holder.onError("Network error")
        val mode = holder.mode.value
        assertThat(mode).isInstanceOf(CapsuleMode.Error::class.java)
        assertThat((mode as CapsuleMode.Error).message).isEqualTo("Network error")
    }

    @Test
    fun `hasActiveTask is false when Hidden`() {
        assertThat(holder.hasActiveTask).isFalse()
    }

    @Test
    fun `hasActiveTask is true when Running`() {
        holder.onTaskStarted("task1", "input")
        assertThat(holder.hasActiveTask).isTrue()
    }

    @Test
    fun `hasActiveTask is false when Done`() {
        holder.onTaskStarted("task1", "input")
        holder.onTaskCompleted(TaskOutcome.FINISHED)
        assertThat(holder.hasActiveTask).isFalse()
    }

    @Test
    fun `hasActiveTask is false when Error`() {
        holder.onError("error")
        assertThat(holder.hasActiveTask).isFalse()
    }
    @Test
    fun `reply draft survives repeated question updates without replacing the task draft`() {
        holder.inputDraft.value = "Unsent note"
        holder.onAskUser(id.steveimm.pocketpilot.protocol.AskUserType.QUESTION, "Question", "q1")
        holder.responseDraft.value = "Partial reply"
        holder.onAskUser(id.steveimm.pocketpilot.protocol.AskUserType.QUESTION, "Question", "q1")
        assertThat(holder.responseDraft.value).isEqualTo("Partial reply")
        assertThat(holder.inputDraft.value).isEqualTo("Unsent note")
        holder.onAskUser(id.steveimm.pocketpilot.protocol.AskUserType.QUESTION, "Next question", "q2")
        assertThat(holder.responseDraft.value).isEmpty()
        assertThat(holder.inputDraft.value).isEqualTo("Unsent note")
    }

}
