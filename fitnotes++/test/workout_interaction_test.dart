import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitnotes_plus/app/theme.dart';
import 'package:fitnotes_plus/core/database/database.dart';
import 'package:fitnotes_plus/core/providers.dart';
import 'package:fitnotes_plus/core/repositories/workout_repository.dart';
import 'package:fitnotes_plus/core/util/dates.dart';
import 'package:fitnotes_plus/features/workout_log/home_screen.dart';
import 'package:fitnotes_plus/shared/widgets.dart';

class _Workouts extends WorkoutRepository {
  _Workouts() : super(AppDatabase.memory());
  final changes = StreamController<List<LoggedSet>>.broadcast();
  final List<LoggedSet> sets = [
    for (final entry in const {1: 'Bench press', 2: 'Curl', 3: 'Row'}.entries)
      LoggedSet(
        set: WorkoutSet(
          id: entry.key,
          exerciseId: entry.key,
          date: Dates.today(),
          rawWeight: 60,
          weightMultiplier: 1,
          reps: 8,
          distance: 0,
          durationSeconds: 0,
          isComplete: true,
          createdAt: DateTime.now(),
          isPlanned: false,
        ),
        exerciseName: entry.value,
        colorArgb: 0xFFC0392B,
        exerciseType: 0,
      ),
  ];
  List<int> order = [1, 2, 3];
  List<int>? moved;
  Set<int>? removed;
  final removedEntries = <int, LoggedSet>{};

  @override
  Stream<List<LoggedSet>> watchDayLog(String date) async* {
    yield [...sets];
    yield* changes.stream;
  }

  @override
  Future<void> reorderExercises(String date, List<int> exerciseIds) async {
    moved = [...exerciseIds];
    order = [...exerciseIds];
    sets.sort((a, b) => order.indexOf(a.set.exerciseId).compareTo(order.indexOf(b.set.exerciseId)));
    changes.add([...sets]);
  }

  @override
  Future<DaySnapshot> removeExercisesFromDay(String date, Iterable<int> exerciseIds) async {
    final ids = exerciseIds.toSet();
    removed = ids;
    final deleted = sets.where((s) => ids.contains(s.set.exerciseId)).toList();
    removedEntries.addEntries(deleted.map((s) => MapEntry(s.set.id, s)));
    sets.removeWhere((s) => ids.contains(s.set.exerciseId));
    changes.add([...sets]);
    return DaySnapshot(deleted.map((s) => s.set).toList(), const [], const []);
  }

  @override
  Future<void> restoreDay(DaySnapshot snapshot) async {
    sets.addAll(snapshot.sets.map((s) => removedEntries[s.id]!));
    sets.sort((a, b) => order.indexOf(a.set.exerciseId).compareTo(order.indexOf(b.set.exerciseId)));
    changes.add([...sets]);
  }
}

