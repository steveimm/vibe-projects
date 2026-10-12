import 'dart:math' as math;

import '../database/database.dart';
import '../repositories/stats_repository.dart';
import '../repositories/workout_repository.dart';
import 'dates.dart';

enum WorkoutMetric {
  volume('Volume'),
  sets('Sets'),
  reps('Reps'),
  duration('Workout duration');

  const WorkoutMetric(this.label);
  final String label;
}

typedef TrendLine = ({double first, double last});

class WorkoutAnalysis {
  static Iterable<WorkoutSet> _selected(Iterable<WorkoutSet> sets, String from, String to) =>
      sets.where((s) => !s.isPlanned && s.date.compareTo(from) >= 0 && s.date.compareTo(to) <= 0);

  static Map<int, double> categoryTotals(
    Iterable<WorkoutSet> sets,
    WorkoutMetric metric,
    Map<int, int> categoryByExercise, {
    required String from,
    required String to,
  }) {
    final totals = <int, double>{};
    void add(int exerciseId, double value) {
      final category = categoryByExercise[exerciseId];
      if (category != null && value.isFinite && value > 0) {
        totals.update(category, (total) => total + value, ifAbsent: () => value);
      }
    }

    final selected = _selected(sets, from, to);
    if (metric == WorkoutMetric.duration) {
      final times = <(String, int), ({DateTime first, DateTime last})>{};
      for (final set in selected) {
        final time = set.loggedAt;
        if (time == null) continue;
        final key = (set.date, set.exerciseId);
        final previous = times[key];
        times[key] = (
          first: previous == null || time.isBefore(previous.first) ? time : previous.first,
          last: previous == null || time.isAfter(previous.last) ? time : previous.last,
        );
      }
      for (final entry in times.entries) {
        add(entry.key.$2, entry.value.last.difference(entry.value.first).inSeconds.toDouble());
      }
    } else {
      for (final set in selected) {
        add(set.exerciseId, switch (metric) {
          WorkoutMetric.volume => set.effectiveWeight * set.reps,
          WorkoutMetric.sets => 1,
          WorkoutMetric.reps => set.reps.toDouble(),
          WorkoutMetric.duration => 0,
        });
      }
    }
    return totals;
  }

  static String monthsBefore(String date, int months) {
    final end = Dates.parse(date);
    final month = DateTime(end.year, end.month - months);
    final day = math.min(end.day, DateTime(month.year, month.month + 1, 0).day);
    return Dates.iso(DateTime(month.year, month.month, day));
  }

  static List<MetricPoint> points(
    Iterable<WorkoutSet> sets,
    WorkoutMetric metric, {
    required String from,
    required String to,
    Iterable<WorkoutSession> sessions = const [],
    required DateTime now,
  }) {
    final days = <String, List<WorkoutSet>>{};
    for (final set in _selected(sets, from, to)) {
      (days[set.date] ??= []).add(set);
    }
    final times = {for (final session in sessions) session.date: session};
    return [
      for (final date in (days.keys.toList()..sort()))
        if (metric != WorkoutMetric.duration || times.containsKey(date))
          (
            date: date,
            value: switch (metric) {
              WorkoutMetric.volume => days[date]!.fold<double>(0, (sum, s) => sum + s.effectiveWeight * s.reps),
              WorkoutMetric.sets => days[date]!.length.toDouble(),
              WorkoutMetric.reps => days[date]!.fold<double>(0, (sum, s) => sum + s.reps),
              WorkoutMetric.duration => times[date]!.durationAt(now).toDouble(),
            },
          ),
    ];
  }

  static TrendLine? trend(Iterable<double> input, {Iterable<double>? positions}) {
    final values = input.toList();
    if (values.length < 2 || values.any((v) => !v.isFinite)) return null;
    final x = positions?.toList() ?? List<double>.generate(values.length, (i) => i.toDouble());
    if (x.length != values.length || x.any((v) => !v.isFinite)) return null;
    final meanX = x.reduce((a, b) => a + b) / x.length;
    final meanY = values.reduce((a, b) => a + b) / values.length;
    var numerator = 0.0, denominator = 0.0;
    for (var i = 0; i < values.length; i++) {
      numerator += (x[i] - meanX) * (values[i] - meanY);
      denominator += (x[i] - meanX) * (x[i] - meanX);
    }
    if (denominator == 0) return null;
    final slope = numerator / denominator;
    return (first: meanY + slope * (x.first - meanX), last: meanY + slope * (x.last - meanX));
  }
}
