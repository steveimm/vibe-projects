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

enum RecordScope { allTime, season }

typedef RecordAchievement = ({RecordScope scope, PrResetMarker? season});

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
    final best = <int, ({int id, double value})>{};
    void recordBest(int key, double value, int id) {
      if (value.isFinite && value > 0 && value > (best[key]?.value ?? 0)) best[key] = (id: id, value: value);
    }

    for (final s in _chronological(sets)) {
      if (s.isPlanned || s.date.compareTo(sinceDate) < 0) continue;
      if (type == ExerciseType.distanceAndTime) {
        recordBest(0, s.distance, s.id);
        recordBest(1, s.durationSeconds.toDouble(), s.id);
        continue;
      }
      final value = type.hasWeight
          ? effective(s)
          : type.hasDistance
          ? s.distance
          : type.hasReps
          ? s.reps.toDouble()
          : s.durationSeconds.toDouble();
      final reps = type.hasWeight && type.hasReps ? s.reps : 0;
      if (type.hasReps && s.reps <= 0) continue;
      recordBest(reps, value, s.id);
    }
    return {
      for (final entry in best.entries)
        if (!(type.hasWeight && type.hasReps) ||
            !best.entries.any((other) => other.key > entry.key && other.value.value >= entry.value.value))
          entry.value.id,
    };
  }

  static Map<int, RecordAchievement> recordAchievements(
    List<WorkoutSet> sets,
    List<PrResetMarker> seasons, {
    ExerciseType type = ExerciseType.weightAndReps,
  }) {
    final ordered = [...seasons]
      ..sort((a, b) {
        final date = a.date.compareTo(b.date);
        return date != 0 ? date : a.id.compareTo(b.id);
      });
    final grouped = <int, List<WorkoutSet>>{};
    for (final set in sets) {
      final started = ordered.where((season) => season.date.compareTo(set.date) <= 0).toList();
      if (started.isEmpty || set.isPlanned) continue;
      final season = started.last;
      (grouped[season.id] ??= []).add(set);
    }
    return {
      for (final season in ordered)
        for (final id in personalRecordSetIds(grouped[season.id] ?? [], type: type))
          id: (scope: RecordScope.season, season: season),
      for (final id in personalRecordSetIds(sets, type: type)) id: (scope: RecordScope.allTime, season: null),
    };
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
