import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fitnotes_plus/core/database/database.dart';
import 'package:fitnotes_plus/core/import/fitnotes_importer.dart';
import 'package:fitnotes_plus/core/repositories/stats_repository.dart';
import 'package:fitnotes_plus/core/util/onerm.dart';

void main() {
  test('Brzycki 1RM matches FitNotes (225 x 5 -> ~253) and round-trips', () {
    expect(OneRm.brzycki(225, 5), closeTo(253.125, 0.001));
    expect(OneRm.brzycki(100, 1), 100);
    expect(OneRm.weightForReps(253.125, 5), closeTo(225, 0.001));
  });

  test('PR detection over imported deadlift history', () async {
    final fixture = [
      'ref/FitNotes_Backup.fitnotes',
      '../ref/FitNotes_Backup.fitnotes',
    ].map(File.new).firstWhere((f) => f.existsSync(), orElse: () => File('ref/FitNotes_Backup.fitnotes'));
    if (!fixture.existsSync()) {
      markTestSkipped('backup fixture not found');
      return;
    }

    final db = AppDatabase.memory();
    addTearDown(db.close);
    await FitNotesImporter(db).importFromFile(fixture.path);

    final exercises = await db.select(db.exercises).get();
    final deadlifts = exercises.where((e) => e.name == 'Deadlift').toList();
    expect(deadlifts, isNotEmpty);
    final deadlift = deadlifts.first;

    final allSets = await db.select(db.workoutSets).get();
    final sets = allSets.where((s) => s.exerciseId == deadlift.id).toList();
    expect(sets, isNotEmpty);

    final prs = Stats.personalRecordSetIds(sets);
    expect(prs, isNotEmpty);

    // The single heaviest set must be a PR for its rep-count.
    final heaviest = sets.reduce((a, b) => (a.rawWeight * a.weightMultiplier) >= (b.rawWeight * b.weightMultiplier) ? a : b);
    expect(prs.contains(heaviest.id), isTrue);
  });
}
