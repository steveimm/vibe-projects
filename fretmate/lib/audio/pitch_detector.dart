import 'dart:math' as math;
import 'dart:typed_data';

const tunerSampleRate = 22050;
const tunerFrameSize = 4096;
const tunerReliableConfidence = 0.85;

typedef PitchEstimate = ({double frequency, double confidence});

class GuitarString {
  const GuitarString(this.number, this.note, this.octave, this.frequency);

  final int number;
  final String note;
  final int octave;
  final double frequency;

  String get label => '$note$octave';
}

const standardStrings = [
  GuitarString(6, 'E', 2, 82.4069),
  GuitarString(5, 'A', 2, 110),
  GuitarString(4, 'D', 3, 146.8324),
  GuitarString(3, 'G', 3, 195.9977),
  GuitarString(2, 'B', 3, 246.9417),
  GuitarString(1, 'E', 4, 329.6276),
];

double centsBetween(double frequency, double target) => 1200 * math.log(frequency / target) / math.ln2;

GuitarString nearestString(double frequency) => standardStrings.reduce((a, b) {
  return centsBetween(frequency, a.frequency).abs() < centsBetween(frequency, b.frequency).abs() ? a : b;
});

double? detectPitch(Float64List samples, {void Function(String message)? onDiagnostic}) =>
    analyzePitch(samples, onDiagnostic: onDiagnostic)?.frequency;

// YIN difference and cumulative mean normalization, followed by parabolic interpolation.
PitchEstimate? analyzePitch(
  Float64List samples, {
  double? previousFrequency,
  double minFrequency = 65,
  double maxFrequency = 400,
  void Function(String message)? onDiagnostic,
}) {
  if (samples.length != tunerFrameSize || samples.any((sample) => !sample.isFinite)) return null;
  if (!minFrequency.isFinite || !maxFrequency.isFinite || minFrequency <= 0 || maxFrequency <= minFrequency) {
    return null;
  }
  if (maxFrequency >= tunerSampleRate / 2) return null;

  final mean = samples.reduce((a, b) => a + b) / samples.length;
  var energy = 0.0;
  for (final sample in samples) {
    energy += (sample - mean) * (sample - mean);
  }
  final rms = math.sqrt(energy / samples.length);
  const minimumRms = 0.001;
  if (rms < minimumRms) {
    onDiagnostic?.call('Tuner: rejected=quiet rms=${rms.toStringAsFixed(6)} minimum=$minimumRms');
    return null;
  }

  // Reduce broadband noise before comparing repeating periods.
  final filtered = Float64List(samples.length);
  final alpha = 1 - math.exp(-2 * math.pi * (2.5 * maxFrequency) / tunerSampleRate);
  var firstStage = samples.first - mean;
  var secondStage = firstStage;
  for (var i = 0; i < samples.length; i++) {
    firstStage += alpha * (samples[i] - mean - firstStage);
    secondStage += alpha * (firstStage - secondStage);
    filtered[i] = secondStage;
  }

  final minTau = tunerSampleRate ~/ maxFrequency;
  final maxTau = tunerSampleRate ~/ minFrequency;
  const windowStart = 64; // Skip the low-pass filter's startup transient.
  final windowEnd = tunerFrameSize - maxTau - 1;
  if (windowEnd - windowStart < maxTau) return null;
  final rawDifference = Float64List(maxTau + 2);
  final difference = Float64List(maxTau + 2);
  difference[0] = 1;
  var runningSum = 0.0;
  for (var tau = 1; tau <= maxTau + 1; tau++) {
    var sum = 0.0;
    for (var i = windowStart; i < windowEnd; i++) {
      final delta = filtered[i] - filtered[i + tau];
      sum += delta * delta;
    }
    rawDifference[tau] = sum;
    runningSum += sum;
    difference[tau] = runningSum == 0 ? 1 : sum * tau / runningSum;
  }

  var bestTau = minTau;
  var bestCandidateDifference = double.infinity;
  final candidates = <int>[];
  for (var tau = minTau; tau <= maxTau; tau++) {
    if (difference[tau] < difference[bestTau]) bestTau = tau;
    if (difference[tau] > difference[tau - 1] || difference[tau] >= difference[tau + 1]) continue;
    candidates.add(tau);
    bestCandidateDifference = math.min(bestCandidateDifference, difference[tau]);
  }
  const minimumConfidence = 0.55;
  // The first acceptable valley may be a harmonic when the fundamental is weak.
  final threshold = math.min(1 - minimumConfidence, bestCandidateDifference + 0.05);
  if (onDiagnostic != null) {
    final choices = candidates.map(
      (tau) => '${(tunerSampleRate / tau).toStringAsFixed(1)}:${(1 - difference[tau]).toStringAsFixed(3)}',
    );
    onDiagnostic('Tuner: candidates(hz:confidence)=${choices.join(',')}');
  }
  for (var tau in candidates) {
    if (difference[tau] > threshold) continue;
    if (previousFrequency != null && previousFrequency.isFinite && previousFrequency > 0) {
      final frequency = tunerSampleRate / tau;
      final multiple = (previousFrequency / frequency).round();
      if (multiple >= 2 && centsBetween(previousFrequency, frequency * multiple).abs() < 50) {
        var nearestDistance = 50.0;
        for (final candidate in candidates) {
          if (difference[candidate] > 1 - minimumConfidence) continue;
          final distance = centsBetween(tunerSampleRate / candidate, previousFrequency).abs();
          if (distance < nearestDistance) {
            tau = candidate;
            nearestDistance = distance;
          }
        }
      }
    }
    final confidence = 1 - difference[tau];
    while (tau > minTau && rawDifference[tau - 1] < rawDifference[tau]) {
      tau--;
    }
    while (tau < maxTau && rawDifference[tau + 1] < rawDifference[tau]) {
      tau++;
    }
    final left = rawDifference[tau - 1];
    final middle = rawDifference[tau];
    final right = rawDifference[tau + 1];
    final denominator = left - 2 * middle + right;
    final offset = denominator == 0 ? 0.0 : (0.5 * (left - right) / denominator).clamp(-1.0, 1.0);
    final frequency = tunerSampleRate / (tau + offset);
    onDiagnostic?.call(
      'Tuner: pitch=${frequency.toStringAsFixed(2)} rms=${rms.toStringAsFixed(6)} confidence=${confidence.toStringAsFixed(3)}',
    );
    return frequency >= minFrequency && frequency <= maxFrequency
        ? (frequency: frequency, confidence: confidence)
        : null;
  }
  onDiagnostic?.call(
    'Tuner: rejected=confidence rms=${rms.toStringAsFixed(6)} bestHz=${(tunerSampleRate / bestTau).toStringAsFixed(2)} confidence=${(1 - difference[bestTau]).toStringAsFixed(3)} minimum=$minimumConfidence',
  );
  return null;
}

