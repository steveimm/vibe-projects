import 'package:drift/drift.dart';

import '../database/database.dart';
import '../database/tables.dart';
import '../models/weight_multiplier.dart';

/// An exercise plus its display category and usage stats (for the list).
class ExerciseListItem {
  ExerciseListItem({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.colorArgb,
    required this.type,
    required this.isFavourite,
    required this.workoutCount,
    required this.lastDate,
  });

  final int id;
  final String name;
  final int categoryId;
  final String categoryName;
  final int colorArgb;
  final ExerciseType type;
  final bool isFavourite;
  final int workoutCount;
  final String? lastDate;
}

class ExerciseRepository {
  ExerciseRepository(this.db);

  final AppDatabase db;

  Stream<List<Category>> watchCategories() =>
      (db.select(db.categories)..orderBy([(c) => OrderingTerm(expression: c.name)])).watch();

  Future<List<Category>> getCategories() => (db.select(db.categories)..orderBy([(c) => OrderingTerm(expression: c.name)])).get();

  Stream<List<ExerciseListItem>> watchExercises({
    String? search,
    int? categoryId,
    bool archived = false,
    bool favourites = false,
  }) {
    final where = <String>['e.archived = ${archived ? 1 : 0}'];
    if (favourites) where.add('e.is_favourite = 1');
    final vars = <Variable>[];
    if (search != null && search.trim().isNotEmpty) {
      where.add("e.name LIKE '%' || ? || '%'"); // LIKE is case-insensitive (ASCII)
      vars.add(Variable.withString(search.trim()));
    }
    if (categoryId != null) {
      where.add('e.category_id = ?');
      vars.add(Variable.withInt(categoryId));
    }
    final sql =
        '''
      SELECT e.id, e.name, e.category_id, e.type, e.is_favourite,
             c.name AS category_name, c.color_argb AS color_argb,
             (SELECT COUNT(DISTINCT s.date) FROM workout_sets s
                WHERE s.exercise_id = e.id AND s.is_planned = 0) AS workout_count,
             (SELECT MAX(s.date) FROM workout_sets s
                WHERE s.exercise_id = e.id AND s.is_planned = 0) AS last_date
      FROM exercises e
      JOIN categories c ON c.id = e.category_id
      WHERE ${where.join(' AND ')}
      ORDER BY e.name COLLATE NOCASE
    ''';
    return db
        .customSelect(sql, variables: vars, readsFrom: {db.exercises, db.categories, db.workoutSets})
        .watch()
        .map(
          (rows) => rows
              .map(
                (r) => ExerciseListItem(
                  id: r.read<int>('id'),
                  name: r.read<String>('name'),
                  categoryId: r.read<int>('category_id'),
                  categoryName: r.read<String>('category_name'),
                  colorArgb: r.read<int>('color_argb'),
                  type: ExerciseType.values[r.read<int>('type')],
                  isFavourite: r.read<int>('is_favourite') == 1,
                  workoutCount: r.read<int>('workout_count'),
                  lastDate: r.readNullable<String>('last_date'),
                ),
              )
              .toList(),
        );
  }

  Future<Exercise> getExercise(int id) => (db.select(db.exercises)..where((e) => e.id.equals(id))).getSingle();

  Stream<Exercise> watchExercise(int id) => (db.select(db.exercises)..where((e) => e.id.equals(id))).watchSingle();

