package id.steveimm.pocketpilot.qa

import id.steveimm.pocketpilot.app.AppSettingsState
import id.steveimm.pocketpilot.app.AppSettingsStore
import id.steveimm.pocketpilot.protocol.PlatformMode
import id.steveimm.pocketpilot.ui.settings.PermissionsAdvancedSettingsPage
import id.steveimm.pocketpilot.ui.settings.SettingsSheet
import id.steveimm.pocketpilot.ui.theme.PocketPilotTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext

/** Render the real SettingsSheet with sensible defaults; callers override what they need. Used by navigation tests (S1-S4) that
 * exercise the full sheet. */
@Composable
internal fun TestSettingsSheet(
    onDismiss: () -> Unit = {},
) {
    val context = LocalContext.current
    PocketPilotTheme {
        SettingsSheet(
            settings = remember { AppSettingsState(AppSettingsStore(context)) },
            perceptionMode = "accessibility_only",
            onPerceptionModeChange = {},
            debugMode = false,
            onDebugModeChange = {},
            traceEnabled = false,
            onTraceEnabledChange = {},
            isAccessibilityEnabled = true,
            isOverlayEnabled = true,
            onAccessibilityClick = {},
            onOverlayClick = {},
            platformMode = PlatformMode.ACCESSIBILITY,
            effectivePlatformMode = null,
            onPlatformModeChange = {},
            onDismiss = onDismiss,
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
