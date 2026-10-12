import 'dart:math' as math;
import 'dart:typed_data';

class ReferenceTone {
  ReferenceTone(double frequency) {
    if (!frequency.isFinite || frequency <= 0 || frequency * 8 >= sampleRate / 2) {
      throw ArgumentError.value(frequency, 'frequency', 'Must have eight harmonics below the Nyquist frequency.');
    }
    final frames = sampleRate * duration.inMilliseconds ~/ 1000;
    final samples = Float64List(frames);
    // Carry low notes on small speakers, tapering to a softer harmonic mix above 220 Hz.
    final bassBlend = ((220 - frequency) / 165).clamp(0.0, 1.0);
    final harmonics = List.generate(8, (i) {
      final harmonic = i + 1;
      return (1 + 2 * bassBlend * i) / (harmonic * harmonic);
    });
    var peak = 0.0;
    final data = ByteData(frames * 2);
    for (var frame = 0; frame < frames; frame++) {
      final phase = 2 * math.pi * frequency * frame / sampleRate;
      final attack = _fade(frame / (sampleRate * 0.02));
      final release = _fade((frames - 1 - frame) / (sampleRate * 0.1));
      var wave = 0.0;
      for (var i = 0; i < harmonics.length; i++) {
        wave += harmonics[i] * math.sin((i + 1) * phase);
      }
      samples[frame] = wave * attack * release;
      peak = math.max(peak, samples[frame].abs());
    }
    final gain = (0.5 + 0.3 * bassBlend) / peak;
    for (var frame = 0; frame < frames; frame++) {
      data.setInt16(frame * 2, (samples[frame] * gain * 32767).round(), Endian.little);
    }
    pcm = data.buffer.asUint8List();
  }

  static const sampleRate = 44100;
  static const duration = Duration(milliseconds: 1200);
  late final Uint8List pcm;

  static double _fade(double position) => 0.5 - 0.5 * math.cos(math.pi * position.clamp(0.0, 1.0));
}
