package id.steveimm.pocketpilot.onboarding

enum class WizardStep { Accessibility, Overlay, Battery, ModelServer, Demo, Complete }
enum class StepOutcome { Pending, Done, Skipped }

data class StepOutcomes(
    val accessibility: StepOutcome = StepOutcome.Pending,
    val overlay: StepOutcome = StepOutcome.Pending,
    val battery: StepOutcome = StepOutcome.Pending,
    val modelServer: StepOutcome = StepOutcome.Pending,
    val demo: StepOutcome = StepOutcome.Pending,
) {
    operator fun get(step: WizardStep): StepOutcome = when (step) {
        WizardStep.Accessibility -> accessibility
        WizardStep.Overlay -> overlay
        WizardStep.Battery -> battery
        WizardStep.ModelServer -> modelServer
        WizardStep.Demo -> demo
        WizardStep.Complete -> StepOutcome.Done
    }
}

sealed interface OnboardingStepState
sealed interface PermissionStepState : OnboardingStepState {
    data object Checking : PermissionStepState
    data object Ready : PermissionStepState
    data object OpeningSettings : PermissionStepState
    data object Satisfied : PermissionStepState
    data object Unsatisfied : PermissionStepState
    data object Skipped : PermissionStepState
}
sealed interface ModelServerStepState : OnboardingStepState {
    data object Ready : ModelServerStepState
}
sealed interface DemoStepState : OnboardingStepState {
    data object Ready : DemoStepState
    data object Preflight : DemoStepState
    data object Running : DemoStepState
    data class Success(val message: String) : DemoStepState
    data class Failure(val reason: String) : DemoStepState
    data object Skipped : DemoStepState
}
sealed interface OnboardingEffect {
    data object OpenAccessibilitySettings : OnboardingEffect
    data object OpenOverlaySettings : OnboardingEffect
    data object OpenBatteryOptimization : OnboardingEffect
    data object OpenBatteryOptimizationList : OnboardingEffect
    data object BringMainActivityToFront : OnboardingEffect
}
