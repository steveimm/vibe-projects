import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitnotes_plus/core/database/database.dart';
import 'package:fitnotes_plus/core/providers.dart';
import 'package:fitnotes_plus/core/repositories/workout_repository.dart';
import 'package:fitnotes_plus/core/util/dates.dart';
import 'package:fitnotes_plus/main.dart';

void main() {
  // Boot the real app with the DB-backed providers overridden by synchronous
  // streams — keeps the widget test free of Drift/FakeAsync flakiness.
  testWidgets('App boots into an empty Workout Log with Monday first even with a legacy Sunday preference', (tester) async {
    final semantics = tester.ensureSemantics();
    final settings = AppSettingsRow(
      id: 1,
      themeMode: 0,
      firstDayOfWeek: 7,
      defaultWeightIncrement: 2.5,
      restTimerSeconds: 60,
      restTimerVibrate: false,
      restTimerSound: true,
      restTimerAutoStart: false,
      trackPersonalRecords: true,
      markSetsComplete: false,
      keepScreenOn: false,
      estimated1rmMaxReps: 0,
      useImperial: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => Stream.value(settings)),
          dayLogProvider(Dates.today()).overrideWith((ref) => Stream.value(const <LoggedSet>[])),
          allLogProvider.overrideWith((ref) => Stream.value(const <LoggedSet>[])),
          dayNoteProvider(Dates.today()).overrideWith((ref) => Stream.value(null)),
          sessionProvider(Dates.today()).overrideWith((ref) => Stream.value(null)),
        ],
        child: const FitNotesApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('FitNotes++'), findsNothing);
    expect(find.text('Workout time'), findsOneWidget);
    expect(find.byTooltip('Start'), findsOneWidget);
    expect(find.text('Routines'), findsOneWidget);
    expect(MaterialLocalizations.of(tester.element(find.text('Today'))).firstDayOfWeekIndex, DateTime.monday);
    expect(
      tester.getCenter(find.bySemanticsLabel(RegExp(r'^Monday,')).hitTestable()).dx,
      lessThan(tester.getCenter(find.bySemanticsLabel(RegExp(r'^Sunday,')).hitTestable()).dx),
    );
    semantics.dispose();
  });
}
