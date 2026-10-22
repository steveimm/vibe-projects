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
import 'package:fitnotes_plus/core/util/format.dart';

Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  for (final imperial in [false, true]) {
    test('v10 upgrade and restore preserve configured increments with imperial=$imperial', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final folder = Directory.systemTemp.createTempSync('fitnotes-increments-');
      addTearDown(() => folder.deleteSync(recursive: true));
      final repo = ExerciseRepository(db);
      final category = (await repo.getCategories()).first.id;
      final systemUnits = Units(imperial);
      await db
          .update(db.appSettings)
          .write(AppSettingsCompanion(useImperial: Value(imperial), defaultWeightIncrement: Value(systemUnits.weightToKg(2.5))));
      final ids = <int>[];
      for (final unit in [null, WeightUnit.kilograms, WeightUnit.pounds]) {
        ids.add(
          await repo.createExercise(
            name: 'Step $unit',
            categoryId: category,
            type: ExerciseType.weightAndReps,
            weightUnit: Value(unit),
            weightIncrement: systemUnits.withWeightUnit(unit).weightToKg(2.5),
          ),
        );
      }
      await WorkoutRepository(db).addSet(exerciseId: ids.first, date: '2026-10-01', rawWeight: 40, reps: 8);
      final service = BackupService(db);
      final old = File('${folder.path}/v10.fitnotesplus')..writeAsBytesSync(await service.backup(directory: folder));
      final raw = sqlite.sqlite3.open(old.path);
      raw.execute('PRAGMA user_version = 10');
      raw.close();
      final migrated = AppDatabase(NativeDatabase(old.copySync('${folder.path}/migration.sqlite')));
      addTearDown(migrated.close);
      await service.restore(old.path);
      for (final current in [db, migrated]) {
        expect((await current.select(current.appSettings).getSingle()).defaultWeightIncrement, closeTo(2.5, 1e-12));
        for (final id in ids) {
          expect((await ExerciseRepository(current).getExercise(id)).weightIncrement, closeTo(2.5, 1e-12));
        }
        final defaults = (await current.select(current.exercises).get()).where((e) => !ids.contains(e.id));
        expect(defaults.every((e) => e.weightIncrement == null), isTrue);
        expect((await current.select(current.workoutSets).getSingle()).rawWeight, 40);
        expect(await current.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      }
      final backup = File('${folder.path}/v11.fitnotesplus')..writeAsBytesSync(await service.backup(directory: folder));
      await service.restore(backup.path);
      expect((await db.select(db.appSettings).getSingle()).defaultWeightIncrement, closeTo(2.5, 1e-12));
      expect((await repo.getExercise(ids.last)).weightIncrement, closeTo(2.5, 1e-12));
    });
  }

  testWidgets('default and custom increments add the same number in lb and kg, and settings have no unit', (tester) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase.memory();
    late int id;
    await tester.runAsync(() async {
      final repo = ExerciseRepository(db);
      id = await repo.createExercise(
        name: 'Press',
        categoryId: (await repo.getCategories()).first.id,
        type: ExerciseType.weightAndReps,
        weightUnit: const Value(WeightUnit.pounds),
      );
      await db
          .update(db.appSettings)
          .write(const AppSettingsCompanion(useImperial: Value(true), defaultWeightIncrement: Value(1.25)));
    });
    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    final router = createAppRouter(initialLocation: '/settings');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await _flush(tester);
    final incrementTile = find.widgetWithText(ListTile, 'Weight increment');
    expect((tester.widget<ListTile>(incrementTile).subtitle as Text).data, '1.25');
    await tester.tap(incrementTile);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).decoration?.labelText, 'Increment');
    await tester.enterText(find.byType(TextFormField), '2.5');
    await tester.tap(find.text('Save'));
    await _flush(tester);
    await tester.runAsync(() async {
      expect((await db.select(db.appSettings).getSingle()).defaultWeightIncrement, 2.5);
      await db.update(db.appSettings).write(const AppSettingsCompanion(useImperial: Value(false)));
    });
    await _flush(tester);
    expect((tester.widget<ListTile>(incrementTile).subtitle as Text).data, '2.5');
    router.go('/log/$id?date=2026-10-01');
    await _flush(tester);
    await tester.enterText(find.byType(TextField).first, '50');
    await tester.tap(find.byTooltip('Increase Weight'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, '52.5');
    await tester.tap(find.text('Weight · lb'));
    await _flush(tester);
    await tester.tap(find.byTooltip('Decrease Weight'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, '50');
    await tester.tap(find.byTooltip('Log set'));
    await _flush(tester);
    await tester.runAsync(() async => expect((await db.select(db.workoutSets).getSingle()).rawWeight, closeTo(50, 1e-12)));
    await tester.tap(find.byTooltip('Edit exercise'));
    await _flush(tester);
    final step = find.widgetWithText(TextFormField, 'Weight step');
    final stepInput = find.descendant(of: step, matching: find.byType(TextField));
    expect(tester.widget<TextField>(stepInput).decoration?.suffixText, isNull);
    await tester.enterText(step, '1.25');
    await tester.tap(find.byTooltip('Save exercise'));
    await _flush(tester);
    await tester.tap(find.text('Weight · kg'));
    await _flush(tester);
    await tester.tap(find.byTooltip('Increase Weight'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, '51.25');
    await tester.tap(find.text('Weight · lb'));
    await _flush(tester);
    await tester.tap(find.byTooltip('Decrease Weight'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, '50');
    await tester.tap(find.byTooltip('Edit exercise'));
    await _flush(tester);
    expect(tester.widget<TextFormField>(step).controller!.text, '1.25');
    expect(tester.widget<TextField>(stepInput).decoration?.suffixText, isNull);
    await tester.runAsync(() async => expect((await ExerciseRepository(db).getExercise(id)).weightIncrement, 1.25));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    container.dispose();
    final closed = db.close();
    await _flush(tester);
    await closed;
  });
}
