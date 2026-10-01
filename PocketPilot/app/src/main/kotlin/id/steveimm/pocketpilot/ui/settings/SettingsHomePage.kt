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
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import id.steveimm.pocketpilot.BuildConfig
import id.steveimm.pocketpilot.app.AppSettingsState
import id.steveimm.pocketpilot.protocol.ApprovalMode
import id.steveimm.pocketpilot.protocol.PlatformMode
import id.steveimm.pocketpilot.ui.theme.RootPageHeader
import id.steveimm.pocketpilot.ui.theme.pocketPilot

@Composable
internal fun SettingsHomePage(
    settings: AppSettingsState,
    isAccessibilityEnabled: Boolean,
    isOverlayEnabled: Boolean,
    platformMode: PlatformMode,
    effectivePlatformMode: PlatformMode?,
    approvalMode: ApprovalMode,
    onNavigate: (SettingsPage) -> Unit,
    onDismiss: () -> Unit
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        RootPageHeader(title = "Settings", onClose = onDismiss)

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = MaterialTheme.pocketPilot.spacing.lg),
            verticalArrangement = Arrangement.spacedBy(MaterialTheme.pocketPilot.spacing.sm)
        ) {
            SettingsNavigationRow(
                title = "Model server",
                subtitle = settings.serverModelId.ifBlank { "Configure your local server" },
                onClick = { onNavigate(SettingsPage.MODEL_SERVER) }
            )
            SettingsNavigationRow(
                title = "Automation",
                subtitle = agentBehaviorSubtitle( platformMode, effectivePlatformMode, approvalMode),
                onClick = { onNavigate(SettingsPage.AGENT_BEHAVIOR) }
            )

            SettingsNavigationRow(
                title = "App access",
                onClick = { onNavigate(SettingsPage.APP_ACCESS) }
            )
            SettingsNavigationRow(
                title = "Permissions & diagnostics",
                subtitle = permissionsSubtitle(isAccessibilityEnabled, isOverlayEnabled),
                onClick = { onNavigate(SettingsPage.PERMISSIONS_ADVANCED) }
            )

            Text(
                text = "Version ${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})",
                style = MaterialTheme.pocketPilot.monoSmall,
                color = MaterialTheme.pocketPilot.mutedText,
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
        ApprovalMode.SMART -> "Per app"
        ApprovalMode.AUTO_APPROVE -> "Auto approve"
        ApprovalMode.ALWAYS_ASK -> "Always ask"
    }
    val displayChip = when (platformMode) {
        PlatformMode.ACCESSIBILITY -> when (effectivePlatformMode) {
            PlatformMode.VIRTUAL_DISPLAY -> " · Virtual display (this session)"
            else -> ""
        }
        PlatformMode.VIRTUAL_DISPLAY -> when (effectivePlatformMode) {
            PlatformMode.ACCESSIBILITY -> " · Virtual display (next session)"
            else -> " · Virtual display"
        }
    }
    return "$approvalChip$displayChip"
}

private fun permissionsSubtitle(
    isAccessibilityEnabled: Boolean,
    isOverlayEnabled: Boolean,
): String {
    val grantedCount = listOf(isAccessibilityEnabled, isOverlayEnabled).count { it }
    val permSummary = when (grantedCount) {
        2 -> "All granted"
        1 -> "1 of 2 granted"
        else -> "Setup required"
    }
    return permSummary
}
