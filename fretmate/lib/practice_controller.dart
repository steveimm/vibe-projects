import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'audio/audio_services.dart';
import 'audio/click_track.dart';
import 'audio/pitch_detector.dart';
import 'tuning.dart';

const _tunerDiagnostics = kDebugMode && bool.fromEnvironment('TUNER_DIAGNOSTICS');

PitchEstimate? _analyzeFrame(
  ({Float64List samples, double? previousFrequency, double minimum, double maximum, bool diagnostics}) frame,
) => analyzePitch(
  frame.samples,
  previousFrequency: frame.previousFrequency,
  minFrequency: frame.minimum,
  maxFrequency: frame.maximum,
  onDiagnostic: frame.diagnostics ? debugPrint : null,
);

class PracticeController extends ChangeNotifier {
  PracticeController({required this.microphone, required this.clicks}) {
    _toneSubscription = clicks.toneEnds.listen(_endReferenceTone);
    _beatSubscription = clicks.beats.listen((value) {
      if (value == null) {
        playing = false;
        beat = null;
      } else if (playing) {
        beat = value;
      }
      _notify();
    }, onError: (Object error) => _audioError('Playback interrupted. Tap Start to try again.'));
  }

  final MicrophoneInput microphone;
  final ClickOutput clicks;
  final TapTempo _tapTempo = TapTempo();
  final Stopwatch _clock = Stopwatch()..start();
  final PitchTracker _pitchTracker = PitchTracker();
  late final StreamSubscription<int?> _beatSubscription;
  late final StreamSubscription<int> _toneSubscription;
  StreamSubscription<Object?>? _microphoneSubscription;
  Future<void> _pending = Future.value();
  Timer? _stalePitch;
  int _epoch = 0;
  int _tuningRevision = 0;
  int _referenceRequest = 0;
  int? _activeToneId;
  int _ignoreMicrophoneUntil = 0;
  int? _selectedStringNumber;
  List<GuitarString> _strings = standardStrings;
  int _operations = 0;
  int _lastPitchLog = 0;
  bool _analyzing = false;
  bool _foreground = true;
  bool _disposed = false;

  int tab = 0;
  bool listening = false;
  bool playing = false;
  double? frequency;
  String? error;
  int bpm = 100;
  int beatsPerBar = 4;
  bool accent = true;
  double volume = 0.7;
  int? beat;

