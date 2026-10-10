package com.steveimm.fitnotes_plus

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper

class RestAlertPlayer(private val context: Context) {
    private val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val attributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_MEDIA)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()
    private val handler = Handler(Looper.getMainLooper())
    private val timeout = Runnable { finish() }
    private var player: MediaPlayer? = null
    private var request: AudioFocusRequest? = null
    private var completion: (() -> Unit)? = null
    private val listener = AudioManager.OnAudioFocusChangeListener { change -> if (change < 0) finish() }

    fun play(uri: String? = null, onComplete: () -> Unit = {}) {
        stop()
        completion = onComplete
        handler.postDelayed(timeout, MAX_DURATION_MS)
        load(uri?.let(Uri::parse)?.takeIf { it.scheme == "content" || it.scheme == "android.resource" })
    }

    private fun load(uri: Uri?) {
        player?.release()
        val sound = MediaPlayer()
        player = sound
        fun failed() {
            if (player !== sound) return
            if (uri != null) load(null) else finish()
        }
        try {
            sound.setAudioAttributes(attributes)
            if (uri == null) {
                context.resources.openRawResourceFd(R.raw.rest_chime).use {
                    sound.setDataSource(it.fileDescriptor, it.startOffset, it.length)
                }
            } else sound.setDataSource(context, uri)
            sound.setVolume(0.9f, 0.9f)
            sound.setOnPreparedListener {
                if (player === sound) {
                    if (requestFocus()) {
                        try { sound.start() } catch (_: RuntimeException) { failed() }
                    } else finish()
                }
            }
            sound.setOnCompletionListener { if (player === sound) finish() }
            sound.setOnErrorListener { _, _, _ -> failed(); true }
            sound.prepareAsync()
        } catch (_: Exception) {
            failed()
        }
    }

    @Suppress("DEPRECATION")
    private fun requestFocus(): Boolean {
        if (request != null) return true
        val granted = if (Build.VERSION.SDK_INT >= 26) {
            val next = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                .setAudioAttributes(attributes)
                .setOnAudioFocusChangeListener(listener)
                .build()
            request = next
            audio.requestAudioFocus(next)
        } else audio.requestAudioFocus(listener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
        return granted == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    }

    @Suppress("DEPRECATION")
    fun stop() {
        handler.removeCallbacks(timeout)
        player?.release()
        player = null
        if (Build.VERSION.SDK_INT >= 26) request?.let(audio::abandonAudioFocusRequest)
        else audio.abandonAudioFocus(listener)
        request = null
        completion = null
    }

    private fun finish() {
        val done = completion
        stop()
        done?.invoke()
    }

    companion object {
        const val MAX_DURATION_MS = 5000L
    }
}
