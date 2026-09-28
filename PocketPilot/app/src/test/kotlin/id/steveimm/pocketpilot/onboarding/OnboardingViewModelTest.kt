package id.steveimm.pocketpilot.onboarding

import com.google.common.truth.Truth.assertThat
import id.steveimm.pocketpilot.app.AppSettingsState
import id.steveimm.pocketpilot.app.AppSettingsStore
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Test

class OnboardingViewModelTest {
    private val store = mockk<OnboardingStore>(relaxed = true)
    private val permissions = mockk<PermissionStateMonitor>()
    private val demo = mockk<OnboardingDemoController>(relaxed = true)
    private val settings = AppSettingsState(mockk<AppSettingsStore>(relaxed = true))
    private var accessibility = false
    private var overlay = false

    private fun TestScope.vm(outcomes: StepOutcomes = StepOutcomes()): OnboardingViewModel {
        every { store.loadOutcomes() } returns outcomes
        every { permissions.isAccessibilityEnabled() } answers { accessibility }
        every { permissions.isOverlayEnabled() } answers { overlay }
        every { permissions.isBatteryOptimized() } returns true
        return OnboardingViewModel(store, settings, permissions, demo, this)
    }

    @Test
    fun `new installation requires permissions then server configuration`() = runTest {
        val vm = vm()
        assertThat(vm.currentStep).isEqualTo(WizardStep.Accessibility)
        vm.skipStep()
        assertThat(vm.currentStep).isEqualTo(WizardStep.Accessibility)
        accessibility = true
        vm.onHostResumed()
        advanceUntilIdle()
        assertThat(vm.currentStep).isEqualTo(WizardStep.Overlay)
        vm.skipStep()
        assertThat(vm.currentStep).isEqualTo(WizardStep.Overlay)
        overlay = true
        vm.onHostResumed()
        advanceUntilIdle()
        assertThat(vm.currentStep).isEqualTo(WizardStep.ModelServer)
        vm.skipStep()
        assertThat(vm.currentStep).isEqualTo(WizardStep.ModelServer)
    }

    @Test
    fun `a server URL and model advance without requiring an API key`() = runTest {
        accessibility = true
        overlay = true
        val vm = vm()
        advanceUntilIdle()
        settings.updateServer("http://server-a:8000/v1", "local-model")
        vm.onServerConfigured()
        assertThat(vm.currentStep).isEqualTo(WizardStep.Demo)
        assertThat(vm.outcomes.modelServer).isEqualTo(StepOutcome.Done)
        vm.skipStep()
        vm.finish()
        verify { store.setCompleted() }
    }

    @Test
    fun `stored authentication outcome cannot replace missing server configuration`() = runTest {
        accessibility = true
        overlay = true
        val vm = vm(StepOutcomes(modelServer = StepOutcome.Done))
        advanceUntilIdle()
        assertThat(vm.currentStep).isEqualTo(WizardStep.ModelServer)
        assertThat(vm.outcomes.modelServer).isEqualTo(StepOutcome.Pending)
        vm.finish()
        verify(exactly = 0) { store.setCompleted() }
    }

    @Test
    fun `revoked accessibility prevents a demo from starting`() = runTest {
        accessibility = true
        overlay = true
        settings.updateServer("http://server-a:8000/v1", "local-model")
        val vm = vm(StepOutcomes(modelServer = StepOutcome.Done))
        advanceUntilIdle()
        accessibility = false
        vm.startDemo()
        assertThat(vm.currentStep).isEqualTo(WizardStep.Accessibility)
        verify(exactly = 0) { demo.run(any(), any(), any()) }
    }

    @Test
    fun `demo completion and return to server setup preserve the wizard flow`() = runTest {
        accessibility = true
        overlay = true
        settings.updateServer("http://server-a:8000/v1", "local-model")
        every { demo.run(any(), any(), any()) } answers { firstArg<(String) -> Unit>().invoke("Opened Settings") }
        val vm = vm(StepOutcomes(modelServer = StepOutcome.Done))
        advanceUntilIdle()
        vm.startDemo()
        assertThat(vm.stepState).isInstanceOf(DemoStepState.Success::class.java)
        advanceUntilIdle()
        assertThat(vm.currentStep).isEqualTo(WizardStep.Complete)
        vm.goToServerStep()
        assertThat(vm.currentStep).isEqualTo(WizardStep.ModelServer)
    }

    @Test
    fun `delayed permission callback cannot advance after going back`() = runTest {
        accessibility = true
        overlay = true
        val vm = vm()
        advanceTimeBy(400)
        runCurrent()
        assertThat(vm.currentStep).isEqualTo(WizardStep.Overlay)
        vm.goBack()
        advanceUntilIdle()
        assertThat(vm.currentStep).isEqualTo(WizardStep.Accessibility)
    }
}
