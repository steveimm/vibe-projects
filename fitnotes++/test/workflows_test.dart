import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:fitnotes_plus/core/database/database.dart';
import 'package:fitnotes_plus/core/database/tables.dart';
import 'package:fitnotes_plus/core/import/fitnotes_importer.dart';
import 'package:fitnotes_plus/core/repositories/exercise_repository.dart';
import 'package:fitnotes_plus/core/repositories/routine_repository.dart';
import 'package:fitnotes_plus/core/repositories/stats_repository.dart';
import 'package:fitnotes_plus/core/repositories/workout_repository.dart';
import 'package:fitnotes_plus/core/util/dates.dart';
import 'package:fitnotes_plus/core/util/format.dart';

void main() {
  late AppDatabase db;
  late WorkoutRepository workouts;
  late ExerciseRepository exercises;
  late Exercise bench;

  setUp(() async {
    db = AppDatabase.memory();
    workouts = WorkoutRepository(db);
    exercises = ExerciseRepository(db);
    bench = (await db.select(db.exercises).get()).firstWhere((e) => e.name == 'Flat Barbell Bench Press');
  });
  tearDown(() => db.close());

  test('version 1 upgrade preserves existing workout and settings', () async {
    final raw = sqlite.sqlite3.openInMemory();
    raw.execute(File('test/fixtures/v1_schema.sql').readAsStringSync());
    raw.execute("INSERT INTO categories (id,name) VALUES (1,'Chest')");
    raw.execute("INSERT INTO exercises (id,name,category_id) VALUES (1,'My press',1)");
    raw.execute("INSERT INTO workout_sets (exercise_id,date,raw_weight,reps,created_at) VALUES (1,'2026-01-01',40,8,1)");
    raw.execute('INSERT INTO app_settings (id,theme_mode) VALUES (1,2)');
    await db.close();
    db = AppDatabase(NativeDatabase.opened(raw));
    final migrated = db;
    final sets = await migrated.select(migrated.workoutSets).get();
    expect(sets.single.rawWeight, 40);
    expect(sets.single.isPlanned, false);
    expect((await migrated.select(migrated.exercises).get()).single.name, 'My press');
    expect((await migrated.select(migrated.appSettings).get()).single.themeMode, 2);
    expect((await migrated.select(migrated.measurementTypes).get()).length, 15);
    expect(await migrated.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });

  test('multipliers are snapshots and copied sets stay planned until completed', () async {
    await exercises.saveMultiplier(exerciseId: bench.id, label: 'Two dumbbells', factor: 2);
    final id = await workouts.addSet(exerciseId: bench.id, date: '2026-01-01', rawWeight: 20, reps: 8);
    final factor = (await exercises.watchMultipliers(bench.id).first).single;
    await exercises.saveMultiplier(id: factor.id, exerciseId: bench.id, label: factor.label, factor: 3);
    expect((await workouts.dayLog('2026-01-01')).single.effectiveWeight, 40);
    await workouts.copySetsToDate([id], '2026-01-02');
    final copy = (await workouts.dayLog('2026-01-02')).single.set;
    expect(copy.weightMultiplier, 3);
    expect(copy.isPlanned, true);
    expect(Stats.graph([copy], GraphMetric.workoutVolume), isEmpty);
    await workouts.setComplete(copy.id, true);
    expect(Stats.graph((await workouts.watchExerciseHistory(bench.id).first), GraphMetric.workoutVolume).last.value, 480);
  });

  test('routines use previous values, preserve order, and create planned sets', () async {
    await workouts.addSet(exerciseId: bench.id, date: '2026-01-01', rawWeight: 45, reps: 7);
    final routines = RoutineRepository(db);
    final id = await routines.create('Upper');
    final day = (await routines.watchDays(id).first).single;
    await routines.addExercise(day.id, bench.id);
    final sets = await routines.watchSets(day.id).first;
    await routines.updateSet(sets.first.id, const RoutineSetsCompanion(reps: Value(5)));
    expect(await routines.logDay(day.id, '2026-01-03'), 3);
    final logged = await workouts.dayLog('2026-01-03');
    expect(logged.map((s) => s.set.reps), [5, 7, 7]);
    expect(logged.every((s) => s.set.rawWeight == 45 && s.set.isPlanned), true);
    await routines.delete(id);
    expect(await db.select(db.routineSets).get(), isEmpty);
    expect((await workouts.dayLog('2026-01-03')).length, 3);
  });

  test('delete and undo restores the entire workout including notes', () async {
    await workouts.addSet(exerciseId: bench.id, date: '2026-02-01', rawWeight: 50, reps: 5);
    await workouts.saveDayNote('2026-02-01', 'Good energy');
    await workouts.startSession('2026-02-01');
    final snapshot = await workouts.deleteDay('2026-02-01');
    expect(await workouts.dayLog('2026-02-01'), isEmpty);
    await workouts.restoreDay(snapshot);
    expect((await workouts.dayLog('2026-02-01')).length, 1);
    expect((await workouts.watchDayNote('2026-02-01').first)?.comment, 'Good energy');
    expect(await workouts.watchSession('2026-02-01').first, isNotNull);
  });

  test('reimport is idempotent and merges the built-in exercise library', () async {
    final importer = FitNotesImporter(db);
    await importer.importFromFile('ref/FitNotes_Backup.fitnotes');
    await importer.importFromFile('ref/FitNotes_Backup.fitnotes');
    expect((await db.select(db.workoutSets).get()).length, 7560);
    expect((await db.select(db.exercises).get()).length, 180);
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });

  test('invalid input cannot be saved and recorded exercise types cannot change', () async {
    expect(() => workouts.addSet(exerciseId: bench.id, date: '2026-02-31', reps: 5), throwsFormatException);
    expect(() => workouts.addSet(exerciseId: bench.id, date: '2026-02-01', reps: 0), throwsFormatException);
    expect(
      () => workouts.addSet(exerciseId: bench.id, date: '2026-02-01', rawWeight: double.nan, reps: 5),
      throwsFormatException,
    );
    await workouts.addSet(exerciseId: bench.id, date: '2026-02-01', rawWeight: 30, reps: 10);
    expect(
      () => exercises.updateExercise(id: bench.id, name: bench.name, categoryId: bench.categoryId, type: ExerciseType.timeOnly),
      throwsFormatException,
    );
  });

  test('cardio permits time-only intervals from original backups but rejects empty intervals', () async {
    final cardio = (await db.select(db.exercises).get()).firstWhere((e) => e.type == ExerciseType.distanceAndTime);
    final id = await workouts.addSet(exerciseId: cardio.id, date: '2026-01-01', durationSeconds: 1800);
    await workouts.updateSet(id, durationSeconds: 1900);
    expect((await workouts.dayLog('2026-01-01')).single.set.durationSeconds, 1900);
    await expectLater(workouts.addSet(exerciseId: cardio.id, date: '2026-01-01'), throwsFormatException);
    final history = await workouts.watchExerciseHistory(cardio.id).first;
    expect(Stats.graph(history, GraphMetric.maxSpeed), isEmpty);
    expect(Stats.graph(history, GraphMetric.maxDistance), isEmpty);
    expect(Stats.personalRecordSetIds(history, type: cardio.type), {id});
    expect(Stats.graph(history, GraphMetric.totalTime).single.value, 1900);
  });

  test('planned sets do not count as performed workouts in the library', () async {
    await workouts.addSet(exerciseId: bench.id, date: '2026-01-01', rawWeight: 30, reps: 10, planned: true);
    final items = await exercises.watchExercises(search: bench.name).first;
    expect(items.single.workoutCount, 0);
    expect(items.single.lastDate, null);
  });

  test('units and durations round trip and dates use calendar days', () {
    const units = Units(true);
    expect(units.weightToKg(units.weightFromKg(42.5)), closeTo(42.5, 0.000001));
    expect(units.distanceToMeters(units.distanceFromMeters(5000)), closeTo(5000, 0.000001));
    expect(Fmt.parseDuration('1:02:03'), 3723);
    expect(Fmt.parseDuration('1:60'), isNull);
    expect(Fmt.number(100), '100');
    expect(Fmt.number(0), '0');
    expect(Dates.daysBetween('2026-03-07', '2026-03-09'), 2);
  });
}
