package id.steveimm.pocketpilot.platform

import com.google.common.truth.Truth.assertThat
import com.google.common.truth.Truth.assertWithMessage
import org.junit.Test

class GestureCoordinatesTest {
    @Test
    fun `taps and long presses only intersect the bubble when their point is inside or on its edge`() {
        assertThat(GestureCoordinates(50f, 50f).intersects(40f, 40f, 60f, 60f)).isTrue()
        assertThat(GestureCoordinates(40f, 60f).intersects(40f, 40f, 60f, 60f)).isTrue()
        assertThat(GestureCoordinates(39f, 50f).intersects(40f, 40f, 60f, 60f)).isFalse()
    }

    @Test
    fun `swipes crossing or touching the bubble require moving it out of the path`() {
        val swipes = listOf(
            GestureCoordinates(0f, 50f, 100f, 50f),
            GestureCoordinates(50f, 100f, 50f, 0f),
            GestureCoordinates(0f, 0f, 100f, 100f),
            GestureCoordinates(100f, 0f, 0f, 100f),
            GestureCoordinates(0f, 40f, 100f, 40f),
            GestureCoordinates(0f, 0f, 40f, 40f),
        )
        for (swipe in swipes) {
            assertWithMessage(swipe.toString()).that(swipe.intersects(40f, 40f, 60f, 60f)).isTrue()
        }
    }

    @Test
    fun `diagonal swipe does not displace a bubble that its surrounding rectangle merely encloses`() {
        val swipe = GestureCoordinates(0f, 0f, 100f, 100f)
        assertThat(swipe.intersects(70f, 10f, 90f, 30f)).isFalse()
        assertThat(swipe.intersects(10f, 70f, 30f, 90f)).isFalse()
        assertThat(GestureCoordinates(100f, 100f, 0f, 0f).intersects(70f, 10f, 90f, 30f)).isFalse()
    }
}
