package id.steveimm.fretmate

import org.junit.Assert.*
import org.junit.Test

class MetronomeSequenceTest {
    private fun config(frames: Int = 22050, beats: Int = 4, value: Int = 10): MetronomeConfig {
        val pcm = ByteArray(frames * beats * 2)
        for (beat in 0 until beats) {
            pcm.fill((value + beat).toByte(), beat * frames * 2, beat * frames * 2 + 2940)
        }
        return MetronomeConfig(pcm, frames, beats)
    }

    @Test fun tempoChangesPreserveTheRemainingFractionOfTheBeat() {
        for (frames in listOf(8820, 44100, 132300)) {
            val sequence = MetronomeSequence(config())
            val beats = mutableListOf<Pair<Long, Int>>()
            sequence.render(ByteArray(11025 * 2)) { frame, beat -> beats.add(frame to beat) }
            sequence.update(config(frames))
            sequence.render(ByteArray((frames / 2 + 1) * 2)) { frame, beat -> beats.add(frame to beat) }
            assertEquals(listOf(0L to 0, (11025L + frames / 2) to 1), beats)
        }
    }

    @Test fun barLengthChangesContinueNumberingAndWrapAtTheNewEnd() {
        val sequence = MetronomeSequence(config())
        val beats = mutableListOf<Int>()
        sequence.render(ByteArray((22050 + 100) * 2)) { _, beat -> beats.add(beat) }
        sequence.update(config(beats = 3))
        sequence.render(ByteArray((44000 + 1) * 2)) { _, beat -> beats.add(beat) }
        assertEquals(listOf(0, 1, 2, 0), beats)
    }

    @Test fun shrinkingBelowTheCurrentBeatWrapsOnTheNextBeatOnly() {
        val sequence = MetronomeSequence(config(beats = 6))
        val beats = mutableListOf<Int>()
        sequence.render(ByteArray((22050 * 4 + 100) * 2)) { _, beat -> beats.add(beat) }
        sequence.update(config(beats = 2))
        assertEquals(listOf(0, 1, 2, 3, 4), beats)
        sequence.render(ByteArray(22050 * 2)) { _, beat -> beats.add(beat) }
        assertEquals(listOf(0, 1, 2, 3, 4, 0), beats)
    }

    @Test fun changingConfigDoesNotCutOrReplayTheCurrentClick() {
        val sequence = MetronomeSequence(config(value = 10))
        sequence.render(ByteArray(1000 * 2)) { _, _ -> }
        sequence.update(config(frames = 8820, value = 90))
        val tail = ByteArray(600 * 2)
        sequence.render(tail) { _, _ -> fail("Unexpected beat") }
        assertTrue(tail.take(470 * 2).all { it == 10.toByte() })
        assertTrue(tail.drop(470 * 2).all { it == 0.toByte() })
        val next = ByteArray(8820 * 2)
        sequence.render(next) { _, _ -> }
        assertTrue(next.any { it == 91.toByte() })
    }

    @Test fun repeatedUpdatesDoNotInsertClicksOrResetTheBar() {
        val sequence = MetronomeSequence(config())
        val beats = mutableListOf<Pair<Long, Int>>()
        repeat(200) {
            sequence.update(config())
            sequence.render(ByteArray(882)) { frame, beat -> beats.add(frame to beat) }
        }
        assertEquals(listOf(0L to 0, 22050L to 1, 44100L to 2, 66150L to 3), beats)
    }

    @Test fun minimumAndMaximumTempoHaveExactBeatSpacing() {
        for (frames in listOf(8820, 132300)) {
            val sequence = MetronomeSequence(config(frames))
            val beats = mutableListOf<Pair<Long, Int>>()
            sequence.render(ByteArray((frames * 2 + 1) * 2)) { frame, beat -> beats.add(frame to beat) }
            assertEquals(listOf(0L to 0, frames.toLong() to 1, frames.toLong() * 2 to 2), beats)
        }
    }
}
