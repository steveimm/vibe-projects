package id.steveimm.pocketpilot.app

import android.accessibilityservice.AccessibilityService
import android.content.pm.PackageManager
import android.util.Log
import androidx.lifecycle.LifecycleOwner
import androidx.savedstate.SavedStateRegistryOwner
import id.steveimm.pocketpilot.protocol.ApprovalDecision
import id.steveimm.pocketpilot.protocol.ApprovalDetails
import id.steveimm.pocketpilot.protocol.ApprovalScope
import id.steveimm.pocketpilot.protocol.AskUserType
import id.steveimm.pocketpilot.protocol.SessionEndReason
import id.steveimm.pocketpilot.protocol.TaskOutcome
import id.steveimm.pocketpilot.protocol.PlatformMode
import id.steveimm.pocketpilot.protocol.TurnPhase
import id.steveimm.pocketpilot.ui.overlay.CapsuleStateHolder
import id.steveimm.pocketpilot.ui.overlay.compose.CapsuleOverlayHost
import id.steveimm.pocketpilot.ui.overlay.compose.GlowOverlayHost
import id.steveimm.pocketpilot.ui.overlay.compose.BubbleOverlayHost
import id.steveimm.pocketpilot.ui.overlay.model.CapsuleMode
import id.steveimm.pocketpilot.platform.OverlayTouchGate
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/** ServiceOverlayController — Coordinator between state and overlay windows. */
class ServiceOverlayController(
    context: AccessibilityService,
    lifecycleOwner: LifecycleOwner,
    savedStateRegistryOwner: SavedStateRegistryOwner,
    private val scope: CoroutineScope,
    private val appPackage: String,
    private val logTag: String,
    private var compactOverlaysEnabled: Boolean,
    private val onStop: () -> Unit,
    private val onSend: (String) -> Unit,
    private val onTakeover: () -> Unit,
    private val onResume: () -> Unit,
    private val onSupplement: (String) -> Unit,
    private val onSupplementAndResume: (String) -> Unit,
    private val onUserResponse: (String, String) -> Unit, // (callId, response)
    private val onApprovalResponse: (String, ApprovalDecision, ApprovalScope, String) -> Unit, // (callId, decision, scope, packageName)
    private val onOpenApp: () -> Unit,
    private val onOpenViewer: (() -> Unit)? = null,
    private val onFinishViewer: (() -> Unit)? = null,
    private val bubbleManager: BubbleOverlayHost? = null
) {

    val stateHolder = CapsuleStateHolder()

    /** Package manager for resolving app labels. */
    private val packageManager = context.packageManager

    /** Touch gate for gesture injection pass-through. */
    val overlayTouchGate: OverlayTouchGate
        get() = object : OverlayTouchGate {
            override fun beginGesturePassThrough(): AutoCloseable {
                val capsule = capsuleManager.touchGate.beginGesturePassThrough()
                val bubble = bubbleManager?.beginGesturePassThrough()
                return AutoCloseable { bubble?.close(); capsule.close() }
            }
        }

    private val edgeGlowManager = GlowOverlayHost(
        service = context,
        scope = scope,
        lifecycleOwner = lifecycleOwner,
        savedStateRegistryOwner = savedStateRegistryOwner,
    )
    private val capsuleManager = CapsuleOverlayHost(
        service = context,
        stateHolder = stateHolder,
        scope = scope,
        lifecycleOwner = lifecycleOwner,
        savedStateRegistryOwner = savedStateRegistryOwner,
    ).apply {
        this.onSend = this@ServiceOverlayController.onSend
        this.onStop = {
            if (stateHolder.onStopRequested()) {
                this@ServiceOverlayController.onStop()
            }
        }
        this.onTakeover = {
            stateHolder.onTakeoverRequested()   // immediate visual feedback
            this@ServiceOverlayController.onTakeover()
        }
        this.onResume = this@ServiceOverlayController.onResume
        this.onSupplement = { text -> this@ServiceOverlayController.onSupplement(text) }
        this.onSupplementAndResume = { text ->
            this@ServiceOverlayController.onSupplementAndResume(text)
        }
        this.onUserResponse = { callId, response ->
            if (stateHolder.onUserResponseSent(callId)) {
                this@ServiceOverlayController.onUserResponse(callId, response)
            }
        }
        this.onApprovalResponse = { callId, decision, scope, packageName ->
            if (stateHolder.onApprovalResolved(callId)) {
                this@ServiceOverlayController.onApprovalResponse(callId, decision, scope, packageName)
            }
        }
        this.onOpenApp = { openMainAppAndHideOverlays() }
        this.onDismissError = { dismissError() }
        // Navigation callbacks
        this.onMinimize = {
            showPreference = ShowPreference.BUBBLE
            applyVisibility()
        }
        this.onOpenViewer = { this@ServiceOverlayController.onOpenViewer?.invoke() }
    }

    private var platformMode: PlatformMode = PlatformMode.ACCESSIBILITY
    private var userLocation = OverlayUserLocation.MAIN_APP

    /** Lifecycle guard for stale accessibility events while MainActivity is visible. */
    private var isMainAppResumed = false

    /** Whether the persistent bubble also displays the task controls. */
    private var showPreference = ShowPreference.BUBBLE

    fun setCompactOverlaysEnabled(enabled: Boolean) {
        compactOverlaysEnabled = enabled
        applyVisibility()
    }

    init {
        bubbleManager?.startObserving(stateHolder)

        // Terminal states preserve the last result in the overlay.
        scope.launch {
            stateHolder.mode.collect { mode ->
                if (mode is CapsuleMode.Hidden || mode is CapsuleMode.Done || mode is CapsuleMode.Error) {
                    applyVisibility()
                }
            }
        }
    }

    /** Set platform mode. Call before any events are dispatched. */
    fun setPlatformMode(mode: PlatformMode) {
        platformMode = mode
        stateHolder.setPlatformMode(mode)
        updateContext()
        applyVisibility()
    }

    /** The ONE function that decides which overlay windows are visible. Called after every state change and context change. */
    private fun applyVisibility() {
        val mode = stateHolder.mode.value
        val decision = deriveOverlayVisibility(
            platformMode = platformMode,
            location = userLocation,
            mode = mode,
            hasActiveTask = stateHolder.hasActiveTask,
            showPreference = showPreference,
        )
        Log.i(
            logTag,
            "applyVisibility: platformMode=$platformMode, location=$userLocation, " +
                "mode=${mode::class.simpleName}, hasActiveTask=${stateHolder.hasActiveTask}, " +
                "showPreference=$showPreference => showCapsule=${decision.showCapsule}, " +
                "showBubble=${decision.showBubble}, showGlow=${decision.showGlow}"
        )
        val lockInteraction = !compactOverlaysEnabled && shouldLockUserInteraction(
            platformMode = platformMode,
            location = userLocation,
            mode = mode,
        )
        capsuleManager.setInteractionLocked(lockInteraction)

        if (decision.showCapsule) {
            if (!capsuleManager.isShowing()) {
                capsuleManager.show()
                bubbleManager?.hide()
            }
        } else {
            capsuleManager.hide()
        }

        bubbleManager?.setExpanded(decision.showCapsule)
        if (decision.showBubble) {
            if (bubbleManager?.isShowing() != true) bubbleManager?.show()
        } else {
            bubbleManager?.hide()
        }

        if (decision.showGlow && !compactOverlaysEnabled) {
            if (!edgeGlowManager.isShowing()) {
                edgeGlowManager.show(stateHolder.derivedGlowState)
            }
        } else {
            edgeGlowManager.hideImmediately()
        }

        // Auto-finish the VD viewer once the agent is fully idle so the user isn't stranded on a frozen, non-interactive VD surface with
        // no overlays.
        if (shouldFinishViewerOnIdle(
                platformMode = platformMode,
                location = userLocation,
                mode = mode,
                hasActiveTask = stateHolder.hasActiveTask,
            )
        ) {
            Log.i(logTag, "Auto-finishing VD viewer: agent idle in VD_VIEWER")
            onFinishViewer?.invoke()
        }
    }

    fun onBubbleTapped() {
        showPreference = if (showPreference == ShowPreference.CAPSULE) ShowPreference.BUBBLE else ShowPreference.CAPSULE
        applyVisibility()
    }

    fun onViewerOpened() {
        userLocation = OverlayUserLocation.VD_VIEWER
        showPreference = ShowPreference.CAPSULE
        updateContext()
        applyVisibility()
    }

    fun onViewerClosed() {
        if (userLocation == OverlayUserLocation.VD_VIEWER) {
            userLocation = OverlayUserLocation.OTHER_APP
        }
        showPreference = ShowPreference.BUBBLE
        updateContext()
        applyVisibility()
    }

    /** Synchronous query mirroring [shouldFinishViewerOnIdle] for the activity's startup race-proof. */
    internal fun shouldFinishViewerNow(): Boolean = shouldFinishViewerOnIdle(
        platformMode = platformMode,
        location = userLocation,
        mode = stateHolder.mode.value,
        hasActiveTask = stateHolder.hasActiveTask,
    )

    /** Dismiss the current error state. Callable from both overlay and main-app paths. */
    fun dismissError() {
        showPreference = ShowPreference.BUBBLE
        stateHolder.onDismissError()
    }

    fun hideAll() {
        capsuleManager.hide()
        edgeGlowManager.hideImmediately()
        bubbleManager?.hide()
    }

    fun dispose() {
        edgeGlowManager.dispose()
        capsuleManager.dispose()
        bubbleManager?.dispose()
    }

    fun handleWindowStateChanged(packageName: String?, className: String?, displayId: Int?) {
        handleWindowStateChangedInternal(packageName, className, displayId)
    }

    /** MainActivity foreground callback. */
    fun onMainAppVisible() {
        isMainAppResumed = true
        if (userLocation != OverlayUserLocation.MAIN_APP) {
            userLocation = OverlayUserLocation.MAIN_APP
            updateContext()
        }
        applyVisibility()
    }

    /** MainActivity onStop callback. Releases the sticky MAIN_APP guard and, only if userLocation is still claiming MAIN_APP,
     * force-flips it to OTHER_APP since MainActivity is no longer on screen. */
    fun onMainAppHidden() {
        isMainAppResumed = false
        val next = resolveLocationOnMainAppHidden(userLocation)
        if (next != userLocation) {
            userLocation = next
            updateContext()
        }
        applyVisibility()
    }

    fun onTaskStarted(taskId: String, input: String) {
        stateHolder.onTaskStarted(taskId, input)
        showPreference = ShowPreference.BUBBLE
        applyVisibility()
    }

    fun onTurnPhaseChanged(phase: TurnPhase) {
        stateHolder.setTurnPhase(phase)
        stateHolder.setAgentMidTurn(phase == TurnPhase.EXECUTION || phase == TurnPhase.PLANNING)
        refreshGlowState()
    }

    fun onActionExecuted(toolName: String, success: Boolean) {
        refreshGlowState()
        // applyVisibility not needed: active task state hasn't changed
    }

    fun onTaskCompleted(outcome: TaskOutcome, message: String?) {
        showPreference = ShowPreference.BUBBLE
        stateHolder.onTaskCompleted(outcome, message)
        refreshGlowState()
        // applyVisibility triggered by mode observer (Done/Error)
    }

    fun onSessionCompleted(reason: SessionEndReason) {
        showPreference = ShowPreference.BUBBLE
        stateHolder.onSessionEnded(reason)
        refreshGlowState()
        applyVisibility()
    }

    fun onSessionError(message: String) {
        stateHolder.onError(message)
        refreshGlowState()
        showPreference = ShowPreference.CAPSULE
        applyVisibility()
    }

    fun onSessionTakeover() {
        stateHolder.onTakeoverConfirmed()
        refreshGlowState()
        applyVisibility()
    }

    fun onSessionResumed() {
        stateHolder.onResumed()
        refreshGlowState()
        applyVisibility()
    }

    fun onSupplementReceived(@Suppress("UNUSED_PARAMETER") text: String) {
        if (capsuleManager.isShowing()) {
            capsuleManager.flashSupplementConfirmation(stateHolder.isAgentMidTurn.value)
        }
    }

    fun onAskUser(type: AskUserType, message: String, callId: String) {
        stateHolder.onAskUser(type, message, callId)
        showPreference = ShowPreference.CAPSULE
        applyVisibility()
    }

    fun suppressForScreenshot(): AutoCloseable {
        val tokens = listOfNotNull(capsuleManager.suppressForScreenshot(), edgeGlowManager.suppressForScreenshot(),
            bubbleManager?.suppressForScreenshot())
        return AutoCloseable { tokens.asReversed().forEach { it.close() } }
    }

    fun onApprovalRequired(details: ApprovalDetails) {
        val appLabel = resolveAppLabel(details.packageName)

        Log.d(logTag, "onApprovalRequired: tool=${details.toolName}, app=$appLabel (${details.packageName}), callId=${details.callId}")
        stateHolder.onApprovalRequired(
            callId = details.callId,
            description = details.description,
            appLabel = appLabel,
            packageName = details.packageName,
            reason = details.reason,
        )
        showPreference = ShowPreference.CAPSULE
        applyVisibility()
    }

    private fun resolveAppLabel(packageName: String): String =
        try {
            packageManager.getApplicationLabel(
                @Suppress("DEPRECATION")
                packageManager.getApplicationInfo(packageName, 0)
            ).toString().ifBlank { packageName }
        } catch (_: PackageManager.NameNotFoundException) {
            packageName
        }

    private fun handleWindowStateChangedInternal(
        packageName: String?,
        className: String?,
        displayId: Int?,
    ) {
        val nextLocation = resolveUserLocation(
            appPackage = appPackage,
            packageName = packageName,
            className = className,
            displayId = displayId,
        ) ?: return

        // While MainActivity is resumed, ignore non-self window events so a queued event from a previously-foregrounded app can't flip
        // userLocation back to OTHER_APP and surface the system overlay over our own UI.
        if (isMainAppResumed && nextLocation != OverlayUserLocation.MAIN_APP) {
            Log.d(
                logTag,
                "Ignoring window event while MainActivity resumed: pkg=$packageName, " +
                    "class=$className, displayId=$displayId, would-be=$nextLocation"
            )
            return
        }

        if (nextLocation != userLocation) {
            Log.d(
                logTag,
                "Window changed: pkg=$packageName, class=$className, displayId=$displayId, " +
                    "from=$userLocation, to=$nextLocation, hasActiveTask=${stateHolder.hasActiveTask}"
            )
            userLocation = nextLocation
            updateContext()
            applyVisibility()
        }
    }

    private fun updateContext() {
        val ctx = resolveCapsuleContext(platformMode, userLocation)
        stateHolder.setContext(ctx)
        stateHolder.setHasBubble(bubbleManager != null)
    }

    private fun refreshGlowState() {
        if (!edgeGlowManager.isShowing()) return
        edgeGlowManager.updateState(stateHolder.derivedGlowState)
    }

    private fun openMainAppAndHideOverlays() {
        onMainAppVisible()
        onOpenApp()
    }
}
