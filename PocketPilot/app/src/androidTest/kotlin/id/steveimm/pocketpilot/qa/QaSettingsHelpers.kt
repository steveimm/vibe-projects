package id.steveimm.pocketpilot.qa

import id.steveimm.pocketpilot.app.MemoryEditGate
import id.steveimm.pocketpilot.llm.ModelCatalog
import id.steveimm.pocketpilot.memory.MemoryStore
import id.steveimm.pocketpilot.protocol.LLMBackendType
import id.steveimm.pocketpilot.protocol.PlatformMode
import id.steveimm.pocketpilot.session.SessionCoordinator
import id.steveimm.pocketpilot.ui.settings.LlmAuthSettingsPage
import id.steveimm.pocketpilot.ui.settings.LocalModelOption
import id.steveimm.pocketpilot.ui.settings.ModelLoadingStatus
import id.steveimm.pocketpilot.ui.settings.OpenAiAuthUiState
import id.steveimm.pocketpilot.ui.settings.PermissionsAdvancedSettingsPage
import id.steveimm.pocketpilot.ui.settings.SettingsSheet
import id.steveimm.pocketpilot.ui.theme.PocketPilotTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob

/** Minimal model catalog with one model per provider, both API shapes on OpenAI. */
internal fun testModelCatalog(): ModelCatalog = ModelCatalog.fromJson(
    """
    {
      "gpt-5.2": {"display_name": "GPT-5.2", "provider":"OPENAI_API", "api": "response", "model_id": "gpt-5.2"},
      "gpt-5.2-chat": {"display_name": "GPT-5.2 (Chat API)", "provider":"OPENAI_API", "api": "chat", "model_id": "gpt-5.2"},
      "glm-5": {"display_name": "GLM-5", "provider": "OPENROUTER", "api": "chat", "model_id": "z-ai/glm-5"},
      "autoglm": {"display_name": "AutoGLM", "provider": "OTHER", "api": "chat", "model_id": "zai-org/autoglm", "base_url": "https://example.invalid/v1"}
    }
    """.trimIndent()
)

/**
 * Render the real SettingsSheet with sensible defaults; callers override what they need.
 * Used by navigation tests (S1-S4) that exercise the full sheet.
 */
@Composable
internal fun TestSettingsSheet(
    llmBackend: LLMBackendType = LLMBackendType.OPENAI,
    selectedModel: String = "gpt-5.2",
    onDismiss: () -> Unit = {},
) {
    val context = LocalContext.current
    val memoryStore = remember(context) {
        MemoryStore(java.io.File(context.cacheDir, "qa-memory-${System.nanoTime()}"))
    }
    val gate = remember(context) {
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
        MemoryEditGate(SessionCoordinator(scope), scope)
    }
    PocketPilotTheme {
        SettingsSheet(
            llmBackend = llmBackend,
            onBackendChange = {},
            selectedModel = selectedModel,
            onModelChange = {},
            modelCatalog = testModelCatalog(),
            selectedLocalModel = "LFM2.5-1.2B-Instruct",
            onLocalModelChange = {},
            modelLoadingStatus = ModelLoadingStatus.Idle,
            perceptionMode = "accessibility_only",
            onPerceptionModeChange = {},
            debugMode = false,
            onDebugModeChange = {},
            traceEnabled = false,
            onTraceEnabledChange = {},
            browserScriptEnabled = false,
            onBrowserScriptEnabledChange = {},
            isAccessibilityEnabled = true,
            isOverlayEnabled = true,
            onAccessibilityClick = {},
            onOverlayClick = {},
            openAiAuthUiState = OpenAiAuthUiState.SignedOut,
            onStartOAuth = {},
            onCancelOAuth = {},
            onSignOut = {},
            platformMode = PlatformMode.ACCESSIBILITY,
            effectivePlatformMode = null,
            onPlatformModeChange = {},
            onDismiss = onDismiss,
            memoryStore = memoryStore,
            memoryEditGate = gate,
        )
    }
}

/**
 * Render LlmAuthSettingsPage directly. Callers supply the callbacks they assert on.
 */
@Composable
internal fun TestLlmAuthPage(
    llmBackend: LLMBackendType = LLMBackendType.OPENAI,
    onBackendChange: (LLMBackendType) -> Unit = {},
    selectedModel: String = "gpt-5.2",
    onModelChange: (String) -> Unit = {},
    selectedLocalModel: String = "LFM2.5-1.2B-Instruct",
    onLocalModelChange: (LocalModelOption) -> Unit = {},
    openAiAuthUiState: OpenAiAuthUiState = OpenAiAuthUiState.SignedOut,
    onStartOAuth: () -> Unit = {},
) {
    PocketPilotTheme {
        LlmAuthSettingsPage(
            llmBackend = llmBackend,
            onBackendChange = onBackendChange,
            selectedModel = selectedModel,
            onModelChange = onModelChange,
            modelCatalog = testModelCatalog(),
            selectedLocalModel = selectedLocalModel,
            onLocalModelChange = onLocalModelChange,
            modelLoadingStatus = ModelLoadingStatus.Idle,
            openAiAuthUiState = openAiAuthUiState,
            onStartOAuth = onStartOAuth,
            onCancelOAuth = {},
            onSignOut = {},
            onBack = {},
            onClose = {},
        )
    }
}

/** Render the Permissions page with caller-controlled trace toggle state. */
@Composable
internal fun TestPermissionsPage(
    traceEnabled: Boolean,
    onTraceEnabledChange: (Boolean) -> Unit = {},
) {
    PocketPilotTheme {
        PermissionsAdvancedSettingsPage(
            isAccessibilityEnabled = true,
            isOverlayEnabled = true,
            onAccessibilityClick = {},
            onOverlayClick = {},
            debugMode = false,
            onDebugModeChange = {},
            traceEnabled = traceEnabled,
            onTraceEnabledChange = onTraceEnabledChange,
            onBack = {},
            onClose = {},
        )
    }
}
