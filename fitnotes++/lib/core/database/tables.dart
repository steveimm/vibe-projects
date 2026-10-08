import 'package:drift/drift.dart';

/// How an exercise is recorded. Index values intentionally mirror FitNotes'
/// `exercise_type_id` for the common cases (0=W&R, 1=Dist&Time, 3=Time-only),
/// which keeps `.fitnotes` import a direct mapping.
enum ExerciseType {
  weightAndReps, // 0
  distanceAndTime, // 1
  repsOnly, // 2
  timeOnly, // 3
  weightOnly,
  distanceOnly,
  weightAndDistance,
  weightAndTime,
  repsAndDistance,
  repsAndTime,
}

extension ExerciseFields on ExerciseType {
  bool get hasWeight => [
    ExerciseType.weightAndReps,
    ExerciseType.weightOnly,
    ExerciseType.weightAndDistance,
    ExerciseType.weightAndTime,
  ].contains(this);
  bool get hasReps =>
      [ExerciseType.weightAndReps, ExerciseType.repsOnly, ExerciseType.repsAndDistance, ExerciseType.repsAndTime].contains(this);
  bool get hasDistance => [
    ExerciseType.distanceAndTime,
    ExerciseType.distanceOnly,
    ExerciseType.weightAndDistance,
    ExerciseType.repsAndDistance,
  ].contains(this);
  bool get hasTime =>
      [ExerciseType.distanceAndTime, ExerciseType.timeOnly, ExerciseType.weightAndTime, ExerciseType.repsAndTime].contains(this);
}

@DataClassName('Category')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();

  /// Packed ARGB color (unsigned, e.g. 0xFF2980B9).
  IntColumn get colorArgb => integer().withDefault(const Constant(0xFF7F8C8D))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('Exercise')
class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get type => intEnum<ExerciseType>().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  IntColumn get defaultRestTimeSeconds => integer().nullable()();
  BoolColumn get isFavourite => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  RealColumn get weightIncrement => real().nullable()();
}

/// Named factors are multiplied together when adding a workout set.
@DataClassName('ExerciseMultiplier')
class ExerciseMultipliers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  TextColumn get label => text()();
  RealColumn get factor => real().withDefault(const Constant(1.0))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('WorkoutSet')
class WorkoutSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId => integer().references(Exercises, #id)();

  /// Calendar day, `yyyy-MM-dd`.
  TextColumn get date => text()();

  /// The number the user actually entered (before any multiplier).
  RealColumn get rawWeight => real().withDefault(const Constant(0))();

  /// Product of enabled factors captured when the set was added.
  /// `effectiveWeight = rawWeight * weightMultiplier`.
  RealColumn get weightMultiplier => real().withDefault(const Constant(1.0))();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  RealColumn get distance => real().withDefault(const Constant(0))();
  IntColumn get durationSeconds => integer().withDefault(const Constant(0))();
  BoolColumn get isComplete => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get sourceKey => text().nullable()();
  BoolColumn get isPlanned => boolean().withDefault(const Constant(false))();
  RealColumn get rpe => real().nullable()();
  TextColumn get groupName => text().nullable()();
}

@DataClassName('WorkoutDayNote')
class WorkoutDayNotes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text().unique()(); // yyyy-MM-dd
  TextColumn get comment => text()();
}

/// PR windows start at the most recent reset date. Historical sets remain intact.
@DataClassName('PrResetMarker')
class PrResetMarkers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text()(); // yyyy-MM-dd
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Single-row settings table (id always 1).
@DataClassName('AppSettingsRow')
class AppSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get themeMode => integer().withDefault(const Constant(0))(); // 0 system / 1 light / 2 dark
  IntColumn get firstDayOfWeek => integer().withDefault(const Constant(1))(); // ISO: 1=Mon .. 7=Sun
  RealColumn get defaultWeightIncrement => real().withDefault(const Constant(2.5))();
  IntColumn get restTimerSeconds => integer().withDefault(const Constant(60))();
  BoolColumn get restTimerVibrate => boolean().withDefault(const Constant(false))();
  BoolColumn get restTimerSound => boolean().withDefault(const Constant(true))();
  BoolColumn get restTimerAutoStart => boolean().withDefault(const Constant(false))();
  BoolColumn get trackPersonalRecords => boolean().withDefault(const Constant(true))();
  BoolColumn get markSetsComplete => boolean().withDefault(const Constant(false))();
  BoolColumn get keepScreenOn => boolean().withDefault(const Constant(false))();
  IntColumn get estimated1rmMaxReps => integer().withDefault(const Constant(0))(); // 0 = no cap
  BoolColumn get useImperial => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Routines extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get notes => text().withDefault(const Constant(''))();
}

class RoutineDays extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineId => integer().references(Routines, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class RoutineSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get dayId => integer().references(RoutineDays, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  RealColumn get rawWeight => real().nullable()();
  IntColumn get reps => integer().nullable()();
  RealColumn get distance => real().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get groupName => text().nullable()();
}

class MeasurementTypes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get unit => text()();
}

class Measurements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get typeId => integer().references(MeasurementTypes, #id, onDelete: KeyAction.cascade)();
  TextColumn get date => text()();
  RealColumn get value => real()();
  TextColumn get note => text().withDefault(const Constant(''))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {typeId, date},
  ];
}

class ExerciseGoals extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId => integer().references(Exercises, #id, onDelete: KeyAction.cascade)();
  TextColumn get metric => text()();
  RealColumn get target => real()();
  TextColumn get targetDate => text().nullable()();
}

class WorkoutSessions extends Table {
  TextColumn get date => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get elapsedSeconds => integer().withDefault(const Constant(0))();
  DateTimeColumn get runningSince => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {date};
}
