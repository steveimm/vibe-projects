package id.steveimm.pocketpilot.session

import com.google.common.truth.Truth.assertThat
import id.steveimm.pocketpilot.history.HistoryManager
import id.steveimm.pocketpilot.history.SessionRecordingService
import id.steveimm.pocketpilot.history.model.CheckpointState
import id.steveimm.pocketpilot.history.model.HistoryItemConverter
import id.steveimm.pocketpilot.history.model.SessionRuntimeSnapshot
import id.steveimm.pocketpilot.history.model.isReloadable
import id.steveimm.pocketpilot.protocol.SessionConfig
import id.steveimm.pocketpilot.protocol.SessionState
import id.steveimm.pocketpilot.protocol.TaskOutcome
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import kotlinx.coroutines.runBlocking
import org.junit.Test

class SessionCheckpointCoordinatorTest {

    private fun buildCoordinator(
        recording: SessionRecordingService,
        historyManager: HistoryManager = HistoryManager(),
        sessionId: String = "session-1",
        config: SessionConfig = SessionConfig()
    ): SessionCheckpointCoordinator =
        SessionCheckpointCoordinator(
            sessionId = sessionId,
            config = config,
            historyManager = historyManager,
            recordingService = recording
        )

    @Test
    fun `scheduleCheckpoint delegates to recording service with state-specific snapshot`() {
        val recording = mockk<SessionRecordingService>(relaxed = true)
        val idleProvider = slot<() -> SessionRuntimeSnapshot>()
        val runningProvider = slot<() -> SessionRuntimeSnapshot>()
        every { recording.scheduleCheckpoint(capture(idleProvider)) } returns Unit andThen Unit
        every { recording.getLastTaskOutcome() } returns null

        val coordinator = buildCoordinator(recording)

        coordinator.scheduleCheckpoint(SessionState.Idle)
        val idleSnapshot = idleProvider.captured.invoke()
        assertThat(idleSnapshot.checkpointState).isEqualTo(CheckpointState.IDLE_READY)

        every { recording.scheduleCheckpoint(capture(runningProvider)) } returns Unit
        coordinator.scheduleCheckpoint(SessionState.Running)
        val runningSnapshot = runningProvider.captured.invoke()
        assertThat(runningSnapshot.checkpointState).isEqualTo(CheckpointState.RUNNING_DIRTY)

        coVerify(exactly = 2) { recording.scheduleCheckpoint(any()) }
    }

    @Test
    fun `flushIdleReady builds snapshot from session state and forces checkpoint`() = runBlocking {
        val recording = mockk<SessionRecordingService>(relaxed = true)
        val captured = slot<SessionRuntimeSnapshot>()
        coEvery { recording.forceCheckpoint(capture(captured)) } returns true
        every { recording.getLastTaskOutcome() } returns TaskOutcome.GOAL_ACHIEVED

        val coordinator = buildCoordinator(
            recording = recording,
            sessionId = "abc-123"
        )

        val beforeMs = System.currentTimeMillis()
        val success = coordinator.flushIdleReady()
        val afterMs = System.currentTimeMillis()

        assertThat(success).isTrue()
        val snapshot = captured.captured
        assertThat(snapshot.sessionId).isEqualTo("abc-123")
        assertThat(snapshot.checkpointState).isEqualTo(CheckpointState.IDLE_READY)
        assertThat(snapshot.historyItems).isEmpty()
        assertThat(snapshot.lastTaskOutcome).isEqualTo("GOAL_ACHIEVED")
        assertThat(snapshot.lastCheckpointAt).isAtLeast(beforeMs)
        assertThat(snapshot.lastCheckpointAt).isAtMost(afterMs)
        assertThat(snapshot.config.mainModel).isEqualTo(SessionConfig().mainModel)
    }

    @Test
    fun `flushClosed emits CLOSED state and propagates failure`() = runBlocking {
        val recording = mockk<SessionRecordingService>(relaxed = true)
        val captured = slot<SessionRuntimeSnapshot>()
        coEvery { recording.forceCheckpoint(capture(captured)) } returns false
        every { recording.getLastTaskOutcome() } returns null

        val coordinator = buildCoordinator(recording)

        val success = coordinator.flushClosed()

        assertThat(success).isFalse()
        assertThat(captured.captured.checkpointState).isEqualTo(CheckpointState.CLOSED)
        assertThat(captured.captured.lastTaskOutcome).isNull()
    }

    // region characterization: section 6 of doc/main/ui/session/state_machine.md

    @Test
    fun `scheduleCheckpoint marks Created Paused and Shutdown as RUNNING_DIRTY`() {
        val recording = mockk<SessionRecordingService>(relaxed = true)
        every { recording.getLastTaskOutcome() } returns null
        val provider = slot<() -> SessionRuntimeSnapshot>()
        every { recording.scheduleCheckpoint(capture(provider)) } returns Unit

        val coordinator = buildCoordinator(recording)

        listOf(SessionState.Created, SessionState.Paused, SessionState.Shutdown).forEach { state ->
            coordinator.scheduleCheckpoint(state)
            assertThat(provider.captured.invoke().checkpointState)
                .isEqualTo(CheckpointState.RUNNING_DIRTY)
        }
    }

    @Test
    fun `flushIdleReady reports failure when recording service rejects write`() = runBlocking {
        val recording = mockk<SessionRecordingService>(relaxed = true)
        coEvery { recording.forceCheckpoint(any()) } returns false
        every { recording.getLastTaskOutcome() } returns null

        val coordinator = buildCoordinator(recording)

        assertThat(coordinator.flushIdleReady()).isFalse()
    }

    @Test
    fun `flushClosed reports success when write succeeds`() = runBlocking {
        val recording = mockk<SessionRecordingService>(relaxed = true)
        coEvery { recording.forceCheckpoint(any()) } returns true
        every { recording.getLastTaskOutcome() } returns TaskOutcome.USER_STOPPED

        val coordinator = buildCoordinator(recording)

        assertThat(coordinator.flushClosed()).isTrue()
    }

    @Test
    fun `isReloadable accepts IDLE_READY and CLOSED but rejects RUNNING_DIRTY`() {
        assertThat(CheckpointState.IDLE_READY.isReloadable()).isTrue()
        assertThat(CheckpointState.CLOSED.isReloadable()).isTrue()
        assertThat(CheckpointState.RUNNING_DIRTY.isReloadable()).isFalse()
    }

    @Test
    fun `snapshot empty session round trips to empty containers`() = runBlocking {
        val recording = mockk<SessionRecordingService>(relaxed = true)
        val captured = slot<SessionRuntimeSnapshot>()
        coEvery { recording.forceCheckpoint(capture(captured)) } returns true
        every { recording.getLastTaskOutcome() } returns null

        val coordinator = buildCoordinator(recording)
        coordinator.flushClosed()

        val snapshot = captured.captured
        assertThat(snapshot.historyItems).isEmpty()

        val restoredHistory = HistoryManager().also {
            it.replaceAll(HistoryItemConverter.fromRecords(snapshot.historyItems))
        }
        assertThat(restoredHistory.isEmpty()).isTrue()
    }

    // endregion
}
