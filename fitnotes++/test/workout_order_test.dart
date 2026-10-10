import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:fitnotes_plus/core/database/database.dart';
import 'package:fitnotes_plus/core/repositories/workout_repository.dart';
import 'package:fitnotes_plus/core/services/backup_service.dart';

List<int> order(List<LoggedSet> sets) => sets.map((s) => s.set.exerciseId).toSet().toList();

void main() {
  test('exercise order persists per day, survives reopening, and carries into copied workouts', () async {
    final folder = Directory.systemTemp.createTempSync('fitnotes-order-');
    addTearDown(() => folder.deleteSync(recursive: true));
    final file = File('${folder.path}/workout.sqlite');
    var db = AppDatabase(NativeDatabase(file));
    var repo = WorkoutRepository(db);
    final exercises = (await db.select(db.exercises).get())
        .where((e) => ['Barbell Curl', 'Barbell Row', 'Barbell Squat', 'Flat Barbell Bench Press'].contains(e.name))
        .toList();
    final ids = exercises.map((e) => e.id).toList();
    for (final day in ['2026-10-08', '2026-10-09']) {
      for (final id in ids.take(3)) {
        await repo.addSet(exerciseId: id, date: day, rawWeight: 60, reps: 8);
      }
    }
    final before = (await repo.dayLog('2026-10-09')).map((s) => s.set).toList();
    final moved = ids.take(3).toList().reversed.toList();
    await repo.reorderExercises('2026-10-09', moved);
    expect(order(await repo.dayLog('2026-10-09')), moved);
    expect(order(await repo.dayLog('2026-10-08')), ids.take(3));
    expect((await repo.dayLog('2026-10-09')).map((s) => s.set), unorderedEquals(before));
    await repo.addSet(exerciseId: moved.first, date: '2026-10-09', rawWeight: 65, reps: 6);
    await repo.addSet(exerciseId: ids.last, date: '2026-10-09', rawWeight: 40, reps: 10);
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    repo = WorkoutRepository(db);
    expect(order(await repo.dayLog('2026-10-09')), [...moved, ids.last]);
    await repo.copyPreviousWorkout('2026-10-10');
    expect(order(await repo.dayLog('2026-10-10')), [...moved, ids.last]);
    await expectLater(repo.reorderExercises('2026-10-09', [99999]), throwsFormatException);
    expect(order(await repo.dayLog('2026-10-09')), [...moved, ids.last]);
  });

  test(
    'removing and undoing an exercise restores every set and its position without touching other days or the library',
    () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final repo = WorkoutRepository(db);
      final exercises = (await db.select(db.exercises).get())
          .where((e) => ['Barbell Curl', 'Barbell Row'].contains(e.name))
          .toList();
      final a = exercises.first.id, b = exercises.last.id;
      await repo.addSet(
        exerciseId: a,
        date: '2026-10-09',
        rawWeight: 20,
        reps: 8,
        weightMultiplier: 2,
        note: 'Controlled',
        rpe: 8,
      );
      await repo.addSet(exerciseId: a, date: '2026-10-09', rawWeight: 22, reps: 6, planned: true);
      await repo.addSet(exerciseId: b, date: '2026-10-09', rawWeight: 40, reps: 10);
      await repo.addSet(exerciseId: a, date: '2026-10-08', rawWeight: 30, reps: 10);
      await repo.reorderExercises('2026-10-09', [b, a]);
      await repo.saveDayNote('2026-10-09', 'Day note');
      final original = await repo.dayLog('2026-10-09');
      final snapshot = await repo.removeExerciseFromDay('2026-10-09', a);
      expect(order(await repo.dayLog('2026-10-09')), [b]);
      expect(await repo.dayLog('2026-10-08'), hasLength(1));
      expect((await db.select(db.exercises).get()).any((e) => e.id == a), true);
      await repo.restoreDay(snapshot);
      expect((await repo.dayLog('2026-10-09')).map((s) => s.set), original.map((s) => s.set));
      expect(order(await repo.dayLog('2026-10-09')), [b, a]);
      final wholeDay = await repo.deleteDay('2026-10-09');
      await repo.restoreDay(wholeDay);
      expect(order(await repo.dayLog('2026-10-09')), [b, a]);
      expect((await repo.watchDayNote('2026-10-09').first)!.comment, 'Day note');
      final folder = Directory.systemTemp.createTempSync('fitnotes-order-backup-');
      addTearDown(() => folder.deleteSync(recursive: true));
      final backup = File('${folder.path}/backup.fitnotesplus')
        ..writeAsBytesSync(await BackupService(db).backup(directory: folder));
      await repo.deleteDay('2026-10-09');
      await BackupService(db).restore(backup.path);
      expect(order(await repo.dayLog('2026-10-09')), [b, a]);
    },
  );

  test('bulk removal and undo preserve all selected sets, their positions, other dates, and workout metadata', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final repo = WorkoutRepository(db);
    final exercises = (await db.select(db.exercises).get())
        .where((e) => ['Barbell Curl', 'Barbell Row', 'Barbell Squat'].contains(e.name))
        .toList();
    final ids = exercises.map((e) => e.id).toList();
    for (final id in ids) {
      await repo.addSet(
        exerciseId: id,
        date: '2026-10-09',
        rawWeight: 20,
        reps: 8,
        weightMultiplier: 2,
        note: 'Controlled',
        rpe: 8,
      );
      await repo.addSet(exerciseId: id, date: '2026-10-08', rawWeight: 15, reps: 10);
    }
    await repo.addSet(exerciseId: ids.first, date: '2026-10-09', rawWeight: 22, reps: 6, planned: true);
    await repo.reorderExercises('2026-10-09', ids.reversed.toList());
    await repo.saveDayNote('2026-10-09', 'Keep this note');
    await repo.editSessionDuration('2026-10-09', 900);
    final before = await repo.dayLog('2026-10-09');
    final snapshot = await repo.removeExercisesFromDay('2026-10-09', [ids.first, ids.last, ids.first]);
    expect(order(await repo.dayLog('2026-10-09')), [ids[1]]);
    expect(await repo.dayLog('2026-10-08'), hasLength(3));
    expect((await repo.watchDayNote('2026-10-09').first)!.comment, 'Keep this note');
    expect((await repo.watchSession('2026-10-09').first)!.elapsedSeconds, 900);
    expect((await db.select(db.exercises).get()).where((e) => ids.contains(e.id)), hasLength(3));
    await repo.restoreDay(snapshot);
    expect((await repo.dayLog('2026-10-09')).map((s) => s.set), before.map((s) => s.set));
    final all = await repo.removeExercisesFromDay('2026-10-09', ids);
    expect(await repo.dayLog('2026-10-09'), isEmpty);
    await repo.restoreDay(all);
    expect((await repo.dayLog('2026-10-09')).map((s) => s.set), before.map((s) => s.set));
  });

  test('version 3 migration and backup restore keep existing workouts and timer durations', () async {
    final folder = Directory.systemTemp.createTempSync('fitnotes-v3-');
    addTearDown(() => folder.deleteSync(recursive: true));
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final repo = WorkoutRepository(db);
    final curl = (await db.select(db.exercises).get()).firstWhere((e) => e.name == 'Barbell Curl');
    await repo.addSet(exerciseId: curl.id, date: '2026-10-09', rawWeight: 20, reps: 8);
    await repo.editSessionDuration('2026-10-09', 1200);
    final old = File('${folder.path}/v3.fitnotesplus')..writeAsBytesSync(await BackupService(db).backup(directory: folder));
    final raw = sqlite.sqlite3.open(old.path);
    raw.execute('DROP TABLE workout_exercise_orders');
    raw.execute('ALTER TABLE app_settings DROP COLUMN rest_timer_sound_uri');
    raw.execute('PRAGMA user_version = 3');
    raw.close();
    final migrated = AppDatabase(NativeDatabase(old.copySync('${folder.path}/migration.sqlite')));
    addTearDown(migrated.close);
    await BackupService(db).restore(old.path);
    for (final current in [db, migrated]) {
      final workouts = WorkoutRepository(current);
      expect((await workouts.dayLog('2026-10-09')).single.set.rawWeight, 20);
      expect((await workouts.watchSession('2026-10-09').first)!.elapsedSeconds, 1200);
      await workouts.reorderExercises('2026-10-09', [curl.id]);
      expect(await current.select(current.workoutExerciseOrders).get(), hasLength(1));
      expect(await current.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    }
  });
}
