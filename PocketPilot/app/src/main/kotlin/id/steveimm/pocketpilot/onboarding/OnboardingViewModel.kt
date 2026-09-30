package id.steveimm.pocketpilot.onboarding

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import id.steveimm.pocketpilot.app.AppSettingsState
import id.steveimm.pocketpilot.llm.ModelIdValidator
import id.steveimm.pocketpilot.llm.ServerBaseUrlValidator
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.launch

class OnboardingViewModel(
    private val store: OnboardingStore,
    private val settingsState: AppSettingsState,
    private val permissionMonitor: PermissionStateMonitor,
    private val demoController: OnboardingDemoController,
    private val scope: CoroutineScope,
) {
    var currentStep by mutableStateOf(WizardStep.Accessibility)
        private set
    var stepState by mutableStateOf<OnboardingStepState>(PermissionStepState.Checking)
        private set
    var outcomes by mutableStateOf(store.loadOutcomes())
        private set
    private val effectChannel = Channel<OnboardingEffect>(Channel.BUFFERED)
    val effects = effectChannel.receiveAsFlow()
    private var transition: Job? = null
    private var demoAttempt = 0

    init {
        if (!serverConfigured()) mark(WizardStep.ModelServer, StepOutcome.Pending)
        enter(firstIncompleteStep())
    }

    fun isAccessibilityEnabled(): Boolean = permissionMonitor.isAccessibilityEnabled()
    fun isOverlayEnabled(): Boolean = permissionMonitor.isOverlayEnabled()
    fun isBatteryOptimized(): Boolean = permissionMonitor.isBatteryOptimized()

    fun onHostResumed() {
        if (currentStep !in permissionSteps || stepState == PermissionStepState.Checking) return
        checkPermission(returned = stepState == PermissionStepState.OpeningSettings)
    }

    fun goBack() {
        val previous = WizardStep.entries.getOrNull(currentStep.ordinal - 1) ?: return
        if (currentStep == WizardStep.Demo) cancelDemo()
        enter(previous, advance = false)
    }

    fun continueForward() {
        when (currentStep) {
            in permissionSteps -> if (permissionGranted(currentStep) || outcomes[currentStep] == StepOutcome.Skipped) advance()
            WizardStep.ModelServer -> onServerConfigured()
            WizardStep.Demo -> if (outcomes.demo != StepOutcome.Pending) advance()
            else -> Unit
        }
    }

    fun onServerConfigured() {
        if (currentStep != WizardStep.ModelServer || !serverConfigured()) return
        mark(WizardStep.ModelServer, StepOutcome.Done)
        advance()
    }

    fun goToServerStep() {
        cancelDemo()
        mark(WizardStep.ModelServer, StepOutcome.Pending)
        mark(WizardStep.Demo, StepOutcome.Pending)
        enter(WizardStep.ModelServer, advance = false)
    }

    fun openSystemSettings() {
        val effect = when (currentStep) {
            WizardStep.Accessibility -> OnboardingEffect.OpenAccessibilitySettings
            WizardStep.Overlay -> OnboardingEffect.OpenOverlaySettings
            WizardStep.Battery -> OnboardingEffect.OpenBatteryOptimization
            else -> return
        }
        stepState = PermissionStepState.OpeningSettings
        effectChannel.trySend(effect)
    }

    fun startDemo() {
        if (currentStep != WizardStep.Demo || stepState == DemoStepState.Running) return
        val missing = listOf(WizardStep.Accessibility, WizardStep.Overlay).firstOrNull { !permissionGranted(it) }
        if (missing != null) {
            mark(missing, StepOutcome.Pending)
            enter(missing)
            return
        }
        if (!serverConfigured() || outcomes.modelServer != StepOutcome.Done) {
            goToServerStep()
            return
        }
        val attempt = ++demoAttempt
        fun isCurrentAttempt() = currentStep == WizardStep.Demo && demoAttempt == attempt && stepState == DemoStepState.Running
        mark(WizardStep.Demo, StepOutcome.Pending)
        stepState = DemoStepState.Running
        demoController.run(
            onSuccess = {
                if (isCurrentAttempt()) {
                    stepState = DemoStepState.Success(it)
                    mark(WizardStep.Demo, StepOutcome.Done)
                    advanceSoon()
                }
            },
            onFailure = { if (isCurrentAttempt()) stepState = DemoStepState.Failure(it) },
            onBringToFront = { if (isCurrentAttempt()) effectChannel.trySend(OnboardingEffect.BringMainActivityToFront) },
            onStopped = { if (isCurrentAttempt()) stepState = DemoStepState.Ready },
        )
    }

    fun stopDemo() {
        if (currentStep != WizardStep.Demo || stepState != DemoStepState.Running) return
        cancelDemo()
        stepState = DemoStepState.Ready
    }

    private fun cancelDemo() {
        demoAttempt += 1
        demoController.cancel()
    }

    fun skipStep() {
        if (currentStep != WizardStep.Battery && currentStep != WizardStep.Demo) return
        if (currentStep == WizardStep.Demo) cancelDemo()
        mark(currentStep, StepOutcome.Skipped)
        advance()
    }

    fun finish() {
        if (serverConfigured()) store.setCompleted()
    }

    private fun firstIncompleteStep(): WizardStep {
        if (!permissionGranted(WizardStep.Accessibility)) return WizardStep.Accessibility
        if (!permissionGranted(WizardStep.Overlay)) return WizardStep.Overlay
        return WizardStep.entries.firstOrNull { it != WizardStep.Complete && outcomes[it] == StepOutcome.Pending }
            ?: WizardStep.Complete
    }

    private fun enter(step: WizardStep, advance: Boolean = true) {
        transition?.cancel()
        currentStep = step
        when (step) {
            in permissionSteps -> checkPermission(returned = false, advance = advance)
            WizardStep.ModelServer -> {
                stepState = ModelServerStepState.Ready
                if (advance && serverConfigured() && outcomes.modelServer == StepOutcome.Done) advanceSoon()
            }
            else -> stepState = DemoStepState.Ready
        }
    }

    private fun checkPermission(returned: Boolean, advance: Boolean = true) {
        transition?.cancel()
        val step = currentStep
        if (permissionGranted(step)) {
            permissionSatisfied(step, advance)
        } else if (step == WizardStep.Accessibility && returned) {
            stepState = PermissionStepState.Checking
            transition = scope.launch {
                repeat(15) {
                    delay(200)
                    if (currentStep != step) return@launch
                    if (permissionGranted(step)) {
                        permissionSatisfied(step, advance)
                        return@launch
                    }
                }
                stepState = PermissionStepState.Unsatisfied
            }
        } else {
            stepState = if (returned) PermissionStepState.Unsatisfied else PermissionStepState.Ready
        }
    }

    private fun permissionSatisfied(step: WizardStep, advance: Boolean) {
        mark(step, StepOutcome.Done)
        stepState = PermissionStepState.Satisfied
        if (advance) advanceSoon()
    }

    private fun advanceSoon() {
        val expected = currentStep
        transition = scope.launch {
            delay(400)
            if (currentStep == expected) advance()
        }
    }

    private fun advance() = enter(WizardStep.entries.getOrElse(currentStep.ordinal + 1) { WizardStep.Complete })

    private fun permissionGranted(step: WizardStep): Boolean = when (step) {
        WizardStep.Accessibility -> permissionMonitor.isAccessibilityEnabled()
        WizardStep.Overlay -> permissionMonitor.isOverlayEnabled()
        WizardStep.Battery -> permissionMonitor.isBatteryOptimized()
        else -> false
    }

    private fun serverConfigured(): Boolean = ServerBaseUrlValidator.validate(settingsState.serverBaseUrl).isSuccess &&
        ModelIdValidator.validate(settingsState.serverModelId).isSuccess

    private fun mark(step: WizardStep, outcome: StepOutcome) {
        store.saveOutcome(step, outcome)
        outcomes = when (step) {
            WizardStep.Accessibility -> outcomes.copy(accessibility = outcome)
            WizardStep.Overlay -> outcomes.copy(overlay = outcome)
            WizardStep.Battery -> outcomes.copy(battery = outcome)
            WizardStep.ModelServer -> outcomes.copy(modelServer = outcome)
            WizardStep.Demo -> outcomes.copy(demo = outcome)
            WizardStep.Complete -> outcomes
        }
    }

    private val permissionSteps get() = listOf(WizardStep.Accessibility, WizardStep.Overlay, WizardStep.Battery)
}
