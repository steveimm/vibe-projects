package id.steveimm.pocketpilot.ui.settings

import id.steveimm.pocketpilot.app.AgentService
import id.steveimm.pocketpilot.app.AppSettingsStore
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import id.steveimm.pocketpilot.platform.virtualdisplay.ShizukuClient
import id.steveimm.pocketpilot.platform.virtualdisplay.ShizukuRuntimeGateway
import id.steveimm.pocketpilot.protocol.PlatformMode
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch

/** Display Mode section for Agent Behavior settings. Renders a single [ToolSettingsCard] "Virtual Display" toggle driven by
 * [virtualDisplayCardState]. */
@Composable
internal fun DisplaySection(
    persistedMode: PlatformMode,
    effectiveMode: PlatformMode?,
    onPlatformModeChange: (PlatformMode) -> Unit,
) {
    val client = remember { ShizukuClient() }
    val shizukuStatus by rememberShizukuStatus(client)
    val scope = rememberCoroutineScope()
    var permissionRequestPending by remember { mutableStateOf(false) }

    val gate = rememberVirtualDisplayToggleGate { enabled ->
        onPlatformModeChange(
            if (enabled) PlatformMode.VIRTUAL_DISPLAY else PlatformMode.ACCESSIBILITY
        )
    }

    LaunchedEffect(persistedMode) {
        if (persistedMode == PlatformMode.VIRTUAL_DISPLAY) gate.clearError()
    }

    val cardState = virtualDisplayCardState(
        persistedMode = persistedMode,
        effectiveMode = effectiveMode,
        shizukuStatus = shizukuStatus,
        gatePending = gate.pending,
        gateError = gate.error,
    )

    val rowAction: (() -> Unit)? = if (permissionRequestPending) {
        null
    } else when (cardState.rowAction) {
        VirtualDisplayRowAction.RetryEnable -> {
            { gate.setEnabled(true) }
        }
        VirtualDisplayRowAction.RequestPermission -> {
            {
                permissionRequestPending = true
                scope.launch {
                    try {
                        ShizukuRuntimeGateway().requestPermissionAndAwait()
                    } finally {
                        permissionRequestPending = false
                    }
                }
            }
        }
        null -> null
    }

    val rowClickLabel = if (rowAction == null) null else when (cardState.rowAction) {
        VirtualDisplayRowAction.RetryEnable -> "Retry Virtual Display setup"
        VirtualDisplayRowAction.RequestPermission -> "Grant Shizuku permission"
        null -> null
    }

    SettingsSection(title = "Display Mode") {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            ToolSettingsCard(
                title = "Virtual Display",
                status = cardState.status,
                switchChecked = cardState.switchChecked,
                switchEnabled = cardState.switchEnabled,
                onSwitchChange = gate::setEnabled,
                onRowClick = rowAction,
                onRowClickLabel = rowClickLabel,
                switchModifier = Modifier.testTag("display-mode-switch"),
            )
            CompactOverlaysSettingsRow()
        }
    }
}

@Composable
private fun CompactOverlaysSettingsRow() {
    val appContext = LocalContext.current.applicationContext
    val store = remember(appContext) { AppSettingsStore(appContext) }
    var enabled by remember(store) { mutableStateOf(store.loadCompactOverlays()) }

    ToolSettingsCard(
        title = "Compact overlays",
        status = ToolStatusUi(
            label = if (enabled) "On" else "Off",
            subtitle = "Use if your phone turns off accessibility during automation. Keeps controls, without full-screen effects or touch blocking. Tap Takeover before using other apps.",
            tone = ToolStatusTone.Neutral,
        ),
        switchChecked = enabled,
        onSwitchChange = { value ->
            store.saveCompactOverlays(value)
            enabled = value
            AgentService.instance?.setCompactOverlaysEnabled(value)
        },
        switchModifier = Modifier.testTag("compact-overlays-switch"),
    )
}
