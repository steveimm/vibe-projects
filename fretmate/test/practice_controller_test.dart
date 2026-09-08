import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fretmate/audio/pitch_detector.dart';
import 'package:fretmate/practice_controller.dart';
import 'package:fretmate/tuning.dart';

import 'audio_fakes.dart';

void main() {
  late FakeMicrophone microphone;
  late FakeClicks clicks;
  late PracticeController controller;

  setUp(() {
    microphone = FakeMicrophone();
    clicks = FakeClicks();
    controller = PracticeController(microphone: microphone, clicks: clicks);
  });
  tearDown(() => controller.dispose());

  test('locking plays the current target and tapping again replays it', () async {
    controller.adjustString(6, -2);
    final string = controller.strings.first;
    await controller.lockAndPlayString(string);
    expect(controller.selectedString, string);
    expect(clicks.tones.single.frequency, string.frequency);
    expect(clicks.tones.single.requestFocus, isTrue);
    expect(controller.referencePlaying, isTrue);
    expect(microphone.starts, 0);
    final oldId = clicks.tones.last.requestId;
    await controller.lockAndPlayString(string);
    expect(clicks.tones.length, 2);
    clicks.toneEvents.add(oldId);
    await Future<void>.delayed(Duration.zero);
    expect(controller.referencePlaying, isTrue);
    clicks.finishTone();
    await Future<void>.delayed(Duration.zero);
    expect(controller.referencePlaying, isFalse);
    expect(controller.selectedString, string);
  });

  test('rapid taps replace the tone instead of queuing every note', () async {
    clicks.toneGate = Completer<void>();
    final first = controller.lockAndPlayString(controller.strings.first);
    await Future<void>.delayed(Duration.zero);
    final second = controller.lockAndPlayString(controller.strings[1]);
    final third = controller.lockAndPlayString(controller.strings.last);
    clicks.toneGate!.complete();
    await Future.wait([first, second, third]);
    expect(clicks.tones.map((tone) => tone.frequency), [
      controller.strings.first.frequency,
      controller.strings.last.frequency,
    ]);
    expect(controller.selectedString?.number, 1);
    expect(controller.referencePlaying, isTrue);
    expect(clicks.activeTone, clicks.tones.last.requestId);
  });

  for (final change in ['auto', 'notes', 'preset', 'tab', 'background']) {
    test('$change cancels the reference tone', () async {
      await controller.toggleTuner();
      await controller.lockAndPlayString(controller.strings.first);
      switch (change) {
        case 'auto':
          controller.selectString(null);
        case 'notes':
          controller.adjustString(6, -1);
        case 'preset':
          controller.selectTuning(tuningPresets[1]);
        case 'tab':
          await controller.selectTab(1);
        case 'background':
          await controller.suspend();
      }
      await Future<void>.delayed(Duration.zero);
      expect(clicks.activeTone, isNull);
      expect(controller.referencePlaying, isFalse);
      expect(microphone.recording, change != 'tab' && change != 'background');
    });
  }

  test('leaving during reference startup cancels playback', () async {
    clicks.toneGate = Completer<void>();
    final start = controller.lockAndPlayString(controller.strings.first);
    await Future<void>.delayed(Duration.zero);
    final stop = controller.suspend();
    clicks.toneGate!.complete();
    await Future.wait([start, stop]);
    expect(controller.referencePlaying, isFalse);
    expect(clicks.activeTone, isNull);
  });

  test('failed reference playback releases state and allows retry', () async {
    clicks.fail = true;
    await controller.lockAndPlayString(controller.strings.first);
    expect(controller.referencePlaying, isFalse);
    expect(controller.error, isNotNull);
    clicks.fail = false;
    await controller.lockAndPlayString(controller.strings.first);
    expect(controller.referencePlaying, isTrue);
    expect(controller.error, isNull);
  });

  test('microphone ignores reference playback and its tail then resumes detection', () async {
    await controller.toggleTuner();
    await controller.lockAndPlayString(controller.strings[1]);
    expect(clicks.tones.single.requestFocus, isFalse);
    final pcm = ByteData(tunerFrameSize * 2);
    for (var i = 0; i < tunerFrameSize; i++) {
      pcm.setInt16(i * 2, (1600 * math.sin(2 * math.pi * 110 * i / tunerSampleRate)).round(), Endian.little);
    }
    final timer = Timer.periodic(
      const Duration(milliseconds: 80),
      (_) => microphone.stream.add(pcm.buffer.asUint8List()),
    );
    addTearDown(timer.cancel);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    expect(controller.frequency, isNull);
    clicks.finishTone();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    expect(controller.referencePlaying, isFalse);
    expect(controller.frequency, isNull);
    final detected = Completer<void>();
    controller.addListener(() {
      if (controller.frequency != null && !detected.isCompleted) detected.complete();
    });
    await detected.future.timeout(const Duration(seconds: 3));
    expect(controller.frequency, closeTo(110, 0.2));
    expect(controller.listening, isTrue);
    expect(microphone.starts, 1);
  });

  test('manual changes recognize presets and keep automatic mode', () {
    expect(controller.tuningName, 'Standard tuning');
    expect(controller.pitchRange, (minimum: 65.0, maximum: 400.0));
    controller.adjustString(6, -1);
    expect(controller.tuningName, 'Custom');
    expect(controller.strings.first.label, 'D♯2');
    controller.adjustString(6, -1);
    expect(controller.tuningName, 'Drop D');
    expect(controller.tuningNotes, 'DADGBE');
    controller.adjustString(1, -2);
    expect(controller.tuningName, 'Double Drop D');
    expect(controller.selectedString, isNull);
  });

  test('locked strings follow edits and preset changes without restarting audio', () async {
    await controller.toggleTuner();
    controller.selectString(controller.strings.first);
    controller.frequency = 82.4;
    controller.adjustString(6, -2);
    expect(controller.selectedString?.label, 'D2');
    expect(controller.frequency, isNull);
    controller.selectTuning(tuningPresets.firstWhere((preset) => preset.name == 'Drop C'));
    expect(controller.target?.number, 6);
    expect(controller.target?.label, 'C2');
    expect(controller.pitchRange.minimum, lessThan(65));
    expect(controller.listening, isTrue);
    expect(microphone.starts, 1);
    controller.selectString(null);
    controller.frequency = controller.strings.first.frequency;
    expect(controller.target?.label, 'C2');
    expect(controller.inTune, isTrue);
  });

  test('semitone edits cross octaves and stop at the supported bounds', () {
    controller.adjustString(2, 1);
    expect(controller.strings[4].label, 'C4');
    controller.adjustString(2, -1);
    expect(controller.strings[4].label, 'B3');
    expect(controller.tuningName, 'Standard tuning');
    controller.adjustString(6, -1000);
    expect(controller.strings.first.midiNote, minimumTuningNote);
    controller.adjustString(6, -1);
    expect(controller.strings.first.midiNote, minimumTuningNote);
    controller.adjustString(1, 1000);
    expect(controller.strings.last.midiNote, maximumTuningNote);
    controller.adjustString(1, 1);
    expect(controller.strings.last.midiNote, maximumTuningNote);
  });

  test('Drop A microphone audio uses the expanded pitch range', () async {
    controller.selectTuning(tuningPresets.firstWhere((preset) => preset.name == 'Drop A'));
    await controller.toggleTuner();
    final detected = Completer<void>();
    controller.addListener(() {
      if (controller.frequency != null && !detected.isCompleted) detected.complete();
    });
    final pcm = ByteData(tunerFrameSize * 2);
    for (var i = 0; i < tunerFrameSize; i++) {
      pcm.setInt16(i * 2, (1600 * math.sin(2 * math.pi * 55 * i / tunerSampleRate)).round(), Endian.little);
    }
    microphone.stream.add(pcm.buffer.asUint8List());
    await detected.future.timeout(const Duration(seconds: 5));
    expect(controller.target?.label, 'A1');
    expect(controller.frequency, closeTo(55, 0.2));
    expect(controller.inTune, isTrue);
  });

  test('microphone PCM reaches the tuner and stale readings expire', () async {
    await controller.toggleTuner();
    final detected = Completer<void>();
    final expired = Completer<void>();
    controller.addListener(() {
      if (controller.frequency != null && !detected.isCompleted) detected.complete();
      if (detected.isCompleted && controller.frequency == null && !expired.isCompleted) expired.complete();
    });
    final pcm = ByteData(tunerFrameSize * 2);
    for (var i = 0; i < tunerFrameSize; i++) {
      pcm.setInt16(i * 2, (16000 * math.sin(2 * math.pi * 110 * i / tunerSampleRate)).round(), Endian.little);
    }
    microphone.stream.add(pcm.buffer.asUint8List());
    await detected.future.timeout(const Duration(seconds: 5));
    expect(controller.frequency, closeTo(110, 0.2));
    expect(controller.target?.label, 'A2');
    expect(controller.inTune, isTrue);
    await expired.future.timeout(const Duration(seconds: 2));
    expect(controller.frequency, isNull);
    expect(controller.target, isNull);
    expect(controller.listening, isTrue);
  });

  for (final string in standardStrings.take(2)) {
    test('weak ${string.label} readings need agreement before selecting the string', () async {
      await controller.toggleTuner();
      final detected = Completer<void>();
      final random = math.Random(42);
      var framesSent = 0;
      int? firstDetectionFrame;
      controller.addListener(() {
        if (controller.frequency != null && !detected.isCompleted) {
          firstDetectionFrame = framesSent;
          detected.complete();
        }
      });
      final timer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
        final pcm = ByteData(tunerFrameSize * 2);
        for (var i = 0; i < tunerFrameSize; i++) {
          final phase = 2 * math.pi * string.frequency * (framesSent * tunerFrameSize + i) / tunerSampleRate;
          final sample = 0.006 * math.sin(phase) + 0.035 * (random.nextDouble() - 0.5);
          pcm.setInt16(i * 2, (sample * 32768).round(), Endian.little);
        }
        framesSent++;
        microphone.stream.add(pcm.buffer.asUint8List());
        if (framesSent == 4) timer.cancel();
      });
      addTearDown(timer.cancel);
      await detected.future.timeout(const Duration(seconds: 5));
      expect(firstDetectionFrame, greaterThanOrEqualTo(2));
      expect(controller.target, string);
    });
  }

  test('a short false lower pitch expires without changing the displayed string', () async {
    await controller.toggleTuner();
    final expired = Completer<void>();
    final readings = <double>[];
    controller.addListener(() {
      final pitch = controller.frequency;
      if (pitch != null) readings.add(pitch);
      if (readings.isNotEmpty && pitch == null && !expired.isCompleted) expired.complete();
    });
    const frequencies = [196.0, 196.0, 65.5, 65.5, 0.0];
    var framesSent = 0;
    final timer = Timer.periodic(const Duration(milliseconds: 180), (timer) {
      final pcm = ByteData(tunerFrameSize * 2);
      final pitch = frequencies[framesSent++];
      for (var i = 0; i < tunerFrameSize; i++) {
        pcm.setInt16(i * 2, (1600 * math.sin(2 * math.pi * pitch * i / tunerSampleRate)).round(), Endian.little);
      }
      microphone.stream.add(pcm.buffer.asUint8List());
      if (framesSent == frequencies.length) timer.cancel();
    });
    addTearDown(timer.cancel);
    await expired.future.timeout(const Duration(seconds: 4));
    expect(readings, isNotEmpty);
    expect(readings, everyElement(closeTo(196, 0.2)));
    expect(controller.target, isNull);
  });

  test('permission denial keeps the microphone off and allows retry', () async {
    microphone.permission = false;
    await controller.toggleTuner();
    expect(controller.listening, isFalse);
    expect(controller.error, contains('Microphone access'));
    microphone.permission = true;
    await controller.toggleTuner();
    expect(controller.error, isNull);
    expect(controller.listening, isTrue);
    await controller.suspend();
    expect(microphone.recording, isFalse);
  });

  test('leaving during the permission request cancels the eventual recording', () async {
    microphone.startGate = Completer<void>();
    final start = controller.toggleTuner();
    await Future<void>.delayed(Duration.zero);
    final stop = controller.suspend();
    microphone.startGate!.complete();
    await Future.wait([start, stop]);
    expect(microphone.recording, isFalse);
    expect(controller.listening, isFalse);
    expect(controller.busy, isFalse);
    controller.resume();
    expect(controller.listening, isFalse);
  });

  test('switching away during microphone startup never enables listening', () async {
    microphone.startGate = Completer<void>();
    final start = controller.toggleTuner();
    await Future<void>.delayed(Duration.zero);
    final switchTab = controller.selectTab(1);
    microphone.startGate!.complete();
    await Future.wait([start, switchTab]);
    expect(controller.tab, 1);
    expect(controller.listening, isFalse);
    expect(microphone.recording, isFalse);
  });

  test('audio failure clears playing state and can be retried', () async {
    await controller.selectTab(1);
    clicks.fail = true;
    await controller.toggleMetronome();
    expect(controller.playing, isFalse);
    expect(controller.error, isNotNull);
    clicks.fail = false;
    await controller.toggleMetronome();
    expect(controller.playing, isTrue);
    expect(controller.error, isNull);
    await controller.selectTab(0);
    expect(clicks.playing, isFalse);
  });

  test('switching tools stops an active microphone stream', () async {
    await controller.toggleTuner();
    expect(microphone.recording, isTrue);
    await controller.selectTab(1);
    expect(microphone.recording, isFalse);
    expect(controller.busy, isFalse);
  });

  test('backgrounding while playback starts releases the audio', () async {
    await controller.selectTab(1);
    clicks.startGate = Completer<void>();
    final start = controller.toggleMetronome();
    await Future<void>.delayed(Duration.zero);
    final stop = controller.suspend();
    clicks.startGate!.complete();
    await Future.wait([start, stop]);
    expect(clicks.playing, isFalse);
    expect(controller.playing, isFalse);
  });

  test('native audio focus loss stops the visual beat', () async {
    await controller.selectTab(1);
    await controller.toggleMetronome();
    clicks.events.add(2);
    await Future<void>.delayed(Duration.zero);
    expect(controller.beat, 2);
    clicks.events.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(controller.playing, isFalse);
    expect(controller.beat, isNull);
  });
}
