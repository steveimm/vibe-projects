import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fretmate/main.dart';
import 'package:fretmate/practice_controller.dart';

import 'audio_fakes.dart';

void main() {
  testWidgets('metronome fits phone screens with six beats and no extra copy or volume slider', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = PracticeController(microphone: FakeMicrophone(), clicks: FakeClicks());
    addTearDown(controller.dispose);
    await controller.selectTab(1);
    controller.setBeats(6);
    for (final size in [const Size(320, 740), const Size(360, 740), const Size(360, 791)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(FretmateApp(controller: controller));
      await tester.pumpAndSettle();
      final scroll = tester.state<ScrollableState>(
        find.descendant(of: find.byKey(const PageStorageKey('tool-scroll-1')), matching: find.byType(Scrollable)),
      );
      expect(scroll.position.maxScrollExtent, 0, reason: '$size');
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('BPM'), findsOneWidget);
      expect(find.text('beats per minute'), findsNothing);
      expect(tester.widget<Slider>(find.byType(Slider)).min, 20);
      expect(tester.widget<Slider>(find.byType(Slider)).max, 300);
      expect(find.text('Settle into rhythm.'), findsNothing);
      expect(find.text('Make every beat count.'), findsNothing);
      expect(find.text('Tap twice or more to set your pace.'), findsNothing);
      expect(find.text('Use your phone’s media volume to adjust the speaker level.'), findsNothing);
      final start = find.byKey(const ValueKey('metronome-button'));
      expect(start.hitTestable(), findsOneWidget);
      expect(tester.getRect(start).bottom, closeTo(size.height - 16, 0.1));
      expect(find.text('Tap tempo').hitTestable(), findsOneWidget);
      expect(find.byKey(const ValueKey('beats-6')).hitTestable(), findsOneWidget);
      expect(find.byType(SwitchListTile).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('swipes and tab taps stay synchronized and stop the tool being left', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final microphone = FakeMicrophone();
    final clicks = FakeClicks();
    final controller = PracticeController(microphone: microphone, clicks: clicks);
    addTearDown(controller.dispose);
    await tester.pumpWidget(FretmateApp(controller: controller));
    await tester.tap(find.byKey(const ValueKey('listen-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('string-6')));
    await tester.pumpAndSettle();
    final pages = find.byKey(const ValueKey('tool-pages'));
    await tester.dragFrom(tester.getTopLeft(pages) + const Offset(280, 24), const Offset(-280, 0));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(controller.tab, 1);
    expect(microphone.recording, isFalse);
    expect(clicks.activeTone, isNull);
    expect(find.text('Tap tempo'), findsOneWidget);
    await tester.ensureVisible(find.text('Start metronome'));
    await tester.tap(find.text('Start metronome'));
    await tester.pumpAndSettle();
    expect(clicks.playing, isTrue);
    await tester.dragFrom(tester.getTopLeft(pages) + const Offset(80, 24), const Offset(280, 0));
    await tester.pumpAndSettle();
    expect(controller.tab, 0);
    expect(clicks.playing, isFalse);
    expect(find.byKey(const ValueKey('listen-button')).hitTestable(), findsOneWidget);
    await tester.tap(find.text('Metronome'));
    await tester.pumpAndSettle();
    expect(controller.tab, 1);
    await tester.tap(find.text('Tuner'));
    await tester.pumpAndSettle();
    expect(controller.tab, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('slider drags and reversed tab taps do not leave the wrong page selected', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = PracticeController(microphone: FakeMicrophone(), clicks: FakeClicks());
    addTearDown(controller.dispose);
    await tester.pumpWidget(FretmateApp(controller: controller));
    await tester.tap(find.text('Metronome'));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.text('Tuner'));
    await tester.pumpAndSettle();
    expect(controller.tab, 0);
    expect(find.byKey(const ValueKey('listen-button')).hitTestable(), findsOneWidget);
    await tester.tap(find.text('Metronome'));
    await tester.pumpAndSettle();
    final slider = find.byType(Slider).first;
    await tester.ensureVisible(slider);
    final previousTempo = controller.bpm;
    await tester.drag(slider, const Offset(70, 0));
    await tester.pumpAndSettle();
    expect(controller.bpm, isNot(previousTempo));
    expect(controller.tab, 1);
    expect(tester.takeException(), isNull);
  });

  for (final listening in [false, true]) {
    testWidgets('reference startup and switching keep ${listening ? 'Stop' : 'Listen'} unchanged', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final clicks = FakeClicks();
      final controller = PracticeController(microphone: FakeMicrophone(), clicks: clicks);
      addTearDown(controller.dispose);
      if (listening) await controller.toggleTuner();
      await tester.pumpWidget(FretmateApp(controller: controller));
      final button = find.byKey(const ValueKey('listen-button'));
      final label = listening ? 'Stop' : 'Listen';
      void expectStableButton() {
        expect(find.text(label), findsOneWidget);
        expect(find.text('Please wait…'), findsNothing);
        expect(find.text('Reference tone'), findsNothing);
        expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      }

      clicks.toneGate = Completer<void>();
      await tester.tap(find.byKey(const ValueKey('string-6')));
      await tester.pump();
      expectStableButton();
      clicks.toneGate!.complete();
      await tester.pumpAndSettle();
      clicks.stopGate = Completer<void>();
      await tester.tap(find.byKey(const ValueKey('string-1')));
      await tester.pump();
      expectStableButton();
      expect(clicks.tones.length, 2);
      await tester.pump(const Duration(milliseconds: 300));
      expectStableButton();
      clicks.stopGate!.complete();
      await tester.pumpAndSettle();
      expectStableButton();
      expect(clicks.tones.length, 2);
    });
  }

  testWidgets('tuner selection, listening, navigation and metronome controls', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final microphone = FakeMicrophone();
    final clicks = FakeClicks();
    final controller = PracticeController(microphone: microphone, clicks: clicks);
    addTearDown(controller.dispose);
    await tester.pumpWidget(FretmateApp(controller: controller));

    expect(find.text('Standard tuning'), findsOneWidget);
    expect(microphone.starts, 0);
    expect(clicks.starts, 0);
    await tester.tap(find.byKey(const ValueKey('string-6')));
    await tester.pumpAndSettle();
    expect(controller.selectedString?.label, 'E2');
    expect(clicks.tones.single.frequency, closeTo(82.4069, 0.001));
    expect(controller.referencePlaying, isTrue);
    expect(find.text('Reference tone'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('listen-button')));
    await tester.pumpAndSettle();
    expect(microphone.recording, isTrue);
    expect(find.text('Stop'), findsOneWidget);
    await tester.tap(find.text('Auto'));
    await tester.pumpAndSettle();
    expect(controller.selectedString, isNull);

    await tester.tap(find.text('Metronome'));
    await tester.pumpAndSettle();
    // Broadcast stream cancellation completes outside the widget test clock.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(controller.tab, 1);
    expect(controller.busy, isFalse);
    expect(microphone.recording, isFalse);
    expect(find.text('Tap tempo'), findsOneWidget);
    await tester.tap(find.byTooltip('Increase tempo'));
    await tester.pumpAndSettle();
    expect(find.text('101'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('beats-3')));
    await tester.tap(find.byKey(const ValueKey('beats-3')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start metronome'));
    await tester.tap(find.text('Start metronome'));
    await tester.pumpAndSettle();
    expect(clicks.settings, (bpm: 101, beats: 3, accent: true, volume: 0.7));
    expect(clicks.playing, isTrue);
    await tester.tap(find.text('Tuner'));
    await tester.pumpAndSettle();
    expect(clicks.playing, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small screen and enlarged text remain scrollable', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = PracticeController(microphone: FakeMicrophone(), clicks: FakeClicks());
    addTearDown(controller.dispose);
    await tester.pumpWidget(FretmateApp(controller: controller));
    await tester.ensureVisible(find.byKey(const ValueKey('listen-button')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Metronome'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start metronome'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone tuner fits without scrolling with strings around the centre panel', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = PracticeController(microphone: FakeMicrophone(), clicks: FakeClicks());
    addTearDown(controller.dispose);
    await tester.pumpWidget(FretmateApp(controller: controller));

    final panel = tester.getRect(find.byKey(const ValueKey('detection-panel')));
    final meter = tester.getRect(find.byKey(const ValueKey('pitch-meter')));
    final listen = tester.getRect(find.byKey(const ValueKey('listen-button')));
    final tabs = tester.getRect(find.byKey(const ValueKey('tool-tabs')));
    expect(tabs.bottom, lessThan(panel.top));
    expect(panel.bottom, lessThan(meter.top));
    expect(meter.bottom, lessThan(listen.top));
    expect(meter.left, 16);
    expect(meter.right, 344);
    expect(meter.height, closeTo(meter.width / 2 + 4, 0.1));
    expect(find.byTooltip('About Fretmate'), findsNothing);
    expect(find.byIcon(Icons.info_outline_rounded), findsNothing);
    expect(find.byType(AboutDialog), findsNothing);
    expect(find.byType(LicensePage), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(SegmentedButton<int>), findsNothing);
    expect(find.text('Pluck one string. Tap a note to lock it.'), findsNothing);
    expect(find.text('A4 = 440 Hz'), findsNothing);
    expect(find.text('EADGBE'), findsOneWidget);
    expect(find.text('Flat'), findsNothing);
    expect(find.text('Sharp'), findsNothing);
    expect(find.text('Ready'), findsNothing);
    expect(tester.widget(find.byKey(const ValueKey('detection-panel'))), isA<Padding>());
    expect(panel.height, greaterThanOrEqualTo(304));
    expect(listen.bottom, closeTo(724, 0.1));

    for (final column in [
      [4, 5, 6],
      [3, 2, 1],
    ]) {
      double? previousBottom;
      for (final number in column) {
        final box = tester.getRect(find.byKey(ValueKey('string-card-$number')));
        if (number >= 4) {
          expect(box.right, lessThan(panel.left));
        } else {
          expect(box.left, greaterThan(panel.right));
        }
        if (previousBottom != null) expect(box.top - previousBottom, closeTo(8, 0.1));
        expect(box.width, greaterThanOrEqualTo(48));
        expect(box.height, greaterThanOrEqualTo(48));
        expect(box.bottom, lessThan(meter.top));
        for (final direction in ['up', 'down']) {
          final arrow = tester.getRect(find.byKey(ValueKey('string-$number-$direction')));
          expect(arrow.width, greaterThanOrEqualTo(48));
          expect(arrow.height, greaterThanOrEqualTo(48));
        }
        previousBottom = box.bottom;
      }
    }
    final scroll = tester.state<ScrollableState>(
      find.descendant(of: find.byKey(const PageStorageKey('tool-scroll-0')), matching: find.byType(Scrollable)),
    );
    expect(scroll.position.maxScrollExtent, 0);

    tester.view.physicalSize = const Size(360, 840);
    await tester.pumpAndSettle();
    final tallerPanel = tester.getRect(find.byKey(const ValueKey('detection-panel')));
    expect(tallerPanel.height, closeTo(panel.height + 100, 0.1));
    expect(tester.getRect(find.byKey(const ValueKey('listen-button'))).bottom, closeTo(824, 0.1));
    expect(scroll.position.maxScrollExtent, 0);

    controller.frequency = 82.4069;
    controller.selectString(null);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const ValueKey('detection-panel'))), tallerPanel);
    expect(find.text('82.4 Hz'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow and landscape layouts keep controls reachable', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = PracticeController(microphone: FakeMicrophone(), clicks: FakeClicks());
    addTearDown(controller.dispose);
    for (final size in [const Size(320, 740), const Size(740, 360)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(FretmateApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('listen-button')));
      await tester.pumpAndSettle();
      final listen = tester.getRect(find.byKey(const ValueKey('listen-button')));
      expect(listen.top, greaterThanOrEqualTo(0));
      expect(listen.bottom, lessThanOrEqualTo(size.height));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('microphone errors can scroll without overflowing the tuner', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final microphone = FakeMicrophone()..permission = false;
    final controller = PracticeController(microphone: microphone, clicks: FakeClicks());
    addTearDown(controller.dispose);
    await tester.pumpWidget(FretmateApp(controller: controller));
    await tester.tap(find.byKey(const ValueKey('listen-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Microphone access is needed'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('listen-button')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('preset dropdown and semitone arrows update notes and recognize tunings', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = PracticeController(microphone: FakeMicrophone(), clicks: FakeClicks());
    addTearDown(controller.dispose);
    await tester.pumpWidget(FretmateApp(controller: controller));
    await tester.tap(find.byKey(const ValueKey('string-6-down')));
    await tester.pumpAndSettle();
    expect(controller.strings.first.label, 'D♯2');
    expect(find.text('Custom'), findsOneWidget);
    expect(controller.selectedString, isNull);
    await tester.tap(find.byKey(const ValueKey('string-6-down')));
    await tester.pumpAndSettle();
    expect(find.text('Drop D'), findsOneWidget);
    expect(find.text('DADGBE'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('string-6')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('string-6-up')));
    await tester.pumpAndSettle();
    expect(controller.selectedString?.label, 'D♯2');
    await tester.tap(find.byKey(const ValueKey('string-6-up')));
    await tester.pumpAndSettle();
    expect(find.text('Standard tuning'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tuning-selector')));
    await tester.pumpAndSettle();
    final dropC = find.byKey(const ValueKey('tuning-Drop C'));
    await tester.ensureVisible(dropC);
    await tester.tap(dropC);
    await tester.pumpAndSettle();
    expect(find.text('Drop C'), findsOneWidget);
    expect(find.text('CGCFAD'), findsOneWidget);
    expect(controller.selectedString?.label, 'C2');
    expect(tester.takeException(), isNull);
  });
}
