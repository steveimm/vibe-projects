import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart';

import '../database/database.dart';
import '../database/tables.dart';

/// Result of importing a `.fitnotes` backup.
class ImportResult {
  const ImportResult({required this.categoriesCreated, required this.exercises, required this.sets, required this.dayNotes});

  final int categoriesCreated;
  final int exercises;
  final int sets;
  final int dayNotes;

  @override
  String toString() =>
      'ImportResult(categoriesCreated: $categoriesCreated, exercises: $exercises, '
      'sets: $sets, dayNotes: $dayNotes)';
}

/// Imports an original FitNotes (Android) `.fitnotes` backup — a plain SQLite
/// database — into our [AppDatabase].
///
/// Mapping:
///  - `Category`        -> categories (deduped by name against existing/seed)
///  - `exercise`        -> exercises  (exercise_type_id -> [ExerciseType])
///  - `Comment` (type1) -> per-set note
///  - `training_log`    -> workout_sets (metric_weight -> rawWeight kg,
///                          weightMultiplier = 1.0)
///  - `WorkoutComment`  -> workout_day_notes
///
/// FitNotes' `is_personal_record` flags are ignored — we recompute PRs.
/// Imported source IDs are retained so repeated imports update, rather than duplicate, sets.
class FitNotesImporter {
  FitNotesImporter(this.db);

  final AppDatabase db;

  Future<ImportResult> importFromFile(String sourcePath) async {
    final src = sqlite3.open(sourcePath, mode: OpenMode.readOnly);
    try {
      return await _import(src);
    } finally {
      src.close();
    }
  }

  Future<ImportResult> _import(Database src) async {
    return db.transaction(() async {
      final srcCatToDest = await _importCategories(src);
      final categoriesCreated = _categoriesCreated;

      final srcExToDest = await _importExercises(src, srcCatToDest);
      final comments = _readSetComments(src);
      final sets = await _importSets(src, srcExToDest, comments);
      final dayNotes = await _importDayNotes(src);

      return ImportResult(categoriesCreated: categoriesCreated, exercises: srcExToDest.length, sets: sets, dayNotes: dayNotes);
    });
  }

  int _categoriesCreated = 0;

  Future<Map<int, int>> _importCategories(Database src) async {
    final existing = await db.select(db.categories).get();
    final byName = {for (final c in existing) c.name.toLowerCase(): c.id};
    final map = <int, int>{};
    _categoriesCreated = 0;

    for (final row in src.select('SELECT _id, name, colour, sort_order FROM Category')) {
      final name = row['name'] as String;
      final key = name.toLowerCase();
      var destId = byName[key];
      if (destId == null) {
        destId = await db
            .into(db.categories)
            .insert(
              CategoriesCompanion.insert(
                name: name,
                colorArgb: Value((row['colour'] as int) & 0xFFFFFFFF),
                sortOrder: Value((row['sort_order'] as int?) ?? 0),
              ),
            );
        byName[key] = destId;
        _categoriesCreated++;
      }
      map[row['_id'] as int] = destId;
    }
    return map;
  }

  Future<Map<int, int>> _importExercises(Database src, Map<int, int> srcCatToDest) async {
    final map = <int, int>{};
    final existing = await db.select(db.exercises).get();
    final used = (await db.select(db.workoutSets).get()).map((s) => s.exerciseId).toSet();
    final byName = {for (final e in existing) '${e.name.toLowerCase()}:${e.categoryId}': e};
    final categories = await db.select(db.categories).get();
    if (categories.isEmpty) throw const FormatException('The backup has no usable exercise categories.');
    final fallbackCat = srcCatToDest.values.firstOrNull ?? categories.first.id;
    for (final row in src.select('SELECT _id, name, category_id, exercise_type_id, notes FROM exercise')) {
      final typeId = row['exercise_type_id'] as int? ?? 0;
      final type = switch (typeId) {
        0 => ExerciseType.weightAndReps,
        1 => ExerciseType.distanceAndTime,
        2 => ExerciseType.repsOnly,
        3 => ExerciseType.timeOnly,
        _ => throw FormatException('Unsupported FitNotes exercise type $typeId. No data was imported.'),
      };
      final name = row['name'] as String;
      final cat = srcCatToDest[row['category_id'] as int] ?? fallbackCat;
      final match = byName['${name.toLowerCase()}:$cat'];
      int id;
      if (match != null && (match.type == type || !used.contains(match.id))) {
        id = match.id;
        await (db.update(
          db.exercises,
        )..where((e) => e.id.equals(id))).write(ExercisesCompanion(type: Value(type), notes: Value(row['notes'] as String?)));
      } else {
        id = await db
            .into(db.exercises)
            .insert(
              ExercisesCompanion.insert(name: name, categoryId: cat, type: Value(type), notes: Value(row['notes'] as String?)),
            );
      }
      map[row['_id'] as int] = id;
    }
    return map;
  }

  Map<int, String> _readSetComments(Database src) {
    final map = <int, String>{};
    // owner_type_id == 1 is a training_log (set) comment in FitNotes.
    for (final row in src.select('SELECT owner_id, comment FROM Comment WHERE owner_type_id = 1')) {
      map[row['owner_id'] as int] = row['comment'] as String;
    }
    return map;
  }

  Future<int> _importSets(Database src, Map<int, int> srcExToDest, Map<int, String> comments) async {
    var count = 0;
    final rows = src.select(
      'SELECT _id, exercise_id, date, metric_weight, reps, distance, '
      'duration_seconds, is_complete FROM training_log ORDER BY _id',
    );

    final existing = {
      for (final s in await db.select(db.workoutSets).get())
        if (s.sourceKey != null) s.sourceKey!: s.id,
    };
    await db.batch((b) {
      for (final row in rows) {
        final destEx = srcExToDest[row['exercise_id'] as int];
        if (destEx == null) continue;
        final date = row['date'] as String;
        final sourceKey = 'fitnotes:${row['exercise_id']}:${row['_id']}:$date';
        b.insert(
          db.workoutSets,
          WorkoutSetsCompanion.insert(
            id: existing.containsKey(sourceKey) ? Value(existing[sourceKey]!) : const Value.absent(),
            sourceKey: Value(sourceKey),
            exerciseId: destEx,
            date: date,
            createdAt: _midnight(date),
            rawWeight: Value((row['metric_weight'] as num).toDouble()),
            weightMultiplier: const Value(1.0),
            reps: Value((row['reps'] as num?)?.toInt() ?? 0),
            distance: Value((row['distance'] as num?)?.toDouble() ?? 0),
            durationSeconds: Value((row['duration_seconds'] as num?)?.toInt() ?? 0),
            isComplete: Value((row['is_complete'] as int? ?? 0) == 1),
            note: Value(comments[row['_id'] as int]),
          ),
          mode: InsertMode.insertOrReplace,
        );
        count++;
      }
    });
    return count;
  }

  Future<int> _importDayNotes(Database src) async {
    var count = 0;
    for (final row in src.select('SELECT date, comment FROM WorkoutComment')) {
      await db
          .into(db.workoutDayNotes)
          .insert(
            WorkoutDayNotesCompanion.insert(date: row['date'] as String, comment: row['comment'] as String),
            mode: InsertMode.insertOrReplace,
          );
      count++;
    }
    return count;
  }

  DateTime _midnight(String isoDate) {
    final parts = isoDate.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }
}
