package id.steveimm.pocketpilot.ui.overlay.model

import com.google.common.truth.Truth.assertThat
import org.junit.Test

class CapsuleRenderSpecTest {

    @Test
    fun `running mode shows stopping disabled when stop pending`() {
        val spec = CapsuleRenderSpec.from(
            mode = CapsuleMode.Running("thinking"),
            isStopPending = true,
        )

        val stop = spec.buttons.stop
        assertThat(stop).isNotNull()
        assertThat(stop?.text).isEqualTo("Stopping...")
        assertThat(stop?.enabled).isFalse()
    }

    @Test
    fun `error mode retains its message and accepts a new request`() {
        val spec = CapsuleRenderSpec.from(
            mode = CapsuleMode.Error("oops"),
            isStopPending = true,
        )

        assertThat(spec.buttons.stop).isNull()
        assertThat(spec.expandedBody).isEqualTo("oops")
        assertThat(spec.input).isNotNull()
    }

    @Test
    fun `waiting for approval renders app-level three-button prompt`() {
        val spec = CapsuleRenderSpec.from(
            mode = CapsuleMode.WaitingForApproval(
                callId = "approval-1",
                description = "Tap OK",
                appLabel = "Chrome",
                packageName = "com.android.chrome",
                reason = "Unknown app requires approval",
            )
        )

        assertThat(spec.thought.text).isEqualTo("App access")
        assertThat(spec.expandedBody).isEqualTo("Allow PocketPilot to operate Chrome?")
        assertThat(spec.buttons.primary?.text).isEqualTo("Always")
        assertThat(spec.buttons.secondary?.text).isEqualTo("Session")
        assertThat(spec.buttons.stop?.text).isEqualTo("Reject")
    }
}
