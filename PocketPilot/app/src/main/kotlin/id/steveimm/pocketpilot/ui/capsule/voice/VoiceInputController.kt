package id.steveimm.pocketpilot.ui.capsule.voice

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import java.util.Locale

/** UI-facing state for the voice-input session. The state machine is: */
enum class VoiceState { Idle, Listening, Stopping, Unavailable }

/** Drives a [Recognizer] session and surfaces a small state machine plus the partial/final text-edit semantics used by the capsule
 * voice input UI. */
class VoiceInputController(
    private val factory: RecognizerFactory,
    private val languageTag: String,
    private val onText: (String) -> Unit,
    private val onToast: (String) -> Unit = {},
) {
    var state: VoiceState by mutableStateOf(
        if (factory.isAvailable()) VoiceState.Idle else VoiceState.Unavailable
    )
        private set

    var lastPartial: String by mutableStateOf("")
        private set

    var partialAtStop: String by mutableStateOf("")
        private set

    private var generation: Int = 0
    private var disposed: Boolean = false
    private var recognizer: Recognizer? = null
    private var baseText: String = ""

    // Tracks whether the current session has produced ANY successful signal (partial or final).
    private var sessionGotAnyCallback: Boolean = false

    fun start(baseText: String) {
        if (disposed || state == VoiceState.Stopping) return
        if (state == VoiceState.Listening) return
        if (state == VoiceState.Unavailable) return
        if (!factory.isAvailable()) {
            state = VoiceState.Unavailable
            return
        }
        this.baseText = baseText
        lastPartial = ""
        partialAtStop = ""
        sessionGotAnyCallback = false
        val r = factory.create() ?: run {
            state = VoiceState.Unavailable
            return
        }
        recognizer = r
        val myGen = generation
        r.start(languageTag, object : RecognizerCallbacks {
            override fun onPartial(text: String) {
                if (myGen != generation || disposed) return
                // During Stopping the partialAtStop snapshot is frozen — incoming partials are
                // noise from audio captured before stop() and must not mutate visible text.
                if (state == VoiceState.Stopping) return
                sessionGotAnyCallback = true
                lastPartial = text
                onText(joinWithSpace(this@VoiceInputController.baseText, text))
            }

            override fun onFinal(text: String) {
                if (myGen != generation || disposed) return
                sessionGotAnyCallback = true
                if (text.isNotEmpty()) {
                    onText(joinWithSpace(this@VoiceInputController.baseText, text))
                } else if (state == VoiceState.Stopping && partialAtStop.isNotEmpty()) {
                    onText(joinWithSpace(this@VoiceInputController.baseText, partialAtStop))
                }
                cleanupAfterTerminal(VoiceState.Idle)
            }

            override fun onError(error: VoiceError) {
                if (myGen != generation || disposed) return
                val next = handleError(error)
                cleanupAfterTerminal(next)
            }
        })
        state = VoiceState.Listening
    }

    fun stop() {
        if (state != VoiceState.Listening) return
        partialAtStop = lastPartial
        state = VoiceState.Stopping
        recognizer?.stop()
    }

    fun cancel() {
        if (state == VoiceState.Idle || state == VoiceState.Unavailable) {
            // Even from Idle, bump generation so any late stale callback from a previous
            // session is dropped.
            generation++
            recognizer?.cancel()
            return
        }
        generation++
        recognizer?.cancel()
        state = VoiceState.Idle
    }

    fun dispose() {
        if (disposed) return
        disposed = true
        generation++
        recognizer?.destroy()
        recognizer = null
    }

    private fun cleanupAfterTerminal(nextState: VoiceState) {
        state = nextState
        generation++
        recognizer?.destroy()
        recognizer = null
    }

    private fun handleError(error: VoiceError): VoiceState = when (error) {
        VoiceError.NoMatch, VoiceError.SpeechTimeout -> {
            if (state == VoiceState.Stopping && partialAtStop.isNotEmpty()) {
                onText(joinWithSpace(baseText, partialAtStop))
            } else {
                onText(baseText)
            }
            VoiceState.Idle
        }
        VoiceError.InsufficientPermissions -> {
            onText(baseText)
            onToast("Microphone permission revoked — re-enable in Settings")
            VoiceState.Idle
        }
        VoiceError.LanguageUnavailable -> {
            onText(baseText)
            onToast("Voice not available for this language")
            VoiceState.Unavailable
        }
        VoiceError.Network, VoiceError.NetworkTimeout -> {
            onText(baseText)
            onToast("Voice needs network for this language")
            VoiceState.Idle
        }
        VoiceError.Busy, VoiceError.ServiceDied, VoiceError.Unknown -> {
            onText(baseText)
            // Hard error before we ever heard back from the recognizer: it's unusable on this device/config (e.g. registered
            // RecognitionService but no default selected, or AppOps blocks binding).
            if (!sessionGotAnyCallback) {
                onToast("Voice unavailable")
                VoiceState.Unavailable
            } else {
                onToast("Voice unavailable")
                VoiceState.Idle
            }
        }
    }

    private fun joinWithSpace(base: String, more: String): String = when {
        base.isEmpty() -> more
        more.isEmpty() -> base
        base.endsWith(' ') -> base + more
        else -> "$base $more"
    }
}

@Composable
fun rememberVoiceInputController(
    factory: RecognizerFactory,
    languageTag: String = Locale.getDefault().toLanguageTag(),
    onText: (String) -> Unit,
    onToast: (String) -> Unit = {},
): VoiceInputController {
    val controller = remember(factory, languageTag) {
        VoiceInputController(factory, languageTag, onText, onToast)
    }
    DisposableEffect(controller) {
        onDispose { controller.dispose() }
    }
    return controller
}
