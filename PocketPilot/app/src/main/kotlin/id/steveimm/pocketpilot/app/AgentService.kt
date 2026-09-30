package id.steveimm.pocketpilot.app

import android.accessibilityservice.AccessibilityService
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import android.view.Display
import android.view.SurfaceView
import android.view.accessibility.AccessibilityEvent
import id.steveimm.pocketpilot.debug.ActionDebugReceiver
import id.steveimm.pocketpilot.platform.DeviceScreenState
import id.steveimm.pocketpilot.protocol.SessionState
import id.steveimm.pocketpilot.protocol.Op
import id.steveimm.pocketpilot.protocol.PlatformMode
import id.steveimm.pocketpilot.session.AgentSession
import id.steveimm.pocketpilot.ui.overlay.compose.BubbleOverlayHost
import id.steveimm.pocketpilot.ui.overlay.compose.ServiceLifecycleOwner
import id.steveimm.pocketpilot.ui.overlay.visualizer.ActionVisualizerManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.cancel
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.coroutines.withContext
import kotlinx.coroutines.NonCancellable
import id.steveimm.pocketpilot.platform.isScreenAvailable
import id.steveimm.pocketpilot.protocol.SessionConfig
import id.steveimm.pocketpilot.protocol.SessionLlmConfig
import id.steveimm.pocketpilot.protocol.TaskOutcome
import id.steveimm.pocketpilot.ui.overlay.model.CapsuleContext
import java.lang.ref.WeakReference

class AgentService : AccessibilityService() {

    companion object {
        private const val TAG = "AgentService"

        const val ACTION_STOP_AGENT = "id.steveimm.pocketpilot.STOP_AGENT"

        private const val OUR_PACKAGE = "id.steveimm.pocketpilot"
        private const val SHUTDOWN_TIMEOUT_MS = 5_000L

        @Volatile
        private var serviceReference = WeakReference<AgentService>(null)

        var instance: AgentService?
            get() = serviceReference.get()
            private set(value) {
                serviceReference = WeakReference(value)
            }

        private val _connected = MutableStateFlow(false)
        val connected: StateFlow<Boolean> = _connected.asStateFlow()

        private val _statusFlow = MutableStateFlow<String>("")
        val statusFlow: StateFlow<String> = _statusFlow.asStateFlow()
    }

    private val _effectivePlatformMode = MutableStateFlow<PlatformMode?>(null)
    val effectivePlatformMode: StateFlow<PlatformMode?> = _effectivePlatformMode.asStateFlow()

    /** Signal that the VirtualDisplayViewerActivity should finish itself. */
    private val _viewerFinishSignal = MutableSharedFlow<Unit>(
        replay = 0,
        extraBufferCapacity = 1,
        onBufferOverflow = BufferOverflow.DROP_OLDEST,
    )
    val viewerFinishSignal: SharedFlow<Unit> = _viewerFinishSignal.asSharedFlow()

    /** Long-lived service-owned coroutine scope. Cancelled in [onDestroy]. */
    internal val serviceScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private val serviceLifecycleOwner = ServiceLifecycleOwner()
    private var session: AgentSession? = null
    private var overlayController: ServiceOverlayController? = null
    private var actionVisualizer: ActionVisualizerManager? = null
    private var currentPlatformMode: PlatformMode = PlatformMode.ACCESSIBILITY
    @Volatile private var isServiceActive = false
    private val viewerBridge by lazy {
        AgentServiceViewerBridge(
            logTag = TAG,
            overlayControllerProvider = { overlayController },
            platformProvider = { session?.getServices()?.platform as? id.steveimm.pocketpilot.platform.virtualdisplay.VirtualDisplayPlatform },
            openViewerActivity = { openViewerActivity() },
            finishViewerActivity = { _viewerFinishSignal.tryEmit(Unit) },
        )
    }
    private val eventHandler =
            AgentServiceEventHandler(
                    logTag = TAG,
                    updateStatus = ::updateStatus,
                    sessionCleared = {
                        session = null
                        _effectivePlatformMode.value = null
                    },
                    overlayController = { overlayController }
            )

    val capsuleStateHolder get() = overlayController?.stateHolder

    fun getActiveSession(): AgentSession? = session

    internal fun getActionVisualizer(): ActionVisualizerManager? = actionVisualizer

