import 'package:flutter_test/flutter_test.dart';
import 'package:fitnotes_plus/core/database/database.dart';
import 'package:fitnotes_plus/core/database/tables.dart';
import 'package:fitnotes_plus/core/repositories/stats_repository.dart';

WorkoutSet logged(
  int id,
  double weight,
  int reps, {
  String date = '2026-10-15',
  double multiplier = 1,
  double bodyweight = 0,
  double distance = 0,
  int seconds = 0,
  bool planned = false,
}) => WorkoutSet(
  id: id,
  exerciseId: 1,
  date: date,
  rawWeight: weight,
  weightMultiplier: multiplier,
  bodyweight: bodyweight,
  reps: reps,
  distance: distance,
  durationSeconds: seconds,
  isComplete: !planned,
  isPlanned: planned,
  createdAt: DateTime.parse(date).add(Duration(seconds: id)),
);

void main() {
  test('a heavier set replaces a weaker record for the same reps on the same or another day', () {
    final first = logged(1, 100, 10);
    final second = logged(2, 120, 10);
    expect(Stats.personalRecordSetIds([first]), {1});
    expect(Stats.personalRecordSetIds([first, second]), {2});
    expect(Stats.personalRecordSetIds([second, first.copyWith(date: '2026-10-14')]), {2});
    expect(Stats.personalRecordSetIds([first, second, logged(3, 110, 10), logged(4, 200, 10, planned: true)]), {2});
    expect(Stats.personalRecordSetIds([first, second.copyWith(rawWeight: 90)]), {1});
  });

  test('ties keep the earliest set, independent of input ordering', () {
    final sets = [logged(1, 100, 10), logged(2, 120, 10), logged(3, 120, 10)];
    expect(Stats.personalRecordSetIds(sets), {2});
    expect(Stats.personalRecordSetIds(sets.reversed.toList()), {2});
    expect(Stats.personalRecordSetIds([logged(1, 120, 10), logged(99, 120, 10, date: '2026-10-14')]), {99});
  });

  test('higher reps at equal or greater weight replace lower-rep records, while weight-rep tradeoffs remain', () {
    final sets = [logged(1, 100, 10), logged(2, 120, 10), logged(3, 120, 10), logged(4, 120, 12)];
    expect(Stats.personalRecordSetIds(sets), {4});
    sets.add(logged(5, 140, 8));
    expect(Stats.personalRecordSetIds(sets), {4, 5});
    sets.addAll([logged(6, 130, 15), logged(7, 110, 5)]);
    expect(Stats.personalRecordSetIds(sets), {5, 6});
  });

  test('record comparison uses captured effective kilograms and the selected date scope', () {
    final sets = [
      logged(1, 150, 10, date: '2026-09-01'),
      logged(2, 100, 10),
      logged(3, 40, 10, multiplier: 0.5, bodyweight: 90),
      logged(4, 0, 10),
    ];
    expect(Stats.personalRecordSetIds(sets), {1});
    expect(Stats.personalRecordSetIds(sets, sinceDate: '2026-10-01'), {3});
  });

  test('non-strength record types mark their current best values instead of every improvement', () {
    final cases = {
      ExerciseType.repsOnly: [logged(1, 0, 8), logged(2, 0, 12)],
      ExerciseType.weightOnly: [logged(1, 100, 0), logged(2, 120, 0)],
      ExerciseType.timeOnly: [logged(1, 0, 0, seconds: 30), logged(2, 0, 0, seconds: 60)],
      ExerciseType.distanceOnly: [logged(1, 0, 0, distance: 1000), logged(2, 0, 0, distance: 2000)],
    };
    for (final entry in cases.entries) {
      expect(Stats.personalRecordSetIds(entry.value, type: entry.key), {2});
    }
    expect(
      Stats.personalRecordSetIds([
        logged(1, 0, 0, distance: 1000, seconds: 120),
        logged(2, 0, 0, distance: 2000, seconds: 90),
        logged(3, 0, 0, distance: 1500, seconds: 180),
      ], type: ExerciseType.distanceAndTime),
      {2, 3},
    );
  });
}
