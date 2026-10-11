import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitnotes_plus/app/router.dart';
import 'package:fitnotes_plus/app/theme.dart';
import 'package:fitnotes_plus/core/database/database.dart';
import 'package:fitnotes_plus/core/providers.dart';
import 'package:fitnotes_plus/core/repositories/routine_repository.dart';
import 'package:fitnotes_plus/core/repositories/workout_repository.dart';
import 'package:fitnotes_plus/core/util/dates.dart';

Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('routine selection supports cancel, Back, pinned actions and confirmed bulk deletion', (tester) async {
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase.memory();
    final routines = RoutineRepository(db);
    final ids = <int>[];
    await tester.runAsync(() async {
      final exercise = (await db.select(db.exercises).get()).first;
      for (var i = 1; i <= 8; i++) {
        final id = await routines.create('Routine $i');
        ids.add(id);
        final day = (await routines.watchDays(id).first).single;
        await routines.addExercise(day.id, exercise.id, count: 1);
      }
      await WorkoutRepository(db).addSet(exerciseId: exercise.id, date: Dates.shift(Dates.today(), -1), rawWeight: 40, reps: 8);
    });
    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    final router = createAppRouter(initialLocation: '/routines');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await _flush(tester);
    final first = find.byKey(ValueKey('routine-${ids.first}'));
    final second = find.byKey(ValueKey('routine-${ids[1]}'));
    await tester.longPress(first);
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.byTooltip('New routine'), findsNothing);
    await tester.tap(second);
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    await tester.tap(second);
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    await tester.tap(second);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete selected routines'));
    await tester.pumpAndSettle();
    expect(find.text('Delete 2 routines?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    final list = find.descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(find.text('Routine 8'), 160, scrollable: list);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Delete selected routines').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Done'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('New routine'), findsOneWidget);
    await tester.scrollUntilVisible(first, -160, scrollable: list);
    await tester.pumpAndSettle();
    await tester.longPress(first);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byTooltip('New routine'), findsOneWidget);
    await tester.longPress(first);
    await tester.pumpAndSettle();
    await tester.tap(second);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete selected routines'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await _flush(tester);
    expect(find.text('Routine 1'), findsNothing);
    expect(find.text('Routine 2'), findsNothing);
    expect(find.byTooltip('New routine'), findsOneWidget);
    expect(find.byTooltip('Delete selected routines'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    await tester.runAsync(() async {
      expect(await db.select(db.routines).get(), hasLength(6));
      expect(await db.select(db.routineDays).get(), hasLength(6));
      expect(await db.select(db.routineSets).get(), hasLength(6));
      expect(await db.select(db.workoutSets).get(), hasLength(1));
    });
    await tester.tap(find.text('Routine 3'));
    await _flush(tester);
    expect(find.text('Day 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    container.dispose();
    final closed = db.close();
    await _flush(tester);
    await closed;
  });
}
