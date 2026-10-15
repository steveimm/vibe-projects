import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fitnotes_plus/app/router.dart';
import 'package:fitnotes_plus/app/theme.dart';
import 'package:fitnotes_plus/core/database/database.dart';
import 'package:fitnotes_plus/core/database/tables.dart';
import 'package:fitnotes_plus/core/providers.dart';
import 'package:fitnotes_plus/core/repositories/exercise_repository.dart';
import 'package:fitnotes_plus/core/repositories/workout_repository.dart';
import 'package:fitnotes_plus/core/util/dates.dart';
import 'package:fitnotes_plus/features/exercises/exercise_picker_screen.dart';
import 'package:fitnotes_plus/features/track/exercise_detail_screen.dart';
import 'package:fitnotes_plus/features/track/history_tab.dart';

final _exercises = [
  for (var id = 1; id <= 16; id++)
    Exercise(
      includeBodyweight: false,
      id: id,
      name: id == 1
          ? 'Bench press'
          : id == 2
          ? 'Row'
          : 'Press ${id.toString().padLeft(2, '0')}',
      categoryId: id == 2 ? 2 : 1,
      type: ExerciseType.weightAndReps,
      isFavourite: false,
      archived: false,
      sortOrder: id,
    ),
];
const _settings = AppSettingsRow(
  id: 1,
  themeMode: 0,
  firstDayOfWeek: 1,
  defaultWeightIncrement: 2.5,
  restTimerSeconds: 60,
  restTimerVibrate: false,
  restTimerSound: true,
  restTimerAutoStart: false,
  trackPersonalRecords: true,
  markSetsComplete: false,
  keepScreenOn: false,
  workoutAutoStopMinutes: 15,
  estimated1rmMaxReps: 0,
  useImperial: false,
);

WorkoutSet _set(int id, String date) => WorkoutSet(
  bodyweight: 0,
  id: id,
  exerciseId: id,
  date: date,
  rawWeight: 60,
  weightMultiplier: 1,
  reps: 8,
  distance: 0,
  durationSeconds: 0,
  isComplete: true,
  createdAt: DateTime.now(),
  isPlanned: false,
);

class _Exercises extends ExerciseRepository {
  _Exercises(super.db);
  @override
  Stream<List<ExerciseListItem>> watchExercises({
    String? search,
    int? categoryId,
    bool archived = false,
    bool favourites = false,
  }) => Stream.value([
    for (final e in _exercises.where(
      (e) => (categoryId == null || e.categoryId == categoryId) && e.name.toLowerCase().contains((search ?? '').toLowerCase()),
    ))
      ExerciseListItem(
        id: e.id,
        name: e.name,
        categoryId: e.categoryId,
        categoryName: e.categoryId == 1 ? 'Chest' : 'Back',
        colorArgb: 0xFFC0392B,
        type: e.type,
        isFavourite: false,
        workoutCount: 1,
        lastDate: Dates.today(),
      ),
  ]);
}

class _Workouts extends WorkoutRepository {
  _Workouts(super.db);
  int savedSets = 0;
  @override
  Future<int> addSet({
    required int exerciseId,
    required String date,
    double rawWeight = 0,
    double? weightMultiplier,
    int reps = 0,
    double distance = 0,
    int durationSeconds = 0,
    double? rpe,
    String? note,
    bool planned = false,
  }) async => ++savedSets;
  @override
  Future<WorkoutSet?> lastSet(int exerciseId, String date) async => null;
  @override
  Stream<List<LoggedSet>> watchDayLog(String date) => Stream.value([
    for (final e in _exercises.take(2))
      LoggedSet(set: _set(e.id, date), exerciseName: e.name, colorArgb: 0xFFC0392B, exerciseType: 0),
  ]);
}

