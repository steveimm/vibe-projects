package id.steveimm.pocketpilot.ui.onboarding

import id.steveimm.pocketpilot.app.AppSettingsState
import id.steveimm.pocketpilot.ui.settings.ModelServerForm
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import id.steveimm.pocketpilot.onboarding.DemoStepState
import id.steveimm.pocketpilot.onboarding.OnboardingEffect
import id.steveimm.pocketpilot.onboarding.OnboardingStepState
import id.steveimm.pocketpilot.onboarding.PermissionStepState
import id.steveimm.pocketpilot.onboarding.StepOutcomes
import id.steveimm.pocketpilot.onboarding.WizardStep
import kotlinx.coroutines.flow.Flow

/** Full-screen onboarding wizard. */
@Composable
fun OnboardingScreen(
    settings: AppSettingsState,
    onServerSaved: () -> Unit,
    currentStep: WizardStep,
    stepState: OnboardingStepState?,
    outcomes: StepOutcomes,
    accessibilityGranted: Boolean,
    overlayGranted: Boolean,
    batteryGranted: Boolean,
    effects: Flow<OnboardingEffect>,
    onBack: () -> Unit,
    onContinue: () -> Unit,
    onOpenSettings: () -> Unit,
    onSkipStep: () -> Unit,
    onStartDemo: () -> Unit,
    onFinish: () -> Unit,
    onGoToServerStep: () -> Unit,
    onEffect: (OnboardingEffect) -> Unit
) {
    // Consume one-shot effects
    LaunchedEffect(Unit) {
        effects.collect { effect -> onEffect(effect) }
    }

    val totalSteps = 5
    // Back arrow on all steps except the first
    val backAction: (() -> Unit)? = if (currentStep != WizardStep.Accessibility) onBack else null

    when (currentStep) {
        WizardStep.Accessibility -> {
            OnboardingShell(
                stepIndex = 1,
                totalSteps = totalSteps,
                title = "Let PocketPilot control your phone"
            ) {
                PermissionStepContent(
                    step = WizardStep.Accessibility,
                    state = stepState as? PermissionStepState ?: PermissionStepState.Checking,
                    onOpenSettings = onOpenSettings,
                    onSkip = {},
                    onContinue = onContinue
                )
            }
        }

        WizardStep.Overlay -> {
            OnboardingShell(
                stepIndex = 2,
                totalSteps = totalSteps,
                title = "See controls while the agent works",
                onBack = backAction
            ) {
                PermissionStepContent(
                    step = WizardStep.Overlay,
                    state = stepState as? PermissionStepState ?: PermissionStepState.Checking,
                    onOpenSettings = onOpenSettings,
                    onSkip = {},
                    onContinue = onContinue
                )
            }
        }

        WizardStep.Battery -> {
            OnboardingShell(
                stepIndex = 3,
                totalSteps = totalSteps,
                title = "Keep long tasks alive",
                onBack = backAction
            ) {
                PermissionStepContent(
                    step = WizardStep.Battery,
                    state = stepState as? PermissionStepState ?: PermissionStepState.Checking,
                    onOpenSettings = onOpenSettings,
                    onSkip = onSkipStep,
                    onContinue = onContinue
                )
            }
        }

        WizardStep.ModelServer -> {
            OnboardingShell(stepIndex = 4, totalSteps = totalSteps, title = "Connect your model server", onBack = backAction) {
                ModelServerForm(settings, onSaved = onServerSaved)
            }
        }

        WizardStep.Demo -> {
            OnboardingShell(
                stepIndex = 5,
                totalSteps = totalSteps,
                title = "Try a safe demo",
                onBack = backAction
            ) {
                DemoStepContent(
                    state = stepState as? DemoStepState ?: DemoStepState.Ready,
                    onRunDemo = onStartDemo,
                    onSkip = onSkipStep,
                    onGoToServerStep = onGoToServerStep
                )
            }
        }

        WizardStep.Complete -> {
            OnboardingShell(
                stepIndex = totalSteps,
                totalSteps = totalSteps,
                title = "You're All Set!",
                onBack = backAction
            ) {
                CompleteStepContent(
                    outcomes = outcomes,
                    accessibilityGranted = accessibilityGranted,
                    overlayGranted = overlayGranted,
                    batteryGranted = batteryGranted,
                    onFinish = onFinish
                )
            }
        }
    }
}
