# Voice input

The microphone button in `CapsuleInputBar` streams partial speech into the editable draft in Main and floating controls. Text is sent to the model only on submission.

## Components

All voice components are in `ui/capsule/voice/`.

- `Recognizer.kt` defines the recognition interfaces and Android adapter. It is the only source file importing `android.speech.*`.
- `VoiceInputController` owns recognition state, partial text, callback generation, and resource cleanup. Its Compose wrapper keeps callbacks current and observes the host lifecycle.
- `VoicePermissionGate` classifies permission as Granted, Request, or OpenAppSettings. Its pending flag prevents duplicate permission launches.
- `VoiceMicDeps`, declared in `CapsuleInputBar.kt`, supplies the factory and permission access. A null dependency hides the microphone.

## Availability and language

The Android factory uses `isOnDeviceRecognitionAvailable` and `createOnDeviceSpeechRecognizer` exclusively. If on-device recognition is unavailable, the mic is hidden. There is no fallback to the potentially remote default recognizer. See [Android's speech API](https://developer.android.com/reference/android/speech/SpeechRecognizer#createOnDeviceSpeechRecognizer(android.content.Context)).

Availability is checked at initialization and before starting an available controller. The language defaults to `Locale.getDefault().toLanguageTag()`.

## Recognition state

`Idle` starts listening on a microphone tap. Stop changes `Listening` to `Stopping` while waiting for a final result or error. Send is disabled during Listening and Stopping. An unavailable recognizer hides the mic.

| Event | Draft and state |
|---|---|
| Partial result while Listening | Append recognized text to the draft captured at start |
| Final result | Commit final text and return to Idle |
| Stop, then final result | Final text replaces the partial captured at Stop |
| Stop, then NoMatch or SpeechTimeout | Keep the partial captured at Stop, or restore the starting draft |
| NoMatch or SpeechTimeout while Listening | Restore the starting draft without an alert |
| Language unavailable | Restore the draft, report failure, hide the mic |
| Network error | Restore the draft, report failure, return to Idle |
| Busy, service died, or unknown error before any result | Report failure and hide the mic |
| Those errors after a partial result | Restore the draft, report failure, return to Idle |
| User types while Listening | Cancel recognition and keep the visible text |

A generation counter rejects callbacks from canceled or completed attempts. Stop keeps the generation unchanged because its terminal callback is still needed. Partials received during Stopping do not alter the frozen `partialAtStop` value.

## Lifecycle and cleanup

Opening the drawer or Settings disables the Main composer and cancels recognition. Changing the bound draft, disabling input, and host `ON_PAUSE` also cancel it. Cancellation preserves visible text, invalidates callbacks, and cancels and destroys the recognizer. A later start creates a new instance. Terminal results and composition disposal also destroy the recognizer.

`rememberUpdatedState` directs callbacks to the current draft and feedback handler. Main displays feedback beside the composer; the floating panel uses a toast.

## Permission flow

Main uses an Android `RequestPermission` launcher. A granted result starts dictation only if the input is still enabled. A denied result reports feedback. Repeated denial routes the user to Android app settings.

The overlay starts recognition directly when microphone permission is already granted. Otherwise it asks `AgentService` to open MainActivity with `EXTRA_REQUEST_VOICE_PERMISSION`. `MainActivityContent` registers the permission launcher before consuming that request, including on a cold start. Granting permission through this route does not automatically start hidden overlay dictation.

## Tests

`VoiceInputControllerTest` covers partial/final handling, stale callbacks, cancellation and restart cleanup, duplicate starts, disposal, availability changes, and service errors. `CapsuleVoiceInputTest` checks microphone visibility, permission routing, streaming drafts, typing cancellation, and Send gating with a fake recognizer.
