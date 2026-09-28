package id.steveimm.pocketpilot.ui.capsule.voice

import android.content.Context
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer

/** Provider-agnostic speech-recognition errors. */
enum class VoiceError {
    NoMatch,
    SpeechTimeout,
    Network,
    NetworkTimeout,
    LanguageUnavailable,
    InsufficientPermissions,
    Busy,
    ServiceDied,
    Unknown,
}

/** Callbacks fired by a [Recognizer] during a recognition session. */
interface RecognizerCallbacks {
    fun onPartial(text: String)
    fun onFinal(text: String)
    fun onError(error: VoiceError)
}

/** A single recognition session controller. */
interface Recognizer {
    fun start(languageTag: String, callbacks: RecognizerCallbacks)
    fun stop()
    fun cancel()
    fun destroy()
}

/** Factory that decides whether on-device speech recognition is wired up and creates instances. */
interface RecognizerFactory {
    fun isAvailable(): Boolean
    fun create(): Recognizer?
}

/** Production [RecognizerFactory] backed by [android.speech.SpeechRecognizer]. */
class AndroidRecognizerFactory(private val context: Context) : RecognizerFactory {
    override fun isAvailable(): Boolean =
        SpeechRecognizer.isRecognitionAvailable(context)

    override fun create(): Recognizer? =
        if (isAvailable()) AndroidRecognizer(context) else null
}

/** The ONLY type in the app that may touch `android.speech.*`. Everything else talks to [Recognizer] / [RecognizerFactory] /
 * [VoiceError] so the framework dependency stays pinned to this file. */
internal class AndroidRecognizer(context: Context) : Recognizer {
    private val recognizer: SpeechRecognizer =
        SpeechRecognizer.createSpeechRecognizer(context)

    private var callbacks: RecognizerCallbacks? = null

    override fun start(languageTag: String, callbacks: RecognizerCallbacks) {
        this.callbacks = callbacks
        recognizer.setRecognitionListener(Listener())
        val intent = android.content.Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, languageTag)
        }
        recognizer.startListening(intent)
    }

    override fun stop() {
        recognizer.stopListening()
    }

    override fun cancel() {
        recognizer.cancel()
    }

    override fun destroy() {
        recognizer.setRecognitionListener(null)
        recognizer.destroy()
        callbacks = null
    }

    /** Adapts framework callbacks to [RecognizerCallbacks]. */
    private inner class Listener : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) {}
        override fun onBeginningOfSpeech() {}
        override fun onRmsChanged(rmsdB: Float) {}
        override fun onBufferReceived(buffer: ByteArray?) {}
        override fun onEndOfSpeech() {}
        override fun onEvent(eventType: Int, params: Bundle?) {}

        override fun onPartialResults(partialResults: Bundle?) {
            val text = extractFirstResult(partialResults)
            if (text.isNotEmpty()) callbacks?.onPartial(text)
        }

        override fun onResults(results: Bundle?) {
            callbacks?.onFinal(extractFirstResult(results))
        }

        override fun onError(error: Int) {
            callbacks?.onError(mapError(error))
        }
    }
}

private fun extractFirstResult(bundle: Bundle?): String =
    bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty()

private fun mapError(code: Int): VoiceError = when (code) {
    SpeechRecognizer.ERROR_NO_MATCH -> VoiceError.NoMatch
    SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> VoiceError.SpeechTimeout
    SpeechRecognizer.ERROR_NETWORK -> VoiceError.Network
    SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> VoiceError.NetworkTimeout
    SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED,
    SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE -> VoiceError.LanguageUnavailable
    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> VoiceError.InsufficientPermissions
    SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> VoiceError.Busy
    SpeechRecognizer.ERROR_SERVER_DISCONNECTED,
    SpeechRecognizer.ERROR_SERVER -> VoiceError.ServiceDied
    else -> VoiceError.Unknown
}
