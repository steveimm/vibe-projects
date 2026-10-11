import 'dart:math' as math;

import '../database/database.dart';
import '../database/tables.dart';
import '../util/onerm.dart';

// Keys are also persisted in exercise goals and backups.
enum GraphMetric {
  estimated1rm('Estimated max weight'),
  maxWeight('Max weight'),
  workoutVolume('Volume'),
  totalReps('Total reps'),
  maxReps('Max reps'),
  weightAtReps('Weight at reps'),
  maxDistance('Longest distance'),
  totalDistance('Total distance'),
  maxTime('Longest time'),
  totalTime('Total time'),
  maxSpeed('Fastest speed'),
  bestPace('Best pace');

  const GraphMetric(this.label);
  final String label;

  bool get isWeight => [estimated1rm, maxWeight, workoutVolume, weightAtReps].contains(this);
  bool get isDistance => [maxDistance, totalDistance].contains(this);
  bool get isTime => [maxTime, totalTime].contains(this);
  static List<GraphMetric> forType(ExerciseType type) => [
    if (type.hasWeight && type.hasReps) estimated1rm,
    if (type.hasWeight) maxWeight,
    if (type.hasWeight && type.hasReps) ...[workoutVolume, weightAtReps],
    if (type.hasReps) ...[totalReps, maxReps],
    if (type.hasDistance) ...[maxDistance, totalDistance],
    if (type.hasTime) ...[maxTime, totalTime],
    if (type.hasDistance && type.hasTime) ...[maxSpeed, bestPace],
  ];
}

typedef MetricPoint = ({String date, double value});

enum RecordScope { allTime, currentSeason }

class Stats {
  Stats._();
  static const allTime = '0000-01-01';
  static double effective(WorkoutSet s) => s.effectiveWeight;

  static List<WorkoutSet> _chronological(List<WorkoutSet> sets) => [...sets]
    ..sort((a, b) {
      final date = a.date.compareTo(b.date);
      if (date != 0) return date;
      final time = a.createdAt.compareTo(b.createdAt);
      return time != 0 ? time : a.id.compareTo(b.id);
    });

  static Set<int> personalRecordSetIds(
    List<WorkoutSet> sets, {
    String sinceDate = allTime,
    ExerciseType type = ExerciseType.weightAndReps,
  }) {
    final best = <int, double>{};
    final ids = <int>{};
    for (final s in _chronological(sets)) {
      if (s.isPlanned || s.date.compareTo(sinceDate) < 0) continue;
      if (type == ExerciseType.distanceAndTime) {
        for (final metric in {0: s.distance, 1: s.durationSeconds.toDouble()}.entries) {
          if (metric.value > (best[metric.key] ?? 0)) {
            ids.add(s.id);
            best[metric.key] = metric.value;
          }
        }
        continue;
      }
      final value = type.hasWeight
          ? effective(s)
          : type.hasDistance
          ? s.distance
          : type.hasReps
          ? s.reps.toDouble()
          : s.durationSeconds.toDouble();
      if (value <= 0) continue;
      final reps = type.hasWeight && type.hasReps ? s.reps : 0;
      if (type.hasReps && s.reps <= 0) continue;
      final superseded = best.entries.any((e) => e.key >= reps && e.value >= value);
      if (!superseded) ids.add(s.id);
      best[reps] = math.max(best[reps] ?? 0, value);
    }
    return ids;
  }

  static Map<int, double> repMaxes(List<WorkoutSet> sets, {String sinceDate = allTime}) {
    final best = <int, double>{};
    for (final s in sets) {
      if (s.isPlanned || s.reps <= 0 || s.date.compareTo(sinceDate) < 0) continue;
      best[s.reps] = math.max(best[s.reps] ?? 0, effective(s));
    }
    return best;
  }

  static List<MetricPoint> graph(
    List<WorkoutSet> sets,
    GraphMetric metric, {
    String sinceDate = allTime,
    int max1rmReps = 0,
    int atReps = 5,
  }) {
    final byDay = <String, List<WorkoutSet>>{};
    for (final s in sets) {
      if (s.isPlanned || s.date.compareTo(sinceDate) < 0) continue;
      (byDay[s.date] ??= []).add(s);
    }
    final points = <MetricPoint>[];
    for (final entry in byDay.entries) {
      final values = <double>[];
      for (final s in entry.value) {
        final weight = effective(s);
        final double? value = switch (metric) {
          GraphMetric.estimated1rm =>
            weight > 0 && s.reps > 0 && s.reps < 37 && (max1rmReps == 0 || s.reps <= max1rmReps)
                ? OneRm.brzycki(weight, s.reps)
                : null,
          GraphMetric.maxWeight => weight,
          GraphMetric.workoutVolume => weight * s.reps,
          GraphMetric.totalReps || GraphMetric.maxReps => s.reps.toDouble(),
          GraphMetric.weightAtReps => s.reps == atReps ? weight : null,
          GraphMetric.maxDistance || GraphMetric.totalDistance => s.distance > 0 ? s.distance : null,
          GraphMetric.maxTime || GraphMetric.totalTime => s.durationSeconds > 0 ? s.durationSeconds.toDouble() : null,
          GraphMetric.maxSpeed => s.durationSeconds > 0 && s.distance > 0 ? s.distance / s.durationSeconds : null,
          GraphMetric.bestPace => s.durationSeconds > 0 && s.distance > 0 ? s.durationSeconds / (s.distance / 1000) : null,
        };
        if (value != null && value.isFinite) values.add(value);
      }
      if (values.isEmpty) continue;
      final total = [
        GraphMetric.workoutVolume,
        GraphMetric.totalReps,
        GraphMetric.totalDistance,
        GraphMetric.totalTime,
      ].contains(metric);
      final value = total
          ? values.fold<double>(0, (a, b) => a + b)
          : values.reduce(metric == GraphMetric.bestPace ? math.min : math.max);
      points.add((date: entry.key, value: value));
    }
    return points..sort((a, b) => a.date.compareTo(b.date));
  }
}
