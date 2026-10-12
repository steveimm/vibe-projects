import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database/database.dart';
import 'repositories/exercise_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/stats_repository.dart';
import 'repositories/workout_repository.dart';
import 'repositories/routine_repository.dart';
import 'repositories/progress_repository.dart';
import 'database/tables.dart';
import 'util/format.dart';
import 'util/dates.dart';

/// The single app-wide database instance.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(openAppConnection());
  ref.onDispose(db.close);
  return db;
});

final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) => ExerciseRepository(ref.watch(databaseProvider)));

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) => WorkoutRepository(ref.watch(databaseProvider)));

final categoriesProvider = StreamProvider<List<Category>>((ref) => ref.watch(exerciseRepositoryProvider).watchCategories());

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) => SettingsRepository(ref.watch(databaseProvider)));

final settingsProvider = StreamProvider<AppSettingsRow>((ref) => ref.watch(settingsRepositoryProvider).watch());

/// The day currently shown on the Workout Log. Shared across the home UI.
class SelectedDateNotifier extends Notifier<String> {
  @override
  String build() => Dates.today();

  void set(String isoDate) => state = isoDate;
  void next() => state = Dates.shift(state, 1);
  void previous() => state = Dates.shift(state, -1);
  String _lastToday = Dates.today();
  void goToday() => state = Dates.today();
  void refreshToday() {
    final today = Dates.today();
    if (state == _lastToday) state = today;
    _lastToday = today;
  }
}

final selectedDateProvider = NotifierProvider<SelectedDateNotifier, String>(SelectedDateNotifier.new);

/// Filter for the exercise list screen.
typedef ExerciseFilter = ({String search, int? categoryId});

final exerciseListProvider = StreamProvider.autoDispose.family<List<ExerciseListItem>, ExerciseFilter>((ref, filter) {
  return ref.watch(exerciseRepositoryProvider).watchExercises(search: filter.search, categoryId: filter.categoryId);
});

final dayLogProvider = StreamProvider.autoDispose.family<List<LoggedSet>, String>(
  (ref, date) => ref.watch(workoutRepositoryProvider).watchDayLog(date),
);

typedef ExerciseDateKey = ({int exerciseId, String date});

final exerciseSetsProvider = StreamProvider.autoDispose.family<List<WorkoutSet>, ExerciseDateKey>(
  (ref, key) => ref.watch(workoutRepositoryProvider).watchSetsForExerciseOnDate(key.exerciseId, key.date),
);

final exerciseProvider = StreamProvider.autoDispose.family<Exercise, int>(
  (ref, id) => ref.watch(exerciseRepositoryProvider).watchExercise(id),
);

/// All sets for an exercise (history + analytics source).
final exerciseHistoryProvider = StreamProvider.autoDispose.family<List<WorkoutSet>, int>(
  (ref, id) => ref.watch(workoutRepositoryProvider).watchExerciseHistory(id),
);

final recordBadgesProvider = Provider.autoDispose.family<Map<int, RecordAchievement>, int>((ref, id) {
  final history = ref.watch(exerciseHistoryProvider(id)).asData?.value ?? const <WorkoutSet>[];
  final enabled = ref.watch(settingsProvider).asData?.value.trackPersonalRecords ?? true;
  if (!enabled) return {};
  final seasons = ref.watch(seasonsProvider).asData?.value ?? const <PrResetMarker>[];
  final type = ref.watch(exerciseProvider(id)).asData?.value.type ?? ExerciseType.weightAndReps;
  return Stats.recordAchievements(history, seasons, type: type);
});

typedef GraphKey = ({int exerciseId, GraphMetric metric});

final graphProvider = Provider.autoDispose.family<List<MetricPoint>, GraphKey>((ref, key) {
  final history = ref.watch(exerciseHistoryProvider(key.exerciseId)).asData?.value ?? const <WorkoutSet>[];
  return Stats.graph(history, key.metric, max1rmReps: ref.watch(settingsProvider).asData?.value.estimated1rmMaxReps ?? 0);
});

final unitsProvider = Provider<Units>((ref) => Units(ref.watch(settingsProvider).asData?.value.useImperial ?? false));
final allLogProvider = StreamProvider((ref) => ref.watch(workoutRepositoryProvider).watchLog());
final dayNoteProvider = StreamProvider.autoDispose.family<WorkoutDayNote?, String>(
  (ref, date) => ref.watch(workoutRepositoryProvider).watchDayNote(date),
);
final workoutSessionsProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.workoutSessions).watch();
});
final sessionProvider = StreamProvider.autoDispose.family<WorkoutSession?, String>(
  (ref, date) => ref.watch(workoutRepositoryProvider).watchSession(date),
);
final multipliersProvider = StreamProvider.autoDispose.family<List<ExerciseMultiplier>, int>(
  (ref, id) => ref.watch(exerciseRepositoryProvider).watchMultipliers(id),
);
final routineRepositoryProvider = Provider((ref) => RoutineRepository(ref.watch(databaseProvider)));
final routinesProvider = StreamProvider((ref) => ref.watch(routineRepositoryProvider).watch());
final routineDaysProvider = StreamProvider.autoDispose.family<List<RoutineDay>, int>(
  (ref, id) => ref.watch(routineRepositoryProvider).watchDays(id),
);
final routineSetsProvider = StreamProvider.autoDispose.family<List<RoutineSet>, int>(
  (ref, id) => ref.watch(routineRepositoryProvider).watchSets(id),
);
final progressRepositoryProvider = Provider((ref) => ProgressRepository(ref.watch(databaseProvider)));
final bodyweightProvider = StreamProvider.autoDispose.family<Measurement?, String>(
  (ref, date) => ref.watch(progressRepositoryProvider).watchLatestBodyweight(date),
);
final seasonsProvider = StreamProvider((ref) => ref.watch(progressRepositoryProvider).watchSeasons());
final measurementTypesProvider = StreamProvider((ref) => ref.watch(progressRepositoryProvider).watchTypes());
final allMeasurementsProvider = StreamProvider((ref) => ref.watch(progressRepositoryProvider).watchAllMeasurements());
final measurementsProvider = StreamProvider.autoDispose.family<List<Measurement>, int>(
  (ref, id) => ref.watch(progressRepositoryProvider).watchMeasurements(id),
);
final goalsProvider = StreamProvider.autoDispose.family<List<ExerciseGoal>, int>(
  (ref, id) => ref.watch(progressRepositoryProvider).watchGoals(id),
);

final allExercisesProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.exercises).watch();
});