  Future<int> createExercise({
    required String name,
    required int categoryId,
    required ExerciseType type,
    String? notes,
    int? restSeconds,
    double? weightIncrement,
    Value<WeightUnit?> weightUnit = const Value.absent(),
    Value<bool> includeBodyweight = const Value.absent(),
    List<MultiplierValue>? multipliers,
  }) => db.transaction(() async {
    final id = await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: name,
            categoryId: categoryId,
            type: Value(type),
            notes: Value(notes),
            defaultRestTimeSeconds: Value(restSeconds),
            weightIncrement: Value(weightIncrement),
            weightUnit: weightUnit,
            includeBodyweight: includeBodyweight,
          ),
        );
    if (multipliers != null) await _replaceMultipliers(id, multipliers);
    return id;
  });

  Future<void> setRestDuration(int id, int? seconds) async {
    if (seconds != null && (seconds < 1 || seconds > 3600)) throw const FormatException('Use 1 second to 60 minutes.');
    await (db.update(
      db.exercises,
    )..where((e) => e.id.equals(id))).write(ExercisesCompanion(defaultRestTimeSeconds: Value(seconds)));
  }

  Future<void> updateExercise({
    required int id,
    required String name,
    required int categoryId,
    required ExerciseType type,
    String? notes,
    int? restSeconds,
    double? weightIncrement,
    Value<WeightUnit?> weightUnit = const Value.absent(),
    Value<bool> includeBodyweight = const Value.absent(),
    List<MultiplierValue>? multipliers,
  }) => db.transaction(() async {
    final old = await getExercise(id);
    if (old.type != type) {
      final sets =
          await (db.select(db.workoutSets)
                ..where((s) => s.exerciseId.equals(id))
                ..limit(1))
              .get();
      final templates =
          await (db.select(db.routineSets)
                ..where((s) => s.exerciseId.equals(id))
                ..limit(1))
              .get();
      if (sets.isNotEmpty || templates.isNotEmpty) {
        throw const FormatException('This exercise has logged sets or templates. Create a new exercise to use a different type.');
      }
    }
    await (db.update(db.exercises)..where((e) => e.id.equals(id))).write(
      ExercisesCompanion(
        name: Value(name.trim()),
        categoryId: Value(categoryId),
        type: Value(type),
        notes: Value(notes),
        defaultRestTimeSeconds: Value(restSeconds),
        weightIncrement: Value(weightIncrement),
        weightUnit: weightUnit,
        includeBodyweight: includeBodyweight,
      ),
    );
    if (multipliers != null) await _replaceMultipliers(id, multipliers);
  });

  Future<void> setFavourite(int id, bool value) =>
      (db.update(db.exercises)..where((e) => e.id.equals(id))).write(ExercisesCompanion(isFavourite: Value(value)));

  Future<void> setArchived(int id, bool value) =>
      (db.update(db.exercises)..where((e) => e.id.equals(id))).write(ExercisesCompanion(archived: Value(value)));

  Future<void> updateCategory(int id, String name, int color) => (db.update(
    db.categories,
  )..where((c) => c.id.equals(id))).write(CategoriesCompanion(name: Value(name.trim()), colorArgb: Value(color)));

  Future<void> deleteCategory(int id) async {
    final exercises =
        await (db.select(db.exercises)
              ..where((e) => e.categoryId.equals(id))
              ..limit(1))
            .get();
    if (exercises.isNotEmpty) {
      throw const FormatException('Move the exercises to another category first, including archived exercises.');
    }
    await (db.delete(db.categories)..where((c) => c.id.equals(id))).go();
  }

  Stream<List<ExerciseMultiplier>> watchMultipliers(int exerciseId) =>
      (db.select(db.exerciseMultipliers)
            ..where((m) => m.exerciseId.equals(exerciseId))
            ..orderBy([(m) => OrderingTerm.asc(m.id)]))
          .watch();

  Future<void> saveMultiplier({
    int? id,
    required int exerciseId,
    String label = '',
    required double factor,
    bool enabled = true,
  }) async {
    final existing = await watchMultipliers(exerciseId).first;
    validateMultipliers([
      for (final m in existing.where((m) => m.id != id)) (label: m.label, factor: m.factor, enabled: m.enabled),
      (label: label, factor: factor, enabled: enabled),
    ]);
    final entry = ExerciseMultipliersCompanion(
      exerciseId: Value(exerciseId),
      label: Value(
        label.trim().isEmpty ? nextMultiplierName(existing.where((m) => m.id != id).map((m) => m.label)) : label.trim(),
      ),
      factor: Value(factor),
      enabled: Value(enabled),
    );
    if (id == null) {
      await db.into(db.exerciseMultipliers).insert(entry);
    } else {
      await (db.update(db.exerciseMultipliers)..where((m) => m.id.equals(id))).write(entry);
    }
  }

  Future<void> deleteMultiplier(int id) => (db.delete(db.exerciseMultipliers)..where((m) => m.id.equals(id))).go();

  Future<void> _replaceMultipliers(int exerciseId, List<MultiplierValue> values) async {
    validateMultipliers(values);
    final labels = values.map((m) => m.label.trim()).where((label) => label.isNotEmpty).toSet();
    await (db.delete(db.exerciseMultipliers)..where((m) => m.exerciseId.equals(exerciseId))).go();
    for (final value in values) {
      final label = value.label.trim().isEmpty ? nextMultiplierName(labels) : value.label.trim();
      labels.add(label);
      await db
          .into(db.exerciseMultipliers)
          .insert(
            ExerciseMultipliersCompanion.insert(
              exerciseId: exerciseId,
              label: label,
              factor: Value(value.factor),
              enabled: Value(value.enabled),
            ),
          );
    }
  }

  Future<int> createCategory({required String name, required int colorArgb}) =>
      db.into(db.categories).insert(CategoriesCompanion.insert(name: name, colorArgb: Value(colorArgb)));
}
