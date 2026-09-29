package id.steveimm.pocketpilot.app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.lifecycleScope
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import id.steveimm.pocketpilot.BuildConfig
import id.steveimm.pocketpilot.onboarding.StepOutcome
import id.steveimm.pocketpilot.ui.chat.SettingsDeepLink
import id.steveimm.pocketpilot.auth.ServerCredentialStore
import id.steveimm.pocketpilot.history.ResumedSessionData
import id.steveimm.pocketpilot.history.SessionHistoryManager
import id.steveimm.pocketpilot.history.model.SessionInfo
import id.steveimm.pocketpilot.history.model.isReloadable
import id.steveimm.pocketpilot.history.storage.SessionStorage
import id.steveimm.pocketpilot.onboarding.OnboardingDemoController
import id.steveimm.pocketpilot.onboarding.OnboardingEffect
import id.steveimm.pocketpilot.onboarding.OnboardingStore
import id.steveimm.pocketpilot.onboarding.OnboardingViewModel
import id.steveimm.pocketpilot.onboarding.PermissionStateMonitor
import id.steveimm.pocketpilot.perception.PerceptionConfig
import id.steveimm.pocketpilot.protocol.ApprovalMode
import id.steveimm.pocketpilot.protocol.SessionConfig
import id.steveimm.pocketpilot.protocol.SessionLlmConfig
import id.steveimm.pocketpilot.platform.OverlayTouchGate
import id.steveimm.pocketpilot.protocol.SessionState
import id.steveimm.pocketpilot.session.AgentSession
import id.steveimm.pocketpilot.session.SessionCoordinator
import id.steveimm.pocketpilot.session.SubmitResult
import id.steveimm.pocketpilot.tool.AppClassifierHolder
import id.steveimm.pocketpilot.ui.chat.ChatViewModel
import id.steveimm.pocketpilot.ui.onboarding.OnboardingScreen
import id.steveimm.pocketpilot.ui.overlay.visualizer.ActionVisualizerManager
import id.steveimm.pocketpilot.ui.theme.PocketPilotTheme
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : ComponentActivity() {

    companion object {
        private const val TAG = "MainActivity"
        private const val KEY_INTENT_PAYLOAD_CONSUMED = "intent_payload_consumed"
        private const val KEY_PENDING_GOAL_CONFIRMATION = "pending_goal_confirmation"
        const val EXTRA_SERVER_BASE_URL = "server_base_url"
        const val EXTRA_SERVER_MODEL_ID = "server_model_id"
        const val EXTRA_SERVER_API_KEY = "server_api_key"
        const val EXTRA_GOAL = "goal"
        const val EXTRA_FRESH_SESSION = "fresh_session"
        const val EXTRA_PERCEPTION_MODE = "perception_mode"
        const val EXTRA_DEBUG_MODE = "debug_mode"
        const val EXTRA_TRACE_ENABLED = "trace_enabled"
        const val EXTRA_TRACE_RUN_ID = "trace_run_id"
        const val EXTRA_APPROVAL_MODE = "approval_mode"
        const val EXTRA_PLATFORM_MODE = "platform_mode"
        const val EXTRA_EXCLUDED_TOOLS = "excluded_tools"
        const val EXTRA_EVAL_TURN_BUDGET = "eval_turn_budget"
        const val EXTRA_REQUEST_VOICE_PERMISSION = "request_voice_permission"
    }

    private val sessionScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private val coordinator = SessionCoordinator(sessionScope)
    private lateinit var settingsState: AppSettingsState
    private var pendingTraceEnabled: Boolean? = null
    private var pendingTraceRunId: String? = null
    private var pendingExcludedTools: Set<String> = emptySet()
    private var pendingApprovalMode: ApprovalMode? = null
    private var pendingEvalTurnBudget: Int? = null
    private var pendingAutoStartGoal: String? = null
    private var pendingGoalRunnable: Runnable? = null
    private var pendingGoalForConfirmation by mutableStateOf<String?>(null)
    private var intentPayloadConsumed = false
    private lateinit var sessionHistoryManager: SessionHistoryManager
    private lateinit var viewModel: ChatViewModel
    private var showSettings by mutableStateOf(false)
    private var pendingSettingsDeepLink by mutableStateOf<SettingsDeepLink?>(null)
    private lateinit var onboardingStore: OnboardingStore
    private lateinit var credentialStore: ServerCredentialStore
    private var onboardingViewModel: OnboardingViewModel? = null
    private var onboardingRequired by mutableStateOf(false)
    private var pendingVoicePermissionRequest by mutableStateOf(false)

    internal fun isVoicePermissionRequestPending(): Boolean = pendingVoicePermissionRequest

    internal fun clearVoicePermissionRequest() {
        pendingVoicePermissionRequest = false
    }

    private fun consumeVoicePermissionRequestIfPresent(intent: Intent) {
        if (intent.getBooleanExtra(EXTRA_REQUEST_VOICE_PERMISSION, false)) {
            pendingVoicePermissionRequest = true
            // Defensively strip the extra so subsequent recompositions / intent re-reads do not re-fire.
            intent.removeExtra(EXTRA_REQUEST_VOICE_PERMISSION)
        }
    }

    private enum class SessionLaunchPolicy {
        AUTO,
        FORCE_FRESH
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        intentPayloadConsumed = savedInstanceState?.getBoolean(KEY_INTENT_PAYLOAD_CONSUMED, false) ?: false
        pendingGoalForConfirmation = savedInstanceState?.getString(KEY_PENDING_GOAL_CONFIRMATION)
        settingsState = AppSettingsState.create(applicationContext)
        settingsState.load()

        // Onboarding: migrate + check completion
        onboardingStore = OnboardingStore(applicationContext)
        credentialStore = ServerCredentialStoreHolder.get(applicationContext)
        onboardingStore.migrateIfNeeded {
            hasLegacyUsageEvidence()
        }
        // Eval/debug bypass: EXTRA_FRESH_SESSION + EXTRA_GOAL → skip onboarding (debug only)
        onboardingRequired = !onboardingStore.isCompleted && !isEvalIntent(intent)

        if (onboardingRequired) {
            val vm = OnboardingViewModel(
                store = onboardingStore,
                settingsState = settingsState,
                permissionMonitor = PermissionStateMonitor(applicationContext),
                demoController = OnboardingDemoController(
                    settingsState = settingsState,
                    scope = lifecycleScope
                ),
                scope = lifecycleScope
            )
            onboardingViewModel = vm
        }

        consumeVoicePermissionRequestIfPresent(intent)
        handleIntent(intent)
        val sessionStorage = SessionStorage(applicationContext)
        sessionHistoryManager = SessionHistoryManager.create(sessionStorage, sessionScope)
        viewModel =
                ChatViewModel(
                        sessionProvider = { coordinator.currentSession },
                        sessionHistoryManager = sessionHistoryManager,
                        onSessionNeeded = { text -> ensureSessionAndSend(text) }
                )

        setContent {
            if (onboardingRequired) {
                val vm = onboardingViewModel!!
                PocketPilotTheme {
                    OnboardingScreen(
                        settings = settingsState,
                        onServerSaved = vm::onServerConfigured,
                        currentStep = vm.currentStep,
                        stepState = vm.stepState,
                        outcomes = vm.outcomes,
                        accessibilityGranted = vm.isAccessibilityEnabled(),
                        overlayGranted = vm.isOverlayEnabled(),
                        batteryGranted = vm.isBatteryOptimized(),
                        effects = vm.effects,
                        onBack = { vm.goBack() },
                        onContinue = { vm.continueForward() },
                        onOpenSettings = { vm.openSystemSettings() },
                        onSkipStep = { vm.skipStep() },
                        onStartDemo = { vm.startDemo() },
                        onGoToServerStep = { vm.goToServerStep() },
                        onFinish = {
                            vm.finish()
                            onboardingRequired = false
                        },
                        onEffect = { effect -> handleOnboardingEffect(effect) }
                    )
                }
            } else {
                var repairModel by remember { mutableStateOf(deriveRepairModel()) }
                val lifecycleOwner = LocalLifecycleOwner.current
                DisposableEffect(lifecycleOwner) {
                    val observer = LifecycleEventObserver { _, event ->
                        if (event == Lifecycle.Event.ON_RESUME) {
                            repairModel = deriveRepairModel()
                        }
                    }
                    lifecycleOwner.lifecycle.addObserver(observer)
                    onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
                }
                MainActivityContent(
                    viewModel = viewModel,
                    settingsState = settingsState,
                    showSettings = showSettings,
                    onShowSettingsChange = {
                        showSettings = it
                        if (!it) pendingSettingsDeepLink = null
                    },
                    initialSettingsDeepLink = pendingSettingsDeepLink,
                    onSessionSelect = { session ->
                        coordinator.selectedSessionForReload = session
                        viewModel.resumeSession(session) {
                            sessionHistoryManager.setActiveSessionId(null)
                            sessionHistoryManager.getRecordingService().clearSessionAndAwait()
                            coordinator.detachSession()
                            Log.d(
                                    TAG,
                                    "History session resumed for viewing; cleared recording state"
                            )
                        }
                    },
                    onNewSession = {
                        coordinator.selectedSessionForReload = null
                        lifecycleScope.launch { coordinator.clearSession() }
                        viewModel.startNewSession(settingsState.serverModelId, BuildConfig.VERSION_NAME)
                    },
                    onOpenViewer = { openViewer(this@MainActivity) },
                    onOpenApp = { pkg ->
                        packageManager.getLaunchIntentForPackage(pkg)
                            ?.apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
                            ?.let { startActivity(it) }
                    },
                    isAccessibilityEnabled = AgentService.instance != null,
                    isOverlayEnabled = Settings.canDrawOverlays(this@MainActivity),
                    onAccessibilityClick = { openAccessibilitySettings(this@MainActivity) },
                    onOverlayClick = { openOverlaySettings(this@MainActivity) },
                    repairModel = repairModel,
                    onFixBattery = {
                        handleOnboardingEffect(OnboardingEffect.OpenBatteryOptimization)
                    },
                    effectivePlatformModeFlow = AgentService.instance?.effectivePlatformMode
                        ?: kotlinx.coroutines.flow.MutableStateFlow(null),
                    appClassifier = AppClassifierHolder.get(applicationContext),
                )
                pendingGoalForConfirmation?.let { goal ->
                    AlertDialog(
                        onDismissRequest = { pendingGoalForConfirmation = null },
                        title = { Text("External Goal") },
                        text = { Text("An external app wants to run:\n\"$goal\"") },
                        confirmButton = {
                            TextButton(onClick = {
                                val confirmed = goal
                                pendingGoalForConfirmation = null
                                scheduleGoalDispatch(confirmed)
                            }) { Text("Run") }
                        },
                        dismissButton = {
                            TextButton(onClick = {
                                pendingGoalForConfirmation = null
                            }) { Text("Cancel") }
                        }
                    )
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Log.d(TAG, "onNewIntent called")
        setIntent(intent)
        consumeVoicePermissionRequestIfPresent(intent)
        intentPayloadConsumed = false
        if (onboardingRequired && isEvalIntent(intent)) {
            Log.d(TAG, "Eval intent received during onboarding; bypassing onboarding")
            onboardingRequired = false
        }
        handleIntent(intent)
        AgentService.instance?.onMainAppVisible()
    }

    private fun isEvalIntent(intent: Intent): Boolean =
        BuildConfig.DEBUG &&
            intent.getBooleanExtra(EXTRA_FRESH_SESSION, false) &&
            intent.hasExtra(EXTRA_GOAL)

    override fun onStart() {
        super.onStart()
        AgentService.instance?.onMainAppVisible()
        rebindActiveServiceSessionIfNeeded()
        retryPendingAutoStartGoalIfReady()
    }

    override fun onResume() {
        super.onResume()
        AgentService.instance?.onMainAppVisible()
        onboardingViewModel?.onHostResumed()
        retryPendingAutoStartGoalIfReady()
    }

    override fun onStop() {
        super.onStop()
        // Use onStop, NOT onPause: between onPause and onStop the activity is still drawn on screen (e.g. when launching another app, the
        // new app's accessibility event fires before this activity is fully hidden).
        AgentService.instance?.onMainAppHidden()
    }

    override fun onDestroy() {
        pendingGoalRunnable?.let { window.decorView.removeCallbacks(it) }
        pendingGoalRunnable = null
        sessionScope.cancel()
        super.onDestroy()
        Log.d(TAG, "onDestroy called, session active: ${coordinator.currentSession != null}")
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putBoolean(KEY_INTENT_PAYLOAD_CONSUMED, intentPayloadConsumed)
        pendingGoalForConfirmation?.let {
            outState.putString(KEY_PENDING_GOAL_CONFIRMATION, it)
        }
    }

    private fun handleIntent(intent: Intent) {
        val payload = MainActivityIntentPayload.from(intent)
        val alreadyConsumed = intentPayloadConsumed
        intentPayloadConsumed = true
        lifecycleScope.launch {
            val applyResult = try {
                applyIntentPayloadToSettings(
                    payload = payload,
                    settingsState = settingsState,
                    credentialStore = credentialStore,
                    isDebugBuild = BuildConfig.DEBUG,
                    currentPendingTraceEnabled = pendingTraceEnabled,
                    currentPendingTraceRunId = pendingTraceRunId,
                    currentPendingExcludedTools = pendingExcludedTools,
                    currentPendingApprovalMode = pendingApprovalMode,
                    currentPendingEvalTurnBudget = pendingEvalTurnBudget,
                    log = { message -> Log.d(TAG, message) },
                )
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Toast.makeText(this@MainActivity, "Invalid model server configuration", Toast.LENGTH_LONG).show()
                return@launch
            }
            pendingTraceEnabled = applyResult.pendingTraceEnabled
            pendingTraceRunId = applyResult.pendingTraceRunId
            pendingExcludedTools = applyResult.pendingExcludedTools
            pendingApprovalMode = applyResult.pendingApprovalMode
            pendingEvalTurnBudget = applyResult.pendingEvalTurnBudget

            if (alreadyConsumed) {
                Log.d(TAG, "Intent payload already consumed, skipping action dispatch")
                return@launch
            }

            if (BuildConfig.DEBUG) {
                if (payload.freshSession) {
                    Log.d(TAG, "Fresh session requested, clearing existing state")
                    clearCurrentSession()
                    coordinator.selectedSessionForReload = null
                    payload.goalText?.let {
                        Log.d(TAG, "Goal set from intent: $it")
                        delay(500)
                        ensureSessionAndSend(it, launchPolicy = SessionLaunchPolicy.FORCE_FRESH)
                    }
                } else {
                    payload.goalText?.let {
                        Log.d(TAG, "Goal set from intent: $it")
                        scheduleGoalDispatch(it)
                    }
                }
            } else {
                payload.goalText?.let { goal ->
                    Log.d(TAG, "External goal received, awaiting user confirmation: $goal")
                    pendingGoalForConfirmation = goal
                }
            }
        }
    }

    private suspend fun clearCurrentSession() {
        coordinator.clearSession()

        if (::viewModel.isInitialized) {
            viewModel.clearConversation()
        }

        if (::sessionHistoryManager.isInitialized) {
            sessionHistoryManager.setActiveSessionId(null)
            sessionHistoryManager.getRecordingService().clearSessionAndAwait()
        }

        Log.d(TAG, "Current session cleared")
    }

    private fun rebindActiveServiceSessionIfNeeded() {
        val service = AgentService.instance ?: return
        val serviceSession = service.getActiveSession() ?: return
        if (coordinator.currentSession === serviceSession) return
        // Don't rebind a dead session — let the next message create a fresh one
        if (serviceSession.state.value == SessionState.Shutdown) return

        coordinator.attachSession(serviceSession)
        sessionHistoryManager.setActiveSessionId(serviceSession.sessionId.value)
        val snapshot = serviceSession.getServices().recordingService.getCurrentSession()
        snapshot?.let {
            viewModel.restoreMessagesFromRecords(snapshot.messages)
            viewModel.startEventCollection(
                    serviceSession,
                    replayCutoffTimestamp = snapshot.lastUpdated
            )
            Log.i(
                    TAG,
                    "Rebound active session ${serviceSession.sessionId} with ${snapshot.messages.size} recorded messages"
            )
        } ?: run {
            viewModel.startEventCollection(serviceSession)
            Log.i(TAG, "Rebound active session ${serviceSession.sessionId} without recorder snapshot")
        }
    }

    /** Validate preconditions (permissions, services), then route input through the [SessionCoordinator]: submit to existing session,
     * or create a new one. */
    private fun ensureSessionAndSend(
            text: String,
            launchPolicy: SessionLaunchPolicy = SessionLaunchPolicy.AUTO
    ) {
        if (!validateServerSettings()) return

        if (!Settings.canDrawOverlays(this)) {
            Toast.makeText(this, "Please grant Overlay permission", Toast.LENGTH_LONG).show()
            openOverlaySettings(this)
            return
        }

        val service = AgentService.instance
        if (service == null) {
            pendingAutoStartGoal = text
            Toast.makeText(this, "Please enable the Accessibility Service", Toast.LENGTH_LONG)
                    .show()
            openAccessibilitySettings(this)
            return
        }

        lifecycleScope.launch {
            // Try existing session first
            val submitResult = coordinator.submit(text)
            when (submitResult) {
                SubmitResult.SENT -> {
                    pendingAutoStartGoal = null
                    return@launch
                }
                SubmitResult.QUEUED -> return@launch
                SubmitResult.NO_SESSION, SubmitResult.SESSION_DEAD -> { /* create new session */ }
            }

            // Auto-reload: if session just died and no explicit reload target is set,
            // recover the dead session's checkpoint so the user keeps context.
            var autoReload = false
            if (coordinator.selectedSessionForReload == null
                && launchPolicy != SessionLaunchPolicy.FORCE_FRESH
            ) {
                val deadFileName = coordinator.consumeDeadSessionFileName()
                val deadSessionId = sessionHistoryManager.getCurrentSessionId()
                if (deadFileName != null && deadSessionId != null) {
                    coordinator.selectedSessionForReload = SessionInfo(
                        id = deadSessionId,
                        fileName = deadFileName,
                        startTime = 0,
                        lastUpdated = 0,
                        messageCount = 0,
                        displayTitle = "",
                        firstUserMessage = ""
                    )
                    autoReload = true
                }
            }

            // Create new session under coordinator's creation lock
            try {
                val result = coordinator.createAndSubmit(text) {
                    createOrReloadSession(service, launchPolicy, autoReload)
                }
                when (result) {
                    id.steveimm.pocketpilot.session.CreateResult.Success -> { /* done */ }
                    id.steveimm.pocketpilot.session.CreateResult.LockBusy -> {
                        // Another creation in progress — enqueue so input drains
                        // once the in-flight session becomes Idle/Created.
                        coordinator.enqueue(text)
                    }
                    id.steveimm.pocketpilot.session.CreateResult.Aborted -> {
                        // Creation explicitly refused (e.g. non-reloadable checkpoint).
                        // Coordinator has cleared pendingInputs; do NOT enqueue.
                    }
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.e(TAG, "Failed to create session", e)
                val errMsg = e.message ?: "Unknown error"
                val deepLink = SettingsDeepLink()
                viewModel.reportStartupFailure(text, errMsg, deepLink)
                Toast.makeText(
                                this@MainActivity,
                                "Failed to start: $errMsg",
                                Toast.LENGTH_LONG
                        )
                        .show()
            }
        }
    }

    /** Create or reload a session. Called inside the coordinator's creation lock. Returns null to abort creation (e.g. non-reloadable
     * checkpoint). */
    private suspend fun createOrReloadSession(
            service: AgentService,
            launchPolicy: SessionLaunchPolicy,
            autoReload: Boolean = false
    ): AgentSession? {
        val visualizer = service.getActionVisualizer()
        val touchGate = service.getOverlayTouchGate()
        val selectedForReload =
                if (launchPolicy == SessionLaunchPolicy.FORCE_FRESH) null
                else coordinator.selectedSessionForReload

        val session = if (selectedForReload != null) {
            val reloaded = tryReloadSelectedSession(
                    service = service,
                    visualizer = visualizer,
                    touchGate = touchGate,
                    selected = selectedForReload
            )
            if (reloaded != null) {
                Log.i(TAG, "Reloaded session ${reloaded.sessionId} from checkpoint")
                reloaded
            } else if (autoReload) {
                Log.w(TAG, "Auto-reload failed for ${selectedForReload.id}, falling back to fresh session")
                coordinator.selectedSessionForReload = null
                createFreshSession(service, visualizer, touchGate)
            } else {
                Log.w(TAG, "Explicit resume failed for ${selectedForReload.id}, checkpoint not reloadable")
                coordinator.selectedSessionForReload = null
                Toast.makeText(this, "Session from previous version — start a new session.", Toast.LENGTH_SHORT).show()
                return null
            }
        } else {
            coordinator.selectedSessionForReload = null
            createFreshSession(service, visualizer, touchGate)
        }

        pendingTraceEnabled = null
        pendingTraceRunId = null
        pendingExcludedTools = emptySet()
        pendingApprovalMode = null
        pendingEvalTurnBudget = null
        pendingAutoStartGoal = null

        sessionHistoryManager.setActiveSessionId(session.sessionId.value)
        viewModel.startEventCollection(session)
        service.observeExternalSession(session, session.getServices().platform.mode)

        Log.i(TAG, "Session ready with model=${settingsState.serverModelId} and message sent")
        return session
    }

    private suspend fun tryReloadSelectedSession(
            service: AgentService,
            visualizer: ActionVisualizerManager?,
            touchGate: OverlayTouchGate?,
            selected: SessionInfo
    ): AgentSession? {
        val storage = SessionStorage(applicationContext)
        val contextFileName = storage.contextFileNameFor(selected.fileName)
        val snapshot = storage.readSnapshot(contextFileName).getOrNull() ?: return null
        if (snapshot.schemaVersion != 2) return null
        if (!snapshot.checkpointState.isReloadable()) return null
        if (id.steveimm.pocketpilot.llm.ServerBaseUrlValidator.validate(snapshot.config.serverBaseUrl).isFailure) return null

        val session = withContext(Dispatchers.Default) {
            AgentSession.reload(
                    snapshot = snapshot,
                    service = service,
                    scope = service.serviceScope,
                    credentialStore = credentialStore,
                    visualizer = visualizer,
                    overlayTouchGate = touchGate,
            )
        }
        if (session == null) return null

        val existingRecord = storage.readSession(selected.fileName).getOrNull()
        if (existingRecord != null) {
            session.getServices().recordingService.resumeSession(
                    ResumedSessionData(
                            session = existingRecord,
                            fileName = selected.fileName
                    )
            )
        }
        return session
    }

    private suspend fun createFreshSession(
            service: AgentService,
            visualizer: ActionVisualizerManager?,
            touchGate: OverlayTouchGate?
    ): AgentSession {
        val sessionConfig =
                SessionConfig(
                        approvalMode = pendingApprovalMode ?: settingsState.approvalMode,
                        mainModel = settingsState.serverModelId,
                        debugMode = settingsState.debugMode,
                        traceEnabled = pendingTraceEnabled ?: settingsState.traceEnabled,
                        traceRunId = pendingTraceRunId,
                        llm = SessionLlmConfig(baseUrl = settingsState.serverBaseUrl),
                        perceptionConfig =
                                when (settingsState.perceptionMode) {
                                    "screenshot_only" ->
                                            PerceptionConfig.ScreenshotOnly()
                                    "hybrid" -> PerceptionConfig.Hybrid()
                                    else -> PerceptionConfig.AccessibilityOnly
                                },
                        platformMode = settingsState.platformMode,
                        excludedTools = pendingExcludedTools,
                        evalTurnBudget = pendingEvalTurnBudget
                )

        val session =
                withContext(Dispatchers.Default) {
                    AgentSession.create(
                            config = sessionConfig,
                            service = service,
                            scope = service.serviceScope,
                            credentialStore = credentialStore,
                            visualizer = visualizer,
                            overlayTouchGate = touchGate,
                    )
                }

        return session
    }

    private fun retryPendingAutoStartGoalIfReady() {
        val pendingGoal = pendingAutoStartGoal ?: return
        if (AgentService.instance == null) return
        if (!Settings.canDrawOverlays(this)) return
        if (serverConfigurationError(settingsState) != null) return
        // Clear before dispatching to prevent double-fire from rapid lifecycle callbacks
        pendingAutoStartGoal = null
        ensureSessionAndSend(pendingGoal)
    }

    private fun scheduleGoalDispatch(goal: String, delayMs: Long = 500L) {
        pendingGoalRunnable?.let { window.decorView.removeCallbacks(it) }
        val runnable =
                Runnable {
                    pendingGoalRunnable = null
                    ensureSessionAndSend(goal)
                }
        pendingGoalRunnable = runnable
        window.decorView.postDelayed(runnable, delayMs)
    }

    private fun validateServerSettings(): Boolean {
        val error = serverConfigurationError(settingsState) ?: return true
        pendingSettingsDeepLink = SettingsDeepLink()
        showSettings = true
        Toast.makeText(this, "Configure your model server: $error", Toast.LENGTH_LONG).show()
        return false
    }

    private fun handleOnboardingEffect(effect: OnboardingEffect) {
        when (effect) {
            OnboardingEffect.OpenAccessibilitySettings ->
                openAccessibilitySettings(this)
            OnboardingEffect.OpenOverlaySettings ->
                openOverlaySettings(this)
            OnboardingEffect.OpenBatteryOptimization -> {
                try {
                    startActivity(
                        Intent(
                            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                            Uri.parse("package:$packageName")
                        )
                    )
                } catch (_: Exception) {
                    try {
                        startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                    } catch (_: Exception) {
                        Toast.makeText(this, "Unable to open battery settings", Toast.LENGTH_SHORT).show()
                    }
                }
            }
            OnboardingEffect.OpenBatteryOptimizationList -> {
                try {
                    startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                } catch (_: Exception) {
                    Toast.makeText(this, "Unable to open battery settings", Toast.LENGTH_SHORT).show()
                }
            }
            OnboardingEffect.BringMainActivityToFront -> {
                val intent = Intent(this, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                }
                startActivity(intent)
            }

        }
    }

    /** Derive permission repair model for post-onboarding state. */
    private fun deriveRepairModel(): PermissionStateMonitor.PermissionRepairModel? {
        if (!onboardingStore.isCompleted) return null
        val outcomes = onboardingStore.loadOutcomes()
        val batteryWasDone = outcomes.battery == StepOutcome.Done
        return PermissionStateMonitor(applicationContext).deriveRepairModel(batteryWasDone)
    }

    /** Check for evidence this is an existing user (for onboarding migration). */
    private fun hasLegacyUsageEvidence(): Boolean {
        val settings = settingsState
        if (settings.serverBaseUrl.isNotBlank() && settings.serverModelId.isNotBlank()) return true
        // User app overrides (persistent per-app policy)
        val overrides = AppSettingsStore(applicationContext).loadUserAppOverrides()
        if (overrides.isNotEmpty()) return true
        // Session directory has files
        val sessionsDir = java.io.File(applicationContext.filesDir, "sessions")
        if (sessionsDir.exists() && (sessionsDir.listFiles()?.isNotEmpty() == true)) return true
        return false
    }
}
