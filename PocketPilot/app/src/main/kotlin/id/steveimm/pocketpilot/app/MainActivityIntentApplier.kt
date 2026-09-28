package id.steveimm.pocketpilot.app

import id.steveimm.pocketpilot.auth.AuthCredential
import id.steveimm.pocketpilot.auth.AuthStore
import id.steveimm.pocketpilot.llm.LLMProvider
import id.steveimm.pocketpilot.llm.ModelIdValidator
import id.steveimm.pocketpilot.llm.OtherBaseUrlValidator
import id.steveimm.pocketpilot.protocol.ApprovalMode
import id.steveimm.pocketpilot.ui.settings.BrowserScriptToggleError
import id.steveimm.pocketpilot.ui.settings.gateBrowserScriptEnable
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

internal data class MainActivityIntentApplyResult(
    val pendingTraceEnabled: Boolean?,
    val pendingTraceRunId: String?,
    val pendingExcludedTools: Set<String>,
    val pendingApprovalMode: ApprovalMode?,
    val pendingEvalTurnBudget: Int?,
)

/** Apply intent extras to runtime state. */
internal suspend fun applyIntentPayloadToSettings(
    payload: MainActivityIntentPayload,
    settingsState: AppSettingsState,
    modelLoadingStatusHolder: ModelLoadingStatusHolder,
    authStore: AuthStore,
    isDebugBuild: Boolean,
    currentPendingTraceEnabled: Boolean?,
    currentPendingTraceRunId: String?,
    currentPendingExcludedTools: Set<String>,
    currentPendingApprovalMode: ApprovalMode?,
    currentPendingEvalTurnBudget: Int?,
    log: (String) -> Unit,
    browserScriptGate: suspend () -> BrowserScriptToggleError? = { gateBrowserScriptEnable() },
    invalidateCatalog: () -> Unit = {},
): MainActivityIntentApplyResult {
    if (!isDebugBuild) {
        return MainActivityIntentApplyResult(
            pendingTraceEnabled = currentPendingTraceEnabled,
            pendingTraceRunId = currentPendingTraceRunId,
            pendingExcludedTools = currentPendingExcludedTools,
            pendingApprovalMode = currentPendingApprovalMode,
            pendingEvalTurnBudget = currentPendingEvalTurnBudget,
        )
    }

    // Credential writes are I/O-bound; batch on Dispatchers.IO off the caller's thread.
    var otherChanged = false
    withContext(Dispatchers.IO) {
        payload.apiKey?.let { key ->
            authStore.set(LLMProvider.OPENAI_API, AuthCredential.ApiKey(key))
            log("OPENAI_API key set from intent via AuthStore")
        }
        payload.openRouterApiKey?.let { key ->
            authStore.set(LLMProvider.OPENROUTER, AuthCredential.ApiKey(key))
            log("OPENROUTER key set from intent via AuthStore")
        }
        payload.otherApiKey?.let { key ->
            authStore.set(LLMProvider.OTHER, AuthCredential.ApiKey(key))
            otherChanged = true
            log("OTHER key set from intent via AuthStore")
        }
    }
    payload.openaiBaseUrl?.let { url ->
        settingsState.updateOpenaiBaseUrl(url)
        log("OpenAI base URL override set from intent: $url")
    }
    payload.otherBaseUrl?.let { url ->
        // Validate before persisting so malformed intent values never become visible settings.
        val validation = OtherBaseUrlValidator.validate(url)
        validation.onSuccess { normalized ->
            settingsState.updateOtherBaseUrl(normalized)
            otherChanged = true
            log("OTHER base URL set from intent: $normalized")
        }.onFailure { err ->
            // Don't echo the rejected URL — it could contain a sensitive host.
            log("OTHER base URL from intent rejected: ${err.message}")
        }
    }
    payload.otherModelId?.let { modelId ->
        // Validate at the intent boundary so a bad id (whitespace, leading ":" / "/") never reaches settings — discovery and the synth
        // path would otherwise enforce the same rule and silently drop the entry.
        ModelIdValidator.validate(modelId).onSuccess { trimmed ->
            settingsState.updateOtherModelId(trimmed)
            otherChanged = true
            log("OTHER model id set from intent: $trimmed")
        }.onFailure { err ->
            // Don't echo the rejected id verbatim — keep the log non-secret.
            log("OTHER model id from intent rejected: ${err.message}")
        }
    }
    // Make absolutely sure the catalog reflects OTHER writes.
    if (otherChanged) invalidateCatalog()
    payload.backendType?.let {
        modelLoadingStatusHolder.updateBackend(it)
        log("LLM backend set from intent: $it")
    }
    payload.perceptionMode?.let { mode ->
        settingsState.updatePerceptionMode(mode)
        log("Perception mode set from intent: $mode")
    }
    payload.platformMode?.let {
        settingsState.updatePlatformMode(it)
        log("Platform mode set from intent: $it")
    }
    payload.mainModel?.let {
        settingsState.updateModel(it)
        log("Main model set from intent: $it")
    }
    payload.debugMode?.let { enabled ->
        settingsState.updateDebugMode(enabled)
        log("Debug mode set from intent: $enabled")
    }
    payload.browserScriptEnabled?.let { enabled ->
        if (!enabled) {
            // OFF is unconditional — never makes things worse, mirrors the UI toggle.
            settingsState.updateBrowserScriptEnabled(false)
            log("browser_script enabled set from intent: false")
        } else {
            // ON must clear the same gate the UI uses (Shizuku reachable + permission + writable command-line file).
            val gateError = browserScriptGate()
            if (gateError == null) {
                settingsState.updateBrowserScriptEnabled(true)
                log("browser_script enabled set from intent: true (gate ok)")
            } else {
                log("browser_script enable from intent skipped: gate denied ($gateError)")
            }
        }
    }

    val pendingTraceEnabled =
        payload.traceEnabled?.also { enabled ->
            log("Trace enabled set from intent: $enabled")
        } ?: currentPendingTraceEnabled
    val pendingTraceRunId =
        payload.traceRunId?.also { runId ->
            log("Trace run id set from intent: $runId")
        } ?: currentPendingTraceRunId

    val pendingExcludedTools =
        payload.excludedTools.ifEmpty { currentPendingExcludedTools }.also { tools ->
            if (tools.isNotEmpty()) log("Excluded tools set from intent: $tools")
        }
    val pendingApprovalMode =
        payload.approvalMode?.also { mode ->
            log("Approval mode set from intent: $mode")
        } ?: currentPendingApprovalMode
    val pendingEvalTurnBudget =
        payload.evalTurnBudget?.also { budget ->
            log("Eval turn budget set from intent: $budget")
        } ?: currentPendingEvalTurnBudget

    return MainActivityIntentApplyResult(
        pendingTraceEnabled = pendingTraceEnabled,
        pendingTraceRunId = pendingTraceRunId,
        pendingExcludedTools = pendingExcludedTools,
        pendingApprovalMode = pendingApprovalMode,
        pendingEvalTurnBudget = pendingEvalTurnBudget,
    )
}
