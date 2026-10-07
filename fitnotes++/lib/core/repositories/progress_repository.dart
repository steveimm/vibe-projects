import 'package:drift/drift.dart';

import '../database/database.dart';
import '../util/dates.dart';

class ProgressRepository {
  ProgressRepository(this.db);
  final AppDatabase db;

  Stream<List<PrResetMarker>> watchSeasons() =>
      (db.select(db.prResetMarkers)..orderBy([(s) => OrderingTerm.desc(s.date), (s) => OrderingTerm.desc(s.id)])).watch();
  Future<void> startSeason(String date, String name) async {
    Dates.validate(date);
    await db
        .into(db.prResetMarkers)
        .insert(PrResetMarkersCompanion.insert(date: date, createdAt: DateTime.now(), note: Value(name.trim())));
  }

  Future<void> deleteSeason(int id) => (db.delete(db.prResetMarkers)..where((s) => s.id.equals(id))).go();

  Stream<List<MeasurementType>> watchTypes() =>
      (db.select(db.measurementTypes)..orderBy([(t) => OrderingTerm.asc(t.id)])).watch();
  Stream<List<Measurement>> watchMeasurements(int id) =>
      (db.select(db.measurements)
            ..where((m) => m.typeId.equals(id))
            ..orderBy([(m) => OrderingTerm.desc(m.date)]))
          .watch();
  Future<int> addType(String name, String unit) =>
      db.into(db.measurementTypes).insert(MeasurementTypesCompanion.insert(name: name.trim(), unit: unit));
  Future<void> saveMeasurement(int typeId, String date, double value, String note) async {
    Dates.validate(date);
    if (!value.isFinite || value <= 0) throw const FormatException('Enter a value greater than zero.');
    await db
        .into(db.measurements)
        .insert(
          MeasurementsCompanion.insert(typeId: typeId, date: date, value: value, note: Value(note.trim())),
          onConflict: DoUpdate(
            (_) => MeasurementsCompanion(value: Value(value), note: Value(note.trim())),
            target: [db.measurements.typeId, db.measurements.date],
          ),
        );
  }

  Future<void> deleteMeasurement(int id) => (db.delete(db.measurements)..where((m) => m.id.equals(id))).go();
  Stream<List<ExerciseGoal>> watchGoals(int exerciseId) =>
      (db.select(db.exerciseGoals)..where((g) => g.exerciseId.equals(exerciseId))).watch();
  Future<void> saveGoal(int exerciseId, String metric, double target, String? date) async {
    if (!target.isFinite || target <= 0) throw const FormatException('Enter a target greater than zero.');
    if (date != null) Dates.validate(date);
    await db
        .into(db.exerciseGoals)
        .insert(ExerciseGoalsCompanion.insert(exerciseId: exerciseId, metric: metric, target: target, targetDate: Value(date)));
  }

  Future<void> deleteGoal(int id) => (db.delete(db.exerciseGoals)..where((g) => g.id.equals(id))).go();
}
