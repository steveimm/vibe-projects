package id.steveimm.pocketpilot.app

import com.google.common.truth.Truth.assertThat
import id.steveimm.pocketpilot.history.SessionRecordingService
import id.steveimm.pocketpilot.protocol.SessionCompleted
import id.steveimm.pocketpilot.protocol.SessionEndReason
import id.steveimm.pocketpilot.protocol.MessageDelta
import id.steveimm.pocketpilot.protocol.ReasoningDelta
import id.steveimm.pocketpilot.protocol.ActionProposed
import id.steveimm.pocketpilot.protocol.SessionError
import id.steveimm.pocketpilot.protocol.SessionId
import id.steveimm.pocketpilot.protocol.TaskCompleted
import id.steveimm.pocketpilot.protocol.TaskOutcome
import id.steveimm.pocketpilot.protocol.TaskStarted
import io.mockk.mockk
import io.mockk.verify
import org.junit.Test

class AgentServiceEventHandlerTest {

    private val sessionId = SessionId("s1")
    private val statusUpdates = mutableListOf<String>()
    private var sessionClearedCount = 0
    private val overlay = mockk<ServiceOverlayController>(relaxed = true)
    private val recording = mockk<SessionRecordingService>(relaxed = true)

    private val handler = AgentServiceEventHandler(
        logTag = "test",
        updateStatus = { statusUpdates += it },
        sessionCleared = { sessionClearedCount++ },
        overlayController = { overlay }
    )

    @Test
    fun `old session finishes saving without replacing the new conversation`() {
        handler.handleEvent(TaskCompleted(sessionId, 2_000L, "old", "old answer", TaskOutcome.FINISHED), recording, updateUi = false)
        handler.handleEvent(SessionCompleted(sessionId, 2_001L, SessionEndReason.USER_STOPPED), recording, updateUi = false)
        verify { recording.recordFinalAnswer("old answer") }
        verify { recording.completeSession() }
        verify(exactly = 0) { overlay.onTaskCompleted(any(), any()) }
        verify(exactly = 0) { overlay.onSessionCompleted(any()) }
        assertThat(sessionClearedCount).isEqualTo(0)
        assertThat(statusUpdates).isEmpty()
    }

    @Test
    fun `progress receives assistant content and the latest tool separately from reasoning`() {
        handler.handleEvent(ReasoningDelta(sessionId, 1_000L, "turn", "internal reasoning"), recording)
        handler.handleEvent(MessageDelta(sessionId, 1_001L, "turn", "Opening Settings."), recording)
        handler.handleEvent(ActionProposed(sessionId, 1_002L, "action", "open_app", "Open Settings"), recording)
        verify(exactly = 1) { overlay.onMessageDelta("turn", "Opening Settings.") }
        verify(exactly = 0) { overlay.onMessageDelta(any(), "internal reasoning") }
        verify { overlay.onActionProposed("Open Settings") }
    }

    @Test
    fun `TaskStarted records user message and notifies overlay`() {
        val event = TaskStarted(
            sessionId = sessionId,
            timestamp = 1_000L,
            taskId = "t1",
            input = "Do the thing"
        )

        handler.handleEvent(event, recording)

        verify { recording.onTaskStarted() }
        verify { recording.recordUserMessage(any(), 1_000L, "Do the thing") }
        verify { recording.startAgentMessage("t1", 1_000L) }
        verify { overlay.onTaskStarted("t1", "Do the thing") }
    }

    @Test
    fun `TaskCompleted finalizes recording and updates overlay`() {
        val event = TaskCompleted(
            sessionId = sessionId,
            timestamp = 2_000L,
            taskId = "t1",
            result = "ok",
            outcome = TaskOutcome.FINISHED
        )

        handler.handleEvent(event, recording)

        verify { recording.completeAgentMessage() }
        verify { recording.recordTaskOutcome(TaskOutcome.FINISHED) }
        verify { overlay.onTaskCompleted(TaskOutcome.FINISHED, "ok") }
    }

    @Test
    fun `SessionError surfaces error in status text and overlay`() {
        val event = SessionError(
            sessionId = sessionId,
            timestamp = 3_000L,
            message = "boom"
        )

        handler.handleEvent(event, recording)

        assertThat(statusUpdates).containsExactly("❌ Error: boom")
        verify { overlay.onSessionError("boom") }
    }
}