    internal fun getOverlayTouchGate(): id.steveimm.pocketpilot.platform.OverlayTouchGate? {
        val controller = overlayController ?: return null
        return object : id.steveimm.pocketpilot.platform.OverlayTouchGate {
            override fun beginGesturePassThrough(): AutoCloseable = controller.overlayTouchGate.beginGesturePassThrough()
            override fun beginScreenshotCapture(): AutoCloseable {
                val controls = controller.suppressForScreenshot()
                val gestures = actionVisualizer?.suppressForScreenshot()
                return AutoCloseable {
                    gestures?.close()
                    controls.close()
                }
            }
        }
    }


    private val screenState by lazy {
        DeviceScreenState(this) { available ->
            actionVisualizer?.screenAvailable = available
            if (!available) overlayStartJob?.cancel()
            overlayController?.setScreenAvailable(available)
        }
    }

    private var eventCollectorJob: Job? = null

    fun observeExternalSession(
            externalSession: AgentSession,
            platformMode: PlatformMode = PlatformMode.ACCESSIBILITY
    ) {
        if (!isServiceActive) {
            Log.w(TAG, "Ignoring observeExternalSession while service is shutting down")
            return
        }
        Log.i(TAG, "Observing external session: ${externalSession.sessionId}, mode=$platformMode")
        session = externalSession
        currentPlatformMode = platformMode
        _effectivePlatformMode.value = platformMode
        overlayController?.setPlatformMode(platformMode)
        observeSession(externalSession)
    }

