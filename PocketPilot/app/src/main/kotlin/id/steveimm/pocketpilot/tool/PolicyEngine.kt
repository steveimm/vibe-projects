package id.steveimm.pocketpilot.tool

import android.util.Log
import id.steveimm.pocketpilot.protocol.AppTier
import id.steveimm.pocketpilot.protocol.ApprovalMode
import org.json.JSONObject
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicReference

/** PolicyEngine — Decides whether tool calls should be allowed, denied, or require approval. */
class PolicyEngine(
    initialApprovalMode: ApprovalMode = ApprovalMode.SMART,
    val appClassifier: AppClassifier
) {
    private val approvalMode = AtomicReference(initialApprovalMode)

    /** Session-scoped allow-list — cleared on reset(). */
    private val sessionAllowedPackages: MutableSet<String> = ConcurrentHashMap.newKeySet()

    companion object {
        private const val TAG = "PolicyEngine"
    }

    /** Check if a tool call should be allowed, denied, or requires approval. */
    fun check(
        toolName: String,
        params: JSONObject = JSONObject(),
        packageName: String? = null,
        destinationPackage: String? = null
    ): PolicyDecision {
        val currentMode = approvalMode.get()
        val currentTier = appClassifier.classify(packageName)
        val destTier = destinationPackage?.let { appClassifier.classify(it) }
        // Effective tier = stricter of the two (lower ordinal = stricter)
        val effectiveTier = if (destTier != null) minOf(currentTier, destTier) else currentTier
        val approvalSubject = destinationPackage ?: packageName
        Log.d(TAG, "Policy check: tool=$toolName, pkg=$packageName, dest=$destinationPackage, tier=$effectiveTier, mode=$currentMode")

        val tool = ToolName.from(toolName)

        // 1. Non-screen-changing tools → always allow.
        if (!tool.isScreenChanging) return PolicyDecision.Allow

        // 2. Escape actions (back/home) → always allow (agent must not be trapped).
        if (isEscape(tool, params)) return PolicyDecision.Allow

        // 3.
        if (effectiveTier == AppTier.BLOCKED) {
            return PolicyDecision.Deny("Blocked: financial/auth app ($packageName)")
        }

        // 5. Session allow-list — capsule "Session" button writes here. Gated by ALWAYS_ASK so
        //    the user's "ask me everything" pref always wins over a prior session approval.
        if (currentMode != ApprovalMode.ALWAYS_ASK && isSessionAllowed(approvalSubject)) {
            return PolicyDecision.Allow
        }

        // 6.
        return when (currentMode) {
            ApprovalMode.ALWAYS_ASK -> PolicyDecision.AskUser(
                reason = "User requested approval for all actions",
                appTier = effectiveTier
            )
            ApprovalMode.AUTO_APPROVE -> PolicyDecision.Allow
            ApprovalMode.SMART -> when (effectiveTier) {
                AppTier.CAUTIOUS -> PolicyDecision.AskUser(
                    reason = "Unknown app — action requires approval",
                    appTier = effectiveTier
                )
                AppTier.NORMAL -> PolicyDecision.Allow
                AppTier.BLOCKED -> PolicyDecision.Deny("unreachable")  // handled in step 3
            }
        }
    }

    fun setApprovalMode(mode: ApprovalMode) {
        val oldMode = approvalMode.getAndSet(mode)
        Log.d(TAG, "Approval mode changed: $oldMode -> $mode")
    }

    fun getApprovalMode(): ApprovalMode = approvalMode.get()

    fun reset() {
        approvalMode.set(ApprovalMode.SMART)
        sessionAllowedPackages.clear()
    }

    fun allowPackageForSession(packageName: String) {
        if (!isValidPackageName(packageName)) {
            Log.w(TAG, "Ignoring invalid package for session allow-list: $packageName")
            return
        }
        sessionAllowedPackages.add(packageName)
        Log.d(TAG, "Session allow-list: +$packageName")
    }

    private fun isValidPackageName(name: String): Boolean =
        name.isNotBlank() && '.' in name

    private fun isSessionAllowed(packageName: String?): Boolean =
        packageName != null && packageName in sessionAllowedPackages

    private fun isEscape(tool: ToolName, params: JSONObject): Boolean {
        // system_button(button="back"|"home")
        if (tool == ToolName.SystemButton) {
            val button = params.optString("button", "").lowercase()
            return button == "back" || button == "home"
        }
        return false
    }

}

sealed interface PolicyDecision {
    /** Tool call is allowed to execute immediately */
    data object Allow : PolicyDecision

    /** Tool call is forbidden by policy */
    data class Deny(val reason: String) : PolicyDecision

    /** Tool call requires user approval */
    data class AskUser(
        val reason: String,
        val appTier: AppTier? = null
    ) : PolicyDecision
}
