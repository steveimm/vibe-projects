import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:fitnotes_plus/core/database/database.dart';
import 'package:fitnotes_plus/core/repositories/workout_repository.dart';
import 'package:fitnotes_plus/core/services/backup_service.dart';
import 'package:fitnotes_plus/core/services/workout_auto_stop.dart';

void main() {
  group('deadline scheduling', schedulingTests);
  group('stored workouts', () {
    const date = '2026-10-15';
    late AppDatabase db;
    late WorkoutRepository repo;
    late DateTime now;
    late int exercise;

    setUp(() async {
      now = DateTime(2026, 10, 15, 10);
      db = AppDatabase.memory();
      repo = WorkoutRepository(db, clock: () => now);
      exercise = (await db.select(db.exercises).get()).first.id;
    });
    tearDown(() => db.close());

    Future<int> log() => repo.addSet(exerciseId: exercise, date: date, reps: 10);
    Future<WorkoutSession> session() async => (await repo.watchSession(date).first)!;

    test('15-minute inactivity ends at the last set, and editing a set does not extend the deadline', () async {
      expect((await db.select(db.appSettings).getSingle()).workoutAutoStopMinutes, 15);
      await log();
      now = now.add(const Duration(minutes: 5));
      final last = await log();
      final lastSetAt = now;
      now = now.add(const Duration(minutes: 14, seconds: 59));
      await repo.updateSet(last, reps: 12);
      await repo.finishInactiveSessions();
      expect((await session()).runningSince, isNotNull);
      now = now.add(const Duration(seconds: 1));
      await repo.finishInactiveSessions();
      expect((await session()).runningSince, isNull);
      expect((await session()).endedAt, lastSetAt);
      expect((await session()).elapsedSeconds, 300);
      now = now.add(const Duration(hours: 1));
      await repo.finishSession(date);
      expect((await session()).endedAt, lastSetAt);
      expect((await session()).durationAt(now), 300);
    });

    test('manual starts, pauses, and duration edits keep the correct elapsed time at the last set', () async {
      await repo.startSession(date);
      now = now.add(const Duration(minutes: 2));
      await log();
      now = now.add(const Duration(minutes: 3));
      await repo.pauseSession(date);
      now = now.add(const Duration(hours: 1));
      await repo.finishInactiveSessions();
      expect((await session()).endedAt, isNull);
      expect((await session()).elapsedSeconds, 300);
      await repo.startSession(date);
      now = now.add(const Duration(minutes: 2));
      await log();
      final lastSetAt = now;
      now = now.add(const Duration(minutes: 1));
      await repo.editSessionDuration(date, 600);
      now = now.add(const Duration(minutes: 15));
      await repo.finishInactiveSessions();
      expect((await session()).endedAt, lastSetAt);
      expect((await session()).elapsedSeconds, 540);
    });

    test('an expired session stays stopped when a later set is logged', () async {
      await log();
      now = now.add(const Duration(minutes: 3));
      await log();
      final last = now;
      now = now.add(const Duration(hours: 2));
      await log();
      expect((await session()).elapsedSeconds, 180);
      expect((await session()).endedAt, last);
      expect((await session()).runningSince, isNull);
    });

    test('custom timeout stops an unused manual timer at zero and planned sets count only when completed', () async {
      await db.update(db.appSettings).write(const AppSettingsCompanion(workoutAutoStopMinutes: Value(1)));
      await repo.startSession(date);
      now = now.add(const Duration(minutes: 1));
      await repo.finishInactiveSessions();
      expect((await session()).elapsedSeconds, 0);
      expect((await session()).endedAt, (await session()).startedAt);
      await repo.resetSession(date);
      final planned = await repo.addSet(exerciseId: exercise, date: date, reps: 10, planned: true);
      expect(await repo.watchSession(date).first, isNull);
      await repo.setComplete(planned, true);
      now = now.add(const Duration(seconds: 30));
      await log();
      final last = now;
      now = now.add(const Duration(seconds: 30));
      await repo.setComplete(planned, true);
      await repo.addSet(exerciseId: exercise, date: '2026-10-14', reps: 10);
      expect((await session()).lastSetAt, last);
      now = now.add(const Duration(seconds: 30));
      await repo.finishInactiveSessions();
      expect((await session()).endedAt, last);
      expect((await session()).elapsedSeconds, 30);
    });

    test('saved activity and custom timeout survive reopening and a full backup restore', () async {
      final folder = Directory.systemTemp.createTempSync('fitnotes-auto-stop-');
      addTearDown(() => folder.deleteSync(recursive: true));
      await db.update(db.appSettings).write(const AppSettingsCompanion(workoutAutoStopMinutes: Value(7)));
      await log();
      now = now.add(const Duration(minutes: 4));
      await log();
      final last = now;
      final file = File('${folder.path}/saved.fitnotesplus')..writeAsBytesSync(await BackupService(db).backup(directory: folder));
      final reopened = AppDatabase(NativeDatabase(file));
      addTearDown(reopened.close);
      await repo.deleteDay(date);
      await BackupService(db).restore(file.path);
      now = now.add(const Duration(hours: 8));
      for (final database in [db, reopened]) {
        expect((await database.select(database.appSettings).getSingle()).workoutAutoStopMinutes, 7);
        final repository = WorkoutRepository(database, clock: () => now);
        await repository.finishInactiveSessions();
        final saved = (await repository.watchSession(date).first)!;
        expect(saved.endedAt, last);
        expect(saved.elapsedSeconds, 240);
        expect(saved.runningSince, isNull);
      }
    });

    test('version 9 migration and restore recover the last timestamp and default to 15 minutes', () async {
      final folder = Directory.systemTemp.createTempSync('fitnotes-auto-stop-v9-');
      addTearDown(() => folder.deleteSync(recursive: true));
      await log();
      now = now.add(const Duration(minutes: 6));
      await log();
      final last = now;
      final file = File('${folder.path}/old.fitnotesplus')..writeAsBytesSync(await BackupService(db).backup(directory: folder));
      final raw = sqlite.sqlite3.open(file.path);
      raw.execute('ALTER TABLE app_settings DROP COLUMN workout_auto_stop_minutes');
      raw.execute('ALTER TABLE workout_sessions DROP COLUMN last_set_at');
      raw.execute('ALTER TABLE workout_sessions DROP COLUMN elapsed_at_last_set');
      raw.execute('PRAGMA user_version = 9');
      raw.close();
      final migrated = AppDatabase(NativeDatabase(file.copySync('${folder.path}/migration.sqlite')));
      addTearDown(migrated.close);
      await BackupService(db).restore(file.path);
      now = now.add(const Duration(minutes: 15));
      for (final database in [db, migrated]) {
        expect((await database.select(database.appSettings).getSingle()).workoutAutoStopMinutes, 15);
        final repository = WorkoutRepository(database, clock: () => now);
        await repository.finishInactiveSessions();
        final saved = (await repository.watchSession(date).first)!;
        expect(saved.endedAt, last);
        expect(saved.elapsedSeconds, 360);
        expect(await database.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      }
    });
  });
}

void schedulingTests() {
  testWidgets('uses one deadline, resets on new activity, and does no work while backgrounded', (tester) async {
    var now = DateTime(2026, 10, 15, 10);
    final start = now;
    var expirations = 0;
    final timer = WorkoutAutoStop(expire: () async => expirations++, clock: () => now);
    addTearDown(timer.dispose);
    WorkoutSession running() => WorkoutSession(
      date: '2026-10-15',
      startedAt: start,
      runningSince: start,
      elapsedSeconds: 0,
      lastSetAt: now,
      elapsedAtLastSet: 0,
    );
    Future<void> advance(Duration duration) async {
      now = now.add(duration);
      await tester.pump(duration);
    }

    timer.update([running()], 15);
    await advance(const Duration(minutes: 14));
    expect(expirations, 0);
    timer.update([running()], 15);
    await advance(const Duration(minutes: 14));
    expect(expirations, 0);
    await advance(const Duration(minutes: 1));
    expect(expirations, 1);
    await advance(const Duration(hours: 2));
    expect(expirations, 1, reason: 'An expired deadline must not become a repeating poll.');
    timer.update([running()], 15);
    timer.setVisible(false);
    await advance(const Duration(hours: 1));
    expect(expirations, 1);
    timer.setVisible(true);
    await tester.pump(const Duration(milliseconds: 1));
    expect(expirations, 2);
    timer.update([running()], 15);
    await advance(const Duration(minutes: 2));
    timer.update([running().copyWith(lastSetAt: Value(now.subtract(const Duration(minutes: 2))))], 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(expirations, 3, reason: 'Shortening the setting applies to an existing timer.');
    timer.update([], 15);
    await advance(const Duration(hours: 1));
    expect(expirations, 3);
  });
}
