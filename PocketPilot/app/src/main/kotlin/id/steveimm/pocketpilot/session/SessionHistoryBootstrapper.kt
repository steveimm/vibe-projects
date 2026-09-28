package id.steveimm.pocketpilot.session

import android.content.Context
import android.util.Log
import id.steveimm.pocketpilot.history.HistoryConfig
import id.steveimm.pocketpilot.history.HistoryManager
import id.steveimm.pocketpilot.history.SessionRecordingService
import id.steveimm.pocketpilot.history.TruncationPolicy
import id.steveimm.pocketpilot.history.storage.SessionStorage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers

internal data class SessionHistoryBootstrap(
        val historyManager: HistoryManager,
        val recordingService: SessionRecordingService
)

/** Creates history manager + session recorder for a session. */
internal object SessionHistoryBootstrapper {
    private const val TAG = "SessionHistoryBootstrap"

    fun create(context: Context, scope: CoroutineScope): SessionHistoryBootstrap {
        val historyConfig =
                HistoryConfig(
                        defaultTruncationPolicy = TruncationPolicy.AGGRESSIVE,
                )
        val historyManager = HistoryManager(historyConfig)

        val storage = SessionStorage(context, Dispatchers.IO)
        val recordingService = SessionRecordingService(storage, scope)

        Log.d(TAG, "Created history stack (truncation=${historyConfig.defaultTruncationPolicy})")

        return SessionHistoryBootstrap(
                historyManager = historyManager,
                recordingService = recordingService
        )
    }
}
