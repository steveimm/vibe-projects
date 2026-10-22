import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:fitnotes_plus/app/router.dart';
import 'package:fitnotes_plus/app/theme.dart';
import 'package:fitnotes_plus/core/database/database.dart';
import 'package:fitnotes_plus/core/database/tables.dart';
import 'package:fitnotes_plus/core/providers.dart';
import 'package:fitnotes_plus/core/repositories/exercise_repository.dart';
import 'package:fitnotes_plus/core/repositories/workout_repository.dart';
import 'package:fitnotes_plus/core/services/backup_service.dart';
import 'package:fitnotes_plus/core/util/dates.dart';
import 'package:fitnotes_plus/core/util/format.dart';
import 'package:fitnotes_plus/shared/widgets.dart';

Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  test('exercise input units convert independently, stacked factors are captured once, and backup preserves them', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final exercises = ExerciseRepository(db);
    final workouts = WorkoutRepository(db);
    final category = (await db.select(db.categories).get()).first.id;
    final id = await exercises.createExercise(
      name: 'Pulley',
      categoryId: category,
      type: ExerciseType.weightAndReps,
      weightUnit: const Value(WeightUnit.pounds),
      multipliers: [
        (label: '', factor: 0.5, enabled: true),
        (label: 'Cable', factor: 0.8, enabled: true),
        (label: '', factor: 3.0, enabled: false),
      ],
    );
    final input = const Units().withWeightUnit((await exercises.getExercise(id)).weightUnit);
    expect(input.weightLabel, 'lb');
    expect(input.distanceLabel, 'km');
    final setId = await workouts.addSet(exerciseId: id, date: '2026-10-01', rawWeight: input.weightToKg(100), reps: 8);
    final first = (await workouts.dayLog('2026-10-01')).single;
    expect(first.set.rawWeight, closeTo(45.359237, 1e-10));
    expect(first.set.weightMultiplier, 0.4);
    expect(first.effectiveWeight, closeTo(18.1436948, 1e-10));
    expect((await exercises.watchMultipliers(id).first).map((m) => m.label), ['Multiplier 1', 'Cable', 'Multiplier 2']);
    await exercises.updateExercise(
      id: id,
      name: 'Pulley',
      categoryId: category,
      type: ExerciseType.weightAndReps,
      weightUnit: const Value(WeightUnit.kilograms),
      multipliers: [(label: '', factor: 2.0, enabled: true)],
    );
    await workouts.updateSet(setId, reps: 9);
    expect((await workouts.dayLog('2026-10-01')).single.effectiveWeight, first.effectiveWeight);
    final imperialApp = const Units(true).withWeightUnit((await exercises.getExercise(id)).weightUnit);
    expect(imperialApp.weightLabel, 'kg');
    expect(imperialApp.distanceLabel, 'mi');
    await workouts.addSet(exerciseId: id, date: '2026-10-02', rawWeight: imperialApp.weightToKg(20), reps: 8);
    expect((await workouts.dayLog('2026-10-02')).single.effectiveWeight, 40);
    await exercises.updateExercise(id: id, name: 'Renamed', categoryId: category, type: ExerciseType.weightAndReps);
    expect((await exercises.getExercise(id)).weightUnit, WeightUnit.kilograms, reason: 'Unrelated updates preserve the override');
    final folder = Directory.systemTemp.createTempSync('fitnotes-unit-backup-');
    addTearDown(() => folder.deleteSync(recursive: true));
    final service = BackupService(db);
    final file = File('${folder.path}/units.fitnotesplus')..writeAsBytesSync(await service.backup(directory: folder));
    await exercises.updateExercise(
      id: id,
      name: 'Changed',
      categoryId: category,
      type: ExerciseType.weightAndReps,
      weightUnit: const Value(null),
      multipliers: [],
    );
    await service.restore(file.path);
    expect((await exercises.getExercise(id)).weightUnit, WeightUnit.kilograms);
    expect((await exercises.watchMultipliers(id).first).single.factor, 2);
    expect((await workouts.dayLog('2026-10-01')).single.set.weightMultiplier, 0.4);
    await expectLater(
      exercises.createExercise(
        name: 'Invalid factor',
        categoryId: category,
        type: ExerciseType.weightAndReps,
        multipliers: [(label: '', factor: double.nan, enabled: true)],
      ),
      throwsFormatException,
    );
    expect(await (db.select(db.exercises)..where((e) => e.name.equals('Invalid factor'))).get(), isEmpty);
  });

  test('version 5 migrates and restores with app-unit defaults without changing old weights', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final folder = Directory.systemTemp.createTempSync('fitnotes-unit-migration-');
    addTearDown(() => folder.deleteSync(recursive: true));
    final exercise = (await db.select(db.exercises).get()).first;
    await WorkoutRepository(db).addSet(exerciseId: exercise.id, date: '2026-10-01', reps: 8);
    final service = BackupService(db);
    final file = File('${folder.path}/v5.fitnotesplus')..writeAsBytesSync(await service.backup(directory: folder));
    final raw = sqlite.sqlite3.open(file.path);
    raw.execute('ALTER TABLE exercises DROP COLUMN weight_unit');
    raw.execute('ALTER TABLE exercises DROP COLUMN include_bodyweight');
    raw.execute('ALTER TABLE workout_sets DROP COLUMN bodyweight');
    raw.execute('ALTER TABLE workout_sets DROP COLUMN logged_at');
    raw.execute('ALTER TABLE pr_reset_markers DROP COLUMN initials');
    raw.execute('ALTER TABLE app_settings DROP COLUMN workout_auto_stop_minutes');
    raw.execute('ALTER TABLE workout_sessions DROP COLUMN last_set_at');
    raw.execute('ALTER TABLE workout_sessions DROP COLUMN elapsed_at_last_set');
    raw.execute('PRAGMA user_version = 5');
    raw.close();
    final migrated = AppDatabase(NativeDatabase(file.copySync('${folder.path}/migrate.sqlite')));
    addTearDown(migrated.close);
    expect((await migrated.select(migrated.exercises).get()).every((e) => e.weightUnit == null), isTrue);
    expect((await migrated.select(migrated.workoutSets).get()).single.reps, 8);
    await db.update(db.exercises).write(const ExercisesCompanion(weightUnit: Value(WeightUnit.pounds)));
    await service.restore(file.path);
    expect((await db.select(db.exercises).get()).every((e) => e.weightUnit == null), isTrue);
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });

  testWidgets('new exercises can stack unnamed multipliers and canceling later edits keeps saved settings', (tester) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase.memory();
    await tester.runAsync(() => db.update(db.appSettings).write(const AppSettingsCompanion(useImperial: Value(true))));
    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    final router = createAppRouter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await _flush(tester);
    await tester.tap(find.byTooltip('Add exercise'));
    await _flush(tester);
    await tester.tap(find.byTooltip('Create exercise'));
    await _flush(tester);
    await tester.enterText(find.byType(TextFormField).first, 'New pulley');
    expect(find.text('Weight unit'), findsNothing);
    for (final factor in ['0.5', '0.8']) {
      await tester.tap(find.byTooltip('Add multiplier'));
      await tester.pumpAndSettle();
      final fields = find.descendant(of: find.byType(AppDialog), matching: find.byType(TextFormField));
      await tester.enterText(fields.first, factor);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    }
    expect(tester.widget<EditableText>(find.byType(EditableText).first).focusNode.hasFocus, isFalse);
    expect(find.text('Multiplier 1'), findsOneWidget);
    expect(find.text('Multiplier 2'), findsOneWidget);
    await tester.tap(find.byType(Switch).last);
    await tester.pump();
    await tester.tap(find.byTooltip('Save exercise'));
    await _flush(tester);
    late Exercise exercise;
    await tester.runAsync(() async {
      exercise = (await (db.select(db.exercises)..where((e) => e.name.equals('New pulley'))).get()).single;
      expect(exercise.weightUnit, isNull);
      final factors = await (db.select(db.exerciseMultipliers)..where((m) => m.exerciseId.equals(exercise.id))).get();
      expect(factors.map((m) => m.label), ['Multiplier 1', 'Multiplier 2']);
      expect(factors.map((m) => m.factor), [0.5, 0.8]);
      expect(factors.map((m) => m.enabled), [true, false]);
    });
    await tester.tap(find.text('Weight · lb'));
    await _flush(tester);
    expect(find.text('Weight · kg'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit exercise'));
    await _flush(tester);
    await tester.tap(find.text('Multiplier 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Multiplier 1'), findsNothing);
    await tester.binding.handlePopRoute();
    await _flush(tester);
    await tester.runAsync(
      () async =>
          expect(await (db.select(db.exerciseMultipliers)..where((m) => m.exerciseId.equals(exercise.id))).get(), hasLength(2)),
    );
    await tester.tap(find.byTooltip('Edit exercise'));
    await _flush(tester);
    expect(find.text('Weight unit'), findsNothing);
    await tester.tap(find.byTooltip('Save exercise'));
    await _flush(tester);
    await tester.runAsync(() async {
      expect((await ExerciseRepository(db).getExercise(exercise.id)).weightUnit, WeightUnit.kilograms);
      expect((await db.select(db.appSettings).getSingle()).useImperial, isTrue);
      expect((await db.select(db.exercises).get()).where((e) => e.id != exercise.id).every((e) => e.weightUnit == null), isTrue);
    });
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    container.dispose();
    final closed = db.close();
    await _flush(tester);
    await closed;
  });

  testWidgets('unit toggles keep the entered number and save it using the selected unit, including set edits', (tester) async {
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase.memory();
    final repo = ExerciseRepository(db);
    late int id;
    await tester.runAsync(() async {
      final category = (await db.select(db.categories).get()).first.id;
      id = await repo.createExercise(
        name: 'Pulley',
        categoryId: category,
        type: ExerciseType.weightAndReps,
        weightUnit: const Value(WeightUnit.pounds),
        multipliers: [(label: 'Pulley', factor: 0.5, enabled: true), (label: 'Cable', factor: 0.8, enabled: true)],
      );
    });
    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    final router = createAppRouter(initialLocation: '/log/$id?date=${Dates.today()}');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await _flush(tester);
    expect(find.text('Weight · lb'), findsOneWidget);
    for (final width in [320.0, 360.0, 390.0]) {
      tester.view.physicalSize = Size(width, 850);
      for (final scale in [1.0, 1.3, 2.0]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        await tester.enterText(find.byType(TextField).first, '999.99');
        await tester.pump();
        final editable = tester.state<EditableTextState>(find.byType(EditableText).first).renderEditable;
        expect(editable.maxScrollExtent, 0, reason: '999.99 must fit at width $width and text scale $scale');
        if (scale <= 1.3) {
          final weightCard = find.ancestor(of: find.byType(TextField).first, matching: find.byType(Card));
          final repsCard = find.ancestor(of: find.byType(TextField).at(1), matching: find.byType(Card));
          expect(tester.getSize(weightCard).height, tester.getSize(repsCard).height);
        }
        expect(tester.takeException(), isNull);
      }
    }
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.view.physicalSize = const Size(390, 850);
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '100');
    await tester.enterText(find.byType(TextField).at(1), '8');
    await tester.pump();
    expect(find.text('× 0.45 (lb to kg) × 0.5 (Pulley) × 0.8 (Cable) = 18.14 kg'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Weight · lb'));
      await _flush(tester);
      expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, '100');
      expect(find.text('× 0.5 (Pulley) × 0.8 (Cable) = 40 kg'), findsOneWidget);
      await tester.tap(find.text('Weight · kg'));
      await _flush(tester);
      expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, '100');
    }
    await tester.tap(find.byTooltip('Log set'));
    await _flush(tester);
    List<LoggedSet>? logged;
    await tester.runAsync(() async => logged = await WorkoutRepository(db).dayLog(Dates.today()));
    final original = logged!.single.set;
    expect(original.rawWeight, closeTo(45.359237, 1e-10));
    expect(original.weightMultiplier, 0.4);
    expect(find.text('18.14 kg × 8 reps'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('logged-set-${original.id}')));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, '100');
    await tester.enterText(find.byType(TextField).at(1), '9');
    await tester.tap(find.byTooltip('Update set'));
    await _flush(tester);
    await tester.runAsync(() async => logged = await WorkoutRepository(db).dayLog(Dates.today()));
    expect(logged!.single.set.rawWeight, original.rawWeight);
    await tester.tap(find.byKey(ValueKey('logged-set-${original.id}')));
    await tester.pump();
    await tester.showKeyboard(find.byType(TextField).first);
    await tester.tap(find.text('Weight · lb'));
    await _flush(tester);
    expect(find.text('Weight · kg'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, '100');
    expect(tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text, '9');
    await tester.tap(find.byTooltip('Update set'));
    await _flush(tester);
    await tester.runAsync(() async => logged = await WorkoutRepository(db).dayLog(Dates.today()));
    expect(logged!.single.set.rawWeight, 100);
    expect(logged!.single.set.weightMultiplier, original.weightMultiplier);
    expect(logged!.single.set.reps, 9);
    await tester.runAsync(() async {
      expect((await repo.getExercise(id)).weightUnit, WeightUnit.kilograms);
      expect((await db.select(db.appSettings).getSingle()).useImperial, isFalse);
    });
    await tester.runAsync(() async {
      await repo.updateExercise(
        id: id,
        name: 'Pulley',
        categoryId: (await repo.getExercise(id)).categoryId,
        type: ExerciseType.weightAndReps,
        multipliers: [(label: 'New pulley', factor: 0.5, enabled: true)],
      );
    });
    await _flush(tester);
    await tester.tap(find.byKey(ValueKey('logged-set-${original.id}')));
    await tester.pump();
    expect(find.text('× 0.4 (Saved multiplier) = 40 kg'), findsOneWidget);
    expect(find.textContaining('New pulley'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    container.dispose();
    final closed = db.close();
    await _flush(tester);
    await closed;
  });
}
