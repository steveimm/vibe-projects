import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fitnotes_plus/core/database/database.dart';
import 'package:fitnotes_plus/core/import/csv_importer.dart';
import 'package:fitnotes_plus/core/repositories/workout_repository.dart';
import 'package:fitnotes_plus/core/repositories/routine_repository.dart';
import 'package:fitnotes_plus/core/services/backup_service.dart';

void main() {
  test('full backup restores deleted sets, routines, notes, and defaults atomically', () async {
    final db = AppDatabase.memory();
    final folder = Directory.systemTemp.createTempSync('fitnotes-backup-test-');
    addTearDown(db.close);
    addTearDown(() => folder.deleteSync(recursive: true));
    final workouts = WorkoutRepository(db);
    final bench = (await db.select(db.exercises).get()).firstWhere((e) => e.name == 'Flat Barbell Bench Press');
    await workouts.addSet(
      exerciseId: bench.id,
      date: '2026-01-01',
      rawWeight: 25,
      weightMultiplier: 2,
      rpe: 7.5,
      reps: 5,
      note: 'Easy, "controlled"\nNext line',
    );
    await workouts.saveDayNote('2026-01-01', 'A full session');
    await RoutineRepository(db).fromWorkout('2026-01-01', 'Upper');
    final service = BackupService(db);
    final file = File('${folder.path}/backup.fitnotesplus')..writeAsBytesSync(await service.backup(directory: folder));
    await workouts.deleteDay('2026-01-01');
    await db.delete(db.routines).go();
    await service.restore(file.path);
    expect((await workouts.dayLog('2026-01-01')).single.set.rawWeight, 25);
    expect((await db.select(db.routines).get()).single.name, 'Upper');
    expect((await workouts.watchDayNote('2026-01-01').first)?.comment, 'A full session');
    final csv = utf8.decode(await service.csv());
    expect(parseCsv(csv)[1].last, 'Easy, "controlled"\nNext line');
    await CsvImporter(db).import(csv);
    expect((await workouts.dayLog('2026-01-01')).length, 1, reason: 'Importing our own export must not duplicate existing sets');
    expect((await workouts.dayLog('2026-01-01')).single.set.weightMultiplier, 2);
    expect((await workouts.dayLog('2026-01-01')).single.set.rpe, 7.5);
    final invalid = File('${folder.path}/invalid.fitnotesplus')..writeAsStringSync('not a database');
    await expectLater(service.restore(invalid.path), throwsFormatException);
    expect((await workouts.dayLog('2026-01-01')).length, 1);
  });

  test('CSV imports convert units, preserve repeated sets, and do not duplicate reimports', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    const csv =
        'Date,Exercise,Category,Weight,Weight Unit,Reps,Distance,Distance Unit,Time,Comment\n'
        '2026-01-01,Test press,Chest,100,lbs,5,,,,"one, two"\n'
        '2026-01-01,Test press,Chest,100,lbs,5,,,,"second set"\n'
        '2026-01-02,Run,Cardio,,,,1,mi,0:10:00,"run"\n';
    await CsvImporter(db).import(csv);
    await CsvImporter(db).import(csv);
    final sets = await db.select(db.workoutSets).get();
    expect(sets.length, 3);
    expect(sets.first.rawWeight, closeTo(45.359237, 0.000001));
    expect(sets.last.distance, closeTo(1609.344, 0.000001));
    expect(sets.last.durationSeconds, 600);
    final bad = csv.replaceAll('2026-01-02', '2026-02-31');
    await expectLater(CsvImporter(db).import(bad), throwsFormatException);
    expect((await db.select(db.workoutSets).get()).length, 3);
  });
}
