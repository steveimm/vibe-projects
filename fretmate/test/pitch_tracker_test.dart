import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:fretmate/audio/pitch_detector.dart';

void main() {
  test('repeated pluck swings are reduced equally at different pitches', () {
    const swings = [15.0, 9.0, 4.0, -2.0, -5.0, -10.0];
    for (final base in [55.0, 82.4069, 130.8128, 329.6276]) {
      final tracker = PitchTracker();
      final displayed = <double>[];
      for (var cycle = 0; cycle < 6; cycle++) {
        for (final cents in swings) {
          final pitch = tracker.add(_estimate(base * math.pow(2, cents / 1200)));
          expect(pitch, isNotNull);
          if (cycle >= 4) displayed.add(centsBetween(pitch!, base));
        }
      }
      expect(displayed.reduce(math.max) - displayed.reduce(math.min), lessThan(12.5));
      final measuredMean = swings.reduce((a, b) => a + b) / swings.length;
      expect(displayed.reduce((a, b) => a + b) / displayed.length, closeTo(measuredMean, 1));
    }
  });

  test('two transient lower readings do not replace an established note', () {
    for (final pair in [(195.9977, 65.5), (261.6256, 87.2), (329.6276, 82.4)]) {
      final tracker = PitchTracker();
      expect(tracker.add(_estimate(pair.$1)), pair.$1);
      expect(tracker.add(_estimate(pair.$2)), isNull);
      expect(tracker.add(_estimate(pair.$2)), isNull);
      expect(tracker.add(_estimate(pair.$1)), pair.$1);
    }
  });

  test('confirmed real note changes switch directly without interpolating between notes', () {
    for (final pair in [(195.9977, 82.4069), (82.4069, 329.6276), (146.8324, 73.4162), (130.8128, 174.6141)]) {
      for (final confidence in [0.7, 0.95]) {
        final tracker = PitchTracker();
        tracker.add(_estimate(pair.$1));
        expect(tracker.add(_estimate(pair.$2, confidence: confidence)), isNull);
        expect(tracker.add(_estimate(pair.$2, confidence: confidence)), isNull);
        expect(tracker.add(_estimate(pair.$2, confidence: confidence)), pair.$2);
      }
    }
  });

  test('missing or disagreeing readings interrupt note-change confirmation', () {
    final tracker = PitchTracker();
    tracker.add(_estimate(196));
    expect(tracker.add(_estimate(65.5)), isNull);
    expect(tracker.add(_estimate(65.5)), isNull);
    expect(tracker.add(null), isNull);
    expect(tracker.add(_estimate(65.5)), isNull);
    expect(tracker.add(_estimate(82.4)), isNull);
    expect(tracker.add(_estimate(65.5)), isNull);
    expect(tracker.add(_estimate(196)), 196);
  });

  test('smoothing follows real tuning adjustments without snapping to a target', () {
    final tracker = PitchTracker();
    const initial = 130.8128;
    final adjusted = initial * math.pow(2, 30 / 1200);
    tracker.add(_estimate(initial));
    double? displayed;
    for (var frame = 0; frame < 14; frame++) {
      displayed = tracker.add(_estimate(adjusted));
    }
    expect(centsBetween(displayed!, adjusted).abs(), lessThan(1));
  });

  test('reset discards the prior note and smoothing history', () {
    final tracker = PitchTracker();
    tracker.add(_estimate(196));
    tracker.add(_estimate(65.5));
    tracker.reset();
    expect(tracker.add(_estimate(82.4)), 82.4);
  });
}

PitchEstimate _estimate(double frequency, {double confidence = 0.95}) => (frequency: frequency, confidence: confidence);
