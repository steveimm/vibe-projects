package id.steveimm.pocketpilot.history

import android.util.Log
import id.steveimm.pocketpilot.history.model.MessageRecord
import id.steveimm.pocketpilot.history.model.SessionInfo
import id.steveimm.pocketpilot.history.storage.SessionStorage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.io.File
import java.util.HashMap

/** High-level session management API. */
class SessionHistoryManager(
    private val storage: SessionStorage,
    private val recordingService: SessionRecordingService
) {
    companion object {
        private const val TAG = "SessionHistoryManager"

        /** Maximum characters for display title */
        private const val MAX_TITLE_LENGTH = 50

        /** Length of timestamp (19) + separator dash (1) in session filenames */
        private const val TIMESTAMP_WITH_SEPARATOR_LENGTH = 20

        /** Factory method for creating a SessionHistoryManager. */
        fun create(
            storage: SessionStorage,
            scope: CoroutineScope
        ): SessionHistoryManager {
            val recordingService = SessionRecordingService(storage, scope)
            return SessionHistoryManager(storage, recordingService)
        }
    }

    private data class CachedSessionInfo(
        val lastModified: Long,
        val info: SessionInfo
    )

    private val sessionInfoCache = HashMap<String, CachedSessionInfo>()
    private val cacheMutex = Mutex()

    /** Externally-set active session ID. */
    @Volatile
    private var externalActiveSessionId: String? = null

    /** List all sessions (lightweight, doesn't load full content). */
    suspend fun listSessions(): List<SessionInfo> {
        val files = storage.listSessionFiles()
        Log.d(TAG, "Found ${files.size} session files")

        return files.map { file ->
            getSessionInfoCached(file)
        }
    }

    /** Load a session for resuming. */
    suspend fun loadSession(sessionId: String): Result<ResumedSessionData> {
        val files = storage.listSessionFiles()
        val file = files.find { extractSessionIdFromFileName(it.name) == sessionId }
            ?: return Result.failure(NoSuchElementException("Session not found: $sessionId"))

        return loadSessionByFileName(file.name)
    }

    /** Load a session by file name. */
    private suspend fun loadSessionByFileName(fileName: String): Result<ResumedSessionData> {
        return storage.readSession(fileName).map { record ->
            ResumedSessionData(
                session = record,
                fileName = fileName
            )
        }
    }

    /** Delete a session. */
    suspend fun deleteSession(sessionId: String): Result<Unit> {
        val files = storage.listSessionFiles()
        val file = files.find { extractSessionIdFromFileName(it.name) == sessionId }
            ?: return Result.failure(NoSuchElementException("Session not found: $sessionId"))

        return storage.deleteSessionPair(file.name).onSuccess {
            cacheMutex.withLock {
                sessionInfoCache.remove(file.name)
            }
        }
    }

    /** Start a new session. */
    fun startNewSession(model: String? = null, appVersion: String? = null): String {
        return recordingService.initializeNewSession(model = model, appVersion = appVersion)
    }

    /** Resume an existing session. */
    fun resumeSession(data: ResumedSessionData) {
        recordingService.resumeSession(data)
    }

    /** Get current session ID (if any). */
    fun getCurrentSessionId(): String? {
        return externalActiveSessionId ?: recordingService.getCurrentSessionId()
    }

    /** Set the active session ID from outside this manager. */
    fun setActiveSessionId(sessionId: String?) {
        externalActiveSessionId = sessionId
    }

    /** Get the recording service (for event recording). */
    fun getRecordingService(): SessionRecordingService = recordingService

    /** Extract the session ID from a filename. */
    private fun extractSessionIdFromFileName(fileName: String): String? {
        // "session-" prefix = 8 chars, timestamp = 19 chars, separator "-" = 1 char
        val prefix = "session-"
        val suffix = ".json"
        if (!fileName.startsWith(prefix) || !fileName.endsWith(suffix)) return null
        // After "session-" and timestamp (19 chars) and "-", the rest before ".json" is sessionId
        val withoutPrefix = fileName.removePrefix(prefix)
        if (withoutPrefix.length <= TIMESTAMP_WITH_SEPARATOR_LENGTH) return null
        val afterTimestamp = withoutPrefix.substring(TIMESTAMP_WITH_SEPARATOR_LENGTH).removeSuffix(suffix)
        return afterTimestamp.ifEmpty { null }
    }

    /** Extract SessionInfo from a session file. If the file cannot be parsed, returns a corrupted-placeholder entry so the user sees
     * the file exists rather than silently missing. */
    private suspend fun extractSessionInfo(fileName: String, lastModified: Long): SessionInfo {
        val result = storage.readSession(fileName)
        val record = result.getOrElse { error ->
            Log.w(TAG, "Session file $fileName is corrupted; surfacing as placeholder", error)
            return corruptedPlaceholder(fileName, lastModified)
        }

        // Extract first user message for preview
        val firstUserMessage = record.messages
            .filterIsInstance<MessageRecord.User>()
            .firstOrNull()?.text ?: "Empty session"

        // Use summary if available, otherwise truncate first user message
        val displayTitle = record.summary ?: firstUserMessage.let { msg ->
            if (msg.length > MAX_TITLE_LENGTH) {
                "${msg.take(MAX_TITLE_LENGTH)}..."
            } else {
                msg
            }
        }

        return SessionInfo(
            id = record.sessionId,
            fileName = fileName,
            startTime = record.startTime,
            lastUpdated = record.lastUpdated,
            messageCount = record.messages.size,
            displayTitle = displayTitle,
            firstUserMessage = firstUserMessage,
            isActive = record.sessionId == getCurrentSessionId()
        )
    }

    private fun corruptedPlaceholder(fileName: String, lastModified: Long): SessionInfo {
        val id = extractSessionIdFromFileName(fileName) ?: fileName
        return SessionInfo(
            id = id,
            fileName = fileName,
            startTime = lastModified,
            lastUpdated = lastModified,
            messageCount = 0,
            displayTitle = "[Unreadable] $fileName",
            firstUserMessage = "",
            isActive = false,
            isCorrupted = true
        )
    }

    private suspend fun getSessionInfoCached(file: File): SessionInfo {
        val fileName = file.name
        val initialLastModified = file.lastModified()

        val cached = cacheMutex.withLock { sessionInfoCache[fileName] }
        val baseInfo: SessionInfo =
            if (cached != null && cached.lastModified == initialLastModified) {
                cached.info
            } else {
                val fresh = extractSessionInfo(fileName, initialLastModified)
                val currentLastModified = file.lastModified()
                if (currentLastModified != initialLastModified) {
                    Log.w(
                        TAG,
                        "Session file $fileName modified during read; returning uncached info"
                    )
                    fresh
                } else {
                    cacheMutex.withLock {
                        sessionInfoCache[fileName] = CachedSessionInfo(currentLastModified, fresh)
                    }
                    fresh
                }
            }

        val currentSessionId = getCurrentSessionId()
        return baseInfo.copy(isActive = !baseInfo.isCorrupted && baseInfo.id == currentSessionId)
    }
}
