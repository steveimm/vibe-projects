package id.steveimm.pocketpilot.ui.overlay.model

import com.google.common.truth.Truth.assertThat
import id.steveimm.pocketpilot.protocol.PlatformMode
import org.junit.Test

class NavSpecTest {
    @Test
    fun `every overlay state permits app navigation and dismissal`() {
        val modes = listOf(CapsuleMode.Hidden, CapsuleMode.Running("Thinking"), CapsuleMode.TakeoverPending("Pausing"),
            CapsuleMode.Takeover("Paused"), CapsuleMode.WaitingForInput("Question", "q"),
            CapsuleMode.WaitingForAction("Action", "a"), CapsuleMode.Done("Done"), CapsuleMode.Error("Offline"))
        for (platform in PlatformMode.entries) for (mode in modes) for (context in CapsuleContext.entries) {
            val spec = NavSpec.from(context, platform, mode)
            assertThat(spec.showApp).isEqualTo(context != CapsuleContext.MAIN_APP)
            assertThat(spec.showClose).isEqualTo(context != CapsuleContext.MAIN_APP)
        }
    }
}
