package id.steveimm.pocketpilot.app

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import id.steveimm.pocketpilot.llm.ModelCatalogRepositoryHolder
import id.steveimm.pocketpilot.protocol.ApprovalMode
import id.steveimm.pocketpilot.protocol.LLMBackendType
import id.steveimm.pocketpilot.protocol.PlatformMode
import id.steveimm.pocketpilot.ui.settings.LocalModelOption

class AppSettingsState(
    private val store: AppSettingsStore,
    /** Optional hook fired after `otherBaseUrl` / `otherModelId` writes. */
    private val onOtherSettingsChanged: () -> Unit = {},
) {
    companion object {
        /** Production wiring: build a state that invalidates the app-singleton [id.steveimm.pocketpilot.llm.ModelCatalogRepository]
         * whenever the OTHER settings change. */
        fun create(context: Context): AppSettingsState {
            val appContext = context.applicationContext
            return AppSettingsState(
                store = AppSettingsStore(appContext),
                onOtherSettingsChanged = {
                    ModelCatalogRepositoryHolder.get(appContext).invalidate()
                },
            )
        }
    }

    private var current by mutableStateOf(AppSettings())

    val selectedModel get() = current.selectedModel
    val debugMode get() = current.debugMode
    val perceptionMode get() = current.perceptionMode
    val llmBackend get() = current.llmBackend
    val localModel get() = current.localModel
    val platformMode get() = current.platformMode
    val traceEnabled get() = current.traceEnabled
    val browserScriptEnabled get() = current.browserScriptEnabled
    val approvalMode get() = current.approvalMode
    val openaiBaseUrl get() = current.openaiBaseUrl
    val otherBaseUrl get() = current.otherBaseUrl
    val otherModelId get() = current.otherModelId

    fun load() {
        current = store.load()
    }

    fun updateBackend(backend: LLMBackendType) {
        current = current.copy(llmBackend = backend)
        store.saveBackend(backend)
    }

    fun updateModel(model: String) {
        current = current.copy(selectedModel = model)
        store.saveModel(model)
    }

    fun updateLocalModel(model: LocalModelOption) {
        current = current.copy(localModel = model)
        store.saveLocalModel(model)
    }

    fun updateOpenaiBaseUrl(url: String) {
        current = current.copy(openaiBaseUrl = url)
        store.saveOpenaiBaseUrl(url)
    }

    fun updateOtherBaseUrl(url: String) {
        current = current.copy(otherBaseUrl = url)
        store.saveOtherBaseUrl(url)
        onOtherSettingsChanged()
    }

    fun updateOtherModelId(modelId: String) {
        current = current.copy(otherModelId = modelId)
        store.saveOtherModelId(modelId)
        onOtherSettingsChanged()
    }

    fun updateDebugMode(value: Boolean) {
        current = current.copy(debugMode = value)
        store.saveDebugMode(value)
    }

    fun updateTraceEnabled(value: Boolean) {
        current = current.copy(traceEnabled = value)
        store.saveTraceEnabled(value)
    }

    fun updateBrowserScriptEnabled(value: Boolean) {
        current = current.copy(browserScriptEnabled = value)
        store.saveBrowserScriptEnabled(value)
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