Future<GoRouter> _show(WidgetTester tester, {String location = '/'}) async {
  tester.view.physicalSize = const Size(390, 850);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final db = AppDatabase.memory();
  addTearDown(db.close);
  final router = createAppRouter(initialLocation: location);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        exerciseRepositoryProvider.overrideWithValue(_Exercises(db)),
        workoutRepositoryProvider.overrideWithValue(_Workouts(db)),
        settingsProvider.overrideWith((ref) => Stream.value(_settings)),
        categoriesProvider.overrideWith(
          (ref) => Stream.value(const [
            Category(id: 1, name: 'Chest', colorArgb: 0xFFC0392B, sortOrder: 0),
            Category(id: 2, name: 'Back', colorArgb: 0xFF2980B9, sortOrder: 1),
          ]),
        ),
        exerciseProvider.overrideWith((ref, id) => Stream.value(_exercises.firstWhere((e) => e.id == id))),
        exerciseSetsProvider.overrideWith((ref, key) => Stream.value([])),
        exerciseHistoryProvider.overrideWith((ref, id) => Stream.value([_set(id, Dates.shift(Dates.today(), -1))])),
        recordBadgesProvider.overrideWith((ref, id) => {}),
        multipliersProvider.overrideWith((ref, id) => Stream.value([])),
        goalsProvider.overrideWith((ref, id) => Stream.value([])),
        seasonsProvider.overrideWith((ref) => Stream.value([])),
        allLogProvider.overrideWith((ref) => Stream.value([])),
        dayNoteProvider.overrideWith((ref, date) => Stream.value(null)),
        sessionProvider.overrideWith((ref, date) => Stream.value(null)),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _back(WidgetTester tester, {bool system = false}) async {
  if (system) {
    await tester.binding.handlePopRoute();
  } else {
    await tester.tap(find.byTooltip('Back'));
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('body-part picker keeps its search and scroll when returning from an exercise', (tester) async {
    await _show(tester);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.text('Exercises'), findsNothing);
    await tester.tap(find.byTooltip('Add exercise'));
    await tester.pumpAndSettle();
    expect(find.text('Body part'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    await tester.tap(find.text('Chest'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Press');
    await tester.pumpAndSettle();
    final list = find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(find.text('Press 12'), 250, scrollable: list);
    await tester.pumpAndSettle();
    final offset = tester.state<ScrollableState>(list).position.pixels;
    await tester.tap(find.text('Press 12'));
    await tester.pumpAndSettle();
    expect(tester.widget<ExerciseDetailScreen>(find.byType(ExerciseDetailScreen)).exerciseId, 12);
    await _back(tester, system: true);
    expect(find.byType(ExercisePickerScreen), findsOneWidget);
    expect(find.text('Chest'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Press');
    expect(tester.state<ScrollableState>(list).position.pixels, closeTo(offset, 0.1));
    await tester.tap(find.byTooltip('Create exercise'));
    await tester.pumpAndSettle();
    expect(find.text('New exercise'), findsOneWidget);
    await _back(tester);
    expect(find.text('Chest'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Press');
    await _back(tester, system: true);
    expect(find.text('Body part'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    await _back(tester);
    expect(find.text('Today'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('body-part screen searches all exercises and opens exercise creation', (tester) async {
    await _show(tester);
    await tester.tap(find.byTooltip('Add exercise'));
    await tester.pumpAndSettle();
    final bodyPart = find.widgetWithText(ListTile, 'Chest');
    expect(tester.getSize(bodyPart).height, 48);
    await tester.enterText(find.byType(TextField), 'Row');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Row'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Chest'), findsNothing);
    await tester.tap(find.widgetWithText(ListTile, 'Row'));
    await tester.pumpAndSettle();
    await _back(tester);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Row');
    await tester.tap(find.byTooltip('Create exercise'));
    await tester.pumpAndSettle();
    expect(find.text('New exercise'), findsOneWidget);
    await _back(tester);
    expect(find.text('Body part'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Row');
    await _back(tester, system: true);
    expect(find.widgetWithText(ListTile, 'Chest'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final system in [false, true]) {
    testWidgets('saving from the picker returns Home with ${system ? 'system' : 'app bar'} Back', (tester) async {
      await _show(tester);
      await tester.tap(find.byTooltip('Add exercise'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Bench');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bench press'));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(tester.element(find.byType(ExerciseDetailScreen)));
      final workouts = container.read(workoutRepositoryProvider) as _Workouts;
      await tester.enterText(find.byType(TextField).first, '60');
      await tester.enterText(find.byType(TextField).at(1), '8');
      await tester.tap(find.byTooltip('Log set'));
      await tester.pumpAndSettle();
      expect(workouts.savedSets, 1);
      if (system) {
        await tester.tap(find.text('History'));
        await tester.pumpAndSettle();
      }
      await _back(tester, system: system);
      expect(find.text('Today'), findsOneWidget);
      expect(find.byType(ExercisePickerScreen), findsNothing);
      expect(find.byType(ExerciseDetailScreen), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('history and workout exercise switching preserve the previous editor and its input', (tester) async {
    await _show(tester);
    await tester.tap(find.byTooltip('Add exercise'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chest'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bench press'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '72.5');
    await tester.tap(find.byTooltip('Workout exercises'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Add exercise'), findsNothing);
    await tester.tap(find.widgetWithText(ListTile, 'Row'));
    await tester.pumpAndSettle();
    expect(tester.widget<ExerciseDetailScreen>(find.byType(ExerciseDetailScreen)).exerciseId, 2);
    await _back(tester);
    expect(tester.widget<ExerciseDetailScreen>(find.byType(ExerciseDetailScreen)).exerciseId, 1);
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, '72.5');
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(tester.widget<ExerciseDetailScreen>(find.byType(ExerciseDetailScreen)).date, Dates.shift(Dates.today(), -1));
    await _back(tester, system: true);
    expect(DefaultTabController.of(tester.element(find.byType(HistoryTab))).index, 1);
    expect(tester.widget<ExerciseDetailScreen>(find.byType(ExerciseDetailScreen)).date, Dates.today());
    await _back(tester);
    expect(find.byType(ExercisePickerScreen), findsOneWidget);
    expect(find.text('Chest'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('routine exercise selection returns an ID after choosing a body part', (tester) async {
    final router = await _show(tester);
    final picked = router.push<int>('/pick-exercise?return=1');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chest'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bench press'));
    await tester.pumpAndSettle();
    expect(find.byType(ExercisePickerScreen), findsNothing);
    expect(await picked, 1);
    expect(find.byType(ExerciseDetailScreen), findsNothing);
    expect(find.text('Today'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
