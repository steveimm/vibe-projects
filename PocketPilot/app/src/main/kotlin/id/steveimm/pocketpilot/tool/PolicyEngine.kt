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
        destinationPackage: String? = null,
        approvedForCall: Set<String> = emptySet(),
    ): PolicyDecision {
        val currentMode = approvalMode.get()
        val currentTier = appClassifier.classify(packageName)
        val destTier = destinationPackage?.let { appClassifier.classify(it) }
        // Effective tier = stricter of the two (lower ordinal = stricter)
        val effectiveTier = if (destTier != null) minOf(currentTier, destTier) else currentTier
        val subjects = buildList {
            add(packageName to currentTier)
            if (destinationPackage != null && destinationPackage != packageName) add(destinationPackage to requireNotNull(destTier))
        }
        Log.d(TAG, "Policy check: tool=$toolName, pkg=$packageName, dest=$destinationPackage, tier=$effectiveTier, mode=$currentMode")

        val tool = ToolName.from(toolName)

        // Non-screen-changing tools do not need app-access approval.
        if (!tool.isScreenChanging) return PolicyDecision.Allow

        // Back and Home remain available even in blocked apps.
        if (isEscape(tool, params)) return PolicyDecision.Allow

        if (effectiveTier == AppTier.BLOCKED) {
            val blockedPackage = subjects.first { it.second == AppTier.BLOCKED }.first
            return PolicyDecision.Deny("Blocked: financial/auth app ($blockedPackage)")
        }

        if (currentMode == ApprovalMode.AUTO_APPROVE) return PolicyDecision.Allow
        val cautiousSubjects = subjects.filter { it.second == AppTier.CAUTIOUS }
        val requiredSubjects = if (currentMode == ApprovalMode.ALWAYS_ASK && cautiousSubjects.isEmpty()) {
            listOf((destinationPackage ?: packageName) to effectiveTier)
        } else cautiousSubjects
        for ((subject, tier) in requiredSubjects) {
            if (subject != null && subject in approvedForCall) continue
            if (currentMode != ApprovalMode.ALWAYS_ASK && isSessionAllowed(subject)) continue
            return PolicyDecision.AskUser(
                reason = if (currentMode == ApprovalMode.ALWAYS_ASK) "User requested approval for all actions"
                    else "This app requires approval",
                appTier = tier,
                packageName = subject,
            )
        }
        return PolicyDecision.Allow
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
        val appTier: AppTier? = null,
        val packageName: String? = null,
    ) : PolicyDecision
}
