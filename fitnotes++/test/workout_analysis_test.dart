import 'package:flutter_test/flutter_test.dart';
import 'package:fitnotes_plus/core/database/database.dart';
import 'package:fitnotes_plus/core/util/workout_analysis.dart';

WorkoutSet set(String date, double weight, int reps, {bool planned = false, double multiplier = 1}) => WorkoutSet(
  bodyweight: 0,
  id: 1,
  exerciseId: 1,
  date: date,
  rawWeight: weight,
  weightMultiplier: multiplier,
  reps: reps,
  distance: 0,
  durationSeconds: 0,
  isComplete: !planned,
  isPlanned: planned,
  createdAt: DateTime(2026),
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