class PitchTracker {
  final List<double> _recent = [];
  double? _frequency;
  double? _candidate;
  int _candidateFrames = 0;

  double? add(PitchEstimate? estimate) {
    if (estimate == null) {
      _candidate = null;
      _candidateFrames = 0;
      return null;
    }
    final pitch = estimate.frequency;
    _candidateFrames = _candidate != null && centsBetween(pitch, _candidate!).abs() <= 50 ? _candidateFrames + 1 : 1;
    _candidate = pitch;
    final changingNote = _frequency != null && centsBetween(pitch, _frequency!).abs() > 80;
    if ((changingNote && _candidateFrames < 3) ||
        (estimate.confidence < tunerReliableConfidence && _candidateFrames < 2)) {
      return null;
    }
    if (changingNote) _recent.clear();
    _recent.add(pitch);
    if (_recent.length > 3) _recent.removeAt(0);
    final sorted = [..._recent]..sort();
    final median = sorted[sorted.length ~/ 2];
    // Smooth in cents so low and high notes have the same response.
    _frequency = _frequency == null || changingNote
        ? median
        : _frequency! * math.pow(2, 0.25 * centsBetween(median, _frequency!) / 1200);
    return _frequency;
  }

  void reset() {
    _frequency = null;
    _candidate = null;
    _candidateFrames = 0;
    _recent.clear();
  }
}

class PcmFrameDecoder {
  Float64List _frame = Float64List(tunerFrameSize);
  int _position = 0;
  int? _lowByte;

  Iterable<Float64List> add(Uint8List bytes) sync* {
    for (final byte in bytes) {
      if (_lowByte == null) {
        _lowByte = byte;
        continue;
      }
      final value = _lowByte! | (byte << 8);
      _lowByte = null;
      _frame[_position++] = (value >= 32768 ? value - 65536 : value) / 32768;
      if (_position == tunerFrameSize) {
        yield _frame;
        _frame = Float64List(tunerFrameSize);
        _position = 0;
      }
    }
  }
}
