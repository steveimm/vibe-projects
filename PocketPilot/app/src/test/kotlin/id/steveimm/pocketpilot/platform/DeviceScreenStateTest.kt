package id.steveimm.pocketpilot.platform

import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import androidx.core.content.ContextCompat
import com.google.common.truth.Truth.assertThat
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.slot
import io.mockk.unmockkStatic
import org.junit.After
import org.junit.Before
import org.junit.Test

class DeviceScreenStateTest {
    private val context = mockk<Context>(relaxed = true)
    private val power = mockk<PowerManager>()
    private val keyguard = mockk<KeyguardManager>()
    private val receiver = slot<BroadcastReceiver>()
    private val changes = mutableListOf<Boolean>()
    private val screen = DeviceScreenState(context, changes::add)

    @Before
    fun setUp() {
        mockkStatic(ContextCompat::class)
        every { context.getSystemService(PowerManager::class.java) } returns power
        every { context.getSystemService(KeyguardManager::class.java) } returns keyguard
        every { power.isInteractive } returns true
        every { keyguard.isKeyguardLocked } returns false
        every {
            ContextCompat.registerReceiver(context, capture(receiver), any(), ContextCompat.RECEIVER_NOT_EXPORTED)
        } returns null
    }

    @After
    fun tearDown() {
        screen.stop()
        unmockkStatic(ContextCompat::class)
    }

    @Test
    fun `screen off hides immediately and waking the locked phone does not restore overlays`() {
        screen.start()
        broadcast(Intent.ACTION_SCREEN_OFF)
        assertThat(changes).containsExactly(true, false).inOrder()

        every { keyguard.isKeyguardLocked } returns true
        broadcast(Intent.ACTION_SCREEN_ON)
        broadcast(Intent.ACTION_USER_PRESENT)
        assertThat(changes).containsExactly(true, false).inOrder()

        every { keyguard.isKeyguardLocked } returns false
        broadcast(Intent.ACTION_USER_PRESENT)
        broadcast(Intent.ACTION_USER_PRESENT)
        assertThat(changes).containsExactly(true, false, true).inOrder()
    }

    @Test
    fun `service starting while locked stays unavailable until screen is both awake and unlocked`() {
        every { keyguard.isKeyguardLocked } returns true
        screen.start()
        assertThat(changes).containsExactly(false)

        every { keyguard.isKeyguardLocked } returns false
        every { power.isInteractive } returns false
        screen.refresh()
        assertThat(changes).containsExactly(false)

        every { power.isInteractive } returns true
        screen.refresh()
        assertThat(changes).containsExactly(false, true).inOrder()
    }

    private fun broadcast(action: String) {
        val intent = mockk<Intent>()
        every { intent.action } returns action
        receiver.captured.onReceive(context, intent)
    }
}
