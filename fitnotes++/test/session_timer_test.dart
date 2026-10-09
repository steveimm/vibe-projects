import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:fitnotes_plus/core/database/database.dart';
import 'package:fitnotes_plus/core/repositories/workout_repository.dart';
import 'package:fitnotes_plus/core/services/backup_service.dart';

void main() {
  test('workout duration survives reopening, excludes pauses, and supports editing and resuming a finished session', () async {
    final directory = Directory.systemTemp.createTempSync('fitnotes-session-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/workout.sqlite');
    var now = DateTime.utc(2026, 10, 8, 10);
    var db = AppDatabase(NativeDatabase(file));
    var repo = WorkoutRepository(db, clock: () => now);
    const date = '2026-10-08';
    await repo.startSession(date);
    now = now.add(const Duration(minutes: 5));
    await repo.startSession(date);
    await repo.pauseSession(date);
    now = now.add(const Duration(minutes: 20));
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    repo = WorkoutRepository(db, clock: () => now);
    addTearDown(db.close);
    expect((await repo.watchSession(date).first)!.durationAt(now), 300);
    await repo.editSessionDuration(date, 600);
    await repo.startSession(date);
    now = now.add(const Duration(minutes: 3));
    await repo.finishSession(date);
    now = now.add(const Duration(hours: 1));
    expect((await repo.watchSession(date).first)!.durationAt(now), 780);
    await repo.startSession(date);
    now = now.add(const Duration(minutes: 1));
    await repo.editSessionDuration(date, 900);
    now = now.add(const Duration(seconds: 30));
    await repo.pauseSession(date);
    expect((await repo.watchSession(date).first)!.durationAt(now), 930);
    await expectLater(repo.editSessionDuration(date, -1), throwsFormatException);
    final ex = (await db.select(db.exercises).get()).firstWhere((e) => e.name == 'Flat Barbell Bench Press');
    await repo.addSet(exerciseId: ex.id, date: date, reps: 10);
    await repo.resetSession(date);
    expect(await repo.watchSession(date).first, isNull);
    expect(await repo.dayLog(date), hasLength(1));
  });

  test('version 2 session migration and backup restore preserve running and finished times', () async {
    final folder = Directory.systemTemp.createTempSync('fitnotes-v2-');
    addTearDown(() => folder.deleteSync(recursive: true));
    final current = AppDatabase.memory();
    addTearDown(current.close);
    await current.select(current.appSettings).get();
    final file = File('${folder.path}/version2.fitnotesplus');
    file.writeAsBytesSync(await BackupService(current).backup(directory: folder));
    final raw = sqlite.sqlite3.open(file.path);
    raw.execute('ALTER TABLE workout_sessions DROP COLUMN elapsed_seconds');
    raw.execute('ALTER TABLE workout_sessions DROP COLUMN running_since');
    raw.execute('DROP TABLE workout_exercise_orders');
    raw.execute('PRAGMA user_version = 2');
    final start = DateTime.utc(2026, 10, 8, 10);
    raw.execute('INSERT INTO workout_sessions VALUES (?,?,?)', [
      '2026-10-07',
      start.millisecondsSinceEpoch ~/ 1000,
      start.millisecondsSinceEpoch ~/ 1000 + 1200,
    ]);
    raw.execute('INSERT INTO workout_sessions VALUES (?,?,NULL)', ['2026-10-08', start.millisecondsSinceEpoch ~/ 1000]);
    raw.close();
    final copy = file.copySync('${folder.path}/migrate.sqlite');
    final migrated = AppDatabase(NativeDatabase(copy));
    addTearDown(migrated.close);
    for (final db in [current, migrated]) {
      if (db == current) await BackupService(db).restore(file.path);
      final repo = WorkoutRepository(db);
      final finished = (await repo.watchSession('2026-10-07').first)!;
      final running = (await repo.watchSession('2026-10-08').first)!;
      expect(finished.runningSince, isNull);
      expect(finished.durationAt(start.add(const Duration(days: 1))), 1200);
      expect(running.runningSince!.isAtSameMomentAs(start), true);
      expect(running.durationAt(start.add(const Duration(minutes: 5))), 300);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    }
  });
}
