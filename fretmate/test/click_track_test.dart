import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fretmate/audio/click_track.dart';

void main() {
  test('audio loop has evenly spaced clicks at slow, fractional and fast tempos', () {
    for (final bpm in [20, 137, 300]) {
      final track = ClickTrack(bpm: bpm, beats: 6, accent: true);
      expect(track.pcm.length, track.framesPerBeat * 6 * 2);
      expect(60 * ClickTrack.sampleRate / track.framesPerBeat, closeTo(bpm, 0.02));
      final data = ByteData.sublistView(track.pcm);
      final energies = <double>[];
      for (var beat = 0; beat < 6; beat++) {
        var energy = 0.0;
        for (var frame = 0; frame < track.framesPerBeat; frame++) {
          final sample = data.getInt16((beat * track.framesPerBeat + frame) * 2, Endian.little);
          if (frame >= ClickTrack.sampleRate ~/ 30) expect(sample, 0);
          energy += sample * sample;
        }
        energies.add(energy);
      }
      expect(energies.first, greaterThan(energies[1]));
      expect(energies.skip(1).every((value) => value == energies[1]), isTrue);
      expect(data.getInt16(0, Endian.little), 0);
      expect(data.getInt16(track.pcm.length - 2, Endian.little), 0);
    }
  });

  test('disabling accent makes every beat identical', () {
    final track = ClickTrack(bpm: 100, beats: 3, accent: false);
    final bytes = track.framesPerBeat * 2;
    expect(track.pcm.sublist(0, bytes), track.pcm.sublist(bytes, bytes * 2));
  });

  test('tap tempo averages taps, ignores double taps and resets after a pause', () {
    final tempo = TapTempo();
    expect(tempo.tap(Duration.zero), isNull);
    expect(tempo.tap(const Duration(milliseconds: 500)), 120);
    expect(tempo.tap(const Duration(milliseconds: 550)), isNull);
    expect(tempo.tap(const Duration(milliseconds: 1000)), 120);
    expect(tempo.tap(const Duration(seconds: 5)), isNull);
    expect(tempo.tap(const Duration(seconds: 6)), 60);
  });

  test('tap tempo supports the new slow and fast limits', () {
    final slow = TapTempo();
    expect(slow.tap(Duration.zero), isNull);
    expect(slow.tap(const Duration(seconds: 3)), 20);
    final fast = TapTempo();
    expect(fast.tap(Duration.zero), isNull);
    expect(fast.tap(const Duration(milliseconds: 200)), 300);
  });
}
