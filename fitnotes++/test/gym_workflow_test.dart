import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:fitnotes_plus/app/theme.dart';
import 'package:fitnotes_plus/core/database/database.dart';
import 'package:fitnotes_plus/core/providers.dart';
import 'package:fitnotes_plus/core/repositories/progress_repository.dart';
import 'package:fitnotes_plus/core/repositories/workout_repository.dart';
import 'package:fitnotes_plus/core/services/rest_timer.dart';
import 'package:fitnotes_plus/core/util/dates.dart';
import 'package:fitnotes_plus/features/progress/progress_screen.dart';
import 'package:fitnotes_plus/features/track/exercise_detail_screen.dart';
import 'package:fitnotes_plus/shared/progress_chart.dart';

Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void _viewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('gym logging keeps controls stable, edits without extra sets, and rest disappears', (tester) async {
    _viewport(tester);
    final db = AppDatabase.memory();
    final repo = WorkoutRepository(db);
    late int exerciseId;
    final ids = <int>[];
    await tester.runAsync(() async {
      exerciseId = (await db.select(db.exercises).get()).firstWhere((e) => e.name == 'Flat Barbell Bench Press').id;
      await db.update(db.appSettings).write(const AppSettingsCompanion(restTimerAutoStart: Value(true)));
      for (var i = 0; i < 7; i++) {
        ids.add(await repo.addSet(exerciseId: exerciseId, date: Dates.today(), rawWeight: 60, reps: 8));
      }
    });
    var now = DateTime.now();
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db), restClockProvider.overrideWithValue(() => now)],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: ExerciseDetailScreen(exerciseId: exerciseId, date: Dates.today()),
        ),
      ),
    );
    await _flush(tester);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('RPE'), findsNothing);
    final last = find.byKey(ValueKey('logged-set-${ids.last}'));
    expect(tester.getBottomRight(last).dy, lessThan(740));
    expect(tester.getSize(last).height, lessThanOrEqualTo(52));
    final addPosition = tester.getCenter(find.byTooltip('Log set'));
    await tester.tap(find.byKey(ValueKey('logged-set-${ids.first}')));
    await tester.pump();
    expect(find.byTooltip('Delete set'), findsOneWidget);
    expect(find.byTooltip('Cancel editing'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Log set'), findsOneWidget);
    expect(find.byType(ExerciseDetailScreen), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('logged-set-${ids.first}')));
    await tester.pump();
    expect(tester.getCenter(find.byTooltip('Update set')), addPosition);
    await tester.enterText(find.byType(TextField).at(1), '9');
    await tester.tap(find.byKey(ValueKey('logged-set-${ids.first}')));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text, '9');
    await tester.tap(find.byTooltip('Update set'));
    await _flush(tester);
    List<LoggedSet>? saved;
    unawaited(repo.dayLog(Dates.today()).then((value) => saved = value));
    await _flush(tester);
    expect(saved!.length, 7);
    expect(saved!.first.set.reps, 9);
    expect(saved!.first.set.loggedAt, isNotNull);
    expect(find.text(DateFormat.Hm().format(saved!.first.set.loggedAt!.toLocal())), findsWidgets);
    expect(find.byType(SnackBar), findsNothing);
    await tester.tap(find.byTooltip('Log set'));
    await _flush(tester);
    expect(container.read(restTimerProvider).status, RestStatus.running);
    expect(find.byType(SnackBar), findsNothing);
    unawaited(repo.dayLog(Dates.today()).then((value) => saved = value));
    await _flush(tester);
    expect(saved, hasLength(8));
    await tester.tap(find.byKey(ValueKey('logged-set-${ids[1]}')));
    await tester.pump();
    await tester.tap(find.byTooltip('Delete set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Update set'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await _flush(tester);
    expect(find.byKey(ValueKey('logged-set-${ids[1]}')), findsNothing);
    expect(find.byTooltip('Log set'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pump();
    expect(tester.getBottomRight(find.byTooltip('Log set')).dy, lessThan(460));
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    now = now.add(const Duration(seconds: 61));
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(restTimerProvider).visible, false);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('History'));
    await _flush(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Log'));
    await _flush(tester);
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.view.physicalSize = const Size(640, 240);
    await tester.pump();
    await tester.ensureVisible(last);
    await tester.pump();
    expect(tester.getBottomRight(last).dy, lessThanOrEqualTo(240));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    final closed = db.close();
    await _flush(tester);
    await closed;
  });

  testWidgets('completing a copied set makes its values available for the next set', (tester) async {
    _viewport(tester);
    final db = AppDatabase.memory();
    final repo = WorkoutRepository(db);
    late int exerciseId;
    await tester.runAsync(() async {
      exerciseId = (await db.select(db.exercises).get()).firstWhere((e) => e.name == 'Flat Barbell Bench Press').id;
      await repo.addSet(exerciseId: exerciseId, date: Dates.shift(Dates.today(), -1), rawWeight: 70, reps: 8);
      await repo.addSet(exerciseId: exerciseId, date: Dates.today(), rawWeight: 50, reps: 6, planned: true);
    });
    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: ExerciseDetailScreen(exerciseId: exerciseId, date: Dates.today()),
        ),
      ),
    );
    await _flush(tester);
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, '70');
    await tester.tap(find.byType(Checkbox));
    await _flush(tester);
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, '50');
    expect(tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text, '6');
    await tester.tap(find.byTooltip('Log set'));
    await _flush(tester);
    List<LoggedSet>? saved;
    unawaited(repo.dayLog(Dates.today()).then((value) => saved = value));
    await _flush(tester);
    expect(saved!.length, 2);
    expect(saved!.every((s) => s.set.rawWeight == 50 && s.set.reps == 6 && !s.set.isPlanned), true);
    expect(find.byType(SnackBar), findsNothing);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    final closed = db.close();
    await _flush(tester);
    await closed;
  });

  testWidgets('measurement overview shows all graphs and recording today edits the existing entry', (tester) async {
    _viewport(tester);
    final db = AppDatabase.memory();
    final repo = ProgressRepository(db);
    await tester.runAsync(() async {
      await db.select(db.measurementTypes).get();
      await repo.saveMeasurement(1, Dates.shift(Dates.today(), -7), 76, '');
      await repo.saveMeasurement(1, Dates.today(), 75, 'After breakfast');
      await repo.saveMeasurement(2, Dates.today(), 18, '');
    });
    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light, home: const ProgressScreen()),
      ),
    );
    await _flush(tester);
    for (final label in ['1m', '3m', '6m', 'All']) {
      expect(tester.getCenter(find.text(label)).dy, tester.getCenter(find.text('1m')).dy);
    }
    expect(tester.getCenter(find.byTooltip('Custom range')).dy, tester.getCenter(find.text('1m')).dy);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.pump();
    expect(find.text('All'), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Measurements'));
    await _flush(tester);
    expect(find.byType(ProgressChart), findsNWidgets(2));
    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
    await tester.tap(find.byTooltip('Record Bodyweight'));
    await _flush(tester);
    expect(tester.widget<TextFormField>(find.byType(TextFormField).first).controller!.text, '75');
    expect(find.text('After breakfast'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '74.5');
    await tester.tap(find.text('Save'));
    await _flush(tester);
    List<Measurement>? saved;
    unawaited(repo.watchMeasurements(1).first.then((value) => saved = value));
    await _flush(tester);
    expect(saved!.length, 2);
    expect(saved!.first.value, 74.5);
    expect(saved!.first.note, 'After breakfast');
    await tester.tap(find.byTooltip('Record Bodyweight'));
    await _flush(tester);
    await tester.tap(find.text(Dates.today()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to input'));
    await tester.pumpAndSettle();
    final dateField = find.descendant(of: find.byType(DatePickerDialog), matching: find.byType(TextField));
    final yesterday = Dates.shift(Dates.today(), -1);
    await tester.enterText(dateField, DateFormat('MM/dd/yyyy').format(Dates.parse(yesterday)));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '74.8');
    await tester.tap(find.text('Save'));
    await _flush(tester);
    unawaited(repo.watchMeasurements(1).first.then((value) => saved = value));
    await _flush(tester);
    expect(saved!.length, 3);
    expect(saved!.first.date, Dates.today());
    expect(saved!.first.value, 74.5);
    expect(saved![1].date, yesterday);
    expect(saved![1].value, 74.8);

    expect(find.byType(ProgressChart), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    final closed = db.close();
    await _flush(tester);
    await closed;
  });
}
