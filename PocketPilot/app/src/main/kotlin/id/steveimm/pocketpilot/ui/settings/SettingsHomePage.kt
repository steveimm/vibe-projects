package id.steveimm.pocketpilot.ui.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import id.steveimm.pocketpilot.BuildConfig
import id.steveimm.pocketpilot.app.AppSettingsState
import id.steveimm.pocketpilot.platform.AppManager
import id.steveimm.pocketpilot.protocol.AppTier
import id.steveimm.pocketpilot.protocol.ApprovalMode
import id.steveimm.pocketpilot.protocol.PlatformMode
import id.steveimm.pocketpilot.tool.AppClassifier
import id.steveimm.pocketpilot.ui.theme.Fleuron
import id.steveimm.pocketpilot.ui.theme.PageMastheadIdentity
import id.steveimm.pocketpilot.ui.theme.SectionHeader
import id.steveimm.pocketpilot.ui.theme.pocketPilot
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

@Composable
internal fun SettingsHomePage(
    settings: AppSettingsState,
    isAccessibilityEnabled: Boolean,
    isOverlayEnabled: Boolean,
    debugMode: Boolean,
    platformMode: PlatformMode,
    effectivePlatformMode: PlatformMode?,
    appClassifier: AppClassifier,
    approvalMode: ApprovalMode,
    onNavigate: (SettingsPage) -> Unit,
    onDismiss: () -> Unit
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        PageMastheadIdentity(title = "Settings", onClose = onDismiss)

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = MaterialTheme.pocketPilot.spacing.lg),
            verticalArrangement = Arrangement.spacedBy(MaterialTheme.pocketPilot.spacing.sm)
        ) {
            SectionHeader("Behavior")
            SettingsNavigationRow(
                title = "Model server",
                subtitle = settings.serverModelId.ifBlank { "Configure your local server" },
                onClick = { onNavigate(SettingsPage.MODEL_SERVER) }
            )
            SettingsNavigationRow(
                title = "Agent Behavior",
                subtitle = agentBehaviorSubtitle( platformMode, effectivePlatformMode, approvalMode),
                onClick = { onNavigate(SettingsPage.AGENT_BEHAVIOR) }
            )

            SectionHeader("Access")
            SettingsNavigationRow(
                title = "App Access",
                subtitle = appAccessSubtitle(appClassifier, approvalMode),
                onClick = { onNavigate(SettingsPage.APP_ACCESS) }
            )
            SettingsNavigationRow(
                title = "System & Debug",
                subtitle = permissionsSubtitle(isAccessibilityEnabled, isOverlayEnabled, debugMode),
                onClick = { onNavigate(SettingsPage.PERMISSIONS_ADVANCED) }
            )

            SectionHeader("About")
            SettingsNavigationRow(
                title = "Open Source Licenses",
                subtitle = "PocketPilot is Apache 2.0 · view third-party notices",
                onClick = { onNavigate(SettingsPage.OPEN_SOURCE_LICENSES) }
            )

            Fleuron()

            Text(
                text = "Version ${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})",
                style = MaterialTheme.pocketPilot.monoSmall,
                color = MaterialTheme.pocketPilot.inkFaint,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(modifier = Modifier.height(16.dp))
        }
    }
}

private fun agentBehaviorSubtitle(
    platformMode: PlatformMode,
    effectivePlatformMode: PlatformMode?,
    approvalMode: ApprovalMode,
): String {
    val approvalChip = when (approvalMode) {
        ApprovalMode.SMART -> "Per-App"
        ApprovalMode.AUTO_APPROVE -> "Auto-Approve"
        ApprovalMode.ALWAYS_ASK -> "Always Ask"
    }
    val displayChip = when (platformMode) {
        PlatformMode.ACCESSIBILITY -> when (effectivePlatformMode) {
            PlatformMode.VIRTUAL_DISPLAY -> " · Virtual Display (this session)"
            else -> ""
        }
        PlatformMode.VIRTUAL_DISPLAY -> when (effectivePlatformMode) {
            PlatformMode.ACCESSIBILITY -> " · Virtual Display (next session)"
            else -> " · Virtual Display"
        }
    }
    return "$approvalChip · Screenshots$displayChip"
}

private fun permissionsSubtitle(
    isAccessibilityEnabled: Boolean,
    isOverlayEnabled: Boolean,
    debugMode: Boolean,
): String {
    val grantedCount = listOf(isAccessibilityEnabled, isOverlayEnabled).count { it }
    val permSummary = when (grantedCount) {
        2 -> "All granted"
        1 -> "1 of 2 granted"
        else -> "Setup required"
    }
    return "$permSummary · Debug ${if (debugMode) "on" else "off"}"
}

/** Subtitle for the App Access entry on the Settings home page. */
@Composable
private fun appAccessSubtitle(classifier: AppClassifier, approvalMode: ApprovalMode): String {
    val context = LocalContext.current
    val overrides by classifier.userOverrides.collectAsStateWithLifecycle()
    val counts by produceState<Triple<Int, Int, Int>?>(
        initialValue = null, context, classifier, overrides,
    ) {
        value = withContext(Dispatchers.IO) {
            var allow = 0
            var ask = 0
            var reject = 0
            AppManager.getInstalledApps(context.packageManager).forEach { info ->
                when (classifier.classify(info.packageName)) {
                    AppTier.NORMAL -> allow++
                    AppTier.CAUTIOUS -> ask++
                    AppTier.BLOCKED -> reject++
                }
            }
            Triple(allow, ask, reject)
        }
    }
    val modeLabel = when (approvalMode) {
        ApprovalMode.SMART -> "Per-App"
        ApprovalMode.AUTO_APPROVE -> "Auto-Approve"
        ApprovalMode.ALWAYS_ASK -> "Always Ask"
    }
    return counts?.let { (a, k, r) -> "$modeLabel · $a Allow · $k Ask · $r Reject" }
        ?: "$modeLabel · …"
}
