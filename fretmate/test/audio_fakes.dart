import 'dart:async';
import 'dart:typed_data';

import 'package:fretmate/audio/audio_services.dart';

class FakeMicrophone implements MicrophoneInput {
  final stream = StreamController<Uint8List>.broadcast();
  bool permission = true;
  bool recording = false;
  int starts = 0;
  Completer<void>? startGate;

  @override
  Future<Stream<Uint8List>> start() async {
    starts++;
    await startGate?.future;
    if (!permission) throw MicrophonePermissionDenied();
    recording = true;
    return stream.stream;
  }

  @override
  Future<void> stop() async => recording = false;

  @override
  Future<void> dispose() => stream.close();
}

class FakeClicks implements ClickOutput {
  final events = StreamController<int?>.broadcast();
  final toneEvents = StreamController<int>.broadcast();
  final tones = <({double frequency, int requestId, bool requestFocus})>[];
  int? activeTone;
  Completer<void>? toneGate;
  Completer<void>? stopGate;
  bool playing = false;
  bool fail = false;
  int starts = 0;
  ({int bpm, int beats, bool accent, double volume})? settings;
  Completer<void>? startGate;

  @override
  Stream<int?> get beats => events.stream;

  @override
  Stream<int> get toneEnds => toneEvents.stream;

  @override
  Future<void> playTone(double frequency, {required int requestId, bool requestFocus = true}) async {
    await toneGate?.future;
    if (fail) throw StateError('No audio device');
    activeTone = requestId;
    tones.add((frequency: frequency, requestId: requestId, requestFocus: requestFocus));
  }

  void finishTone() {
    if (activeTone != null) toneEvents.add(activeTone!);
    activeTone = null;
  }

  @override
  Future<void> start({required int bpm, required int beats, required bool accent, required double volume}) async {
    await startGate?.future;
    if (fail) throw StateError('No audio device');
    playing = true;
    starts++;
    settings = (bpm: bpm, beats: beats, accent: accent, volume: volume);
  }

  @override
  Future<void> stop() async {
    await stopGate?.future;
    playing = false;
    finishTone();
  }

  @override
  Future<void> dispose() async {
    await events.close();
    await toneEvents.close();
  }
}
