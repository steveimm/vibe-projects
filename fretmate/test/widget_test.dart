import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fretmate/main.dart';
import 'package:fretmate/practice_controller.dart';

import 'audio_fakes.dart';

void main() {
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
    expect(find.text('Reference tone'), findsOneWidget);

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
    expect(find.text('Settle into rhythm.'), findsOneWidget);
    await tester.tap(find.byTooltip('Increase tempo'));
    await tester.pumpAndSettle();
    expect(find.text('101'), findsOneWidget);
    await tester.ensureVisible(find.text('3 beats'));
    await tester.tap(find.text('3 beats'));
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
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
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
