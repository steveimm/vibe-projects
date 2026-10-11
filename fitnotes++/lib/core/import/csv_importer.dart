import 'package:drift/drift.dart';

import '../database/database.dart';
import '../database/tables.dart';
import '../models/set_values.dart';
import '../util/dates.dart';
import '../util/format.dart';
import 'fitnotes_importer.dart';

class CsvImporter {
  CsvImporter(this.db);
  final AppDatabase db;

  Future<ImportResult> import(String contents) => db.transaction(() async {
    final rows = parseCsv(contents.replaceFirst('\uFEFF', ''));
    if (rows.isEmpty) throw const FormatException('The CSV file is empty.');
    final header = rows.first.map((s) => s.trim().toLowerCase()).toList();
    for (final key in ['date', 'exercise', 'category', 'reps']) {
      if (!header.contains(key)) throw FormatException('Missing CSV column: $key.');
    }
    String field(List<String> row, String name) {
      final i = header.indexOf(name);
      return i < 0 || i >= row.length ? '' : row[i].trim();
    }

    final categories = {for (final c in await db.select(db.categories).get()) c.name.toLowerCase(): c.id};
    final exercises = {
      for (final e in await db.select(db.exercises).get()) '${e.name.toLowerCase()}:${e.categoryId}:${e.type.index}': e.id,
    };
    final saved = await db.select(db.workoutSets).get();
    final existing = {
      for (final s in saved)
        if (s.sourceKey != null) s.sourceKey!: s,
    };
    String signature(String date, int exerciseId, double weight, int reps, double distance, int seconds) =>
        '$date:$exerciseId:${weight.toStringAsFixed(6)}:$reps:${distance.toStringAsFixed(6)}:$seconds';
    final matching = <String, List<WorkoutSet>>{};
    for (final set in saved.where((s) => !s.isPlanned)) {
      final key = signature(set.date, set.exerciseId, set.effectiveWeight, set.reps, set.distance, set.durationSeconds);
      (matching[key] ??= []).add(set);
    }
    final occurrences = <String, int>{};
    final importedExercises = <int>{};
    var createdCategories = 0;
    var count = 0;
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((v) => v.trim().isEmpty)) continue;
      final date = field(row, 'date');
      Dates.validate(date);
      final name = field(row, 'exercise');
      final category = field(row, 'category');
      if (name.isEmpty || category.isEmpty) throw FormatException('Row ${i + 1}: exercise and category are required.');
      final weightText = field(row, 'weight').isNotEmpty ? field(row, 'weight') : field(row, 'weight (lbs)');
      final repsText = field(row, 'reps');
      final distanceText = field(row, 'distance');
      final timeText = field(row, 'time');
      final type = ExerciseType.values
          .where(
            (t) =>
                t.hasWeight == weightText.isNotEmpty &&
                t.hasReps == repsText.isNotEmpty &&
                t.hasDistance == distanceText.isNotEmpty &&
                t.hasTime == timeText.isNotEmpty,
          )
          .firstOrNull;
      if (type == null) throw FormatException('Row ${i + 1}: unsupported combination of set fields.');
      double number(String value) {
        if (value.isEmpty) return 0;
        final parsed = double.tryParse(value);
        if (parsed == null || !parsed.isFinite || parsed < 0) throw FormatException('Row ${i + 1}: invalid number.');
        return parsed;
      }

      final weightUnit = field(row, 'weight unit').toLowerCase();
      if (type.hasWeight && !['', 'kg', 'kgs', 'lb', 'lbs'].contains(weightUnit)) {
        throw FormatException('Row ${i + 1}: unknown weight unit.');
      }
      final imperial = ['lb', 'lbs'].contains(weightUnit) || header.contains('weight (lbs)');
      final weight = Units(imperial).weightToKg(number(weightText));
      final distanceUnit = field(row, 'distance unit').toLowerCase();
      if (type.hasDistance && !['', 'm', 'km', 'mi'].contains(distanceUnit)) {
        throw FormatException('Row ${i + 1}: unknown distance unit.');
      }
      final distance =
          number(distanceText) *
          (distanceUnit == 'km'
              ? 1000
              : distanceUnit == 'mi'
              ? 1609.344
              : 1);
      final reps = repsText.isEmpty ? 0 : int.tryParse(repsText);
      final seconds = timeText.isEmpty ? 0 : Fmt.parseDuration(timeText);
      if (reps == null || seconds == null) throw FormatException('Row ${i + 1}: invalid reps or duration.');
      SetValues(weight: weight, reps: reps, distance: distance, seconds: seconds).validate(type);
      var categoryId = categories[category.toLowerCase()];
      if (categoryId == null) {
        categoryId = await db.into(db.categories).insert(CategoriesCompanion.insert(name: category));
        categories[category.toLowerCase()] = categoryId;
        createdCategories++;
      }
      final key = '${name.toLowerCase()}:$categoryId:${type.index}';
      var exerciseId = exercises[key];
      if (exerciseId == null) {
        exerciseId = await db
            .into(db.exercises)
            .insert(ExercisesCompanion.insert(name: name, categoryId: categoryId, type: Value(type)));
        exercises[key] = exerciseId;
      }
      importedExercises.add(exerciseId);
      final keySignature = signature(date, exerciseId, weight, reps, distance, seconds);
      final occurrence = occurrences.update(keySignature, (n) => n + 1, ifAbsent: () => 0);
      final sourceKey = 'csv:$keySignature:$occurrence';
      final previous = existing[sourceKey];
      if (previous == null && (matching[keySignature]?.length ?? 0) > occurrence) {
        count++;
        continue;
      }
      await db
          .into(db.workoutSets)
          .insert(
            WorkoutSetsCompanion.insert(
              id: previous == null ? const Value.absent() : Value(previous.id),
              rpe: Value(previous?.rpe),
              groupName: Value(previous?.groupName),
              exerciseId: exerciseId,
              date: date,
              createdAt: Dates.parse(date).add(Duration(seconds: i)),
              rawWeight: Value(weight),
              reps: Value(reps),
              distance: Value(distance),
              durationSeconds: Value(seconds),
              note: Value(field(row, 'comment').isEmpty ? null : field(row, 'comment')),
              isComplete: const Value(true),
              sourceKey: Value(sourceKey),
            ),
            mode: InsertMode.insertOrReplace,
          );
      count++;
    }
    return ImportResult(categoriesCreated: createdCategories, exercises: importedExercises.length, sets: count, dayNotes: 0);
  });
}

List<List<String>> parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  var cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (c == '"') {
      if (quoted && i + 1 < text.length && text[i + 1] == '"') {
        cell.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (c == ',' && !quoted) {
      row.add(cell.toString());
      cell = StringBuffer();
    } else if ((c == '\n' || c == '\r') && !quoted) {
      row.add(cell.toString());
      rows.add(row);
      row = [];
      cell = StringBuffer();
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
    } else {
      cell.write(c);
    }
  }
  if (quoted) throw const FormatException('The CSV file has an unfinished quoted field.');
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows;
}
