package id.steveimm.pocketpilot.session

import android.util.Log
import id.steveimm.pocketpilot.history.HistoryManager
import id.steveimm.pocketpilot.history.SessionRecordingService
import id.steveimm.pocketpilot.history.model.CheckpointState
import id.steveimm.pocketpilot.history.model.ConversationConfigSnapshot
import id.steveimm.pocketpilot.history.model.HistoryItemConverter
import id.steveimm.pocketpilot.history.model.SessionRuntimeSnapshot
import id.steveimm.pocketpilot.perception.PerceptionConfig
import id.steveimm.pocketpilot.protocol.ApprovalMode
import id.steveimm.pocketpilot.protocol.PlatformMode
import id.steveimm.pocketpilot.protocol.SessionConfig
import id.steveimm.pocketpilot.protocol.SessionLlmConfig
import id.steveimm.pocketpilot.protocol.SessionState

/** Coordinates building and persisting LLM context snapshots. */
internal class SessionCheckpointCoordinator(
    private val sessionId: String,
    private val config: SessionConfig,
    private val historyManager: HistoryManager,
    private val recordingService: SessionRecordingService
) {
    companion object {
        private const val TAG = "CheckpointCoordinator"
    }

    fun scheduleCheckpoint(sessionState: SessionState) {
        val checkpointState = when (sessionState) {
            SessionState.Idle -> CheckpointState.IDLE_READY
            else -> CheckpointState.RUNNING_DIRTY
        }
        recordingService.scheduleCheckpoint { buildSnapshot(checkpointState) }
    }

    suspend fun flushIdleReady(): Boolean {
        val snapshot = buildSnapshot(CheckpointState.IDLE_READY)
        val success = recordingService.forceCheckpoint(snapshot)
        if (success) {
            Log.d(TAG, "Flushed IDLE_READY checkpoint for $sessionId")
        } else {
            Log.e(TAG, "Failed to flush IDLE_READY checkpoint for $sessionId")
        }
        return success
    }

    suspend fun flushClosed(): Boolean {
        val snapshot = buildSnapshot(CheckpointState.CLOSED)
        val success = recordingService.forceCheckpoint(snapshot)
        if (success) {
            Log.d(TAG, "Flushed CLOSED checkpoint for $sessionId")
        } else {
            Log.e(TAG, "Failed to flush CLOSED checkpoint for $sessionId")
        }
        return success
    }

    private fun buildSnapshot(state: CheckpointState): SessionRuntimeSnapshot {
        val items = historyManager.getAll()

        return SessionRuntimeSnapshot(
            schemaVersion = 2,
            sessionId = sessionId,
            config = config.toConfigSnapshot(),
            historyItems = HistoryItemConverter.toRecords(items),
            checkpointState = state,
            lastCheckpointAt = System.currentTimeMillis(),
            lastTaskOutcome = recordingService.getLastTaskOutcome()?.name
        )
    }
}

internal fun SessionConfig.toConfigSnapshot() = ConversationConfigSnapshot(
    mainModel = mainModel,
    platformMode = platformMode.name,
    serverBaseUrl = llm.baseUrl,
    actionDelayMs = actionDelayMs,
    approvalMode = approvalMode.name,
    debugMode = debugMode,
    traceEnabled = traceEnabled,
    traceRunId = traceRunId,
    excludedTools = excludedTools.toList()
)

internal fun ConversationConfigSnapshot.toSessionConfig(): SessionConfig = SessionConfig(
    mainModel = mainModel,
    platformMode = try { PlatformMode.valueOf(platformMode) } catch (_: Exception) {
        Log.w(SNAPSHOT_TAG, "Unknown PlatformMode in snapshot: $platformMode"); PlatformMode.ACCESSIBILITY
    },
    llm = SessionLlmConfig(baseUrl = serverBaseUrl),
    actionDelayMs = actionDelayMs,
    approvalMode = try { ApprovalMode.valueOf(approvalMode) } catch (_: Exception) {
        Log.w(SNAPSHOT_TAG, "Unknown ApprovalMode in snapshot: $approvalMode"); ApprovalMode.SMART
    },
    debugMode = debugMode,
    traceEnabled = traceEnabled,
    traceRunId = traceRunId,
    excludedTools = excludedTools.toSet()
)

private const val SNAPSHOT_TAG = "ConfigSnapshot"
