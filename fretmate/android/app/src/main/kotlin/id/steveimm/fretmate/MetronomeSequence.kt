package id.steveimm.fretmate

data class MetronomeConfig(val pcm: ByteArray, val framesPerBeat: Int, val beats: Int) {
    init {
        require(framesPerBeat in 8820..132300 && beats in 1..6)
        require(pcm.size == framesPerBeat * beats * 2)
    }
}

class MetronomeSequence(private var config: MetronomeConfig) {
    private var remaining = 0.0
    private var nextBeat = 0
    private var frame = 0L
    private var click = config.pcm
    private var clickOffset = 0
    private var clickEnd = 0

    fun update(value: MetronomeConfig) {
        remaining *= value.framesPerBeat.toDouble() / config.framesPerBeat
        config = value
    }

    fun render(output: ByteArray, onBeat: (Long, Int) -> Unit) {
        for (offset in output.indices step 2) {
            if (remaining <= 0) {
                val beat = if (nextBeat >= config.beats) 0 else nextBeat
                nextBeat = beat + 1
                onBeat(frame, beat)
                click = config.pcm
                clickOffset = beat * config.framesPerBeat * 2
                clickEnd = clickOffset + 1470 * 2
                remaining += config.framesPerBeat
            }
            output[offset] = if (clickOffset < clickEnd) click[clickOffset++] else 0
            output[offset + 1] = if (clickOffset < clickEnd) click[clickOffset++] else 0
            remaining--
            frame++
        }
    }
}