    private val stopReceiver =
            object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action == ACTION_STOP_AGENT) {
                        Log.i(TAG, "Received STOP_AGENT broadcast")
                        stopAgent()
                    }
                }
            }

    private val debugExecReceiver = ActionDebugReceiver()

    override fun onServiceConnected() {
        super.onServiceConnected()
        isServiceActive = true
        instance = this
        Log.i(TAG, "AgentService connected")

        val info = serviceInfo
        if (info != null) {
            info.flags =
                    info.flags or
                            android.accessibilityservice.AccessibilityServiceInfo
                                    .FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            serviceInfo = info
            Log.i(TAG, "Updated service info flags: ${info.flags}")
        } else {
            Log.w(TAG, "Service info was null!")
        }

        updateStatus("Accessibility Service connected")

        val compactOverlays = AppSettingsStore(this).loadCompactOverlays()
        val controller =
                ServiceOverlayController(
                        context = this,
                        lifecycleOwner = serviceLifecycleOwner,
                        savedStateRegistryOwner = serviceLifecycleOwner,
                        scope = serviceScope,
                        appPackage = OUR_PACKAGE,
                        logTag = TAG,
                        compactOverlaysEnabled = compactOverlays,
                        actionIndicatorsEnabled = AppSettingsStore(this).loadActionIndicators(),
                        onStop = ::stopFromOverlay,
                        onSend = ::sendOverlayInput,
                        onTakeover = { submitOp(Op.Takeover) },
                        onResume = { submitOp(Op.Resume) },
                        onSupplement = { text -> submitOp(Op.Supplement(text)) },
                        onSupplementAndResume = { text ->
                            submitOps(Op.Supplement(text), Op.Resume)
                        },
                        onUserResponse = { callId, response -> submitOp(Op.UserResponse(callId, response)) },
                        onApprovalResponse = { callId, decision, scope, packageName ->
                            submitOp(Op.Approve(callId, decision, scope, packageName))
                        },
                        onOpenApp = ::openMainActivity,
                        onIndicatorsDismissed = { actionVisualizer?.hide() },
                        onOpenViewer = { viewerBridge.openViewer() },
                        onFinishViewer = { viewerBridge.finishViewer() },
                        bubbleManager =
                                BubbleOverlayHost(
                                        service = this,
                                        lifecycleOwner = serviceLifecycleOwner,
                                        savedStateRegistryOwner = serviceLifecycleOwner,
                                        onDismiss = { overlayController?.dismissOverlays() },
                                        onToggleCapsule = {
                                            overlayController?.onBubbleTapped()
                                        }
                                )
                )
        overlayController = controller

        actionVisualizer = ActionVisualizerManager(
                context = this,
                renderContext = controller.stateHolder.context,
                enabled = AppSettingsStore(this).loadActionIndicators(),
        )
        Log.i(TAG, "ActionVisualizerManager initialized")

        registerDebugStopReceiverIfNeeded(this, stopReceiver)
        registerDebugExecReceiverIfNeeded(this, debugExecReceiver)
        screenState.start()
        _connected.value = true
    }

    fun setActionIndicatorsEnabled(enabled: Boolean) {
        actionVisualizer?.enabled = enabled
        overlayController?.setActionIndicatorsEnabled(enabled)
    }

    fun setCompactOverlaysEnabled(enabled: Boolean) {
        overlayController?.setCompactOverlaysEnabled(enabled)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            screenState.refresh()
            val eventDisplayId = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                event.displayId
            } else {
                Display.DEFAULT_DISPLAY
            }
            overlayController?.handleWindowStateChanged(
                    packageName = event.packageName?.toString(),
                    className = event.className?.toString(),
                    displayId = eventDisplayId,
            )
        }
    }

    override fun onInterrupt() {
        Log.w(TAG, "AgentService interrupted")
    }

    override fun onDestroy() {
        screenState.stop()
        isServiceActive = false
        if (instance === this) {
            instance = null
            _connected.value = false
            _statusFlow.value = ""
        }

        eventCollectorJob?.cancel()
        eventCollectorJob = null

        val currentSession = session
        if (currentSession != null) {
            // Detach shutdown onto a scope that outlives `serviceScope`. The session handles its own checkpoint persistence via
            // NonCancellable, so the main goal here is to avoid blocking the main thread (ANR risk).
            val shutdownScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
            shutdownScope.launch {
                try {
                    val completed = withTimeoutOrNull(SHUTDOWN_TIMEOUT_MS) {
                        currentSession.submit(Op.Shutdown)
                        true
                    }
                    if (completed != true) {
                        Log.w(TAG, "Timed out waiting for session shutdown")
                    }
                } finally {
                    shutdownScope.cancel()
                }
            }
        }
        session = null
        _effectivePlatformMode.value = null

        overlayController?.dispose()
        overlayController = null
        actionVisualizer?.dispose()
        actionVisualizer = null
        unregisterDebugStopReceiverIfNeeded(this, stopReceiver)
        unregisterDebugExecReceiverIfNeeded(this, debugExecReceiver)
        serviceLifecycleOwner.onDestroy()
        super.onDestroy()
        serviceScope.cancel()
    }

    override fun onCreate() {
        super.onCreate()
        serviceLifecycleOwner.onCreate()
    }

    private var overlayStartJob: Job? = null

    private fun stopFromOverlay() {
        overlayStartJob?.cancel()
        overlayStartJob = null
        if (session != null) submitOp(Op.Shutdown)
        else overlayController?.onTaskCompleted(TaskOutcome.USER_STOPPED, "Stopped")
    }

    private fun sendOverlayInput(text: String) {
        if (overlayStartJob?.isActive == true) return
        val controller = overlayController ?: return
        controller.onTaskStarted("overlay-start", text)
        overlayStartJob = serviceScope.launch {
            var created: AgentSession? = null
            var attached = false
            try {
                check(isScreenAvailable(this@AgentService)) { "Unlock the phone to continue." }
                val targetMode = if (currentPlatformMode == PlatformMode.VIRTUAL_DISPLAY &&
                    controller.stateHolder.context.value == CapsuleContext.SCREEN_VIEWING) PlatformMode.VIRTUAL_DISPLAY
                    else PlatformMode.ACCESSIBILITY
                var target = session
                if (target?.state?.value == SessionState.Shutdown || target?.getServices()?.platform?.mode != targetMode) {
                    target?.submit(Op.Shutdown)
                    target = null
                }
                if (target == null) {
                    val settings = AppSettingsStore(this@AgentService).load()
                    val baseUrl = id.steveimm.pocketpilot.llm.ServerBaseUrlValidator.validate(settings.serverBaseUrl).getOrThrow()
                    val model = id.steveimm.pocketpilot.llm.ModelIdValidator.validate(settings.serverModelId).getOrThrow()
                    val config = SessionConfig(mainModel = model, llm = SessionLlmConfig(baseUrl = baseUrl),
                        approvalMode = settings.approvalMode, debugMode = settings.debugMode,
                        traceEnabled = settings.traceEnabled, platformMode = targetMode)
                    target = withContext(Dispatchers.Default) {
                        AgentSession.create(config, this@AgentService, serviceScope, ServerCredentialStoreHolder.get(this@AgentService),
                            actionVisualizer, getOverlayTouchGate()).also { created = it }
                    }
                    check(isScreenAvailable(this@AgentService)) { "Unlock the phone to continue." }
                    observeExternalSession(target, targetMode)
                    attached = true
                }
                target.submit(Op.UserInput(text, observeScreen = true))
            } catch (e: CancellationException) {
                if (controller.stateHolder.inputDraft.value.isBlank()) controller.stateHolder.inputDraft.value = text
                controller.onTaskCompleted(TaskOutcome.USER_STOPPED, "Stopped")
                throw e
            } catch (e: Exception) {
                if (controller.stateHolder.inputDraft.value.isBlank()) controller.stateHolder.inputDraft.value = text
                controller.onSessionError(e.message ?: "Could not start the task. Check the model server in PocketPilot.")
            } finally {
                if (!attached && created != null) withContext(NonCancellable) { created?.submit(Op.Shutdown) }
            }
        }
    }

    private fun openMainActivity() {
        startActivity(Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        })
    }

    private fun submitOp(op: Op) {
        submitOps(op)
    }

    private fun submitOps(vararg ops: Op) {
        if (!isServiceActive) {
            Log.w(TAG, "Dropping ops while service is not active: ${ops.toList()}")
            return
        }
        val currentSession = session
        Log.d(TAG, "submitOps: ${ops.toList()}, session=${currentSession?.sessionId}")

        if (currentSession == null) {
            Log.w(TAG, "No active session for ops: ${ops.toList()}")
            return
        }

        serviceScope.launch {
            ops.forEach { op -> currentSession.submit(op) }
        }
    }

    private fun updateStatus(status: String) {
        Log.d(TAG, status)
        _statusFlow.value = status
    }

    private fun observeSession(agentSession: AgentSession) {
        eventCollectorJob?.cancel()

        val recordingService = agentSession.getServices().recordingService

        eventCollectorJob =
                serviceScope.launch {
                    try {
                        agentSession.events.collect { event ->
                            try {
                                eventHandler.handleEvent(event, recordingService)
                            } catch (e: Exception) {
                                Log.e(
                                        TAG,
                                        "Failed to handle event: ${event::class.simpleName}",
                                        e
                                )
                            }
                        }
                    } catch (e: CancellationException) {
                        throw e
                    } catch (e: Exception) {
                        Log.e(TAG, "Session event collector crashed", e)
                    }
                }
    }

    fun stopAgent() {
        submitOp(Op.Shutdown)
        overlayController?.hideAll()
        updateStatus("🛑 Agent stopped")
    }

    fun onViewerOpened() {
        viewerBridge.onViewerOpened()
    }

    /** Synchronous version of the [shouldFinishViewerOnIdle] rule. */
    fun shouldFinishViewerNow(): Boolean = overlayController?.shouldFinishViewerNow() == true

    fun onViewerClosed() {
        viewerBridge.onViewerClosed()
    }

    fun onMainAppVisible() {
        viewerBridge.onMainAppVisible()
    }

    /** Bring MainActivity to the foreground and ask it to prompt for RECORD_AUDIO. */
    fun requestVoicePermissionViaMainActivity() {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(MainActivity.EXTRA_REQUEST_VOICE_PERMISSION, true)
        }
        startActivity(intent)
    }

    fun onMainAppHidden() {
        viewerBridge.onMainAppHidden()
    }

    private fun openViewerActivity() {
        try {
            val intent =
                    Intent().setClassName(
                                    this,
                                    "id.steveimm.pocketpilot.ui.viewer.VirtualDisplayViewerActivity"
                            )
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open viewer", e)
        }
    }

    fun notifyViewerVisible(surfaceView: SurfaceView) {
        viewerBridge.notifyViewerVisible(surfaceView)
    }

    fun notifyViewerHidden() {
        viewerBridge.notifyViewerHidden()
    }

    fun onViewerTouch(
            action: Int,
            x: Float,
            y: Float,
            downTime: Long,
            eventTime: Long,
            viewWidth: Int,
            viewHeight: Int,
    ): Boolean {
        return viewerBridge.onViewerTouch(
                action = action,
                x = x,
                y = y,
                downTime = downTime,
                eventTime = eventTime,
                viewWidth = viewWidth,
                viewHeight = viewHeight,
        )
    }

}
