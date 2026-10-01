package id.steveimm.pocketpilot.ui.capsule.surface

import android.app.Activity
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ArrowUpward
import androidx.compose.material.icons.rounded.Mic
import androidx.compose.material.icons.rounded.StopCircle
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.minimumInteractiveComponentSize
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.isCtrlPressed
import androidx.compose.ui.input.key.isMetaPressed
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.type
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import id.steveimm.pocketpilot.protocol.PlatformMode
import id.steveimm.pocketpilot.ui.capsule.voice.RecognizerFactory
import id.steveimm.pocketpilot.ui.capsule.voice.VoicePermissionDisposition
import id.steveimm.pocketpilot.ui.capsule.voice.VoiceState
import id.steveimm.pocketpilot.ui.capsule.voice.rememberVoiceInputController
import id.steveimm.pocketpilot.ui.capsule.voice.rememberVoicePermissionGate
import id.steveimm.pocketpilot.ui.overlay.model.CapsuleContext
import id.steveimm.pocketpilot.ui.overlay.model.CapsuleMode
import id.steveimm.pocketpilot.ui.overlay.model.CapsuleRenderSpec
import id.steveimm.pocketpilot.ui.theme.pocketPilot

/** Dependencies needed for the mic leadingIcon. */
interface VoiceMicDeps {
    val factory: RecognizerFactory
    val activity: Activity?
    fun isPermissionGranted(): Boolean
    fun requestOverlayPermission()
}

internal val LocalVoiceFeedback = staticCompositionLocalOf<(String) -> Unit> { {} }

/** CapsuleInputBar — text field with the send button as a trailing icon and an optional voice-mic leadingIcon when [voice] is wired by
 * the caller. */
