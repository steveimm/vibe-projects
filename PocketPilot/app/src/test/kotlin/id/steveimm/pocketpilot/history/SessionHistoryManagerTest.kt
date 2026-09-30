package id.steveimm.pocketpilot.history

import com.google.common.truth.Truth.assertThat
import id.steveimm.pocketpilot.history.storage.SessionStorage
import id.steveimm.pocketpilot.test.buildTestContext
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

@OptIn(ExperimentalCoroutinesApi::class)
class SessionHistoryManagerTest {

    @get:Rule
    val tempFolder = TemporaryFolder()

    @Test
    fun `listSessions returns active session and load works`() = runTest {
        val context = buildTestContext(tempFolder.newFolder("files"))
        val ioDispatcher = StandardTestDispatcher(testScheduler)
        val storage = SessionStorage(context, ioDispatcher)
        val manager = SessionHistoryManager.create(storage, this)

        val sessionId = manager.startNewSession(model = "gpt-5.2", appVersion = "1.0")
        val recording = manager.getRecordingService()
        recording.recordUserMessage(id = "u1", timestamp = 100L, text = "first task")

        advanceTimeBy(600L)
        advanceUntilIdle()

        val sessions = manager.listSessions()
        assertThat(sessions).hasSize(1)
        val info = sessions.single()
        assertThat(info.id).isEqualTo(sessionId)
        assertThat(info.isActive).isTrue()
        assertThat(info.firstUserMessage).isEqualTo("first task")

        val resumed = manager.loadSession(sessionId).getOrThrow()
        assertThat(resumed.session.sessionId).isEqualTo(sessionId)
    }

    @Test
    fun `deleting the current chat prevents later writes while deleting another keeps the current chat`() = runTest {
        val context = buildTestContext(tempFolder.newFolder("files"))
        val storage = SessionStorage(context, StandardTestDispatcher(testScheduler))
        val manager = SessionHistoryManager.create(storage, this)
        val oldId = manager.startNewSession(model = "local-model")
        val recording = manager.getRecordingService()
        recording.recordUserMessage("old", 1L, "older chat")
        advanceUntilIdle()
        val currentId = manager.startNewSession(model = "local-model")
        manager.setActiveSessionId(currentId)
        recording.recordUserMessage("current", 2L, "current chat")
        advanceUntilIdle()

        manager.deleteSession(oldId).getOrThrow()
        assertThat(recording.getCurrentSessionId()).isEqualTo(currentId)
        recording.recordUserMessage("pending", 3L, "must be deleted")
        manager.deleteSession(currentId).getOrThrow()
        recording.completeSession()
        advanceUntilIdle()

        assertThat(recording.getCurrentSession()).isNull()
        assertThat(manager.getCurrentSessionId()).isNull()
        assertThat(manager.listSessions()).isEmpty()
    }

    @Test
    fun `clear history removes persisted and pending records before a fresh conversation`() = runTest {
        val context = buildTestContext(tempFolder.newFolder("files"))
        val storage = SessionStorage(context, StandardTestDispatcher(testScheduler))
        val manager = SessionHistoryManager.create(storage, this)
        val oldId = manager.startNewSession(model = "local-model")
        manager.setActiveSessionId(oldId)
        val recording = manager.getRecordingService()
        recording.recordUserMessage("old", 1L, "private old message")
        advanceUntilIdle()
        assertThat(manager.listSessions()).hasSize(1)
        File(storage.getSessionsDir(), "orphan-context.json.tmp").writeText("old checkpoint")
        recording.recordUserMessage("pending", 2L, "not saved yet")

        manager.clearHistory().getOrThrow()
        recording.completeSession()
        advanceUntilIdle()
        assertThat(manager.listSessions()).isEmpty()
        assertThat(storage.getSessionsDir().listFiles()).isEmpty()
        assertThat(manager.getCurrentSessionId()).isNull()

        val newId = manager.startNewSession(model = "local-model")
        recording.recordUserMessage("new", 3L, "new message")
        advanceUntilIdle()
        val sessions = manager.listSessions()
        assertThat(sessions.map { it.id }).containsExactly(newId)
        assertThat(manager.loadSession(newId).getOrThrow().session.messages).hasSize(1)
        assertThat(sessions.single().firstUserMessage).isEqualTo("new message")
    }

    @Test
    fun `loadSession fails when session is missing`() = runTest {
        val context = buildTestContext(tempFolder.newFolder("files"))
        val ioDispatcher = StandardTestDispatcher(testScheduler)
        val storage = SessionStorage(context, ioDispatcher)
        val manager = SessionHistoryManager.create(storage, this)

        val result = manager.loadSession("missing-session")

        assertThat(result.isFailure).isTrue()
    }

    @Test
    fun `startNewSession preserves model and appVersion metadata`() = runTest {
        val context = buildTestContext(tempFolder.newFolder("files"))
        val ioDispatcher = StandardTestDispatcher(testScheduler)
        val storage = SessionStorage(context, ioDispatcher)
        val manager = SessionHistoryManager.create(storage, this)

        val sessionId = manager.startNewSession(model = "gpt-5.2", appVersion = "1.0")

        advanceTimeBy(600L)
        advanceUntilIdle()

        val file = storage.listSessionFiles().single()
        val record = storage.readSession(file.name).getOrThrow()
        assertThat(record.sessionId).isEqualTo(sessionId)
        assertThat(record.sessionId).isNotEqualTo("gpt-5.2")
        assertThat(record.metadata.model).isEqualTo("gpt-5.2")
        assertThat(record.metadata.appVersion).isEqualTo("1.0")
    }

    @Test
    fun `loadSession uses exact id match not substring`() = runTest {
        val context = buildTestContext(tempFolder.newFolder("files"))
        val ioDispatcher = StandardTestDispatcher(testScheduler)
        val storage = SessionStorage(context, ioDispatcher)
        val manager = SessionHistoryManager.create(storage, this)

        // Create two sessions with IDs where one is a substring of the other
        val fullId = "abc-123-def-456"
        val recording = manager.getRecordingService()

        recording.initializeNewSession(sessionId = fullId, model = "m1", appVersion = "1.0")
        recording.recordUserMessage(id = "u1", timestamp = 100L, text = "session one")
        advanceTimeBy(600L)
        advanceUntilIdle()
        recording.clearSessionAndAwait()

        // Loading with a partial substring should NOT match
        val partialResult = manager.loadSession("abc-123")
        assertThat(partialResult.isFailure).isTrue()

        // Loading with the exact full ID should match
        val exactResult = manager.loadSession(fullId)
        assertThat(exactResult.isSuccess).isTrue()
        assertThat(exactResult.getOrThrow().session.sessionId).isEqualTo(fullId)
    }

    @Test
    fun `listSessions surfaces corrupted session file as placeholder`() = runTest {
        val context = buildTestContext(tempFolder.newFolder("files"))
        val ioDispatcher = StandardTestDispatcher(testScheduler)
        val storage = SessionStorage(context, ioDispatcher)
        val manager = SessionHistoryManager.create(storage, this)

        val sessionsDir = storage.getSessionsDir()
        val malformedName = "session-2024-01-21T14-30-45-corrupt-session-id.json"
        File(sessionsDir, malformedName).writeText("{ this is not valid json ::: ")

        val sessions = manager.listSessions()

        assertThat(sessions).hasSize(1)
        val info = sessions.single()
        assertThat(info.isCorrupted).isTrue()
        assertThat(info.fileName).isEqualTo(malformedName)
        assertThat(info.displayTitle).contains(malformedName)
        assertThat(info.isActive).isFalse()
    }
}
