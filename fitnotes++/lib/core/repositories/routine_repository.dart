import 'package:drift/drift.dart';

import '../database/database.dart';
import '../database/tables.dart';
import '../models/set_values.dart';
import 'workout_repository.dart';

class RoutineRepository {
  RoutineRepository(this.db);
  final AppDatabase db;

  Stream<List<Routine>> watch() => (db.select(db.routines)..orderBy([(r) => OrderingTerm.asc(r.name)])).watch();
  Stream<List<RoutineDay>> watchDays(int id) =>
      (db.select(db.routineDays)
            ..where((d) => d.routineId.equals(id))
            ..orderBy([(d) => OrderingTerm.asc(d.sortOrder), (d) => OrderingTerm.asc(d.id)]))
          .watch();
  Stream<List<RoutineSet>> watchSets(int dayId) =>
      (db.select(db.routineSets)
            ..where((s) => s.dayId.equals(dayId))
            ..orderBy([(s) => OrderingTerm.asc(s.sortOrder), (s) => OrderingTerm.asc(s.id)]))
          .watch();

  Future<int> create(String name, {String notes = ''}) => db.transaction(() async {
    final id = await db.into(db.routines).insert(RoutinesCompanion.insert(name: name.trim(), notes: Value(notes)));
    await addDay(id, 'Day 1');
    return id;
  });
  Future<void> update(int id, String name, String notes) => (db.update(
    db.routines,
  )..where((r) => r.id.equals(id))).write(RoutinesCompanion(name: Value(name.trim()), notes: Value(notes)));
  Future<void> delete(int id) => (db.delete(db.routines)..where((r) => r.id.equals(id))).go();
  Future<int> addDay(int routineId, String name) async {
    final days = await watchDays(routineId).first;
    return db
        .into(db.routineDays)
        .insert(RoutineDaysCompanion.insert(routineId: routineId, name: name.trim(), sortOrder: Value(days.length)));
  }

  Future<void> renameDay(int id, String name) =>
      (db.update(db.routineDays)..where((d) => d.id.equals(id))).write(RoutineDaysCompanion(name: Value(name.trim())));
  Future<void> deleteDay(int id) => (db.delete(db.routineDays)..where((d) => d.id.equals(id))).go();

  Future<void> addExercise(int dayId, int exerciseId, {int count = 3}) async {
    final sets = await watchSets(dayId).first;
    final start = sets.isEmpty ? 0 : sets.last.sortOrder + 1;
    await db.batch((b) {
      for (var i = 0; i < count; i++) {
        b.insert(db.routineSets, RoutineSetsCompanion.insert(dayId: dayId, exerciseId: exerciseId, sortOrder: Value(start + i)));
      }
    });
  }

  Future<void> updateSet(int id, RoutineSetsCompanion changes) async {
    final preset = await (db.select(db.routineSets)..where((s) => s.id.equals(id))).getSingle();
    final exercise = await (db.select(db.exercises)..where((e) => e.id.equals(preset.exerciseId))).getSingle();
    SetValues(
      weight: (changes.rawWeight.present ? changes.rawWeight.value : preset.rawWeight) ?? 0,
      reps: (changes.reps.present ? changes.reps.value : preset.reps) ?? 10,
      distance: (changes.distance.present ? changes.distance.value : preset.distance) ?? 1000,
      seconds: (changes.durationSeconds.present ? changes.durationSeconds.value : preset.durationSeconds) ?? 60,
    ).validate(exercise.type);
    await (db.update(db.routineSets)..where((s) => s.id.equals(id))).write(changes);
  }

  Future<void> duplicateSet(int id) => db.transaction(() async {
    final set = await (db.select(db.routineSets)..where((s) => s.id.equals(id))).getSingle();
    await db.customStatement('UPDATE routine_sets SET sort_order = sort_order + 1 WHERE day_id = ? AND sort_order > ?', [
      set.dayId,
      set.sortOrder,
    ]);
    await db
        .into(db.routineSets)
        .insert(set.toCompanion(false).copyWith(id: const Value.absent(), sortOrder: Value(set.sortOrder + 1)));
  });
  Future<void> deleteSets(Iterable<int> ids) => (db.delete(db.routineSets)..where((s) => s.id.isIn(ids))).go();
  Future<void> swapSetOrder(int firstId, int secondId) => db.transaction(() async {
    final first = await (db.select(db.routineSets)..where((s) => s.id.equals(firstId))).getSingle();
    final second = await (db.select(
      db.routineSets,
    )..where((s) => s.id.equals(secondId) & s.dayId.equals(first.dayId))).getSingle();
    await (db.update(
      db.routineSets,
    )..where((s) => s.id.equals(firstId))).write(RoutineSetsCompanion(sortOrder: Value(second.sortOrder)));
    await (db.update(
      db.routineSets,
    )..where((s) => s.id.equals(secondId))).write(RoutineSetsCompanion(sortOrder: Value(first.sortOrder)));
  });

  Future<void> deleteSet(int id) => (db.delete(db.routineSets)..where((s) => s.id.equals(id))).go();
  Future<void> reorder(List<int> ids) => db.batch((b) {
    for (var i = 0; i < ids.length; i++) {
      b.update(db.routineSets, RoutineSetsCompanion(sortOrder: Value(i)), where: (s) => s.id.equals(ids[i]));
    }
  });

  Future<int> logDay(int dayId, String date) => db.transaction(() async {
    final sets = await watchSets(dayId).first;
    if (sets.isEmpty) throw const FormatException('Add exercises to this routine day first.');
    final workouts = WorkoutRepository(db);
    final last = <int, WorkoutSet?>{};
    final exercises = {for (final e in await db.select(db.exercises).get()) e.id: e};
    for (final s in sets) {
      if (!last.containsKey(s.exerciseId)) last[s.exerciseId] = await workouts.lastSet(s.exerciseId, date);
      final previous = last[s.exerciseId];
      final type = exercises[s.exerciseId]!.type;
      await workouts.addSet(
        exerciseId: s.exerciseId,
        date: date,
        planned: true,
        groupName: s.groupName,
        rawWeight: s.rawWeight ?? previous?.rawWeight ?? 0,
        reps: type.hasReps ? s.reps ?? previous?.reps ?? 10 : 0,
        distance: type.hasDistance ? s.distance ?? previous?.distance ?? 1000 : 0,
        durationSeconds: type.hasTime ? s.durationSeconds ?? previous?.durationSeconds ?? 60 : 0,
      );
    }
    return sets.length;
  });

  Future<int> fromWorkout(String date, String name) => db.transaction(() async {
    final sets = await WorkoutRepository(db).dayLog(date);
    if (sets.isEmpty) throw const FormatException('Log some sets before saving a routine.');
    final id = await create(name);
    final day = (await watchDays(id).first).single;
    for (var i = 0; i < sets.length; i++) {
      final s = sets[i].set;
      await db
          .into(db.routineSets)
          .insert(
            RoutineSetsCompanion.insert(
              dayId: day.id,
              exerciseId: s.exerciseId,
              rawWeight: Value(s.rawWeight),
              reps: Value(s.reps),
              distance: Value(s.distance),
              durationSeconds: Value(s.durationSeconds),
              groupName: Value(s.groupName),
              sortOrder: Value(i),
            ),
          );
    }
    return id;
  });
}
