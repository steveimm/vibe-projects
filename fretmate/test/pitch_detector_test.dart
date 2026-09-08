import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fretmate/audio/pitch_detector.dart';

void main() {
  for (final string in standardStrings) {
    for (final cents in [-35, 0, 35]) {
      test('${string.label}, $cents cents, with harmonics, decay and noise', () {
        final frequency = string.frequency * math.pow(2, cents / 1200);
        final random = math.Random(42);
        final samples = Float64List.fromList(
          List.generate(tunerFrameSize, (i) {
            final phase = 2 * math.pi * frequency * i / tunerSampleRate;
            final envelope = math.exp(-2 * i / tunerFrameSize);
            return 0.1 +
                envelope * (0.25 * math.sin(phase) + 0.4 * math.sin(2 * phase) + 0.15 * math.sin(3 * phase)) +
                0.015 * (random.nextDouble() - 0.5);
          }),
        );
        final detected = detectPitch(samples);
        expect(detected, isNotNull);
        expect(centsBetween(detected!, frequency).abs(), lessThan(3));
        expect(nearestString(detected), string);
        expect(centsBetween(detected, string.frequency), closeTo(cents, 3));
      });
    }
    for (final level in [(amplitude: 0.006, noise: 0.009), (amplitude: 0.012, noise: 0.024)]) {
      test('${string.label} at microphone level ${level.amplitude} with background noise', () {
        final random = math.Random(42);
        final pitches = <double>[];
        for (var frame = 0; frame < 3; frame++) {
          final samples = Float64List.fromList(
            List.generate(tunerFrameSize, (i) {
              final position = frame * tunerFrameSize + i;
              final phase = 2 * math.pi * string.frequency * position / tunerSampleRate;
              final envelope = math.exp(-0.5 * position / (3 * tunerFrameSize));
              final tone = math.sin(phase) + 0.3 * math.sin(2 * phase) + 0.1 * math.sin(3 * phase);
              return level.amplitude * envelope * tone + level.noise * (random.nextDouble() - 0.5);
            }),
          );
          final detected = detectPitch(samples);
          expect(detected, isNotNull);
          expect(centsBetween(detected!, string.frequency).abs(), lessThan(10));
          expect(nearestString(detected), string);
          pitches.add(detected);
        }
        pitches.sort();
        expect(centsBetween(pitches[1], string.frequency).abs(), lessThan(5));
      });
    }
  }

  test('silence, DC offset, very quiet audio and noise have no pitch', () {
    expect(detectPitch(Float64List(tunerFrameSize)), isNull);
    expect(detectPitch(Float64List.fromList(List.filled(tunerFrameSize, 0.5))), isNull);
    final random = math.Random(7);
    expect(detectPitch(Float64List.fromList(List.generate(tunerFrameSize, (_) => random.nextDouble() - 0.5))), isNull);
    expect(detectPitch(Float64List.fromList(List.generate(tunerFrameSize, (i) => 0.001 * math.sin(i / 20)))), isNull);
  });

  test('background noise at microphone levels does not select a string', () {
    for (var seed = 0; seed < 20; seed++) {
      final random = math.Random(seed);
      final samples = Float64List.fromList(List.generate(tunerFrameSize, (_) => 0.009 * (random.nextDouble() - 0.5)));
      expect(detectPitch(samples), isNull, reason: 'Noise sample $seed');
    }
  });

  test('pitch estimation accepts notes outside standard tuning and a configurable range', () {
    for (final frequency in [73.4162, 87.3071, 130.8128, 369.9944]) {
      final pitch = analyzePitch(_sineWave(frequency));
      expect(pitch, isNotNull);
      expect(centsBetween(pitch!.frequency, frequency).abs(), lessThan(3));
    }
    final lowA = analyzePitch(_sineWave(55), minFrequency: 50, maxFrequency: 450);
    expect(lowA, isNotNull);
    expect(centsBetween(lowA!.frequency, 55).abs(), lessThan(3));
  });

  test('an established note does not jump to a lower subharmonic as interference grows', () {
    for (final signal in [
      (frequency: 146.8324, divisor: 2, interference: 0.0045),
      (frequency: 329.6276, divisor: 5, interference: 0.006),
      (frequency: 130.8128, divisor: 2, interference: 0.0045),
    ]) {
      final samples = Float64List.fromList(
        List.generate(tunerFrameSize, (i) {
          final phase = 2 * math.pi * signal.frequency * i / tunerSampleRate;
          return 0.01 * math.sin(phase) + signal.interference * math.sin(phase / signal.divisor);
        }),
      );
      final pitch = analyzePitch(samples, previousFrequency: signal.frequency);
      expect(pitch, isNotNull);
      expect(centsBetween(pitch!.frequency, signal.frequency).abs(), lessThan(50));
    }
  });

  test('tracking allows real note changes, including lower octaves', () {
    for (final change in [(329.6276, 82.4069), (146.8324, 73.4162), (82.4069, 110.0), (146.8324, 293.6648)]) {
      final pitch = analyzePitch(_sineWave(change.$2), previousFrequency: change.$1);
      expect(pitch, isNotNull);
      expect(centsBetween(pitch!.frequency, change.$2).abs(), lessThan(3));
    }
  });

  for (final harmonic in [2, 3]) {
    test('a dominant harmonic $harmonic does not replace the fundamental', () {
      for (final frequency in [73.4162, 82.4069, 110.0, 130.8128, 146.8324, 194.5]) {
        final random = math.Random(42);
        double? previousFrequency;
        for (var frame = 0; frame < 3; frame++) {
          final samples = Float64List.fromList(
            List.generate(tunerFrameSize, (i) {
              final position = frame * tunerFrameSize + i;
              final phase = 2 * math.pi * frequency * position / tunerSampleRate;
              final envelope = math.exp(-0.4 * position / tunerFrameSize);
              final fundamental = frame == 0 ? 0.012 : 0.004;
              return envelope * (fundamental * math.sin(phase) + 0.02 * math.sin(harmonic * phase)) +
                  0.002 * (random.nextDouble() - 0.5);
            }),
          );
          final pitch = analyzePitch(samples, previousFrequency: previousFrequency);
          expect(pitch, isNotNull, reason: '$frequency Hz, frame $frame');
          expect(centsBetween(pitch!.frequency, frequency).abs(), lessThan(5), reason: '$frequency Hz, frame $frame');
          previousFrequency = pitch.frequency;
        }
      }
    });
  }

  test('PCM decoding preserves signed samples across arbitrary byte boundaries', () {
    final original = List.generate(tunerFrameSize * 2, (i) => (i * 997) % 65536 - 32768);
    final bytes = ByteData(original.length * 2);
    for (var i = 0; i < original.length; i++) {
      bytes.setInt16(i * 2, original[i], Endian.little);
    }
    final decoder = PcmFrameDecoder();
    final decoded = <double>[];
    final source = bytes.buffer.asUint8List();
    for (var i = 0; i < source.length; i += 333) {
      for (final frame in decoder.add(Uint8List.sublistView(source, i, math.min(i + 333, source.length)))) {
        decoded.addAll(frame);
      }
    }
    expect(decoded, original.map((value) => value / 32768).toList());
  });
}

Float64List _sineWave(double frequency) => Float64List.fromList(
  List.generate(tunerFrameSize, (i) => 0.02 * math.sin(2 * math.pi * frequency * i / tunerSampleRate)),
);
