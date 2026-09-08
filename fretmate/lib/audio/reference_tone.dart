import 'dart:math' as math;
import 'dart:typed_data';

class ReferenceTone {
  ReferenceTone(double frequency) {
    if (!frequency.isFinite || frequency <= 0 || frequency * 3 >= sampleRate / 2) {
      throw ArgumentError.value(frequency, 'frequency', 'Must have three harmonics below the Nyquist frequency.');
    }
    final frames = sampleRate * duration.inMilliseconds ~/ 1000;
    final data = ByteData(frames * 2);
    for (var frame = 0; frame < frames; frame++) {
      final phase = 2 * math.pi * frequency * frame / sampleRate;
      final attack = math.min(1.0, frame / (sampleRate * 0.02));
      final release = math.min(1.0, (frames - 1 - frame) / (sampleRate * 0.1));
      final wave = 0.42 * math.sin(phase) + 0.14 * math.sin(2 * phase) + 0.04 * math.sin(3 * phase);
      data.setInt16(frame * 2, (wave * attack * release * 32767).round(), Endian.little);
    }
    pcm = data.buffer.asUint8List();
  }

  static const sampleRate = 44100;
  static const duration = Duration(milliseconds: 1200);
  late final Uint8List pcm;
}
