package id.steveimm.fretmate

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Handler
import android.os.Process
import java.util.concurrent.ConcurrentLinkedQueue

class StreamingMetronome(
    attributes: AudioAttributes,
    private val handler: Handler,
    initial: MetronomeConfig,
    private val onBeat: (Int) -> Unit,
    private val onError: () -> Unit,
) {
    @Volatile private var config = initial
    @Volatile private var running = false
    private val beats = ConcurrentLinkedQueue<Pair<Long, Int>>()
    private var lastHead = 0L
    private var headWrap = 0L
    private val player = AudioTrack.Builder()
        .setAudioAttributes(attributes)
        .setAudioFormat(AudioFormat.Builder()
            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
            .setSampleRate(44100)
            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
            .build())
        .setTransferMode(AudioTrack.MODE_STREAM)
        .setBufferSizeInBytes(maxOf(1764, AudioTrack.getMinBufferSize(
            44100, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT)))
        .build()

    fun update(value: MetronomeConfig, volume: Float) {
        config = value
        check(player.setVolume(volume) == AudioTrack.SUCCESS)
    }

    fun start(volume: Float) {
        update(config, volume)
        player.setPlaybackPositionUpdateListener(object : AudioTrack.OnPlaybackPositionUpdateListener {
            override fun onMarkerReached(track: AudioTrack) {}
            override fun onPeriodicNotification(track: AudioTrack) {
                if (!running) return
                val head = player.playbackHeadPosition.toLong() and 0xffffffffL
                if (head < lastHead) headWrap += 0x100000000L
                lastHead = head
                while (true) {
                    val beat = beats.peek() ?: break
                    if (beat.first > headWrap + head) break
                    beats.poll()
                    onBeat(beat.second)
                }
            }
        }, handler)
        check(player.setPositionNotificationPeriod(441) == AudioTrack.SUCCESS)
        running = true
        Thread({
            try {
                Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO)
                var current = config
                val sequence = MetronomeSequence(current)
                val buffer = ByteArray(882)
                var started = false
                while (running) {
                    val latest = config
                    if (current !== latest) {
                        sequence.update(latest)
                        current = latest
                    }
                    sequence.render(buffer) { frame, beat -> beats.add(frame to beat) }
                    var offset = 0
                    while (running && offset < buffer.size) {
                        val written = player.write(buffer, offset, buffer.size - offset, AudioTrack.WRITE_BLOCKING)
                        check(written > 0) { "Metronome audio write failed: $written" }
                        offset += written
                    }
                    if (running && !started) {
                        player.play()
                        started = true
                    }
                }
            } catch (_: Exception) {
                handler.post { if (running) onError() }
            }
        }, "FretmateMetronome").start()
    }

    fun stop() {
        running = false
        player.setPlaybackPositionUpdateListener(null)
        try {
            player.pause()
            player.flush()
        } finally {
            player.release()
            beats.clear()
        }
    }
}
