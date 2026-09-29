package id.steveimm.pocketpilot.app

import android.content.Intent
import id.steveimm.pocketpilot.protocol.ApprovalMode
import id.steveimm.pocketpilot.protocol.PlatformMode

data class MainActivityIntentPayload(
    val serverBaseUrl: String? = null,
    val serverModelId: String? = null,
    val serverApiKey: String? = null,
    val platformMode: PlatformMode? = null,
    val approvalMode: ApprovalMode? = null,
    val goalText: String? = null,
    val freshSession: Boolean = false,
    val debugMode: Boolean? = null,
    val traceEnabled: Boolean? = null,
    val traceRunId: String? = null,
    val excludedTools: Set<String> = emptySet(),
    val evalTurnBudget: Int? = null,
) {
    companion object {
        fun from(intent: Intent): MainActivityIntentPayload = MainActivityIntentPayload(
            serverBaseUrl = intent.getStringExtra(MainActivity.EXTRA_SERVER_BASE_URL),
            serverModelId = intent.getStringExtra(MainActivity.EXTRA_SERVER_MODEL_ID),
            serverApiKey = intent.getStringExtra(MainActivity.EXTRA_SERVER_API_KEY),
            platformMode = enumValue<PlatformMode>(intent.getStringExtra(MainActivity.EXTRA_PLATFORM_MODE)),
            approvalMode = enumValue<ApprovalMode>(intent.getStringExtra(MainActivity.EXTRA_APPROVAL_MODE)),
            goalText = intent.getStringExtra(MainActivity.EXTRA_GOAL)?.takeIf { it.isNotBlank() },
            freshSession = intent.getBooleanExtra(MainActivity.EXTRA_FRESH_SESSION, false),
            debugMode = intent.optionalBoolean(MainActivity.EXTRA_DEBUG_MODE),
            traceEnabled = intent.optionalBoolean(MainActivity.EXTRA_TRACE_ENABLED),
            traceRunId = intent.getStringExtra(MainActivity.EXTRA_TRACE_RUN_ID)?.takeIf { it.isNotBlank() },
            excludedTools = intent.getStringExtra(MainActivity.EXTRA_EXCLUDED_TOOLS)?.split(",")
                ?.map { it.trim() }?.filter { it.isNotEmpty() }?.toSet().orEmpty(),
            evalTurnBudget = intent.getIntExtra(MainActivity.EXTRA_EVAL_TURN_BUDGET, 0).takeIf { it > 0 },
        )

        private fun Intent.optionalBoolean(key: String): Boolean? = if (hasExtra(key)) getBooleanExtra(key, false) else null
        private inline fun <reified T : Enum<T>> enumValue(raw: String?): T? = enumValues<T>().firstOrNull { it.name == raw?.uppercase() }
    }
}
