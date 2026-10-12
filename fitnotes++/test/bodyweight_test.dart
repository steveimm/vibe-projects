import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:fitnotes_plus/app/router.dart';
import 'package:fitnotes_plus/app/theme.dart';
import 'package:fitnotes_plus/core/database/database.dart';
import 'package:fitnotes_plus/core/database/tables.dart';
import 'package:fitnotes_plus/core/import/csv_importer.dart';
import 'package:fitnotes_plus/core/providers.dart';
import 'package:fitnotes_plus/core/repositories/exercise_repository.dart';
import 'package:fitnotes_plus/core/repositories/progress_repository.dart';
import 'package:fitnotes_plus/core/repositories/routine_repository.dart';
import 'package:fitnotes_plus/core/repositories/stats_repository.dart';
import 'package:fitnotes_plus/core/repositories/workout_repository.dart';
import 'package:fitnotes_plus/core/services/backup_service.dart';
import 'package:fitnotes_plus/core/util/dates.dart';
import 'package:fitnotes_plus/core/util/workout_analysis.dart';

Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  test('bodyweight is added after factors and captured for totals, edits, copies, routines, and data transfers', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final progress = ProgressRepository(db);
    final exercises = ExerciseRepository(db);
    final workouts = WorkoutRepository(db);
    final category = (await db.select(db.categories).get()).first.id;
    final bodyType = (await db.select(db.measurementTypes).get()).firstWhere((t) => t.name == 'Bodyweight');
    final id = await exercises.createExercise(
      name: 'Weighted pull-up',
      categoryId: category,
      type: ExerciseType.weightAndReps,
      includeBodyweight: const Value(true),
      multipliers: [(label: 'Pulley', factor: 0.5, enabled: true)],
    );
    await expectLater(workouts.addSet(exerciseId: id, date: '2026-10-10', rawWeight: 20, reps: 5), throwsFormatException);
    expect(await workouts.dayLog('2026-10-10'), isEmpty);
    await progress.saveMeasurement(bodyType.id, '2026-09-01', 75, '');
    await progress.saveMeasurement(bodyType.id, '2026-10-01', 80, '');
    await progress.saveMeasurement(bodyType.id, '2026-11-01', 100, 'Future');
    await progress.renameType(bodyType.id, 'My bodyweight');
    final setId = await workouts.addSet(exerciseId: id, date: '2026-10-10', rawWeight: 20, reps: 5);
    final first = (await workouts.dayLog('2026-10-10')).single;
    expect(first.set.rawWeight, 20);
    expect(first.set.bodyweight, 80);
    expect(first.effectiveWeight, 90);
    expect(Stats.graph([first.set], GraphMetric.workoutVolume).single.value, 450);
    expect(Stats.repMaxes([first.set])[5], 90);
    expect(
      WorkoutAnalysis.points(
        [first.set],
        WorkoutMetric.volume,
        from: '2026-10-01',
        to: '2026-10-10',
        now: DateTime(2026, 10, 10),
      ).single.value,
      450,
    );
    await progress.saveMeasurement(bodyType.id, '2026-10-08', 82, 'New weight');
    await workouts.addSet(exerciseId: id, date: '2026-10-10', rawWeight: 20, reps: 5);
    expect((await workouts.dayLog('2026-10-10')).map((s) => s.set.bodyweight), [80, 82]);
    await workouts.updateSet(setId, rawWeight: 30);
    expect((await workouts.dayLog('2026-10-10')).first.effectiveWeight, 95);
    await workouts.copySetsToDate([setId], '2026-10-12');
    final copied = (await workouts.dayLog('2026-10-12')).single.set;
    expect((copied.rawWeight, copied.bodyweight, copied.effectiveWeight), (30, 82, 97));
    final routines = RoutineRepository(db);
    final routine = await routines.fromWorkout('2026-10-10', 'Pull');
    final day = (await routines.watchDays(routine).first).single;
    await routines.logDay(day.id, '2026-10-13');
    expect((await workouts.dayLog('2026-10-13')).map((s) => s.set.rawWeight), [30, 20]);
    expect((await workouts.dayLog('2026-10-13')).map((s) => s.effectiveWeight), [97, 92]);
    final service = BackupService(db);
    final csv = utf8.decode(await service.csv());
    expect(parseCsv(csv)[1][3], '95');
    await CsvImporter(db).import(csv);
    expect(await workouts.dayLog('2026-10-10'), hasLength(2));
    final directory = Directory.systemTemp.createTempSync('bodyweight-backup-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final backup = File('${directory.path}/snapshot.fitnotesplus')..writeAsBytesSync(await service.backup(directory: directory));
    await db.delete(db.workoutSets).go();
    await service.restore(backup.path);
    expect((await exercises.getExercise(id)).includeBodyweight, isTrue);
    expect((await workouts.dayLog('2026-10-10')).map((s) => s.set.bodyweight), [80, 82]);
    expect((await workouts.dayLog('2026-10-10')).first.effectiveWeight, 95);
  });

  test('version 6 migration and restore keep prior weights with bodyweight disabled', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final exercise = (await db.select(db.exercises).get()).firstWhere((e) => e.type == ExerciseType.weightAndReps);
    await WorkoutRepository(db)
        .addSet(exerciseId: exercise.id, date: '2026-10-01', rawWeight: 20, weightMultiplier: 0.5, reps: 5);
    final directory = Directory.systemTemp.createTempSync('bodyweight-v6-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final service = BackupService(db);
    final file = File('${directory.path}/v6.fitnotesplus')..writeAsBytesSync(await service.backup(directory: directory));
    final raw = sqlite.sqlite3.open(file.path);
    raw.execute('ALTER TABLE exercises DROP COLUMN include_bodyweight');
    raw.execute('ALTER TABLE workout_sets DROP COLUMN bodyweight');
    raw.execute('ALTER TABLE workout_sets DROP COLUMN logged_at');
    raw.execute('ALTER TABLE pr_reset_markers DROP COLUMN initials');
    raw.execute('PRAGMA user_version = 6');
    raw.close();
    final migrated = AppDatabase(NativeDatabase(file.copySync('${directory.path}/migrate.sqlite')));
    addTearDown(migrated.close);
    expect((await migrated.select(migrated.exercises).get()).every((e) => !e.includeBodyweight), isTrue);
    expect((await migrated.select(migrated.workoutSets).get()).single.effectiveWeight, 10);
    await service.restore(file.path);
    expect((await db.select(db.workoutSets).get()).single.bodyweight, 0);
    expect((await db.select(db.workoutSets).get()).single.effectiveWeight, 10);
  });

  testWidgets('bodyweight setting is disabled without a record, adds a separate base, and keeps old sets unchanged', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase.memory();
    late int id, bodyType;
    await tester.runAsync(() async {
      final category = (await db.select(db.categories).get()).first.id;
      bodyType = (await db.select(db.measurementTypes).get()).first.id;
      id = await ExerciseRepository(db).createExercise(
        name: 'Pull-up',
        categoryId: category,
        type: ExerciseType.weightAndReps,
        multipliers: [(label: 'Pulley', factor: 0.5, enabled: true)],
      );
    });
    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    final router = createAppRouter(initialLocation: '/log/$id?date=${Dates.today()}');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await _flush(tester);
    await tester.tap(find.byTooltip('Edit exercise'));
    await _flush(tester);
    final setting = find.widgetWithText(SwitchListTile, 'Add bodyweight');
    expect(tester.widget<SwitchListTile>(setting).onChanged, isNull);
    await tester.runAsync(() => ProgressRepository(db).saveMeasurement(bodyType, Dates.today(), 80, ''));
    await _flush(tester);
    expect(tester.widget<SwitchListTile>(setting).onChanged, isNotNull);
    await tester.tap(find.text('Add bodyweight'));
    await tester.pump();
    await tester.tap(find.byTooltip('Save exercise'));
    await _flush(tester);
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, '0');
    await tester.enterText(find.byType(TextField).first, '20');
    await tester.enterText(find.byType(TextField).at(1), '5');
    await tester.pump();
    expect(find.text('× 0.5 (Pulley) + 80 kg (Bodyweight) = 90 kg'), findsOneWidget);
    await tester.tap(find.byTooltip('Log set'));
    await _flush(tester);
    expect(find.text('90 kg × 5 reps'), findsOneWidget);
    await tester.runAsync(() => ProgressRepository(db).saveMeasurement(bodyType, Dates.today(), 82, ''));
    await _flush(tester);
    expect(find.text('× 0.5 (Pulley) + 82 kg (Bodyweight) = 92 kg'), findsOneWidget);
    await tester.tap(find.text('90 kg × 5 reps'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, '20');
    expect(find.text('× 0.5 (Pulley) + 80 kg (Bodyweight) = 90 kg'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), '6');
    await tester.tap(find.byTooltip('Update set'));
    await _flush(tester);
    expect(find.text('90 kg × 6 reps'), findsOneWidget);
    await tester.runAsync(() async {
      final set = (await (db.select(db.workoutSets)..where((s) => s.exerciseId.equals(id))).get()).single;
      expect((set.rawWeight, set.bodyweight, set.weightMultiplier), (20, 80, 0.5));
    });
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    container.dispose();
    final closed = db.close();
    await _flush(tester);
    await closed;
  });
}
