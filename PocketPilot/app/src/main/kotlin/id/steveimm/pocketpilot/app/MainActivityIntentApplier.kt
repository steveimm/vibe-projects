package id.steveimm.pocketpilot.app

import id.steveimm.pocketpilot.auth.ServerCredentialStore
import id.steveimm.pocketpilot.llm.ModelIdValidator
import id.steveimm.pocketpilot.llm.ServerBaseUrlValidator
import id.steveimm.pocketpilot.protocol.ApprovalMode
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
    credentialStore: ServerCredentialStore,
    isDebugBuild: Boolean,
    currentPendingTraceEnabled: Boolean?,
    currentPendingTraceRunId: String?,
    currentPendingExcludedTools: Set<String>,
    currentPendingApprovalMode: ApprovalMode?,
    currentPendingEvalTurnBudget: Int?,
    log: (String) -> Unit,
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

    if (payload.serverBaseUrl != null || payload.serverModelId != null || payload.serverApiKey != null) {
        val url = ServerBaseUrlValidator.validate(payload.serverBaseUrl ?: settingsState.serverBaseUrl).getOrThrow()
        val model = ModelIdValidator.validate(payload.serverModelId ?: settingsState.serverModelId).getOrThrow()
        payload.serverApiKey?.let { key -> withContext(Dispatchers.IO) { credentialStore.setApiKey(url, key) } }
        settingsState.updateServer(url, model)
        log("Model server configured from debug intent")
    }
    payload.platformMode?.let {
        settingsState.updatePlatformMode(it)
        log("Platform mode set from intent: $it")
    }
    payload.debugMode?.let { enabled ->
        settingsState.updateDebugMode(enabled)
        log("Debug mode set from intent: $enabled")
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
