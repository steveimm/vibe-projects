import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'database.g.dart';

/// Default muscle-group categories, seeded on first launch. Names + colors
/// mirror FitNotes' defaults (the classic Flat-UI palette) so an imported
/// `.fitnotes` backup dedupes against them by name.
const _seedCategories = <(String, int)>[
  ('Abs', 0xFF2C3E50),
  ('Back', 0xFF2980B9),
  ('Biceps', 0xFFF39C12),
  ('Cardio', 0xFF7F8C8D),
  ('Chest', 0xFFC0392B),
  ('Forearm', 0xFF2ECC71),
  ('Legs', 0xFF54B2B6),
  ('Shoulders', 0xFF8E44AD),
  ('Triceps', 0xFF27AE60),
];

@DriftDatabase(
  tables: [
    Categories,
    Exercises,
    ExerciseMultipliers,
    WorkoutSets,
    WorkoutDayNotes,
    PrResetMarkers,
    AppSettings,
    Routines,
    RoutineDays,
    RoutineSets,
    MeasurementTypes,
    Measurements,
    ExerciseGoals,
    WorkoutSessions,
    WorkoutExerciseOrders,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// In-memory database for tests.
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seed();
      await _seedExercises();
      await _seedMeasurements();
      await _indexes();
    },
    onUpgrade: (m, from, to) async {
      if (from < 9) await m.addColumn(prResetMarkers, prResetMarkers.initials);
      if (from < 8) await m.addColumn(workoutSets, workoutSets.loggedAt);
      if (from < 6) await m.addColumn(exercises, exercises.weightUnit);
      if (from < 7) {
        await m.addColumn(exercises, exercises.includeBodyweight);
        await m.addColumn(workoutSets, workoutSets.bodyweight);
      }
      if (from < 2) {
        await m.addColumn(exercises, exercises.weightIncrement);
        await m.addColumn(workoutSets, workoutSets.sourceKey);
        await m.addColumn(workoutSets, workoutSets.isPlanned);
        await m.addColumn(workoutSets, workoutSets.rpe);
        await m.addColumn(workoutSets, workoutSets.groupName);
        await m.addColumn(appSettings, appSettings.useImperial);
        for (final table in <TableInfo>[
          routines,
          routineDays,
          routineSets,
          measurementTypes,
          measurements,
          exerciseGoals,
          workoutSessions,
        ]) {
          await m.createTable(table);
        }
        await _seedExercises();
        await _seedMeasurements();
        await _indexes();
      }
      if (from == 2) {
        await m.addColumn(workoutSessions, workoutSessions.elapsedSeconds);
        await m.addColumn(workoutSessions, workoutSessions.runningSince);
        await customStatement('''
          UPDATE workout_sessions SET
            elapsed_seconds = CASE WHEN ended_at IS NULL THEN 0 ELSE MAX(0, ended_at - started_at) END,
            running_since = CASE WHEN ended_at IS NULL THEN started_at ELSE NULL END
        ''');
      }
      if (from < 4) await m.createTable(workoutExerciseOrders);
      if (from < 5) await m.addColumn(appSettings, appSettings.restTimerSoundUri);
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _indexes() async {
    await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS workout_source_key ON workout_sets(source_key)');
    await customStatement('CREATE INDEX IF NOT EXISTS workout_exercise_date ON workout_sets(exercise_id, date)');
    await customStatement('CREATE INDEX IF NOT EXISTS workout_date ON workout_sets(date)');
  }

  Future<void> _seedExercises() async {
    if ((await (select(exercises)..limit(1)).get()).isNotEmpty) return;
    final cats = {for (final c in await select(categories).get()) c.name: c.id};
    const defaults = {
      'Abs': ['Crunch', 'Cable Crunch', 'Hanging Leg Raise', 'Plank', 'Side Plank'],
      'Back': ['Deadlift', 'Barbell Row', 'Dumbbell Row', 'Lat Pulldown', 'Seated Cable Row', 'Pull Up', 'Chin Up'],
      'Biceps': ['Barbell Curl', 'Dumbbell Curl', 'Dumbbell Hammer Curl', 'EZ-Bar Curl'],
      'Cardio': [
        'Cycling',
        'Walking',
        'Rowing Machine',
        'Stationary Bike',
        'Swimming',
        'Running (Treadmill)',
        'Running (Outdoor)',
      ],
      'Chest': [
        'Flat Barbell Bench Press',
        'Flat Dumbbell Bench Press',
        'Incline Dumbbell Bench Press',
        'Cable Crossover',
        'Push Up',
      ],
      'Forearm': ['Barbell Wrist Curl', 'Dumbbell Wrist Curl'],
      'Legs': [
        'Barbell Squat',
        'Barbell Front Squat',
        'Leg Press',
        'Leg Extension',
        'Lying Leg Curl Machine',
        'Romanian Deadlift',
        'Hip Thrust',
        'Dumbbell Lunge',
      ],
      'Shoulders': ['Overhead Press', 'Seated Dumbbell Press', 'Lateral Dumbbell Raise', 'Cable Face Pull'],
      'Triceps': ['Close Grip Barbell Bench Press', 'Rope Push Down', 'Cable Overhead Triceps Extension', 'EZ-Bar Skullcrusher'],
    };
    await batch((b) {
      for (final entry in defaults.entries) {
        final category = cats[entry.key];
        if (category == null) continue;
        for (final name in entry.value) {
          final type = entry.key == 'Cardio'
              ? ExerciseType.distanceAndTime
              : name.contains('Plank')
              ? ExerciseType.timeOnly
              : ['Crunch', 'Hanging Leg Raise', 'Pull Up', 'Chin Up', 'Push Up'].contains(name)
              ? ExerciseType.repsOnly
              : ExerciseType.weightAndReps;
          b.insert(exercises, ExercisesCompanion.insert(name: name, categoryId: category, type: Value(type)));
        }
      }
    });
  }

  Future<void> _seedMeasurements() async {
    for (final name in [
      'Bodyweight',
      'Body fat',
      'Neck',
      'Shoulders',
      'Chest',
      'Waist',
      'Hips',
      'Left upper arm',
      'Right upper arm',
      'Left forearm',
      'Right forearm',
      'Left thigh',
      'Right thigh',
      'Left calf',
      'Right calf',
    ]) {
      await into(measurementTypes).insert(
        MeasurementTypesCompanion.insert(
          name: name,
          unit: name == 'Bodyweight'
              ? 'kg'
              : name == 'Body fat'
              ? '%'
              : 'cm',
        ),
      );
    }
  }

  Future<void> _seed() async {
    await batch((b) {
      for (var i = 0; i < _seedCategories.length; i++) {
        final (name, color) = _seedCategories[i];
        b.insert(categories, CategoriesCompanion.insert(name: name, colorArgb: Value(color), sortOrder: Value(i)));
      }
    });
    // Single settings row with column defaults.
    await into(appSettings).insert(const AppSettingsCompanion(id: Value(1)), mode: InsertMode.insertOrIgnore);
  }
}

extension WorkoutSetWeight on WorkoutSet {
  double get effectiveWeight => rawWeight * weightMultiplier + bodyweight;
}

/// App connection: a lazily-opened native SQLite file in the app documents dir.
QueryExecutor openAppConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'fitnotes_plus.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
