import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fitnotes_plus/core/database/database.dart';
import 'package:fitnotes_plus/core/import/fitnotes_importer.dart';

void main() {
  // The real backup committed under fitnotes++/ref. Resolve it regardless of
  // the test's working directory.
  final fixture = [
    'ref/FitNotes_Backup.fitnotes',
    '../ref/FitNotes_Backup.fitnotes',
  ].map(File.new).firstWhere((f) => f.existsSync(), orElse: () => File('ref/FitNotes_Backup.fitnotes'));

  test('imports the real FitNotes backup with the expected counts', () async {
    expect(fixture.existsSync(), isTrue, reason: 'Missing backup fixture at ${fixture.absolute.path}');

    final db = AppDatabase.memory();
    addTearDown(db.close);

    final result = await FitNotesImporter(db).importFromFile(fixture.path);

    final categories = await db.select(db.categories).get();
    final exercises = await db.select(db.exercises).get();
    final sets = await db.select(db.workoutSets).get();
    final distinctDays = sets.map((s) => s.date).toSet();

    // Ground-truth counts decoded directly from the backup.
    expect(categories.length, 9, reason: 'categories');
    expect(exercises.length, 180, reason: 'exercises');
    expect(result.sets, 7560, reason: 'imported set count');
    expect(sets.length, 7560, reason: 'persisted set count');
    expect(distinctDays.length, 338, reason: 'distinct workout days');

    // Seed categories already covered all 9 names, so none were newly created.
    expect(result.categoriesCreated, 0, reason: 'no new categories');
  });

  test('weights import unscaled and effective weight = raw in v1', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    await FitNotesImporter(db).importFromFile(fixture.path);

    final sets = await db.select(db.workoutSets).get();
    // Half-kg plates exist in the data (e.g. 122.5kg deadlifts).
    expect(sets.any((s) => s.rawWeight == 122.5), isTrue);
    // v1: multiplier defaults to 1.0, so effective == raw everywhere.
    expect(sets.every((s) => s.weightMultiplier == 1.0), isTrue);
  });
}
