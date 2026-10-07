import '../database/tables.dart';

class SetValues {
  const SetValues({this.weight = 0, this.reps = 0, this.distance = 0, this.seconds = 0, this.rpe});

  final double weight;
  final int reps;
  final double distance;
  final int seconds;
  final double? rpe;

  void validate(ExerciseType type) {
    if (!weight.isFinite || weight < 0 || weight > 10000) throw const FormatException('Enter a weight between 0 and 10,000 kg.');
    if (type.hasReps && (reps < 1 || reps > 10000)) throw const FormatException('Enter at least one rep (up to 10,000).');
    final cardio = type == ExerciseType.distanceAndTime;
    if (type.hasDistance && (!distance.isFinite || distance < 0 || (!cardio && distance == 0) || distance > 10000000)) {
      throw const FormatException('Enter a distance greater than zero.');
    }
    if (type.hasTime && (seconds < 0 || (!cardio && seconds == 0) || seconds > 604800)) {
      throw const FormatException('Enter a time between one second and seven days.');
    }
    if (cardio && distance == 0 && seconds == 0) throw const FormatException('Enter a distance or duration greater than zero.');
    if (rpe != null && (!rpe!.isFinite || rpe! < 1 || rpe! > 10)) throw const FormatException('Effort must be between 1 and 10.');
  }
}
