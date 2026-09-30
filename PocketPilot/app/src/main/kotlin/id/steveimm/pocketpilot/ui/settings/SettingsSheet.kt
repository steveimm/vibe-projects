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
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.platform.LocalContext
import id.steveimm.pocketpilot.app.AppSettingsState
import id.steveimm.pocketpilot.protocol.ApprovalMode
import id.steveimm.pocketpilot.protocol.PlatformMode
import id.steveimm.pocketpilot.tool.AppClassifier
import id.steveimm.pocketpilot.tool.AppClassifierHolder
import id.steveimm.pocketpilot.ui.theme.PocketPilotMotion

enum class SettingsPage {
    HOME,
    MODEL_SERVER,
    AGENT_BEHAVIOR,
    PERMISSIONS_ADVANCED,
    APP_ACCESS,
    OPEN_SOURCE_LICENSES,
}

@Composable
fun SettingsSheet(
    settings: AppSettingsState,
    debugMode: Boolean,
    onDebugModeChange: (Boolean) -> Unit,
    traceEnabled: Boolean,
    onTraceEnabledChange: (Boolean) -> Unit,
    onClearTraces: suspend () -> Result<Unit>,
    onClearHistory: suspend () -> Result<Unit>,
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
    approvalMode: ApprovalMode = ApprovalMode.SMART,
    onApprovalModeChange: (ApprovalMode) -> Unit = {},
) {
    val focusManager = LocalFocusManager.current
    val keyboard = LocalSoftwareKeyboardController.current
    val hideInput: () -> Unit = { focusManager.clearFocus(force = true); keyboard?.hide() }
    var pages by rememberSaveable(initialPage) {
        mutableStateOf(if (initialPage == SettingsPage.HOME) listOf(initialPage) else listOf(SettingsPage.HOME, initialPage))
    }
    var navigatingForward by rememberSaveable { mutableStateOf(true) }
    val settingsPage = pages.last()
    val navigate: (SettingsPage) -> Unit = { page ->
        if (page != pages.last()) {
            hideInput()
            navigatingForward = true
            pages = pages + page
        }
    }
    val close: () -> Unit = { hideInput(); onDismiss() }
    val goBack: () -> Unit = {
        hideInput()
        navigatingForward = false
        if (pages.size > 1) pages = pages.dropLast(1) else close()
    }
    val reducedMotion = PocketPilotMotion.reducedMotion()

    BackHandler(onBack = goBack)

    Box(
        modifier = modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.background)
    ) {
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
                        val fade = tween<Float>(durationMillis = PocketPilotMotion.Quick)
                        fadeIn(fade) togetherWith fadeOut(fade)
                    } else {
                        val spec = tween<androidx.compose.ui.unit.IntOffset>(
                            durationMillis = PocketPilotMotion.PageSlide,
                            easing = PocketPilotMotion.EaseOutCubic,
                        )
                        if (!navigatingForward) {
                            (slideInHorizontally(spec) { -it / 10 } + fadeIn()) togetherWith
                                (slideOutHorizontally(spec) { it / 10 } + fadeOut())
                        } else {
                            (slideInHorizontally(spec) { it / 10 } + fadeIn()) togetherWith
                                (slideOutHorizontally(spec) { -it / 10 } + fadeOut())
                        }
                    }
                },
                label = "SettingsPageTransition"
            ) { page ->
                when (page) {
                    SettingsPage.HOME -> SettingsHomePage(
                        settings = settings,
                        isAccessibilityEnabled = isAccessibilityEnabled,
                        isOverlayEnabled = isOverlayEnabled,
                        platformMode = platformMode,
                        effectivePlatformMode = effectivePlatformMode,
                        approvalMode = approvalMode,
                        onNavigate = navigate,
                        onDismiss = close
                    )
                    SettingsPage.MODEL_SERVER -> ModelServerSettingsPage(
                        settings = settings,
                        onBack = goBack,
                        onClose = close,
                    )
                    SettingsPage.AGENT_BEHAVIOR -> AgentBehaviorSettingsPage(
                        platformMode = platformMode,
                        effectivePlatformMode = effectivePlatformMode,
                        onPlatformModeChange = onPlatformModeChange,
                        approvalMode = approvalMode,
                        onApprovalModeChange = onApprovalModeChange,
                        onNavigateToAppAccess = { navigate(SettingsPage.APP_ACCESS) },
                        onBack = goBack,
                        onClose = close,
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
                        onClearTraces = onClearTraces,
                        onClearHistory = onClearHistory,
                        onBack = goBack,
                        onClose = close
                    )
                    SettingsPage.APP_ACCESS -> AppAccessSettingsPage(
                        appClassifier = appClassifier,
                        approvalMode = approvalMode,
                        onBack = goBack,
                        onClose = close,
                    )
                    SettingsPage.OPEN_SOURCE_LICENSES -> OpenSourceLicensesPage(
                        onBack = goBack,
                        onClose = close,
                    )
                }
            }
        }
    }
}
