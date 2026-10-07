import '../database/tables.dart';

class Units {
  const Units([this.imperial = false]);
  final bool imperial;
  String get weightLabel => imperial ? 'lb' : 'kg';
  String get distanceLabel => imperial ? 'mi' : 'km';
  String get lengthLabel => imperial ? 'in' : 'cm';
  double weightFromKg(double kg) => imperial ? kg / 0.45359237 : kg;
  double weightToKg(double value) => imperial ? value * 0.45359237 : value;
  double distanceFromMeters(double meters) => meters / (imperial ? 1609.344 : 1000);
  double distanceToMeters(double value) => value * (imperial ? 1609.344 : 1000);
  String weight(double kg) => '${Fmt.number(weightFromKg(kg))} $weightLabel';
  String distance(double meters) => imperial
      ? '${Fmt.number(distanceFromMeters(meters), precision: 5)} mi'
      : meters < 1000
      ? '${Fmt.number(meters)} m'
      : '${Fmt.number(meters / 1000, precision: 3)} km';
}

class Fmt {
  Fmt._();
  static String count(int value, String word) => '$value $word${value == 1 ? '' : 's'}';

  static String number(double value, {int precision = 2}) {
    if (!value.isFinite) return '0';
    return value.toStringAsFixed(precision).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  static String weightValue(double value) => number(value);
  static String weight(double kg) => Units().weight(kg);
  static String distance(double meters) => Units().distance(meters);

  static String duration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
  }

  static int? parseDuration(String text) {
    final parts = text.trim().split(':');
    if (parts.isEmpty || parts.length > 3) return null;
    final values = parts.map(int.tryParse).toList();
    if (values.any((v) => v == null || v < 0)) return null;
    if (values.skip(1).any((v) => v! >= 60)) return null;
    return values.fold<int>(0, (sum, v) => sum * 60 + v!);
  }
}

List<(String, String)> setColumns({
  required ExerciseType type,
  required double weight,
  required int reps,
  required double distance,
  required int seconds,
  Units units = const Units(),
}) => [
  if (type.hasWeight) (Fmt.number(units.weightFromKg(weight)), units.weightLabel),
  if (type.hasReps) ('$reps', 'reps'),
  if (type.hasDistance) (Fmt.number(units.distanceFromMeters(distance), precision: units.imperial ? 5 : 3), units.distanceLabel),
  if (type.hasTime) (Fmt.duration(seconds), ''),
];

String describeSet({
  required ExerciseType type,
  required double effectiveWeight,
  required int reps,
  required double distance,
  required int durationSeconds,
  Units units = const Units(),
}) => setColumns(
  type: type,
  weight: effectiveWeight,
  reps: reps,
  distance: distance,
  seconds: durationSeconds,
  units: units,
).map((v) => '${v.$1}${v.$2.isEmpty ? '' : ' ${v.$2}'}').join(' × ');

String exerciseTypeLabel(ExerciseType type) => switch (type) {
  ExerciseType.weightAndReps => 'Weight & reps',
  ExerciseType.distanceAndTime => 'Distance & time',
  ExerciseType.repsOnly => 'Reps only',
  ExerciseType.timeOnly => 'Time only',
  ExerciseType.weightOnly => 'Weight only',
  ExerciseType.distanceOnly => 'Distance only',
  ExerciseType.weightAndDistance => 'Weight & distance',
  ExerciseType.weightAndTime => 'Weight & time',
  ExerciseType.repsAndDistance => 'Reps & distance',
  ExerciseType.repsAndTime => 'Reps & time',
};
