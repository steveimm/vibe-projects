package id.steveimm.pocketpilot.protocol

import android.content.pm.PackageManager

/** Runtime metadata captured at `TaskCompleted` for Virtual Display tasks so the chat row can render the explicit "Open <App>" handoff
 * CTA. Absent (null) for non-VD completions. Carries only facts knowable at completion time — no intent classification. */
data class CompletionHandoff(
        val appPackage: String?,
        val appLabel: String?,
)

/** Build a [CompletionHandoff] from runtime facts at task completion. */
fun buildVdCompletionHandoff(
        appPackage: String?,
        packageManager: PackageManager,
        selfPackage: String,
        classifyTier: (String) -> AppTier,
): CompletionHandoff {
    val filtered = appPackage?.takeIf { pkg ->
        pkg != selfPackage &&
                pkg != "com.android.systemui" &&
                classifyTier(pkg) != AppTier.BLOCKED
    }
    val label = filtered?.let { pkg ->
        try {
            val info = packageManager.getApplicationInfo(pkg, 0)
            packageManager.getApplicationLabel(info).toString()
        } catch (_: PackageManager.NameNotFoundException) {
            null
        }
    }
    return CompletionHandoff(
            appPackage = filtered,
            appLabel = label,
    )
}
