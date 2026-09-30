package id.steveimm.pocketpilot.ui.chat

import android.util.Log
import androidx.compose.runtime.snapshots.SnapshotStateList
import id.steveimm.pocketpilot.history.SessionHistoryManager
import id.steveimm.pocketpilot.history.model.MessageConverter
import id.steveimm.pocketpilot.history.model.SessionInfo
import id.steveimm.pocketpilot.ui.chat.model.ChatMessage
import id.steveimm.pocketpilot.ui.chat.model.ChatUiState
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class ChatSessionHistoryController(
    private val scope: CoroutineScope,
    private val sessionHistoryManager: SessionHistoryManager?,
    private val messages: SnapshotStateList<ChatMessage>,
    private val stateLock: Any,
    private val uiState: MutableStateFlow<ChatUiState>,
) {
    companion object {
        private const val TAG = "ChatSessionHistory"
    }

    private var loadJob: Job? = null
    private var resumeJob: Job? = null

    private val _sessions = MutableStateFlow<List<SessionInfo>>(emptyList())
    val sessions: StateFlow<List<SessionInfo>> = _sessions.asStateFlow()

    fun clearConversation() {
        loadJob?.cancel()
        resumeJob?.cancel()
        synchronized(stateLock) {
            messages.clear()
            uiState.update { it.copy(showEmptyState = true) }
        }
    }

    fun clearHistoryState() {
        clearConversation()
        _sessions.value = emptyList()
        uiState.update { it.copy(historyError = null) }
    }

    fun loadSessions(onLoaded: () -> Unit = {}) {
        val manager = sessionHistoryManager ?: return
        loadJob?.cancel()
        loadJob = scope.launch {
            try {
                _sessions.value = manager.listSessions()
                onLoaded()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.e(TAG, "Failed to list chats", e)
                uiState.update { it.copy(historyError = "Could not load your chats. Try opening history again.") }
            }
        }
    }

    fun resumeSession(sessionInfo: SessionInfo, onResumed: (suspend () -> Unit)? = null) {
        val manager = sessionHistoryManager ?: return
        resumeJob?.cancel()
        resumeJob = scope.launch {
            manager.loadSession(sessionInfo.id)
                .onSuccess { data ->
                    val restoredMessages = MessageConverter.fromRecords(data.session.messages)
                    synchronized(stateLock) {
                        messages.clear()
                        messages.addAll(restoredMessages)
                        uiState.update { it.copy(showEmptyState = messages.isEmpty()) }
                    }

                    manager.resumeSession(data)

                    Log.i(TAG, "Resumed session ${sessionInfo.id} with ${restoredMessages.size} messages")
                    onResumed?.invoke()
                }
                .onFailure { error ->
                    Log.e(TAG, "Failed to resume session", error)
                    uiState.update { it.copy(historyError = "Could not open this chat.") }
                }
        }
    }

    fun startNewSession(model: String? = null, appVersion: String? = null) {
        clearConversation()
        // Don't create a recording session here — the history entry will be created when the actual AgentSession starts. Creating it now
        // would save an empty placeholder that clutters history and fails on reload.
        Log.d(TAG, "Started new session")
    }

    suspend fun deleteSession(sessionInfo: SessionInfo): Result<Unit> {
        val manager = sessionHistoryManager ?: return Result.failure(IllegalStateException("History is unavailable"))
        return manager.deleteSession(sessionInfo.id)
            .onSuccess {
                Log.d(TAG, "Deleted session ${sessionInfo.id}")
                loadSessions()
            }
            .onFailure { error ->
                Log.e(TAG, "Failed to delete session", error)
                uiState.update { it.copy(historyError = "Could not delete this chat. Try again.") }
            }
    }

    fun hasSessionHistory(): Boolean = sessionHistoryManager != null
}
