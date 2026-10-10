import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitnotes_plus/app/router.dart';
import 'package:fitnotes_plus/app/theme.dart';
import 'package:fitnotes_plus/core/database/database.dart';
import 'package:fitnotes_plus/core/providers.dart';
import 'package:fitnotes_plus/core/repositories/routine_repository.dart';
import 'package:fitnotes_plus/core/util/dates.dart';
import 'package:fitnotes_plus/shared/widgets.dart';

Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('grouped presets support adding, editing all sets, exercise reordering and adding to a workout', (tester) async {
    tester.view.physicalSize = const Size(412, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase.memory();
    final repo = RoutineRepository(db);
    late int routineId, dayId, benchId, rowId;
    await tester.runAsync(() async {
      final exercises = await db.select(db.exercises).get();
      benchId = exercises.firstWhere((e) => e.name == 'Flat Barbell Bench Press').id;
      rowId = exercises.firstWhere((e) => e.name == 'Barbell Row').id;
      routineId = await repo.create('Upper');
      dayId = (await repo.watchDays(routineId).first).single.id;
      await repo.addExercise(dayId, benchId);
      await repo.addExercise(dayId, rowId);
    });
    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    final router = createAppRouter(initialLocation: '/routine/$routineId');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await _flush(tester);
    expect(find.text('Flat Barbell Bench Press'), findsOneWidget);
    expect(find.text('Barbell Row'), findsOneWidget);
    expect(find.text('Last values'), findsNWidgets(6));
    expect(find.byTooltip('Add exercise').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Add set for Flat Barbell Bench Press'));
    await _flush(tester);
    await tester.tap(find.text('Last values').first);
    await _flush(tester);
    final dialog = find.byType(AppDialog);
    final fields = find.descendant(of: dialog, matching: find.byType(TextFormField));
    await tester.enterText(fields.at(0), '60');
    await tester.enterText(fields.at(1), '8');
    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.text('Save'));
    await _flush(tester);
    List<RoutineSet>? presets;
    unawaited(repo.watchSets(dayId).first.then((value) => presets = value));
    await _flush(tester);
    expect(presets!.where((s) => s.exerciseId == benchId).every((s) => s.rawWeight == 60 && s.reps == 8), true);
    expect(presets!.length, 7);
    await tester.tap(find.byTooltip('Flat Barbell Bench Press options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move down'));
    await _flush(tester);
    unawaited(repo.watchSets(dayId).first.then((value) => presets = value));
    await _flush(tester);
    expect(presets!.take(3).every((s) => s.exerciseId == rowId), true);
    await tester.tap(find.text('Add to today'));
    await _flush(tester);
    List<WorkoutSet>? logged;
    unawaited((db.select(db.workoutSets)..where((s) => s.date.equals(Dates.today()))).get().then((value) => logged = value));
    await _flush(tester);
    expect(logged, hasLength(7));
    expect(logged!.every((s) => s.isPlanned), true);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    container.dispose();
    final closed = db.close();
    await _flush(tester);
    await closed;
  });

  test('duplicate and reorder presets preserve values and deletion removes the chosen set', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final repo = RoutineRepository(db);
    final exercise = (await db.select(db.exercises).get()).first;
    final routine = await repo.create('Template');
    final day = (await repo.watchDays(routine).first).single;
    await repo.addExercise(day.id, exercise.id, count: 2);
    final first = (await repo.watchSets(day.id).first).first;
    await repo.updateSet(first.id, const RoutineSetsCompanion(rawWeight: Value(40), reps: Value(6), groupName: Value('A')));
    await repo.duplicateSet(first.id);
    final sets = await repo.watchSets(day.id).first;
    expect(sets, hasLength(3));
    expect(sets[1].rawWeight, 40);
    expect(sets[1].groupName, 'A');
    await repo.swapSetOrder(sets[1].id, sets[2].id);
    expect((await repo.watchSets(day.id).first).last.id, sets[1].id);
    await repo.deleteSet(sets.first.id);
    expect((await repo.watchSets(day.id).first).any((s) => s.id == sets.first.id), false);
  });
}
