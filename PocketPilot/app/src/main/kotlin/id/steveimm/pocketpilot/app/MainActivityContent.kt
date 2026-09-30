package id.steveimm.pocketpilot.app

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import id.steveimm.pocketpilot.onboarding.PermissionStateMonitor.PermissionRepairModel
import id.steveimm.pocketpilot.protocol.PlatformMode
import id.steveimm.pocketpilot.tool.AppClassifier
import id.steveimm.pocketpilot.ui.capsule.CapsuleBinding
import id.steveimm.pocketpilot.ui.capsule.InertCapsuleBinding
import id.steveimm.pocketpilot.ui.capsule.voice.VoicePermissionDisposition
import id.steveimm.pocketpilot.ui.capsule.voice.rememberVoicePermissionGate
import id.steveimm.pocketpilot.ui.chat.ChatScreen
import id.steveimm.pocketpilot.ui.chat.ChatViewModel
import id.steveimm.pocketpilot.ui.chat.SettingsDeepLink
import id.steveimm.pocketpilot.ui.chat.SettingsPage as DeepLinkPage
import id.steveimm.pocketpilot.ui.settings.SettingsPage
import id.steveimm.pocketpilot.ui.settings.SettingsSheet
import id.steveimm.pocketpilot.ui.theme.PocketPilotTheme
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/** Build a [CapsuleBinding] backed by the running [AgentService], or [InertCapsuleBinding] when the service isn't bound yet (so the
 * chat surface still renders its idle state). */
@Composable
private fun rememberCapsuleBinding(): CapsuleBinding {
    val holder = AgentService.instance?.capsuleStateHolder ?: return InertCapsuleBinding
    return remember(holder) {
        CapsuleBinding(
            mode = holder.mode,
            platformMode = holder.platformMode,
            isStopPending = holder.isStopPending,
            onStopRequested = { holder.onStopRequested() },
            onApprovalResolved = { callId -> holder.onApprovalResolved(callId) },
            onUserResponseSent = { callId -> holder.onUserResponseSent(callId) },
            responseDraft = holder.responseDraft,
        )
    }
}

@Composable
internal fun MainActivityContent(
    viewModel: ChatViewModel,
    settingsState: AppSettingsState,
    initialSettingsDeepLink: SettingsDeepLink? = null,
    showSettings: Boolean,
    onShowSettingsChange: (Boolean) -> Unit,
    onSessionSelect: (id.steveimm.pocketpilot.history.model.SessionInfo) -> Unit,
    onNewSession: () -> Unit,
    onDeleteSession: (id.steveimm.pocketpilot.history.model.SessionInfo) -> Unit,
    dataOperationLabel: String?,
    onClearTraces: suspend () -> Result<Unit>,
    onClearHistory: suspend () -> Result<Unit>,
    onOpenViewer: () -> Unit,
    onOpenApp: (String) -> Unit,
    isAccessibilityEnabled: Boolean,
    isOverlayEnabled: Boolean,
    onAccessibilityClick: () -> Unit,
    onOverlayClick: () -> Unit,
    repairModel: PermissionRepairModel? = null,
    onFixBattery: () -> Unit = {},
    effectivePlatformModeFlow: StateFlow<PlatformMode?> = MutableStateFlow(null),
    appClassifier: AppClassifier,
) {
    PocketPilotTheme {
        val sessions by viewModel.sessions.collectAsStateWithLifecycle()
        val effectivePlatformMode by effectivePlatformModeFlow.collectAsStateWithLifecycle()
        // Register the launcher before consuming an overlay voice-permission request, including on a cold start.
        val activity = LocalContext.current as? MainActivity
        if (activity != null) {
            val gate = rememberVoicePermissionGate(activity) { _ -> /* voice-ui owns the real callback */ }
            val pendingRequest = activity.isVoicePermissionRequestPending()
            LaunchedEffect(pendingRequest) {
                if (!pendingRequest) return@LaunchedEffect
                when (gate.disposition()) {
                    VoicePermissionDisposition.Request -> {
                        gate.requestPermission()
                        activity.clearVoicePermissionRequest()
                    }
                    VoicePermissionDisposition.Granted,
                    VoicePermissionDisposition.OpenAppSettings -> {
                        // Clear the handled request. Any remaining denial is shown on the next overlay mic tap.
                        activity.clearVoicePermissionRequest()
                    }
                }
            }
        }

        // Deep-link target captured when a banner/tap wants Settings opened at a specific tab.
        var pendingDeepLink by remember(initialSettingsDeepLink) {
            mutableStateOf<SettingsDeepLink?>(initialSettingsDeepLink)
        }

        Column {
            ChatScreen(
                isVisible = !showSettings && dataOperationLabel == null,
                viewModel = viewModel,
                capsuleBinding = rememberCapsuleBinding(),
                sessions = sessions,
                currentModel = settingsState.serverModelId,
                onOpenSettings = { deepLink ->
                    pendingDeepLink = deepLink
                    onShowSettingsChange(true)
                },
                onSessionSelect = onSessionSelect,
                onNewSession = onNewSession,
                onDeleteSession = onDeleteSession,
                onLoadSessions = viewModel::loadSessions,
                onOpenViewer = onOpenViewer,
                onOpenApp = onOpenApp,
                repairModel = repairModel,
                onFixAccessibility = onAccessibilityClick,
                onFixOverlay = onOverlayClick,
                onFixBattery = onFixBattery,
            )
        }

        if (showSettings) {
            val dismissSettings = {
                onShowSettingsChange(false)
                pendingDeepLink = null
            }
            Surface(
                modifier = Modifier.fillMaxSize(),
                color = MaterialTheme.colorScheme.surface,
            ) {
                SettingsSheet(
                    settings = settingsState,
                    debugMode = settingsState.debugMode,
                    onDebugModeChange = settingsState::updateDebugMode,
                    traceEnabled = settingsState.traceEnabled,
                    onTraceEnabledChange = settingsState::updateTraceEnabled,
                    onClearTraces = onClearTraces,
                    onClearHistory = onClearHistory,
                    isAccessibilityEnabled = isAccessibilityEnabled,
                    isOverlayEnabled = isOverlayEnabled,
                    onAccessibilityClick = onAccessibilityClick,
                    onOverlayClick = onOverlayClick,
                    platformMode = settingsState.platformMode,
                    effectivePlatformMode = effectivePlatformMode,
                    onPlatformModeChange = settingsState::updatePlatformMode,
                    onDismiss = dismissSettings,
                    initialPage = when (pendingDeepLink?.page) {
                        DeepLinkPage.MODEL_SERVER -> SettingsPage.MODEL_SERVER
                        DeepLinkPage.HOME, null -> SettingsPage.HOME
                    },
                    appClassifier = appClassifier,
                    approvalMode = settingsState.approvalMode,
                    onApprovalModeChange = settingsState::updateApprovalMode,
                )
            }
        }
        if (dataOperationLabel != null) {
            Dialog(onDismissRequest = {}, properties = DialogProperties(dismissOnBackPress = false, dismissOnClickOutside = false)) {
                Surface(shape = MaterialTheme.shapes.large, color = MaterialTheme.colorScheme.surface) {
                    Row(
                        modifier = Modifier.padding(24.dp),
                        horizontalArrangement = Arrangement.spacedBy(16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                        Text(dataOperationLabel, style = MaterialTheme.typography.bodyMedium)
                    }
                }
            }
        }
    }
}
