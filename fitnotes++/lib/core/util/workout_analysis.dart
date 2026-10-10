import 'dart:math' as math;

import '../database/database.dart';
import '../repositories/stats_repository.dart';
import '../repositories/workout_repository.dart';
import 'dates.dart';

enum WorkoutMetric {
  volume('Volume per workout'),
  sets('Sets per workout'),
  reps('Reps per workout'),
  duration('Workout duration');

  const WorkoutMetric(this.label);
  final String label;
}

typedef TrendLine = ({double first, double last});

class WorkoutAnalysis {
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
    for (final set in sets) {
      if (!set.isPlanned && set.date.compareTo(from) >= 0 && set.date.compareTo(to) <= 0) {
        (days[set.date] ??= []).add(set);
      }
    }
    final times = {for (final session in sessions) session.date: session};
    return [
      for (final date in (days.keys.toList()..sort()))
        if (metric != WorkoutMetric.duration || times.containsKey(date))
          (
            date: date,
            value: switch (metric) {
              WorkoutMetric.volume => days[date]!.fold<double>(0, (sum, s) => sum + s.rawWeight * s.weightMultiplier * s.reps),
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