  bool get busy => _operations > 0;
  bool get referencePlaying => _activeToneId != null;
  bool get _ignoreMicrophone => referencePlaying || _clock.elapsedMilliseconds < _ignoreMicrophoneUntil;
  List<GuitarString> get strings => _strings;
  TuningPreset? get tuning => matchingTuning(_strings);
  String get tuningName => tuning?.name ?? 'Custom';
  String get tuningNotes => _strings.map((string) => string.note).join();
  GuitarString? get selectedString => _selectedStringNumber == null ? null : _strings[6 - _selectedStringNumber!];
  GuitarString? get target =>
      selectedString ?? (frequency == null ? null : nearestString(frequency!, strings: _strings));
  double? get cents => frequency == null || target == null ? null : centsBetween(frequency!, target!.frequency);
  bool get inTune => cents != null && cents!.abs() <= 5;
  ({double minimum, double maximum}) get pitchRange {
    final frequencies = _strings.map((string) => string.frequency);
    return (
      minimum: math.min(65, frequencies.reduce(math.min) / math.pow(2, 2 / 12)),
      maximum: math.max(400, frequencies.reduce(math.max) * math.pow(2, 2 / 12)),
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _enqueue(Future<void> Function() action, {bool blockControls = true}) {
    if (_disposed) return Future.value();
    if (blockControls) _operations++;
    _notify();
    _pending = _pending.then((_) async {
      try {
        if (!_disposed) await action();
      } on MicrophonePermissionDenied {
        error = 'Microphone access is needed to tune. Allow it when prompted, or enable it in Android Settings → Apps → Fretmate → Permissions.';
        await _recover();
      } catch (_) {
        error = 'Audio is unavailable. Close other audio apps and try again.';
        await _recover();
      } finally {
        if (blockControls) _operations--;
        _notify();
      }
    });
    return _pending;
  }

  Future<void> _recover() async {
    try {
      await _stopAudio();
    } catch (_) {
      error = 'Audio could not be released. Close and reopen Fretmate.';
    }
  }

  Future<void> selectTab(int value) {
    if (value == tab) return _pending;
    tab = value;
    _epoch++;
    error = null;
    return _enqueue(_stopAudio);
  }

  void selectString(GuitarString? value) {
    _cancelReferenceTone();
    _selectedStringNumber = value?.number;
    _notify();
  }

  Future<void> lockAndPlayString(GuitarString string) {
    _selectedStringNumber = string.number;
    final request = ++_referenceRequest;
    return _enqueue(() async {
      if (!_foreground || tab != 0 || request != _referenceRequest) return;
      error = null;
      _activeToneId = request;
      _tuningRevision++;
      _clearPitch();
      _notify();
      if (_tunerDiagnostics) debugPrint('Reference: start id=$request note=${selectedString!.label}');
      await clicks.playTone(selectedString!.frequency, requestId: request, requestFocus: !listening);
      if (!_foreground || _disposed || tab != 0) {
        await clicks.stop();
        _endReferenceTone(request);
      }
    }, blockControls: false);
  }

  void _endReferenceTone(int request) {
    if (_activeToneId != request) return;
    _activeToneId = null;
    _ignoreMicrophoneUntil = _clock.elapsedMilliseconds + 300;
    if (_tunerDiagnostics) debugPrint('Reference: end id=$request');
    _notify();
  }

  void _cancelReferenceTone() {
    _referenceRequest++;
    final active = _activeToneId;
    if (active == null) return;
    unawaited(
      _enqueue(() async {
        if (_activeToneId != active) return;
        await clicks.stop();
        _endReferenceTone(active);
      }, blockControls: false),
    );
  }

  void _clearPitch() {
    frequency = null;
    _pitchTracker.reset();
    _stalePitch?.cancel();
  }

  void selectTuning(TuningPreset preset) => _setStrings(preset.strings);

  void adjustString(int number, int semitones) {
    final index = 6 - number;
    final note = (_strings[index].midiNote + semitones).clamp(minimumTuningNote, maximumTuningNote);
    if (note == _strings[index].midiNote) return;
    final updated = _strings.toList();
    updated[index] = GuitarString(number, note);
    _setStrings(updated);
  }

  void _setStrings(List<GuitarString> value) {
    _cancelReferenceTone();
    _strings = List.unmodifiable(value);
    _tuningRevision++;
    _clearPitch();
    _notify();
  }

  Future<void> toggleTuner() => _enqueue(() async {
    error = null;
    if (listening) return _stopAudio();
    if (!_foreground || tab != 0) return;
    await _stopAudio();
    final session = _epoch;
    final stream = await microphone.start();
    if (session != _epoch || !_foreground || _disposed) {
      await microphone.stop();
      return;
    }
    listening = true;
    final decoder = PcmFrameDecoder();
    _microphoneSubscription = stream.listen(
      (bytes) {
        for (final frame in decoder.add(bytes)) {
          if (_analyzing || !listening || _ignoreMicrophone) continue;
          _analyzing = true;
          final now = _clock.elapsedMilliseconds;
          final logPitch = _tunerDiagnostics && now - _lastPitchLog >= 250;
          if (logPitch) _lastPitchLog = now;
          final revision = _tuningRevision;
          final range = pitchRange;
          compute(_analyzeFrame, (
                samples: frame,
                previousFrequency: frequency,
                minimum: range.minimum,
                maximum: range.maximum,
                diagnostics: logPitch,
              ))
              .then((pitch) {
                if (!_disposed && listening && !_ignoreMicrophone && session == _epoch && revision == _tuningRevision) {
                  _acceptPitch(pitch);
                }
              })
              .catchError((Object error) {
                if (session == _epoch) _audioError('Could not analyze the microphone. Tap Listen to try again.');
              })
              .whenComplete(() => _analyzing = false);
        }
      },
      onError: (Object error) {
        if (session == _epoch) _audioError('Microphone interrupted. Tap Listen to try again.');
      },
      onDone: () {
        if (session == _epoch && listening) _audioError('Microphone stopped. Tap Listen to try again.');
      },
    );
  });

  void _acceptPitch(PitchEstimate? estimate) {
    final pitch = _pitchTracker.add(estimate);
    if (pitch == null) return;
    frequency = pitch;
    if (_tunerDiagnostics) {
      debugPrint(
        'Tuner: displayed=${frequency!.toStringAsFixed(2)} string=${target?.number} confidence=${estimate!.confidence.toStringAsFixed(3)}',
      );
    }
    _stalePitch?.cancel();
    _stalePitch = Timer(const Duration(milliseconds: 600), () {
      frequency = null;
      _pitchTracker.reset();
      _notify();
    });
    _notify();
  }

  void _audioError(String message) {
    _epoch++;
    unawaited(
      _enqueue(() async {
        error = message;
        await _stopAudio();
      }),
    );
  }

  Future<void> toggleMetronome() => _enqueue(() async {
    error = null;
    if (playing) return _stopAudio();
    if (!_foreground || tab != 1) return;
    await _stopAudio();
    await _startClicks();
  });

  Future<void> _startClicks() async {
    if (!_foreground || _disposed) return;
    final session = _epoch;
    await clicks.start(bpm: bpm, beats: beatsPerBar, accent: accent, volume: volume);
    if (session != _epoch || !_foreground || _disposed) {
      await clicks.stop();
      return;
    }
    playing = true;
    beat = 0;
  }

  void setTempo(int value) {
    bpm = value.clamp(40, 240);
    _notify();
  }

  void tapTempo() {
    final value = _tapTempo.tap(_clock.elapsed);
    if (value == null) return;
    setTempo(value);
    unawaited(applyMetronomeSettings());
  }

  void setBeats(int value) {
    beatsPerBar = value;
    unawaited(applyMetronomeSettings());
  }

  void setAccent(bool value) {
    accent = value;
    unawaited(applyMetronomeSettings());
  }

  void setVolume(double value) {
    volume = value.clamp(0, 1);
    _notify();
  }

  Future<void> applyMetronomeSettings() => _enqueue(() async {
    if (!playing) return;
    await _startClicks();
  });

  Future<void> _stopAudio() async {
    _epoch++;
    _referenceRequest++;
    if (_activeToneId != null) _endReferenceTone(_activeToneId!);
    listening = false;
    playing = false;
    beat = null;
    _clearPitch();
    await _microphoneSubscription?.cancel();
    _microphoneSubscription = null;
    try {
      await microphone.stop();
    } finally {
      await clicks.stop();
    }
  }

  Future<void> suspend() {
    _foreground = false;
    _epoch++;
    return _enqueue(_stopAudio);
  }

  void resume() => _foreground = true;

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _stalePitch?.cancel();
    unawaited(
      _pending
          .then((_) async {
            await _beatSubscription.cancel();
            await _toneSubscription.cancel();
            try {
              await _stopAudio();
            } finally {
              await microphone.dispose();
              await clicks.dispose();
            }
          })
          .catchError((Object error) => debugPrint('Audio cleanup failed: $error')),
    );
    super.dispose();
  }
}
