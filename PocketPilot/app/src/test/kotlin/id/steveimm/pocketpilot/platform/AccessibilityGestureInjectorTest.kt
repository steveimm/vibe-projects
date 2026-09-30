package id.steveimm.pocketpilot.platform

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.app.KeyguardManager
import android.os.PowerManager
import com.google.common.truth.Truth.assertThat
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.slot
import io.mockk.unmockkConstructor
import io.mockk.verify
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.Test
import org.junit.Before
import org.junit.After

@OptIn(ExperimentalCoroutinesApi::class)
class AccessibilityGestureInjectorTest {
    private val dispatcher = StandardTestDispatcher()
    private val gesture = mockk<GestureDescription>(relaxed = true)
    private val service = mockk<AccessibilityService>(relaxed = true)
    private var userTouchingBubble = false
    private var interrupted = false
    private var releasedLeases = 0
    private val leasedGestures = mutableListOf<GestureCoordinates>()
    private val gate = object : OverlayTouchGate {
        override fun canInjectGesture(): Boolean = !interrupted
        override fun isUserTouchActive(): Boolean = userTouchingBubble
        override fun beginGesturePassThrough(gesture: GestureCoordinates): AutoCloseable {
            leasedGestures += gesture
            return AutoCloseable { releasedLeases++ }
        }
    }
    private val injector = AccessibilityGestureInjector(service, overlayTouchGate = gate)

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
        mockkConstructor(GestureDescription.Builder::class)
        every { anyConstructed<GestureDescription.Builder>().addStroke(any()) } answers { self as GestureDescription.Builder }
        every { anyConstructed<GestureDescription.Builder>().build() } returns gesture
        val power = mockk<PowerManager>()
        val keyguard = mockk<KeyguardManager>()
        every { service.getSystemService(PowerManager::class.java) } returns power
        every { service.getSystemService(KeyguardManager::class.java) } returns keyguard
        every { power.isInteractive } returns true
        every { keyguard.isKeyguardLocked } returns false
        every { service.dispatchGesture(any(), any(), any()) } answers {
            secondArg<AccessibilityService.GestureResultCallback>().onCompleted(firstArg())
            true
        }
    }

    @After
    fun tearDown() {
        unmockkConstructor(GestureDescription.Builder::class)
        Dispatchers.resetMain()
    }

    @Test
    fun `a plain bubble tap delays the pending gesture until release without stopping it`() = runTest {
        val result = async { injector.injectSwipe(100f, 1000f, 900f, 200f, 2500) }
        runCurrent()
        assertThat(leasedGestures).containsExactly(GestureCoordinates(100f, 1000f, 900f, 200f))

        userTouchingBubble = true
        advanceTimeBy(500)
        runCurrent()
        assertThat(result.isCompleted).isFalse()
        verify(exactly = 0) { service.dispatchGesture(any(), any(), any()) }

        userTouchingBubble = false
        advanceUntilIdle()
        assertThat(result.await()).isInstanceOf(ActionResult.Success::class.java)
        verify(exactly = 1) { service.dispatchGesture(any(), any(), any()) }
        assertThat(releasedLeases).isEqualTo(1)
    }

    @Test
    fun `drag takeover during gesture setup prevents injection and releases the touch lease`() = runTest {
        val result = async { injector.injectSwipe(100f, 1000f, 900f, 200f, 2500) }
        runCurrent()
        userTouchingBubble = true
        interrupted = true
        advanceTimeBy(50)
        runCurrent()

        assertThat(result.await()).isInstanceOf(ActionResult.Cancelled::class.java)
        verify(exactly = 0) { service.dispatchGesture(any(), any(), any()) }
        assertThat(releasedLeases).isEqualTo(1)
    }

    @Test
    fun `a bubble touch interrupting an active swipe waits for release and reports a recoverable action failure`() = runTest {
        val callback = slot<AccessibilityService.GestureResultCallback>()
        every { service.dispatchGesture(any(), capture(callback), any()) } returns true
        val result = async { injector.injectSwipe(100f, 1000f, 900f, 200f, 2500) }
        advanceTimeBy(50)
        runCurrent()
        assertThat(callback.isCaptured).isTrue()

        userTouchingBubble = true
        callback.captured.onCancelled(gesture)
        runCurrent()
        assertThat(result.isCompleted).isFalse()

        userTouchingBubble = false
        advanceUntilIdle()
        assertThat(result.await()).isInstanceOf(ActionResult.Failure::class.java)
        verify(exactly = 1) { service.dispatchGesture(any(), any(), any()) }
        assertThat(releasedLeases).isEqualTo(1)
    }
}
