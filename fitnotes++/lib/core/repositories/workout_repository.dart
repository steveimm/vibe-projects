import 'package:drift/drift.dart';

import '../database/database.dart';
import '../database/tables.dart';
import '../models/set_values.dart';
import '../util/dates.dart';

class LoggedSet {
  LoggedSet({required this.set, required this.exerciseName, required this.colorArgb, required this.exerciseType});
  final WorkoutSet set;
  final String exerciseName;
  final int colorArgb;
  final int exerciseType;
  double get effectiveWeight => set.rawWeight * set.weightMultiplier;
}

class DaySnapshot {
  const DaySnapshot(this.sets, this.notes, this.sessions, [this.orders = const []]);
  final List<WorkoutSet> sets;
  final List<WorkoutDayNote> notes;
  final List<WorkoutSession> sessions;
  final List<WorkoutExerciseOrder> orders;
}

class WorkoutRepository {
  WorkoutRepository(this.db, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;
  final AppDatabase db;
  final DateTime Function() _now;

  Stream<List<WorkoutSet>> watchSetsForExerciseOnDate(int exerciseId, String date) =>
      (db.select(db.workoutSets)
            ..where((s) => s.exerciseId.equals(exerciseId) & s.date.equals(date))
            ..orderBy([(s) => OrderingTerm.asc(s.createdAt), (s) => OrderingTerm.asc(s.id)]))
          .watch();

  Stream<List<WorkoutSet>> watchExerciseHistory(int exerciseId) =>
      (db.select(db.workoutSets)
            ..where((s) => s.exerciseId.equals(exerciseId))
            ..orderBy([(s) => OrderingTerm.desc(s.date), (s) => OrderingTerm.asc(s.createdAt), (s) => OrderingTerm.asc(s.id)]))
          .watch();

  Stream<List<LoggedSet>> watchLog({String? date, int? categoryId, int? exerciseId}) {
    final conditions = <String>[];
    final variables = <Variable>[];
    if (date != null) {
      conditions.add('s.date = ?');
      variables.add(Variable.withString(date));
    }
    if (categoryId != null) {
      conditions.add('e.category_id = ?');
      variables.add(Variable.withInt(categoryId));
    }
    if (exerciseId != null) {
      conditions.add('e.id = ?');
      variables.add(Variable.withInt(exerciseId));
    }
    return db
        .customSelect(
          '''
      SELECT s.*, e.name AS ex_name, e.type AS ex_type, c.color_argb AS color_argb
      FROM workout_sets s JOIN exercises e ON e.id = s.exercise_id JOIN categories c ON c.id = e.category_id
      LEFT JOIN workout_exercise_orders o ON o.date = s.date AND o.exercise_id = s.exercise_id
      ${conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}'}
      ORDER BY s.date DESC, COALESCE(o.sort_order, 2147483647), s.created_at, s.id
    ''',
          variables: variables,
          readsFrom: {db.workoutSets, db.exercises, db.categories, db.workoutExerciseOrders},
        )
        .watch()
        .map(
          (rows) => rows
              .map(
                (r) => LoggedSet(
                  set: db.workoutSets.map(r.data),
                  exerciseName: r.read<String>('ex_name'),
                  colorArgb: r.read<int>('color_argb'),
                  exerciseType: r.read<int>('ex_type'),
                ),
              )
              .toList(),
        );
  }

  Stream<List<LoggedSet>> watchDayLog(String date) => watchLog(date: date);
  Future<List<LoggedSet>> dayLog(String date) => watchDayLog(date).first;

  Future<void> reorderExercises(String date, List<int> exerciseIds) => db.transaction(() async {
    final existing = (await dayLog(date)).map((s) => s.set.exerciseId).toSet();
    if (exerciseIds.toSet().length != exerciseIds.length || !existing.containsAll(exerciseIds)) {
      throw const FormatException('The workout changed. Try moving the exercise again.');
    }
    await (db.delete(db.workoutExerciseOrders)..where((o) => o.date.equals(date))).go();
    await db.batch((b) {
      for (var i = 0; i < exerciseIds.length; i++) {
        b.insert(
          db.workoutExerciseOrders,
          WorkoutExerciseOrdersCompanion.insert(date: date, exerciseId: exerciseIds[i], sortOrder: i),
        );
      }
    });
  });

  Future<DaySnapshot> removeExerciseFromDay(String date, int exerciseId) => removeExercisesFromDay(date, [exerciseId]);

  Future<DaySnapshot> removeExercisesFromDay(String date, Iterable<int> exerciseIds) => db.transaction(() async {
    final ids = exerciseIds.toSet();
    final sets = await (db.select(db.workoutSets)..where((s) => s.date.equals(date) & s.exerciseId.isIn(ids))).get();
    final orders = await (db.select(db.workoutExerciseOrders)..where((o) => o.date.equals(date) & o.exerciseId.isIn(ids))).get();
    await (db.delete(db.workoutSets)..where((s) => s.date.equals(date) & s.exerciseId.isIn(ids))).go();
    await (db.delete(db.workoutExerciseOrders)..where((o) => o.date.equals(date) & o.exerciseId.isIn(ids))).go();
    return DaySnapshot(sets, const [], const [], orders);
  });

  Future<String?> previousWorkoutDate(String before) async {
    final dates = await workoutDatesBefore(before);
    return dates.firstOrNull;
  }

  Stream<Set<String>> watchWorkoutDates() => db
      .customSelect('SELECT DISTINCT date FROM workout_sets', readsFrom: {db.workoutSets})
      .watch()
      .map((rows) => rows.map((r) => r.read<String>('date')).toSet());

  Future<List<String>> workoutDatesBefore(String date) async =>
      (await db
              .customSelect(
                'SELECT DISTINCT date FROM workout_sets WHERE date < ? ORDER BY date DESC',
                variables: [Variable.withString(date)],
              )
              .get())
          .map((r) => r.read<String>('date'))
          .toList();

  Future<WorkoutSet?> lastSet(int exerciseId, String date) =>
      (db.select(db.workoutSets)
            ..where((s) => s.exerciseId.equals(exerciseId) & s.date.isSmallerOrEqualValue(date) & s.isPlanned.equals(false))
            ..orderBy([(s) => OrderingTerm.desc(s.date), (s) => OrderingTerm.desc(s.createdAt), (s) => OrderingTerm.desc(s.id)])
            ..limit(1))
          .getSingleOrNull();

  Future<double> multiplier(int exerciseId) async {
    final factors = await (db.select(
      db.exerciseMultipliers,
    )..where((m) => m.exerciseId.equals(exerciseId) & m.enabled.equals(true))).get();
    return factors.fold<double>(1, (product, m) => product * m.factor);
  }

  Future<int> addSet({
    required int exerciseId,
    required String date,
    double rawWeight = 0,
    double? weightMultiplier,
    int reps = 0,
    double distance = 0,
    int durationSeconds = 0,
    double? rpe,
    String? note,
    String? groupName,
    bool planned = false,
  }) => db.transaction(() async {
    Dates.validate(date);
    final exercise = await (db.select(db.exercises)..where((e) => e.id.equals(exerciseId))).getSingle();
    SetValues(weight: rawWeight, reps: reps, distance: distance, seconds: durationSeconds, rpe: rpe).validate(exercise.type);
    final factor = weightMultiplier ?? await multiplier(exerciseId);
    if (!factor.isFinite || factor <= 0) throw const FormatException('Weight multiplier must be greater than zero.');
    return db
        .into(db.workoutSets)
        .insert(
          WorkoutSetsCompanion.insert(
            exerciseId: exerciseId,
            date: date,
            createdAt: DateTime.now(),
            rawWeight: Value(exercise.type.hasWeight ? rawWeight : 0),
            weightMultiplier: Value(factor),
            reps: Value(exercise.type.hasReps ? reps : 0),
            distance: Value(exercise.type.hasDistance ? distance : 0),
            durationSeconds: Value(exercise.type.hasTime ? durationSeconds : 0),
            rpe: Value(rpe),
            note: Value(note),
            groupName: Value(groupName),
            isPlanned: Value(planned),
            isComplete: Value(!planned),
          ),
        );
  });

  Future<void> updateSet(
    int id, {
    double? rawWeight,
    int? reps,
    double? distance,
    int? durationSeconds,
    Value<double?> rpe = const Value.absent(),
    Value<String?> note = const Value.absent(),
  }) => db.transaction(() async {
    final set = await (db.select(db.workoutSets)..where((s) => s.id.equals(id))).getSingle();
    final exercise = await (db.select(db.exercises)..where((e) => e.id.equals(set.exerciseId))).getSingle();
    SetValues(
      weight: rawWeight ?? set.rawWeight,
      reps: reps ?? set.reps,
      distance: distance ?? set.distance,
      seconds: durationSeconds ?? set.durationSeconds,
      rpe: rpe.present ? rpe.value : set.rpe,
    ).validate(exercise.type);
    await (db.update(db.workoutSets)..where((s) => s.id.equals(id))).write(
      WorkoutSetsCompanion(
        rawWeight: rawWeight == null ? const Value.absent() : Value(rawWeight),
        reps: reps == null ? const Value.absent() : Value(reps),
        distance: distance == null ? const Value.absent() : Value(distance),
        durationSeconds: durationSeconds == null ? const Value.absent() : Value(durationSeconds),
        rpe: rpe,
        note: note,
        isComplete: const Value(true),
        isPlanned: const Value(false),
      ),
    );
  });

  Future<void> deleteSet(int id) => (db.delete(db.workoutSets)..where((s) => s.id.equals(id))).go();
  Future<void> restoreSets(List<WorkoutSet> sets) => db.batch((b) {
    for (final s in sets) {
      b.insert(db.workoutSets, s.toCompanion(true), mode: InsertMode.insertOrIgnore);
    }
  });
  Future<void> setComplete(int id, bool value) => (db.update(
    db.workoutSets,
  )..where((s) => s.id.equals(id))).write(WorkoutSetsCompanion(isComplete: Value(value), isPlanned: Value(!value)));
  Future<void> setNote(int id, String? note) =>
      (db.update(db.workoutSets)..where((s) => s.id.equals(id))).write(WorkoutSetsCompanion(note: Value(note)));
  Future<void> setGroup(int exerciseId, String date, String? group) => (db.update(
    db.workoutSets,
  )..where((s) => s.exerciseId.equals(exerciseId) & s.date.equals(date))).write(WorkoutSetsCompanion(groupName: Value(group)));

  Future<int> copyPreviousWorkout(String date) async {
    final previous = await previousWorkoutDate(date);
    if (previous == null) return 0;
    return copySetsToDate((await dayLog(previous)).map((s) => s.set.id).toList(), date);
  }

  Future<int> copySetsToDate(List<int> setIds, String targetDate) => db.transaction(() async {
    Dates.validate(targetDate);
    final sets = await (db.select(db.workoutSets)..where((s) => s.id.isIn(setIds))).get();
    final byId = {for (final s in sets) s.id: s};
    var count = 0;
    for (final id in setIds.toSet()) {
      final s = byId[id];
      if (s == null) continue;
      await db
          .into(db.workoutSets)
          .insert(
            WorkoutSetsCompanion.insert(
              exerciseId: s.exerciseId,
              date: targetDate,
              createdAt: DateTime.now(),
              rawWeight: Value(s.rawWeight),
              weightMultiplier: Value(await multiplier(s.exerciseId)),
              reps: Value(s.reps),
              distance: Value(s.distance),
              durationSeconds: Value(s.durationSeconds),
              groupName: Value(s.groupName),
              isPlanned: const Value(true),
            ),
          );
      count++;
    }
    return count;
  });

  Stream<WorkoutDayNote?> watchDayNote(String date) =>
      (db.select(db.workoutDayNotes)..where((n) => n.date.equals(date))).watchSingleOrNull();
  Future<void> saveDayNote(String date, String note) async {
    Dates.validate(date);
    if (note.trim().isEmpty) {
      await (db.delete(db.workoutDayNotes)..where((n) => n.date.equals(date))).go();
      return;
    }
    await db
        .into(db.workoutDayNotes)
        .insert(
          WorkoutDayNotesCompanion.insert(date: date, comment: note.trim()),
          onConflict: DoUpdate((_) => WorkoutDayNotesCompanion(comment: Value(note.trim())), target: [db.workoutDayNotes.date]),
        );
  }

  Future<DaySnapshot> deleteDay(String date) => db.transaction(() async {
    final sets = await (db.select(db.workoutSets)..where((s) => s.date.equals(date))).get();
    final notes = await (db.select(db.workoutDayNotes)..where((s) => s.date.equals(date))).get();
    final sessions = await (db.select(db.workoutSessions)..where((s) => s.date.equals(date))).get();
    final orders = await (db.select(db.workoutExerciseOrders)..where((s) => s.date.equals(date))).get();
    await (db.delete(db.workoutSets)..where((s) => s.date.equals(date))).go();
    await (db.delete(db.workoutDayNotes)..where((s) => s.date.equals(date))).go();
    await (db.delete(db.workoutSessions)..where((s) => s.date.equals(date))).go();
    await (db.delete(db.workoutExerciseOrders)..where((s) => s.date.equals(date))).go();
    return DaySnapshot(sets, notes, sessions, orders);
  });

  Future<void> restoreDay(DaySnapshot snapshot) => db.transaction(() async {
    await restoreSets(snapshot.sets);
    for (final n in snapshot.notes) {
      await db.into(db.workoutDayNotes).insert(n.toCompanion(true), mode: InsertMode.insertOrIgnore);
    }
    for (final s in snapshot.sessions) {
      await db.into(db.workoutSessions).insert(s.toCompanion(true), mode: InsertMode.insertOrIgnore);
    }
    for (final order in snapshot.orders) {
      await db.into(db.workoutExerciseOrders).insert(order.toCompanion(true), mode: InsertMode.insertOrIgnore);
    }
  });

  Stream<WorkoutSession?> watchSession(String date) =>
      (db.select(db.workoutSessions)..where((s) => s.date.equals(date))).watchSingleOrNull();
  Future<void> startSession(String date) => db.transaction(() async {
    Dates.validate(date);
    final session = await watchSession(date).first;
    final now = _now();
    if (session == null) {
      await db
          .into(db.workoutSessions)
          .insert(WorkoutSessionsCompanion.insert(date: date, startedAt: now, runningSince: Value(now)));
    } else if (session.runningSince == null) {
      await (db.update(
        db.workoutSessions,
      )..where((s) => s.date.equals(date))).write(WorkoutSessionsCompanion(runningSince: Value(now), endedAt: const Value(null)));
    }
  });

  Future<void> pauseSession(String date) => _stopSession(date, finish: false);
  Future<void> finishSession(String date) => _stopSession(date, finish: true);

  Future<void> _stopSession(String date, {required bool finish}) => db.transaction(() async {
    final session = await watchSession(date).first;
    if (session == null) return;
    final now = _now();
    await (db.update(db.workoutSessions)..where((s) => s.date.equals(date))).write(
      WorkoutSessionsCompanion(
        elapsedSeconds: Value(session.durationAt(now)),
        runningSince: const Value(null),
        endedAt: Value(finish ? now : session.endedAt),
      ),
    );
  });

  Future<void> editSessionDuration(String date, int seconds) => db.transaction(() async {
    if (seconds < 0 || seconds > 604800) throw const FormatException('Use a duration between 0 and 168 hours.');
    final session = await watchSession(date).first;
    final now = _now();
    if (session == null) {
      Dates.validate(date);
      await db
          .into(db.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(date: date, startedAt: now, endedAt: Value(now), elapsedSeconds: Value(seconds)),
          );
    } else {
      await (db.update(db.workoutSessions)..where((s) => s.date.equals(date))).write(
        WorkoutSessionsCompanion(elapsedSeconds: Value(seconds), runningSince: Value(session.runningSince == null ? null : now)),
      );
    }
  });

  Future<void> resetSession(String date) => (db.delete(db.workoutSessions)..where((s) => s.date.equals(date))).go();

  Future<Map<String, List<int>>> workoutDayCategoryColors({int? categoryId, int? exerciseId}) async {
    final sets = await watchLog(categoryId: categoryId, exerciseId: exerciseId).first;
    return workoutDayColors(sets);
  }
}

extension WorkoutSessionDuration on WorkoutSession {
  int durationAt(DateTime now) =>
      elapsedSeconds + (runningSince == null ? 0 : now.difference(runningSince!).inSeconds.clamp(0, 604800));
}

Map<String, List<int>> workoutDayColors(Iterable<LoggedSet> sets) {
  final days = <String, Set<int>>{};
  for (final s in sets) {
    (days[s.set.date] ??= {}).add(s.colorArgb);
  }
  return days.map((date, colors) => MapEntry(date, colors.toList()));
}
