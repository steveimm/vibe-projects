import 'dart:async';

import 'package:flutter/services.dart';
import 'package:record/record.dart';

import 'click_track.dart';
import 'pitch_detector.dart';
import 'reference_tone.dart';

class MicrophonePermissionDenied implements Exception {}

abstract class MicrophoneInput {
  Future<Stream<Uint8List>> start();
  Future<void> stop();
  Future<void> dispose();
}

class DeviceMicrophone implements MicrophoneInput {
  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _audio;
  StreamSubscription<RecordState>? _state;
  StreamController<Uint8List>? _stream;

  @override
  Future<Stream<Uint8List>> start() async {
    final recorder = _recorder ??= AudioRecorder();
    if (!await recorder.hasPermission()) throw MicrophonePermissionDenied();
    final source = await recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: tunerSampleRate,
        numChannels: 1,
        streamBufferSize: 2048,
        androidConfig: AndroidRecordConfig(manageBluetooth: false, audioSource: AndroidAudioSource.unprocessed),
      ),
    );
    final stream = StreamController<Uint8List>.broadcast();
    _stream = stream;
    _audio = source.listen(stream.add, onError: stream.addError, onDone: stream.close);
    _state = recorder.onStateChanged().listen((state) {
      if (state == RecordState.pause && !stream.isClosed) {
        stream.addError(StateError('Microphone interrupted by another app.'));
      }
    }, onError: stream.addError);
    return stream.stream;
  }

  @override
  Future<void> stop() async {
    await _state?.cancel();
    _state = null;
    await _audio?.cancel();
    _audio = null;
    await _recorder?.stop();
    await _stream?.close();
    _stream = null;
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _recorder?.dispose();
    _recorder = null;
  }
}

abstract class ClickOutput {
  Stream<int?> get beats;
  Stream<int> get toneEnds;
  Future<void> start({required int bpm, required int beats, required bool accent, required double volume});
  Future<void> playTone(double frequency, {required int requestId, bool requestFocus = true});
  Future<void> stop();
  Future<void> dispose();
}

class AndroidClickOutput implements ClickOutput {
  AndroidClickOutput() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'beat') _beats.add(call.arguments as int);
      if (call.method == 'stopped') _beats.add(null);
      if (call.method == 'toneEnded') _toneEnds.add(call.arguments as int);
      if (call.method == 'audioError') _beats.addError(StateError(call.arguments as String));
    });
  }

  static const _channel = MethodChannel('id.steveimm.fretmate/metronome');
  final _beats = StreamController<int?>.broadcast();
  final _toneEnds = StreamController<int>.broadcast();
  bool _started = false;
  ({int bpm, int beats, bool accent, double volume})? _settings;

  @override
  Stream<int?> get beats => _beats.stream;

  @override
  Stream<int> get toneEnds => _toneEnds.stream;

  @override
  Future<void> playTone(double frequency, {required int requestId, bool requestFocus = true}) async {
    _settings = null;
    await _channel.invokeMethod<void>('playTone', {
      'pcm': ReferenceTone(frequency).pcm,
      'requestId': requestId,
      'requestFocus': requestFocus,
      'volume': 0.7,
    });
    _started = true;
  }

  @override
  Future<void> start({required int bpm, required int beats, required bool accent, required double volume}) async {
    final settings = (bpm: bpm, beats: beats, accent: accent, volume: volume);
    if (_settings == settings) return;
    final click = ClickTrack(bpm: bpm, beats: beats, accent: accent);
    await _channel.invokeMethod<void>('start', {
      'pcm': click.pcm,
      'framesPerBeat': click.framesPerBeat,
      'beats': beats,
      'volume': volume,
    });
    _started = true;
    _settings = settings;
  }

  @override
  Future<void> stop() async {
    if (!_started) return;
    await _channel.invokeMethod<void>('stop');
    _started = false;
    _settings = null;
  }

  @override
  Future<void> dispose() async {
    await stop();
    _channel.setMethodCallHandler(null);
    await _beats.close();
    await _toneEnds.close();
  }
}
