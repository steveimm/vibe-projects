import 'package:flutter_test/flutter_test.dart';
import 'package:fitnotes_plus/core/database/database.dart';
import 'package:fitnotes_plus/core/util/workout_analysis.dart';

WorkoutSet set(
  String date,
  double weight,
  int reps, {
  bool planned = false,
  double multiplier = 1,
  double bodyweight = 0,
  int exerciseId = 1,
  DateTime? loggedAt,
}) => WorkoutSet(
  bodyweight: bodyweight,
  id: 1,
  exerciseId: exerciseId,
  date: date,
  rawWeight: weight,
  weightMultiplier: multiplier,
  reps: reps,
  distance: 0,
  durationSeconds: 0,
  isComplete: !planned,
  isPlanned: planned,
  createdAt: DateTime(2026),
  loggedAt: loggedAt,
);

void main() {
  final now = DateTime(2026, 10, 10, 10);
  final fixture = [
    set('2026-10-08', 60, 8),
    set('2026-10-08', 60, 8),
    set('2026-10-10', 50, 8),
    set('2026-10-10', 55, 6),
    set('2026-10-05', 20, 10),
  ];
  test('per-workout totals match the dataset tested in original FitNotes', () {
    for (final metric in WorkoutMetric.values.where((m) => m != WorkoutMetric.duration)) {
      final points = WorkoutAnalysis.points(fixture, metric, from: '2026-09-10', to: '2026-10-10', now: now);
      expect(points.map((p) => p.date), ['2026-10-05', '2026-10-08', '2026-10-10']);
      expect(points.map((p) => p.value), switch (metric) {
        WorkoutMetric.volume => [200.0, 960.0, 730.0],
        WorkoutMetric.sets => [1.0, 2.0, 2.0],
        _ => [10.0, 16.0, 14.0],
      });
    }
    final points = WorkoutAnalysis.points(
      [...fixture, set('2026-10-08', 100, 10, planned: true), set('2026-10-11', 100, 10), set('2026-10-07', 100, 10)],
      WorkoutMetric.volume,
      from: '2026-10-08',
      to: '2026-10-10',
      now: now,
    );
    expect(points.map((p) => p.value), [960.0, 730.0]);
    expect(
      WorkoutAnalysis.points(
        [set('2026-10-10', 20, 8, multiplier: 2)],
        WorkoutMetric.volume,
        from: '2026-10-10',
        to: '2026-10-10',
        now: now,
      ).single.value,
      320,
    );
  });

  test('month ranges clamp short months and cross year boundaries correctly', () {
    expect(WorkoutAnalysis.monthsBefore('2024-03-31', 1), '2024-02-29');
    expect(WorkoutAnalysis.monthsBefore('2025-03-31', 1), '2025-02-28');
    expect(WorkoutAnalysis.monthsBefore('2026-01-31', 3), '2025-10-31');
    expect(WorkoutAnalysis.monthsBefore('2026-10-10', 6), '2026-04-10');
  });

  test('category volume, set and rep totals respect snapshots, dates and performed status', () {
    final sets = [
      set('2026-10-10', 100, 10, multiplier: 0.5, bodyweight: 80),
      set('2026-10-10', 20, 5, exerciseId: 2),
      set('2026-10-11', 40, 3, exerciseId: 3),
      set('2026-10-09', 100, 10),
      set('2026-10-12', 100, 10),
      set('2026-10-10', 100, 10, planned: true),
    ];
    final categories = {1: 10, 2: 10, 3: 20};
    for (final entry in {
      WorkoutMetric.volume: {10: 1400.0, 20: 120.0},
      WorkoutMetric.sets: {10: 2.0, 20: 1.0},
      WorkoutMetric.reps: {10: 15.0, 20: 3.0},
    }.entries) {
      expect(WorkoutAnalysis.categoryTotals(sets, entry.key, categories, from: '2026-10-10', to: '2026-10-11'), entry.value);
    }
    expect(
      WorkoutAnalysis.categoryTotals(
        [set('2026-10-10', 0, 0)],
        WorkoutMetric.volume,
        categories,
        from: '2026-10-10',
        to: '2026-10-11',
      ),
      isEmpty,
    );
  });

  test('duration sums each exercise span per day, ignoring unknown, single and planned times', () {
    WorkoutSet timed(String day, int exercise, int minute, {bool planned = false}) => set(
      day,
      20,
      10,
      exerciseId: exercise,
      loggedAt: DateTime.parse('${day}T10:00:00').add(Duration(minutes: minute)),
      planned: planned,
    );
    final sets = [
      timed('2026-10-10', 1, 4),
      timed('2026-10-10', 1, 0),
      timed('2026-10-10', 2, 10),
      timed('2026-10-10', 2, 16),
      timed('2026-10-10', 3, 20),
      timed('2026-10-10', 3, 22),
      timed('2026-10-11', 1, 0),
      timed('2026-10-11', 1, 3),
      timed('2026-10-10', 1, 45, planned: true),
      timed('2026-10-09', 1, 0),
      timed('2026-10-09', 1, 55),
      timed('2026-10-12', 1, 0),
      timed('2026-10-12', 1, 55),
      timed('2026-10-10', 4, 30),
      timed('2026-10-10', 5, 30),
      timed('2026-10-10', 5, 30),
      set('2026-10-10', 20, 10),
      set('2026-10-10', 20, 10, exerciseId: 6),
    ];
    expect(
      WorkoutAnalysis.categoryTotals(
        sets,
        WorkoutMetric.duration,
        {1: 10, 2: 10, 3: 20, 4: 30, 5: 30, 6: 30},
        from: '2026-10-10',
        to: '2026-10-11',
      ),
      {10: 780.0, 20: 120.0},
    );
  });

  test('duration includes recorded elapsed time and running time without inventing missing times', () {
    final sessions = [
      WorkoutSession(date: '2026-10-08', startedAt: now, elapsedSeconds: 1800),
      WorkoutSession(
        date: '2026-10-10',
        startedAt: now,
        elapsedSeconds: 1200,
        runningSince: now.subtract(const Duration(minutes: 5)),
      ),
      WorkoutSession(date: '2026-10-09', startedAt: now, elapsedSeconds: 500),
    ];
    final points = WorkoutAnalysis.points(
      fixture,
      WorkoutMetric.duration,
      from: '2026-09-10',
      to: '2026-10-10',
      sessions: sessions,
      now: now,
    );
    expect(points, [(date: '2026-10-08', value: 1800.0), (date: '2026-10-10', value: 1500.0)]);
  });

  test('trend is a linear fit over workouts and handles missing or constant data', () {
    expect(WorkoutAnalysis.trend([]), isNull);
    expect(WorkoutAnalysis.trend([1]), isNull);
    expect(WorkoutAnalysis.trend([2, 2, 2]), (first: 2.0, last: 2.0));
    expect(WorkoutAnalysis.trend([200, 960, 730]), (first: 365.0, last: 895.0));
    final dated = WorkoutAnalysis.trend([200, 960, 730], positions: [0, 3, 5])!;
    expect(dated.first, closeTo(316.315789, 0.000001));
    expect(dated.last, closeTo(904.473684, 0.000001));
    expect(WorkoutAnalysis.trend([1, 2], positions: [0, 0]), isNull);
    expect(WorkoutAnalysis.trend([double.nan, 2]), isNull);
  });
}
