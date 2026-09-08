import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fretmate/audio/pitch_detector.dart';
import 'package:fretmate/practice_controller.dart';
import 'package:fretmate/tuning.dart';

import 'audio_fakes.dart';

void main() {
  test('notes use A4 = 440 Hz and exact semitone intervals', () {
    expect(const GuitarString(1, 69).frequency, 440);
    expect(const GuitarString(1, 47).label, 'B2');
    expect(const GuitarString(1, 48).label, 'C3');
    for (var note = minimumTuningNote; note < maximumTuningNote; note++) {
      final lower = GuitarString(6, note);
      final higher = GuitarString(6, note + 1);
      expect(centsBetween(higher.frequency, lower.frequency), closeTo(100, 0.000001));
    }
  });

  test('common preset notes and octaves match the reference', () {
    const expected = {
      'Standard tuning': 'E2 A2 D3 G3 B3 E4',
      'Drop D': 'D2 A2 D3 G3 B3 E4',
      'Double Drop D': 'D2 A2 D3 G3 B3 D4',
      'Drop C♯': 'C♯2 G♯2 C♯3 F♯3 A♯3 D♯4',
      'Drop C': 'C2 G2 C3 F3 A3 D4',
      'Drop B': 'B1 F♯2 B2 E3 G♯3 C♯4',
      'Drop B♭': 'A♯1 F2 A♯2 D♯3 G3 C4',
      'Drop A': 'A1 E2 A2 D3 F♯3 B3',
      'E♭ standard': 'D♯2 G♯2 C♯3 F♯3 A♯3 D♯4',
      'D standard': 'D2 G2 C3 F3 A3 D4',
      'C♯ standard': 'C♯2 F♯2 B2 E3 G♯3 C♯4',
      'C standard': 'C2 F2 A♯2 D♯3 G3 C4',
      'B standard': 'B1 E2 A2 D3 F♯3 B3',
      'A standard': 'A1 D2 G2 C3 E3 A3',
      'DADGAD': 'D2 A2 D3 G3 A3 D4',
      'Open D': 'D2 A2 D3 F♯3 A3 D4',
      'Open G': 'D2 G2 D3 G3 B3 D4',
      'Open C': 'C2 G2 C3 G3 C4 E4',
      'Open E': 'E2 B2 E3 G♯3 B3 E4',
      'Open A': 'E2 A2 E3 A3 C♯4 E4',
      'Open D minor': 'D2 A2 D3 F3 A3 D4',
      'Open G minor': 'D2 G2 D3 G3 A♯3 D4',
      'Open C minor': 'C2 G2 C3 G3 C4 D♯4',
      'Open E minor': 'E2 B2 E3 G3 B3 E4',
      'Nashville': 'E3 A3 D4 G4 B3 E4',
      'New standard': 'C2 G2 D3 A3 E4 G4',
    };
    expect(tuningPresets.length, expected.length);
    for (final preset in tuningPresets) {
      expect(preset.strings.map((string) => string.label).join(' '), expected[preset.name]);
      expect(preset.strings.map((string) => string.number), [6, 5, 4, 3, 2, 1]);
      expect(matchingTuning(preset.strings), same(preset));
    }
  });

  test('preset matching checks all six notes including octaves', () {
    final custom = standardStrings.toList()..[0] = const GuitarString(6, 52);
    expect(custom.map((string) => string.note).join(), 'EADGBE');
    expect(matchingTuning(custom), isNull);
  });

  for (final preset in tuningPresets) {
    test('${preset.name} detects its strings inside the configured range', () {
      final controller = PracticeController(microphone: FakeMicrophone(), clicks: FakeClicks());
      addTearDown(controller.dispose);
      controller.selectTuning(preset);
      final range = controller.pitchRange;
      for (final string in controller.strings) {
        for (final cents in [-35, 35]) {
          final frequency = string.frequency * math.pow(2, cents / 1200);
          final samples = Float64List.fromList(
            List.generate(tunerFrameSize, (i) {
              final phase = 2 * math.pi * frequency * i / tunerSampleRate;
              return 0.02 * math.sin(phase) + 0.006 * math.sin(2 * phase);
            }),
          );
          final pitch = analyzePitch(samples, minFrequency: range.minimum, maxFrequency: range.maximum);
          expect(pitch, isNotNull, reason: '${string.label}, $cents cents');
          expect(centsBetween(pitch!.frequency, frequency).abs(), lessThan(3));
          expect(nearestString(pitch.frequency, strings: controller.strings).number, string.number);
        }
      }
    });
  }
}