void main() {
  testWidgets('deletion requires confirmation, cancel keeps selection, and success exits edit mode without a snackbar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _Workouts();
    addTearDown(repo.db.close);
    addTearDown(repo.changes.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutRepositoryProvider.overrideWithValue(repo),
          settingsProvider.overrideWith((ref) => const Stream.empty()),
          allLogProvider.overrideWith((ref) => Stream.value(repo.sets)),
          dayNoteProvider.overrideWith((ref, date) => Stream.value(null)),
          sessionProvider.overrideWith((ref, date) => Stream.value(null)),
          recordBadgesProvider.overrideWith((ref, id) => {}),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('FitNotes++'), findsNothing);
    expect(find.text('Today'), findsOneWidget);
    final destination = tester.getBottomLeft(find.byKey(const ValueKey(3))) + const Offset(100, 40);
    final originalCard = find.descendant(of: find.byKey(const ValueKey(1)), matching: find.byType(Card));
    final originalHeight = tester.getSize(originalCard).height;
    final origin = tester.getCenter(find.text('Bench press'));
    final gesture = await tester.startGesture(origin);
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byTooltip('Done'), findsOneWidget);
    expect(find.byTooltip('Add exercise'), findsNothing);
    final previewCard = find.descendant(of: find.byKey(const ValueKey('workout-drag-preview')), matching: find.byType(Card));
    expect(tester.getSize(previewCard).height, originalHeight);
    expect(tester.widget<Card>(previewCard).clipBehavior, Clip.antiAlias);
    for (var step = 1; step <= 10; step++) {
      await gesture.moveTo(Offset.lerp(origin, destination, step / 10)!);
      await tester.pump(const Duration(milliseconds: 80));
    }
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(repo.moved, [2, 3, 1]);
    expect(tester.getTopLeft(find.text('Curl')).dy, lessThan(tester.getTopLeft(find.text('Row')).dy));
    expect(tester.getTopLeft(find.text('Row')).dy, lessThan(tester.getTopLeft(find.text('Bench press')).dy));
    expect(find.text('1 selected'), findsOneWidget);
    await tester.tap(find.text('Row'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    expect(find.widgetWithIcon(IconButton, Icons.delete_outline_rounded), findsOneWidget);
    await tester.tap(find.byTooltip('Delete selected exercises'));
    await tester.pumpAndSettle();
    expect(repo.removed, isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    expect(repo.removed, isNull);
    await tester.tap(find.byTooltip('Delete selected exercises'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(repo.removed, {1, 3});
    expect(find.text('Row'), findsNothing);
    expect(find.text('Bench press'), findsNothing);
    expect(find.text('Curl'), findsOneWidget);
    expect(find.byTooltip('Done'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byTooltip('Delete selected exercises'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byTooltip('Add exercise'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('exercise count, Add exercise, and Done stay visible while scrolling and editing blocks unrelated actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _Workouts();
    for (var id = 4; id <= 10; id++) {
      repo.sets.add(
        LoggedSet(
          set: repo.sets.first.set.copyWith(id: id, exerciseId: id),
          exerciseName: 'Exercise $id',
          colorArgb: 0xFFC0392B,
          exerciseType: 0,
        ),
      );
    }
    repo.order = repo.sets.map((s) => s.set.exerciseId).toList();
    addTearDown(repo.db.close);
    addTearDown(repo.changes.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutRepositoryProvider.overrideWithValue(repo),
          settingsProvider.overrideWith((ref) => const Stream.empty()),
          allLogProvider.overrideWith((ref) => Stream.value(repo.sets)),
          dayNoteProvider.overrideWith((ref, date) => Stream.value(null)),
          sessionProvider.overrideWith((ref, date) => Stream.value(null)),
          recordBadgesProvider.overrideWith((ref, id) => {}),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final scrollable = find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable));
    final toolbar = find.byKey(const ValueKey('workout-list-toolbar'));
    await tester.scrollUntilVisible(find.text('Exercise 7'), 220, scrollable: scrollable);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Add exercise').hitTestable(), findsOneWidget);
    expect(find.text('10 exercises').hitTestable(), findsOneWidget);
    expect(tester.getTopLeft(toolbar).dy, closeTo(tester.getTopLeft(find.byType(CustomScrollView)).dy, 0.1));
    final pinnedTop = tester.getTopLeft(toolbar).dy;
    await tester.longPress(find.text('Exercise 7'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Done').hitTestable(), findsOneWidget);
    expect(find.byTooltip('Add exercise'), findsNothing);
    final actions = find.byWidgetPredicate((w) => w is AppMenuButton<String> && w.tooltip == 'Workout actions');
    expect(tester.widget<AppMenuButton<String>>(actions).enabled, false);
    await tester.tap(find.text('Exercise 7'));
    await tester.pumpAndSettle();
    expect(find.text('0 selected'), findsOneWidget);
    await tester.tap(find.text('Exercise 7'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Done').hitTestable(), findsOneWidget);
    expect(tester.getTopLeft(toolbar).dy, pinnedTop);
    await tester.tap(find.byTooltip('Done'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Add exercise').hitTestable(), findsOneWidget);
    expect(tester.widget<AppMenuButton<String>>(actions).enabled, true);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
