import 'package:drift/drift.dart';

import '../database/database.dart';
import '../util/dates.dart';

class ProgressRepository {
  ProgressRepository(this.db);
  final AppDatabase db;

  Selectable<Measurement> _bodyweightQuery(String date) => db
      .customSelect(
        '''
    SELECT m.* FROM measurements m JOIN measurement_types t ON t.id = m.type_id
    WHERE t.unit = 'kg' AND (t.id = 1 OR LOWER(TRIM(t.name)) IN ('bodyweight', 'body weight'))
      AND m.date <= ? AND m.value > 0
    ORDER BY m.date DESC, m.id DESC LIMIT 1
  ''',
        variables: [Variable.withString(date)],
        readsFrom: {db.measurements, db.measurementTypes},
      )
      .map((row) => db.measurements.map(row.data));

  Stream<Measurement?> watchLatestBodyweight(String date) => _bodyweightQuery(date).watchSingleOrNull();
  Future<Measurement?> latestBodyweight(String date) => _bodyweightQuery(date).getSingleOrNull();

  Stream<List<PrResetMarker>> watchSeasons() =>
      (db.select(db.prResetMarkers)..orderBy([(s) => OrderingTerm.desc(s.date), (s) => OrderingTerm.desc(s.id)])).watch();
  Future<void> startSeason(String date, String name, {String? initials}) async {
    Dates.validate(date);
    await db
        .into(db.prResetMarkers)
        .insert(
          PrResetMarkersCompanion.insert(
            date: date,
            createdAt: DateTime.now(),
            note: Value(name.trim()),
            initials: Value(initials?.trim().isNotEmpty == true ? initials!.trim() : null),
          ),
        );
  }

  Future<void> deleteSeason(int id) => (db.delete(db.prResetMarkers)..where((s) => s.id.equals(id))).go();

  Stream<List<MeasurementType>> watchTypes() =>
      (db.select(db.measurementTypes)..orderBy([(t) => OrderingTerm.asc(t.id)])).watch();
  Stream<List<Measurement>> watchMeasurements(int id) =>
      (db.select(db.measurements)
            ..where((m) => m.typeId.equals(id))
            ..orderBy([(m) => OrderingTerm.desc(m.date)]))
          .watch();
  Stream<List<Measurement>> watchAllMeasurements() =>
      (db.select(db.measurements)..orderBy([(m) => OrderingTerm.desc(m.date), (m) => OrderingTerm.desc(m.id)])).watch();
  Future<Measurement?> measurementOnDate(int typeId, String date) =>
      (db.select(db.measurements)..where((m) => m.typeId.equals(typeId) & m.date.equals(date))).getSingleOrNull();
  Future<int> addType(String name, String unit) =>
      db.into(db.measurementTypes).insert(MeasurementTypesCompanion.insert(name: name.trim(), unit: unit));
  Future<void> renameType(int id, String name) =>
      (db.update(db.measurementTypes)..where((t) => t.id.equals(id))).write(MeasurementTypesCompanion(name: Value(name.trim())));
  Future<void> deleteType(int id) => (db.delete(db.measurementTypes)..where((t) => t.id.equals(id))).go();

  Future<void> saveMeasurement(int typeId, String date, double value, String note, {int? id}) => db.transaction(() async {
    Dates.validate(date);
    if (!value.isFinite || value <= 0) throw const FormatException('Enter a value greater than zero.');
    if (id != null) {
      final conflict = await (db.select(
        db.measurements,
      )..where((m) => m.typeId.equals(typeId) & m.date.equals(date))).getSingleOrNull();
      if (conflict != null && conflict.id != id) {
        throw const FormatException('That day already has an entry. Choose another date or edit that entry.');
      }
      final changed = await (db.update(db.measurements)..where((m) => m.id.equals(id) & m.typeId.equals(typeId))).write(
        MeasurementsCompanion(date: Value(date), value: Value(value), note: Value(note.trim())),
      );
      if (changed == 0) throw const FormatException('This measurement is no longer available.');
      return;
    }
    await db
        .into(db.measurements)
        .insert(
          MeasurementsCompanion.insert(typeId: typeId, date: date, value: value, note: Value(note.trim())),
          onConflict: DoUpdate(
            (_) => MeasurementsCompanion(value: Value(value), note: Value(note.trim())),
            target: [db.measurements.typeId, db.measurements.date],
          ),
        );
  });

  Future<void> deleteMeasurement(int id) => (db.delete(db.measurements)..where((m) => m.id.equals(id))).go();
  Stream<List<ExerciseGoal>> watchGoals(int exerciseId) =>
      (db.select(db.exerciseGoals)..where((g) => g.exerciseId.equals(exerciseId))).watch();
  Future<void> saveGoal(int exerciseId, String metric, double target, String? date, {int? id}) async {
    if (!target.isFinite || target <= 0) throw const FormatException('Enter a target greater than zero.');
    if (date != null) Dates.validate(date);
    if (id == null) {
      await db
          .into(db.exerciseGoals)
          .insert(ExerciseGoalsCompanion.insert(exerciseId: exerciseId, metric: metric, target: target, targetDate: Value(date)));
    } else {
      await (db.update(db.exerciseGoals)..where((g) => g.id.equals(id) & g.exerciseId.equals(exerciseId))).write(
        ExerciseGoalsCompanion(metric: Value(metric), target: Value(target), targetDate: Value(date)),
      );
    }
  }

  Future<void> deleteGoal(int id) => (db.delete(db.exerciseGoals)..where((g) => g.id.equals(id))).go();
}
