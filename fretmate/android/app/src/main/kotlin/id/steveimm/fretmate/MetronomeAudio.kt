package id.steveimm.fretmate

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MetronomeAudio(context: Context, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "id.steveimm.fretmate/metronome")
    private val handler = Handler(Looper.getMainLooper())
    private val audioManager = context.getSystemService(AudioManager::class.java)
    private val attributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_MEDIA)
        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
        .build()
    private var track: AudioTrack? = null
    private var focusRequest: AudioFocusRequest? = null
    private var toneId: Int? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "start" -> {
                    val pcm = requireNotNull(call.argument<ByteArray>("pcm"))
                    val framesPerBeat = requireNotNull(call.argument<Int>("framesPerBeat"))
                    val beats = requireNotNull(call.argument<Int>("beats"))
                    val volume = requireNotNull(call.argument<Double>("volume"))
                    require(framesPerBeat in 11025..66150 && beats in 1..6)
                    require(pcm.size == framesPerBeat * beats * 2 && volume in 0.0..1.0)
                    start(pcm, volume.toFloat(), framesPerBeat, beats)
                    result.success(null)
                }
                "playTone" -> {
                    val pcm = requireNotNull(call.argument<ByteArray>("pcm"))
                    val requestId = requireNotNull(call.argument<Int>("requestId"))
                    val requestFocus = requireNotNull(call.argument<Boolean>("requestFocus"))
                    val volume = requireNotNull(call.argument<Double>("volume"))
                    require(pcm.size in 2..441000 && pcm.size % 2 == 0 && volume in 0.0..1.0)
                    start(pcm, volume.toFloat(), requestId = requestId, requestFocus = requestFocus)
                    result.success(null)
                }
                "stop" -> {
                    stop()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            stop()
            result.error("audio_unavailable", error.message ?: "Audio playback failed", null)
        }
    }

    private fun start(
        pcm: ByteArray,
        volume: Float,
        framesPerBeat: Int? = null,
        beats: Int = 0,
        requestId: Int? = null,
        requestFocus: Boolean = true,
    ) {
        stop(notify = false)
        // An active recorder already owns focus and handles interruptions for the app.
        if (requestFocus) {
            val focusGain = if (requestId == null) AudioManager.AUDIOFOCUS_GAIN else AudioManager.AUDIOFOCUS_GAIN_TRANSIENT
            val request = AudioFocusRequest.Builder(focusGain)
                .setAudioAttributes(attributes)
                .setOnAudioFocusChangeListener({ change ->
                    if (change != AudioManager.AUDIOFOCUS_GAIN) stop()
                }, handler)
                .build()
            focusRequest = request
            check(audioManager.requestAudioFocus(request) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                "Another app is using audio. Try again when it finishes."
            }
        }

        val player = AudioTrack.Builder()
            .setAudioAttributes(attributes)
            .setAudioFormat(AudioFormat.Builder()
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setSampleRate(44100)
                .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                .build())
            .setTransferMode(AudioTrack.MODE_STATIC)
            .setBufferSizeInBytes(pcm.size)
            .build()
        track = player
        toneId = requestId
        check(player.write(pcm, 0, pcm.size) == pcm.size) { "Could not load the audio." }
        check(player.setVolume(volume) == AudioTrack.SUCCESS)
        if (framesPerBeat != null) {
            check(player.setLoopPoints(0, pcm.size / 2, -1) == AudioTrack.SUCCESS)
            check(player.setPositionNotificationPeriod(framesPerBeat) == AudioTrack.SUCCESS)
        } else {
            check(player.setNotificationMarkerPosition(pcm.size / 2 - 1) == AudioTrack.SUCCESS)
        }
        player.setPlaybackPositionUpdateListener(object : AudioTrack.OnPlaybackPositionUpdateListener {
            override fun onMarkerReached(audioTrack: AudioTrack) {
                if (track === audioTrack && toneId != null) stop()
            }

            override fun onPeriodicNotification(audioTrack: AudioTrack) {
                if (framesPerBeat == null || track !== audioTrack || audioTrack.playState != AudioTrack.PLAYSTATE_PLAYING) return
                val frame = audioTrack.playbackHeadPosition.toLong() and 0xffffffffL
                channel.invokeMethod("beat", ((frame / framesPerBeat) % beats).toInt())
            }
        }, handler)
        player.play()
        if (framesPerBeat != null) channel.invokeMethod("beat", 0)
    }

    fun stop(notify: Boolean = true) {
        val previous = track
        val previousToneId = toneId
        track = null
        toneId = null
        if (previous != null) {
            previous.setPlaybackPositionUpdateListener(null)
            try {
                if (previous.playState == AudioTrack.PLAYSTATE_PLAYING) previous.pause()
            } finally {
                previous.release()
            }
        }
        focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
        focusRequest = null
        if (notify && previous != null) {
            if (previousToneId == null) channel.invokeMethod("stopped", null)
            else channel.invokeMethod("toneEnded", previousToneId)
        }
    }

    fun dispose() {
        stop(notify = false)
        channel.setMethodCallHandler(null)
    }
}
