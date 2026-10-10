import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:fitnotes_plus/app/theme.dart';
import 'package:fitnotes_plus/core/database/database.dart';
import 'package:fitnotes_plus/core/providers.dart';
import 'package:fitnotes_plus/core/repositories/workout_repository.dart';
import 'package:fitnotes_plus/core/util/dates.dart';
import 'package:fitnotes_plus/features/workout_log/home_screen.dart';
import 'package:fitnotes_plus/features/workout_log/workout_day_dots.dart';
import 'package:fitnotes_plus/features/workout_log/workout_session_card.dart';
import 'package:fitnotes_plus/features/workout_log/workout_week_strip.dart';

void main() {
  testWidgets('Android fractional text scaling keeps the pinned workout toolbar and list visible', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => const Stream.empty()),
          allLogProvider.overrideWith((ref) => Stream.value([])),
          dayLogProvider.overrideWith((ref, date) => Stream.value([])),
          dayNoteProvider.overrideWith((ref, date) => Stream.value(null)),
          sessionProvider.overrideWith((ref, date) => Stream.value(null)),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const _AndroidTextScale()),
            child: child!,
          ),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final toolbar = find.byKey(const ValueKey('workout-list-toolbar'));
    expect(tester.getSize(toolbar).height, 64);
    expect(find.byTooltip('Add exercise').hitTestable(), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('changing the selected day keeps the home heading, week, and summary in place', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final logged = LoggedSet(
      set: WorkoutSet(
        id: 1,
        exerciseId: 1,
        date: Dates.today(),
        rawWeight: 60,
        weightMultiplier: 1,
        reps: 8,
        distance: 0,
        durationSeconds: 0,
        isComplete: true,
        createdAt: DateTime.now(),
        isPlanned: false,
      ),
      exerciseName: 'Bench press',
      colorArgb: 0xFFC0392B,
      exerciseType: 0,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => const Stream.empty()),
          allLogProvider.overrideWith((ref) => Stream.value([logged])),
          dayLogProvider.overrideWith((ref, date) => Stream.value(date == logged.set.date ? [logged] : [])),
          prSetIdsProvider.overrideWith((ref, id) => <int>{}),
          dayNoteProvider.overrideWith((ref, date) => Stream.value(null)),
          sessionProvider.overrideWith((ref, date) => Stream.value(null)),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    final headingSize = tester.getSize(find.text('Today'));
    final weekTop = tester.getTopLeft(find.byType(WorkoutWeekStrip)).dy;
    final cardTop = tester.getTopLeft(find.byType(WorkoutSessionCard)).dy;
    final fontSize = tester.widget<Text>(find.text('Today')).style!.fontSize;
    for (final date in [Dates.shift(Dates.today(), -1), '2025-12-31', Dates.today()]) {
      container.read(selectedDateProvider.notifier).set(date);
      await tester.pumpAndSettle();
      final heading = date == Dates.today()
          ? 'Today'
          : DateFormat(Dates.parse(date).year == DateTime.now().year ? 'EEE, d MMM' : 'EEE, d MMM yyyy')
                .format(Dates.parse(date));
      expect(tester.getSize(find.text(heading)).height, headingSize.height);
      expect(tester.widget<Text>(find.text(heading)).style!.fontSize, fontSize);
      expect(tester.getTopLeft(find.byType(WorkoutWeekStrip)).dy, weekTop);
      expect(tester.getTopLeft(find.byType(WorkoutSessionCard)).dy, cardTop);
      expect(tester.takeException(), isNull);
    }
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('01'),
      200,
      scrollable: find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('60 kg × 8 reps')).left - tester.getRect(find.text('01')).right, greaterThanOrEqualTo(12));
    expect(tester.takeException(), isNull);
  });

  testWidgets('week swipes cross year boundaries and calendar selections keep the pager synchronized', (tester) async {
    var date = '2026-12-31';
    var weekStart = 1;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return WorkoutWeekStrip(
                date: date,
                firstDayOfWeek: weekStart,
                dayColors: const {
                  '2026-12-31': [0xFFC0392B, 0xFF2980B9, 0xFF54B2B6],
                },
                onSelectDay: (value) => setState(() => date = value),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final marks = tester.widgetList<WorkoutDayDots>(find.byType(WorkoutDayDots)).where((dots) => dots.colors.isNotEmpty).single;
    expect(marks.colors, [0xFFC0392B, 0xFF2980B9, 0xFF54B2B6]);
    expect(tester.getSize(find.byType(WorkoutWeekStrip)).height, lessThan(65));
    await tester.fling(find.byType(WorkoutWeekStrip), const Offset(-650, 0), 1200);
    await tester.pumpAndSettle();
    expect(date, '2027-01-07');
    await tester.fling(find.byType(WorkoutWeekStrip), const Offset(650, 0), 1200);
    await tester.pumpAndSettle();
    expect(date, '2026-12-31');
    update(() => date = '2025-02-05');
    await tester.pumpAndSettle();
    await tester.fling(find.byType(WorkoutWeekStrip), const Offset(-650, 0), 1200);
    await tester.pumpAndSettle();
    expect(date, '2025-02-12');
    update(() => weekStart = 7);
    await tester.pumpAndSettle();
    await tester.tap(find.text('9'));
    await tester.pumpAndSettle();
    expect(date, '2025-02-09');
    expect(tester.takeException(), isNull);
  });

  testWidgets('timer controls stay beside the duration on narrow screens and at large text sizes', (tester) async {
    for (final width in [320.0, 390.0]) {
      for (final scale in [1.0, 2.0]) {
        final now = DateTime.now();
        final session = WorkoutSession(date: Dates.today(), startedAt: now, runningSince: now, elapsedSeconds: 86399);
        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey('$width-$scale'),
            overrides: [
              settingsProvider.overrideWith((ref) => const Stream.empty()),
              sessionProvider.overrideWith((ref, date) => Stream.value(session)),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: width,
                    child: MediaQuery(
                      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: WorkoutSessionCard(date: Dates.today(), sets: const []),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final finish = find.byTooltip('Finish').evaluate().isNotEmpty
            ? find.byTooltip('Finish')
            : find.widgetWithText(TextButton, 'Finish');
        final pause = find.byTooltip('Pause').evaluate().isNotEmpty
            ? find.byTooltip('Pause')
            : find.widgetWithText(TextButton, 'Pause');
        final duration = find.byKey(const ValueKey('workout-duration'));
        expect(tester.getCenter(find.byTooltip('Workout timer options')).dy, closeTo(tester.getCenter(duration).dy, 0.1));
        expect(tester.getCenter(finish).dy, closeTo(tester.getCenter(duration).dy, 0.1));
        expect(tester.getCenter(pause).dy, closeTo(tester.getCenter(duration).dy, 0.1));
        if (scale == 1) expect(tester.getSize(find.byType(WorkoutSessionCard)).height, lessThan(160));
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _AndroidTextScale extends TextScaler {
  const _AndroidTextScale();
  @override
  double scale(double fontSize) => fontSize == 16 ? 24.000000762939453 : fontSize * 1.6;
  @override
  double get textScaleFactor => 1.6;
}
