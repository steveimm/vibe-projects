import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:fitnotes_plus/core/database/database.dart';
import 'package:fitnotes_plus/core/import/csv_importer.dart';
import 'package:fitnotes_plus/core/repositories/workout_repository.dart';
import 'package:fitnotes_plus/core/services/backup_service.dart';

void main() {
  test('performed sets capture time once, and planned, copied, historical, and imported sets do not invent times', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    var now = DateTime(2026, 10, 12, 10);
    final repo = WorkoutRepository(db, clock: () => now);
    final exercise = (await db.select(db.exercises).get()).first;
    Future<WorkoutSet> get(int id) => (db.select(db.workoutSets)..where((s) => s.id.equals(id))).getSingle();
    final first = await repo.addSet(exerciseId: exercise.id, date: '2026-10-12', reps: 10);
    final started = now;
    expect((await get(first)).loggedAt, started);
    now = now.add(const Duration(minutes: 5));
    await repo.updateSet(first, reps: 12);
    await repo.setComplete(first, true);
    expect((await get(first)).loggedAt, started);
    final second = await repo.addSet(exerciseId: exercise.id, date: '2026-10-12', reps: 10, planned: true);
    expect((await get(second)).loggedAt, isNull);
    await repo.updateSet(second, reps: 8);
    expect((await get(second)).loggedAt, isNull);
    await repo.setComplete(second, true);
    expect((await get(second)).loggedAt, now);
    await repo.setComplete(second, false);
    expect((await get(second)).loggedAt, isNull);
    now = now.add(const Duration(minutes: 3));
    await repo.setComplete(second, true);
    expect((await get(second)).loggedAt, now);
    await repo.copySetsToDate([first], '2026-10-12');
    final copied = (await repo.dayLog('2026-10-12')).singleWhere((entry) => entry.set.isPlanned).set;
    expect(copied.loggedAt, isNull);
    await repo.setComplete(copied.id, true);
    expect((await get(copied.id)).loggedAt, now);
    for (final date in ['2026-10-11', '2026-10-13']) {
      final id = await repo.addSet(exerciseId: exercise.id, date: date, reps: 10);
      await repo.setComplete(id, false);
      await repo.setComplete(id, true);
      expect((await get(id)).loggedAt, isNull);
    }
    await CsvImporter(db).import(
      'Date,Exercise,Category,Weight,Weight Unit,Reps,Distance,Distance Unit,Time,Comment\n'
      '2026-10-12,Imported press,Chest,20,kgs,10,,,,\n',
    );
    final imported = (await db.select(db.workoutSets).get()).where((s) => s.sourceKey != null);
    expect(imported, hasLength(1));
    expect(imported.single.loggedAt, isNull);
  });

  test('version 7 upgrade and restore leave timestamps unknown, while new backups preserve captured times', () async {
    final folder = Directory.systemTemp.createTempSync('fitnotes-timestamps-');
    addTearDown(() => folder.deleteSync(recursive: true));
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final now = DateTime(2026, 10, 12, 10, 15, 42);
    final repo = WorkoutRepository(db, clock: () => now);
    final exercise = (await db.select(db.exercises).get()).first;
    await repo.addSet(exerciseId: exercise.id, date: '2026-10-12', reps: 8);
    final service = BackupService(db);
    final current = File('${folder.path}/current.fitnotesplus')..writeAsBytesSync(await service.backup(directory: folder));
    await repo.deleteDay('2026-10-12');
    await service.restore(current.path);
    expect((await repo.dayLog('2026-10-12')).single.set.loggedAt, now);
    final old = current.copySync('${folder.path}/version7.fitnotesplus');
    final raw = sqlite.sqlite3.open(old.path);
    raw.execute('ALTER TABLE workout_sets DROP COLUMN logged_at');
    raw.execute('PRAGMA user_version = 7');
    raw.close();
    final migrated = AppDatabase(NativeDatabase(old.copySync('${folder.path}/migrated.sqlite')));
    addTearDown(migrated.close);
    expect((await migrated.select(migrated.workoutSets).get()).single.loggedAt, isNull);
    expect((await migrated.select(migrated.workoutSets).get()).single.createdAt, now);
    expect(await migrated.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    await service.restore(old.path);
    final restored = (await repo.dayLog('2026-10-12')).single.set;
    expect(restored.loggedAt, isNull);
    expect(restored.reps, 8);
    expect(restored.createdAt, now);
  });
}