@Composable
internal fun CapsuleInputBar(
    spec: CapsuleRenderSpec.InputSpec,
    active: Boolean = true,
    mode: CapsuleMode,
    platformMode: PlatformMode,
    context: CapsuleContext,
    pendingInputText: String,
    inputDraft: MutableState<String>? = null,
    onPendingInputConsumed: () -> Unit,
    autoFocusInput: Boolean,
    onInputFocusChanged: (Boolean) -> Unit,
    onSubmit: (String) -> Unit,
    voice: VoiceMicDeps? = null,
) {
    val draftState: MutableState<String> = inputDraft ?: remember { mutableStateOf("") }
    var inputText by draftState

    val focusRequester = remember { FocusRequester() }
    val keyboard = LocalSoftwareKeyboardController.current
    LaunchedEffect(pendingInputText) {
        if (pendingInputText.isNotEmpty()) {
            inputText = pendingInputText
            onPendingInputConsumed()
            focusRequester.requestFocus()
            keyboard?.show()
        }
    }
    val inputEnabled = active && when {
        context == CapsuleContext.MAIN_APP -> true
        mode is CapsuleMode.Running && platformMode == PlatformMode.ACCESSIBILITY -> false
        mode is CapsuleMode.TakeoverPending && platformMode == PlatformMode.ACCESSIBILITY -> false
        else -> true
    }

    // Track the last text the recognizer pushed via onText so typing-during-Listening can be
    // detected as a delta from controller output.
    val controllerLastText = remember { mutableStateOf("") }
    val reportVoiceFeedback by rememberUpdatedState(LocalVoiceFeedback.current)
    val voiceController = if (voice != null) {
        rememberVoiceInputController(
            factory = voice.factory,
            onText = { newText ->
                controllerLastText.value = newText
                inputText = newText
            },
            onToast = { msg ->
                reportVoiceFeedback(msg)
            },
        )
    } else {
        null
    }

    // VoiceInputController.state is backed by mutableStateOf, so a direct read here makes the
    // mic icon (and the Send/IME gating below) recompose automatically on every state change.
    val voiceState = voiceController?.state ?: VoiceState.Unavailable

    val gate = if (voice?.activity != null) {
        rememberVoicePermissionGate(activity = voice.activity!!) { granted ->
            if (granted && inputEnabled) {
                voiceController?.start(baseText = inputText)
            } else if (!granted) {
                reportVoiceFeedback("Microphone permission denied")
            }
        }
    } else {
        null
    }

    val hint = when {
        voiceState == VoiceState.Listening -> "Listening…"
        inputEnabled -> spec.hint
        else -> "Take over to type note"
    }
    val autoFocus = autoFocusInput && mode is CapsuleMode.WaitingForInput

    LaunchedEffect(autoFocus, inputEnabled) {
        if (autoFocus && inputEnabled) {
            focusRequester.requestFocus()
            keyboard?.show()
        }
    }

    val submit: () -> Unit = submit@{
        if (voiceState == VoiceState.Listening || voiceState == VoiceState.Stopping) {
            return@submit
        }
        val text = inputText.trim()
        if (text.isNotEmpty()) {
            onSubmit(text)
            inputText = ""
        }
    }

    val canSend = inputEnabled && inputText.isNotBlank() &&
        voiceState != VoiceState.Listening && voiceState != VoiceState.Stopping
    LaunchedEffect(inputEnabled, draftState) { voiceController?.cancel() }

    val onMicTap: () -> Unit = mic@{
        val v = voice ?: return@mic
        val act = v.activity
        if (act != null && gate != null) {
            when (gate.disposition()) {
                VoicePermissionDisposition.Granted ->
                    voiceController?.start(baseText = inputText)
                VoicePermissionDisposition.Request ->
                    gate.requestPermission()
                VoicePermissionDisposition.OpenAppSettings -> {
                    reportVoiceFeedback("Microphone permission is disabled. Re-enable it in Android Settings.")
                    gate.openAppSettings()
                }
            }
        } else {
            if (v.isPermissionGranted()) {
                voiceController?.start(baseText = inputText)
            } else {
                reportVoiceFeedback("Microphone permission is required")
                v.requestOverlayPermission()
            }
        }
    }

    val leadingIcon: (@Composable () -> Unit)? = when (voiceState) {
        VoiceState.Unavailable -> null
        VoiceState.Idle -> {
            {
                Box(modifier = Modifier.size(48.dp), contentAlignment = Alignment.Center) {
                    IconButton(
                        onClick = onMicTap,
                        enabled = inputEnabled,
                        modifier = Modifier
                            .minimumInteractiveComponentSize()
                            .size(36.dp)
                            .testTag("qa-capsule-mic"),
                    ) {
                        Icon(
                            imageVector = Icons.Rounded.Mic,
                            contentDescription = "Start voice input",
                            modifier = Modifier.size(18.dp),
                        )
                    }
                }
            }
        }
        VoiceState.Listening -> {
            {
                Box(modifier = Modifier.size(48.dp), contentAlignment = Alignment.Center) {
                    IconButton(
                        onClick = { voiceController?.stop() },
                        modifier = Modifier
                            .minimumInteractiveComponentSize()
                            .size(36.dp)
                            .testTag("qa-capsule-mic"),
                    ) {
                        Icon(
                            imageVector = Icons.Rounded.StopCircle,
                            contentDescription = "Stop voice input",
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(18.dp),
                        )
                    }
                }
            }
        }
        VoiceState.Stopping -> {
            {
                Box(modifier = Modifier.size(48.dp), contentAlignment = Alignment.Center) {
                    IconButton(
                        onClick = {},
                        enabled = false,
                        modifier = Modifier
                            .minimumInteractiveComponentSize()
                            .size(36.dp)
                            .testTag("qa-capsule-mic"),
                    ) {
                        Icon(
                            imageVector = Icons.Rounded.StopCircle,
                            contentDescription = "Stopping voice input",
                            modifier = Modifier.size(18.dp),
                        )
                    }
                }
            }
        }
    }

    Row(Modifier.fillMaxWidth().heightIn(min = 48.dp), verticalAlignment = Alignment.Bottom) {
        leadingIcon?.invoke()
        BasicTextField(
            value = inputText,
            onValueChange = { newText ->
                if (voiceState == VoiceState.Listening && newText != controllerLastText.value) voiceController?.cancel()
                inputText = newText
            },
            enabled = inputEnabled,
            textStyle = MaterialTheme.typography.bodyMedium.copy(color = MaterialTheme.colorScheme.onSurface),
            cursorBrush = SolidColor(MaterialTheme.colorScheme.primary),
            modifier = Modifier
                .weight(1f)
                .align(Alignment.CenterVertically)
                .padding(horizontal = 4.dp, vertical = 14.dp)
                .focusRequester(focusRequester)
                .onFocusChanged { onInputFocusChanged(it.isFocused) }
                .onPreviewKeyEvent { event ->
                    if (event.key == Key.Enter && (event.isCtrlPressed || event.isMetaPressed)) {
                        if (event.type == KeyEventType.KeyDown && canSend) submit()
                        true
                    } else false
                }
                .testTag("qa-capsule-input"),
            decorationBox = { innerField ->
                Box {
                    if (inputText.isEmpty()) Text(hint, style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    innerField()
                }
            },
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Default),
            maxLines = 5,
            singleLine = false,
        )
        Box(Modifier.size(48.dp), contentAlignment = Alignment.Center) {
            FilledIconButton(
                onClick = submit,
                enabled = canSend,
                modifier = Modifier.size(36.dp).testTag("qa-capsule-send"),
                shape = CircleShape,
                colors = IconButtonDefaults.filledIconButtonColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    contentColor = MaterialTheme.colorScheme.onPrimary,
                    disabledContainerColor = MaterialTheme.pocketPilot.mutedText.copy(alpha = 0.18f),
                    disabledContentColor = MaterialTheme.pocketPilot.mutedText,
                ),
            ) {
                Icon(Icons.Rounded.ArrowUpward, spec.submitLabel, Modifier.size(18.dp))
            }
        }
    }
}
