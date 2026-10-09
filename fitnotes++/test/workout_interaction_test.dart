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
  int? removed;

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
  Future<DaySnapshot> removeExerciseFromDay(String date, int exerciseId) async {
    removed = exerciseId;
    final deleted = sets.where((s) => s.set.exerciseId == exerciseId).map((s) => s.set).toList();
    sets.removeWhere((s) => s.set.exerciseId == exerciseId);
    changes.add([...sets]);
    return DaySnapshot(deleted, const [], const []);
  }

  @override
  Future<void> restoreDay(DaySnapshot snapshot) async {
    sets.add(LoggedSet(set: snapshot.sets.single, exerciseName: 'Row', colorArgb: 0xFFC0392B, exerciseType: 0));
    sets.sort((a, b) => order.indexOf(a.set.exerciseId).compareTo(order.indexOf(b.set.exerciseId)));
    changes.add([...sets]);
  }
}

void main() {
  testWidgets('holding an exercise enables dragging and removal, and Undo restores the removed card', (tester) async {
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
          prSetIdsProvider.overrideWith((ref, id) => <int>{}),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('FitNotes++'), findsNothing);
    expect(find.text('Today'), findsOneWidget);
    final destination = tester.getBottomLeft(find.byKey(const ValueKey(3))) + const Offset(100, 40);
    final origin = tester.getCenter(find.text('Bench press'));
    final gesture = await tester.startGesture(origin);
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Done'), findsOneWidget);
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
    await tester.tap(find.byTooltip('Remove Row from workout'));
    await tester.pumpAndSettle();
    expect(repo.removed, 3);
    expect(find.text('Row'), findsNothing);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Row'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Row')).dy, lessThan(tester.getTopLeft(find.text('Bench press')).dy));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove Row from workout'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
