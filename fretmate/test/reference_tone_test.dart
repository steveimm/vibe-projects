import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fretmate/audio/audio_services.dart';
import 'package:fretmate/audio/pitch_detector.dart';
import 'package:fretmate/audio/reference_tone.dart';
import 'package:fretmate/tuning.dart';

void main() {
  test('reference tones last 1.2 seconds, fade at both ends and never clip', () {
    final pcm = ReferenceTone(110).pcm;
    expect(pcm.length, ReferenceTone.sampleRate * 1200 ~/ 1000 * 2);
    final data = ByteData.sublistView(pcm);
    expect(data.getInt16(0, Endian.little), 0);
    expect(data.getInt16(pcm.length - 2, Endian.little), 0);
    for (var offset = 0; offset < pcm.length; offset += 2) {
      expect(data.getInt16(offset, Endian.little).abs(), lessThan(26215));
    }
    for (var frame = 0; frame < 20; frame++) {
      expect(data.getInt16(frame * 2, Endian.little).abs(), lessThan(1000));
      expect(data.getInt16(pcm.length - 2 - frame * 2, Endian.little).abs(), lessThan(1000));
    }
  });

  test('every supported semitone keeps headroom and silent endpoints', () {
    for (var note = minimumTuningNote; note <= maximumTuningNote; note++) {
      final data = ByteData.sublistView(ReferenceTone(GuitarString(6, note).frequency).pcm);
      var peak = 0;
      for (var offset = 0; offset < data.lengthInBytes; offset += 2) {
        peak = math.max(peak, data.getInt16(offset, Endian.little).abs());
      }
      expect(peak, inInclusiveRange(16382, 26214), reason: 'MIDI $note');
      expect(data.getInt16(0, Endian.little), 0);
      expect(data.getInt16(data.lengthInBytes - 2, Endian.little), 0);
    }
  });

  for (final frequency in [32.7032, 55.0, 82.4069, 110.0, 130.8128, 329.6276, 391.9954, 1046.5023]) {
    test('$frequency Hz reference tone produces the requested pitch', () {
      final data = ByteData.sublistView(ReferenceTone(frequency).pcm);
      final samples = Float64List.fromList(
        List.generate(tunerFrameSize, (i) {
          return data.getInt16(20000 + i * 4, Endian.little) / 32768;
        }),
      );
      final pitch = analyzePitch(samples, minFrequency: 30, maxFrequency: 1200);
      expect(pitch, isNotNull);
      expect(centsBetween(pitch!.frequency, frequency).abs(), lessThan(1));
    });
  }

  for (final frequency in [55.0, 82.4069, 110.0, 146.8324]) {
    test('$frequency Hz has stronger harmonics above 200 Hz without losing its fundamental', () {
      final data = ByteData.sublistView(ReferenceTone(frequency).pcm);
      final amplitudes = List.generate(8, (i) => _amplitude(data, frequency * (i + 1)));
      expect(amplitudes.first, greaterThan(amplitudes.skip(1).reduce(math.max)));
      var power = 0.0;
      var oldPower = 0.0;
      const oldAmplitudes = [0.42, 0.14, 0.04, 0.0, 0.0, 0.0, 0.0, 0.0];
      for (var i = 0; i < amplitudes.length; i++) {
        if (frequency * (i + 1) < 200) continue;
        power += amplitudes[i] * amplitudes[i];
        oldPower += oldAmplitudes[i] * oldAmplitudes[i];
      }
      expect(power, greaterThan(math.max(0.02, oldPower * 3)));
    });
  }

  test('invalid reference frequencies are rejected', () {
    for (final frequency in [0.0, -1.0, double.nan, double.infinity, 8000.0]) {
      expect(() => ReferenceTone(frequency), throwsArgumentError);
    }
  });

  testWidgets('Android output sends one-shot PCM and its request ID', (tester) async {
    const channel = MethodChannel('id.steveimm.fretmate/metronome');
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    final output = AndroidClickOutput();
    await output.playTone(110, requestId: 7, requestFocus: false);
    expect(calls.single.method, 'playTone');
    final arguments = calls.single.arguments as Map;
    expect(arguments['requestId'], 7);
    expect(arguments['requestFocus'], isFalse);
    expect(arguments['pcm'], ReferenceTone(110).pcm);
    expect(arguments['volume'], 0.7);
    await output.dispose();
    expect(calls.last.method, 'stop');
  });

  testWidgets('metronome configuration changes do not send a stop or repeat unchanged settings', (tester) async {
    const channel = MethodChannel('id.steveimm.fretmate/metronome');
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    final output = AndroidClickOutput();
    await output.start(bpm: 20, beats: 4, accent: true, volume: 0.7);
    await output.start(bpm: 300, beats: 6, accent: false, volume: 0.7);
    await output.start(bpm: 300, beats: 6, accent: false, volume: 0.7);
    expect(calls.map((call) => call.method), ['start', 'start']);
    expect((calls.first.arguments as Map)['framesPerBeat'], 132300);
    expect((calls.last.arguments as Map)['framesPerBeat'], 8820);
    await output.stop();
    await output.start(bpm: 300, beats: 6, accent: false, volume: 0.7);
    expect(calls.map((call) => call.method), ['start', 'start', 'stop', 'start']);
    await output.dispose();
  });
}

double _amplitude(ByteData data, double frequency) {
  const start = ReferenceTone.sampleRate ~/ 5;
  const count = ReferenceTone.sampleRate ~/ 2;
  var real = 0.0;
  var imaginary = 0.0;
  for (var frame = start; frame < start + count; frame++) {
    final phase = 2 * math.pi * frequency * frame / ReferenceTone.sampleRate;
    final sample = data.getInt16(frame * 2, Endian.little) / 32768;
    real += sample * math.cos(phase);
    imaginary += sample * math.sin(phase);
  }
  return 2 * math.sqrt(real * real + imaginary * imaginary) / count;
}
