# Fretmate

A Flutter guitar tuner and metronome for Android 15 and newer. Organization: `id.steveimm`. Application ID: `id.steveimm.fretmate`.

## Features

- Microphone tuner with automatic string detection or manual string locking, measured frequency, and a cents meter. Readings within ±5 cents show “In tune.”
- Standard six-string tuning with A4 = 440 Hz.
- Audible metronome from 40–240 BPM, tap tempo, 2/3/4/6 beats per bar, optional first-beat accent, volume, and beat indicators.
- Switching tools, backgrounding the app, or losing audio focus stops the relevant audio. Resume is manual. Microphone access is requested only after tapping Listen.
- Audio stays in memory on the device. No recordings are saved, and no account, server, downloaded assets, or runtime internet connection is needed.

| String | Note | Frequency |
| --- | --- | --- |
| 6 (lowest) | E2 | 82.41 Hz |
| 5 | A2 | 110.00 Hz |
| 4 | D3 | 146.83 Hz |
| 3 | G3 | 196.00 Hz |
| 2 | B3 | 246.94 Hz |
| 1 (highest) | E4 | 329.63 Hz |

Pluck one open string at a time and let it ring. Auto selects the nearest standard string by pitch distance. Select a string manually when the instrument is far out of tune. Pitch estimation is independent of the tuning targets and uses a configurable frequency range, currently 65–400 Hz. Weaker readings need two consecutive frames to agree before being displayed. Changing an established note needs three agreeing frames. Within a note, median filtering and gradual smoothing in cents reduce needle movement without snapping to the tuning target. The detector does not analyze chords.

## Development

Created with Flutter 3.47.2 and Dart 3.13.2. Only the Android platform is generated. Android `minSdk` is 35 (Android 15), while `compileSdk` and `targetSdk` are 36. “Android ≥15” is interpreted as the OS version, not API level 15. The [Android 15 SDK documentation](https://developer.android.com/about/versions/15/setup-sdk) identifies Android 15 as API 35.

From this directory, these checks need Flutter but do not need an Android SDK or an emulator:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

The dependency lockfile is committed. Dart formatting uses a 120-column page width from `analysis_options.yaml`.

Initial verification: `flutter analyze` reported no issues, the formatting check passed, and all 33 automated tests passed. Android resource XML was parsed and the manifest/package/API settings were checked separately.

## Android build later

Android compilation and device audio behavior have not been verified. No Android SDK was installed or configured for this initial implementation, and no emulator was launched.

Once the Android toolchain is configured, install Android SDK Platform 36 and the build tools/NDK required by the generated Flutter Gradle project. Then:

```sh
flutter doctor -v
flutter doctor --android-licenses
flutter build apk --debug
```

The debug APK will be under `build/app/outputs/flutter-apk/`. Release signing currently uses Flutter's generated debug configuration and must be replaced with a private release signing configuration before distribution. Android setup guidance: [Flutter Android setup](https://docs.flutter.dev/platform-integration/android/setup).

## Code layout

- `lib/main.dart` and `lib/ui/`: Material interface, accessible controls, scrollable layouts, and lifecycle handling.
- `lib/practice_controller.dart`: serialized audio actions, session cancellation, pitch smoothing, stale reading expiry, and UI state.
- `lib/audio/pitch_detector.dart`: PCM16 framing, low-pass noise filtering, and YIN pitch detection. Each 4,096-sample frame is analyzed in a background Dart isolate, with backpressure to avoid queued stale frames.
- `lib/audio/audio_services.dart`: microphone capture through [`record`](https://pub.dev/packages/record) and the Android metronome channel.
- `lib/audio/click_track.dart`: generated PCM clicks, bar construction, and tap tempo. Tempo changes restart the bar. No audio assets are required.
- `android/app/src/main/kotlin/id/steveimm/fretmate/MetronomeAudio.kt`: an Android [`AudioTrack`](https://developer.android.com/reference/android/media/AudioTrack) static buffer loop, playback-position beat callbacks, and [audio focus handling](https://developer.android.com/media/optimize/audio-focus). Click timing is driven by audio frames. Visual callbacks can lag with device output latency.
- `test/`: synthetic guitar pitch signals with harmonics/noise/detuning, PCM chunk boundaries, click timing and accents, tap tempo, audio failures, cancellation races, and widget controls/layouts. Device audio is replaced with fakes in these tests.

## Remaining device checks

When physical-device testing is available, check microphone permission denial/retry, tuning accuracy on all six strings, low-volume/noisy rooms, metronome timing and output latency, incoming calls, app backgrounding, audio routing, and Android 15+ launch behavior. These host-side tests do not establish microphone quality or native playback timing on hardware.
