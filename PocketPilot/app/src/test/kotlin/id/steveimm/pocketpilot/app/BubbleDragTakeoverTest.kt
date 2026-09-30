package id.steveimm.pocketpilot.app

import com.google.common.truth.Truth.assertThat
import com.google.common.truth.Truth.assertWithMessage
import org.junit.Test

class BubbleDragTakeoverTest {
    @Test
    fun `drag keeps control until release and resumes its own pause only once`() {
        val takeover = BubbleDragTakeover()
        assertThat(takeover.begin(isRunning = true)).isTrue()
        assertThat(takeover.begin(isRunning = true)).isFalse()
        assertThat(takeover.onPaused()).isFalse()
        assertThat(takeover.onPaused()).isFalse()

        assertThat(takeover.finish()).isTrue()
        assertThat(takeover.finish()).isFalse()
        assertThat(takeover.onPaused()).isFalse()
        assertThat(takeover.begin(isRunning = true)).isTrue()
    }

    @Test
    fun `short drag waits for the pending pause before resuming`() {
        val takeover = BubbleDragTakeover()
        assertThat(takeover.begin(isRunning = true)).isTrue()
        assertThat(takeover.finish()).isFalse()
        assertThat(takeover.finish()).isFalse()

        assertThat(takeover.onPaused()).isTrue()
        assertThat(takeover.onPaused()).isFalse()
        assertThat(takeover.finish()).isFalse()
    }

    @Test
    fun `another drag before pause confirmation keeps the task paused until its own release`() {
        val takeover = BubbleDragTakeover()
        assertThat(takeover.begin(isRunning = true)).isTrue()
        assertThat(takeover.finish()).isFalse()

        assertThat(takeover.begin(isRunning = false)).isFalse()
        assertThat(takeover.onPaused()).isFalse()
        assertThat(takeover.finish()).isTrue()
        assertThat(takeover.onPaused()).isFalse()
    }

    @Test
    fun `moving a bubble while already paused never resumes the task`() {
        val takeover = BubbleDragTakeover()
        assertThat(takeover.begin(isRunning = false)).isFalse()
        assertThat(takeover.onPaused()).isFalse()
        assertThat(takeover.finish()).isFalse()
        assertThat(takeover.onPaused()).isFalse()
    }

    @Test
    fun `revoking drag ownership prevents a delayed release or pause callback from resuming`() {
        for (phase in listOf("awaiting pause", "paused before release", "released before pause")) {
            val takeover = BubbleDragTakeover()
            takeover.begin(isRunning = true)
            when (phase) {
                "paused before release" -> takeover.onPaused()
                "released before pause" -> takeover.finish()
            }
            takeover.cancel()

            assertWithMessage(phase).that(takeover.finish()).isFalse()
            assertWithMessage(phase).that(takeover.onPaused()).isFalse()
            assertWithMessage(phase).that(takeover.finish()).isFalse()
            assertWithMessage(phase).that(takeover.begin(isRunning = true)).isTrue()
        }
    }
}
