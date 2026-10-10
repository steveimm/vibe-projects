package com.steveimm.fitnotes_plus

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build

class RestAlertPlayer(private val context: Context) {
    private val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val attributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_MEDIA)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()
    private var player: MediaPlayer? = null
    private var request: AudioFocusRequest? = null
    private var completion: (() -> Unit)? = null
    private val listener = AudioManager.OnAudioFocusChangeListener { change ->
        if (change < 0) finish()
    }

    @Suppress("DEPRECATION")
    fun play(onComplete: () -> Unit = {}) {
        stop()
        completion = onComplete
        val focus = if (Build.VERSION.SDK_INT >= 26) {
            val next = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                .setAudioAttributes(attributes)
                .setOnAudioFocusChangeListener(listener)
                .build()
            request = next
            audio.requestAudioFocus(next)
        } else {
            audio.requestAudioFocus(listener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
        }
        if (focus != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
            finish()
            return
        }
        try {
            val sound = MediaPlayer()
            player = sound
            sound.apply {
                setAudioAttributes(attributes)
                context.resources.openRawResourceFd(R.raw.rest_chime).use {
                    setDataSource(it.fileDescriptor, it.startOffset, it.length)
                }
                setVolume(0.9f, 0.9f)
                setOnCompletionListener { this@RestAlertPlayer.finish() }
                setOnErrorListener { _, _, _ -> this@RestAlertPlayer.finish(); true }
                prepare()
                start()
            }
        } catch (_: Exception) {
            finish()
        }
    }

    @Suppress("DEPRECATION")
    fun stop() {
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
}
