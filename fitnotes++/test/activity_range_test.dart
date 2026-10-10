import 'package:flutter_test/flutter_test.dart';
import 'package:fitnotes_plus/core/database/database.dart';
import 'package:fitnotes_plus/core/repositories/stats_repository.dart';

WorkoutSet _set(String date, {bool planned = false}) => WorkoutSet(
  id: 1,
  exerciseId: 1,
  date: date,
  rawWeight: 60,
  weightMultiplier: 1,
  reps: 8,
  distance: 0,
  durationSeconds: 0,
  isComplete: !planned,
  isPlanned: planned,
  createdAt: DateTime(2026),
);

void main() {
  test('activity clips to the chosen range and excludes unperformed sets', () {
    final sets = [
      _set('2026-10-03'),
      _set('2026-10-04'),
      _set('2026-10-10'),
      _set('2026-10-10', planned: true),
      _set('2026-10-11'),
    ];
    final week = Stats.activity(sets, from: '2026-10-04', to: '2026-10-10');
    expect(week.length, 7);
    expect(week.first, (start: '2026-10-04', end: '2026-10-04', sets: 1));
    expect(week.map((b) => b.sets).reduce((a, b) => a + b), 2);
    final quarter = Stats.activity(sets, from: '2026-07-13', to: '2026-10-10');
    expect(quarter.length, 13);
    expect(quarter.first.start, '2026-07-13');
    expect(quarter.last.end, '2026-10-10');
    expect(quarter.map((b) => b.sets).reduce((a, b) => a + b), 3);
  });

  test('long ranges group calendar months or years without omitting edge dates', () {
    for (final from in ['2025-12-20', '2019-12-20']) {
      final buckets = Stats.activity([_set(from), _set('2026-10-10')], from: from, to: '2026-10-10');
      expect(buckets.first.start, from);
      expect(buckets.last.end, '2026-10-10');
      expect(buckets.first.sets, 1);
      expect(buckets.last.sets, 1);
      expect(buckets.map((b) => b.sets).reduce((a, b) => a + b), 2);
    }
  });
}
