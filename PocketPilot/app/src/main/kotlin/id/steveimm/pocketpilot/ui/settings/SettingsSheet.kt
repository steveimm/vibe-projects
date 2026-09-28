package id.steveimm.pocketpilot.ui.settings

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.displayCutoutPadding
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import id.steveimm.pocketpilot.app.AppSettingsState
import id.steveimm.pocketpilot.app.MemoryEditGate
import id.steveimm.pocketpilot.memory.MemoryStore
import id.steveimm.pocketpilot.protocol.ApprovalMode
import id.steveimm.pocketpilot.protocol.PlatformMode
import id.steveimm.pocketpilot.tool.AppClassifier
import id.steveimm.pocketpilot.tool.AppClassifierHolder
import id.steveimm.pocketpilot.ui.theme.PocketPilotMotion
import id.steveimm.pocketpilot.ui.theme.paperGrain

enum class SettingsPage {
    HOME,
    MODEL_SERVER,
    AGENT_BEHAVIOR,
    MEMORY,
    PERMISSIONS_ADVANCED,
    APP_ACCESS,
    OPEN_SOURCE_LICENSES,
}

@Composable
fun SettingsSheet(
    settings: AppSettingsState,
    perceptionMode: String,
    onPerceptionModeChange: (String) -> Unit,
    debugMode: Boolean,
    onDebugModeChange: (Boolean) -> Unit,
    traceEnabled: Boolean,
    onTraceEnabledChange: (Boolean) -> Unit,
    browserScriptEnabled: Boolean,
    onBrowserScriptEnabledChange: (Boolean) -> Unit,
    isAccessibilityEnabled: Boolean,
    isOverlayEnabled: Boolean,
    onAccessibilityClick: () -> Unit,
    onOverlayClick: () -> Unit,
    platformMode: PlatformMode,
    effectivePlatformMode: PlatformMode?,
    onPlatformModeChange: (PlatformMode) -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
    initialPage: SettingsPage = SettingsPage.HOME,
    appClassifier: AppClassifier = AppClassifierHolder.get(LocalContext.current.applicationContext),
    isSessionRunning: Boolean = false,
    memoryStore: MemoryStore,
    memoryEditGate: MemoryEditGate,
    approvalMode: ApprovalMode = ApprovalMode.SMART,
    onApprovalModeChange: (ApprovalMode) -> Unit = {},
) {
    var settingsPage by rememberSaveable(initialPage) { mutableStateOf(initialPage) }
    val reducedMotion = PocketPilotMotion.reducedMotion()

    BackHandler {
        if (settingsPage != SettingsPage.HOME) settingsPage = SettingsPage.HOME
        else onDismiss()
    }

    Box(
        modifier = modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.background)
    ) {
        Box(modifier = Modifier.matchParentSize().paperGrain())
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .statusBarsPadding()
                .displayCutoutPadding()
                .navigationBarsPadding()
                .imePadding()
        ) {
            AnimatedContent(
                targetState = settingsPage,
                transitionSpec = {
                    if (reducedMotion) {
                        // D1 §8: page slide collapses to a 120ms fade under reduced motion.
                        val fade = tween<Float>(durationMillis = PocketPilotMotion.Quick)
                        fadeIn(fade) togetherWith fadeOut(fade)
                    } else {
                        // D1 §5: 240ms page slide on EaseOutCubic. Sourced from PocketPilotMotion
                        // so settings shares the same page-transition cadence as the rest of the app.
                        val spec = tween<androidx.compose.ui.unit.IntOffset>(
                            durationMillis = PocketPilotMotion.PageSlide,
                            easing = PocketPilotMotion.EaseOutCubic,
                        )
                        if (targetState == SettingsPage.HOME) {
                            slideInHorizontally(spec) { -it } togetherWith slideOutHorizontally(spec) { it }
                        } else {
                            slideInHorizontally(spec) { it } togetherWith slideOutHorizontally(spec) { -it }
                        }
                    }
                },
                label = "SettingsPageTransition"
            ) { page ->
                when (page) {
                    SettingsPage.HOME -> SettingsHomePage(
                        settings = settings,
                        perceptionMode = perceptionMode,
                        isAccessibilityEnabled = isAccessibilityEnabled,
                        isOverlayEnabled = isOverlayEnabled,
                        debugMode = debugMode,
                        platformMode = platformMode,
                        effectivePlatformMode = effectivePlatformMode,
                        appClassifier = appClassifier,
                        approvalMode = approvalMode,
                        onNavigate = { settingsPage = it },
                        onDismiss = onDismiss
                    )
                    SettingsPage.MODEL_SERVER -> ModelServerSettingsPage(
                        settings = settings,
                        onBack = { settingsPage = SettingsPage.HOME },
                        onClose = onDismiss,
                    )
                    SettingsPage.AGENT_BEHAVIOR -> AgentBehaviorSettingsPage(
                        perceptionMode = perceptionMode,
                        onPerceptionModeChange = onPerceptionModeChange,
                        platformMode = platformMode,
                        effectivePlatformMode = effectivePlatformMode,
                        onPlatformModeChange = onPlatformModeChange,
                        browserScriptEnabled = browserScriptEnabled,
                        onBrowserScriptEnabledChange = onBrowserScriptEnabledChange,
                        approvalMode = approvalMode,
                        onApprovalModeChange = onApprovalModeChange,
                        onNavigateToAppAccess = { settingsPage = SettingsPage.APP_ACCESS },
                        onBack = { settingsPage = SettingsPage.HOME },
                        onClose = onDismiss,
                        isSessionRunning = isSessionRunning,
                    )
                    SettingsPage.MEMORY -> MemorySettingsPage(
                        memoryStore = memoryStore,
                        gate = memoryEditGate,
                        onBack = { settingsPage = SettingsPage.HOME },
                        onClose = onDismiss,
                    )
                    SettingsPage.PERMISSIONS_ADVANCED -> PermissionsAdvancedSettingsPage(
                        isAccessibilityEnabled = isAccessibilityEnabled,
                        isOverlayEnabled = isOverlayEnabled,
                        onAccessibilityClick = onAccessibilityClick,
                        onOverlayClick = onOverlayClick,
                        debugMode = debugMode,
                        onDebugModeChange = onDebugModeChange,
                        traceEnabled = traceEnabled,
                        onTraceEnabledChange = onTraceEnabledChange,
                        onBack = { settingsPage = SettingsPage.HOME },
                        onClose = onDismiss
                    )
                    SettingsPage.APP_ACCESS -> AppAccessSettingsPage(
                        appClassifier = appClassifier,
                        memoryStore = memoryStore,
                        gate = memoryEditGate,
                        approvalMode = approvalMode,
                        onBack = { settingsPage = SettingsPage.HOME },
                        onClose = onDismiss,
                    )
                    SettingsPage.OPEN_SOURCE_LICENSES -> OpenSourceLicensesPage(
                        onBack = { settingsPage = SettingsPage.HOME },
                        onClose = onDismiss,
                    )
                }
            }
        }
    }
}
