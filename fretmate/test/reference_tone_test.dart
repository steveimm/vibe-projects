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
      expect(data.getInt16(offset, Endian.little).abs(), lessThan(20000));
    }
    for (var frame = 0; frame < 20; frame++) {
      expect(data.getInt16(frame * 2, Endian.little).abs(), lessThan(1000));
      expect(data.getInt16(pcm.length - 2 - frame * 2, Endian.little).abs(), lessThan(1000));
    }
  });

  for (final frequency in [55.0, 82.4069, 110.0, 130.8128, 329.6276, 391.9954]) {
    test('$frequency Hz reference tone produces the requested pitch', () {
      final data = ByteData.sublistView(ReferenceTone(frequency).pcm);
      final samples = Float64List.fromList(
        List.generate(tunerFrameSize, (i) {
          return data.getInt16(20000 + i * 4, Endian.little) / 32768;
        }),
      );
      final pitch = analyzePitch(samples, minFrequency: 50, maxFrequency: 450);
      expect(pitch, isNotNull);
      expect(centsBetween(pitch!.frequency, frequency).abs(), lessThan(1));
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
}
