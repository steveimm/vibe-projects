package id.steveimm.pocketpilot.app

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import id.steveimm.pocketpilot.protocol.ApprovalMode
import id.steveimm.pocketpilot.protocol.PlatformMode

class AppSettingsState(private val store: AppSettingsStore) {
    companion object {
        fun create(context: Context): AppSettingsState = AppSettingsState(AppSettingsStore(context.applicationContext))
    }

    private var current by mutableStateOf(AppSettings())

    val serverBaseUrl get() = current.serverBaseUrl
    val serverModelId get() = current.serverModelId

    val debugMode get() = current.debugMode
    val perceptionMode get() = current.perceptionMode
    val platformMode get() = current.platformMode
    val traceEnabled get() = current.traceEnabled
    val approvalMode get() = current.approvalMode

    fun updateServer(baseUrl: String, modelId: String) {
        store.saveServer(baseUrl, modelId)
        current = current.copy(serverBaseUrl = baseUrl, serverModelId = modelId)
    }

    fun load() {
        current = store.load()
    }

    fun updateDebugMode(value: Boolean) {
        current = current.copy(debugMode = value)
        store.saveDebugMode(value)
    }

    fun updateTraceEnabled(value: Boolean) {
        current = current.copy(traceEnabled = value)
        store.saveTraceEnabled(value)
    }

    fun updatePerceptionMode(value: String) {
        current = current.copy(perceptionMode = value)
        store.savePerceptionMode(value)
    }

    fun updatePlatformMode(value: PlatformMode) {
        current = current.copy(platformMode = value)
        store.savePlatformMode(value)
    }

    fun updateApprovalMode(value: ApprovalMode) {
        current = current.copy(approvalMode = value)
        store.saveApprovalMode(value)
    }
}
