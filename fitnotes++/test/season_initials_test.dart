import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:fitnotes_plus/app/theme.dart';
import 'package:fitnotes_plus/core/database/database.dart';
import 'package:fitnotes_plus/core/models/season.dart';
import 'package:fitnotes_plus/core/providers.dart';
import 'package:fitnotes_plus/core/repositories/progress_repository.dart';
import 'package:fitnotes_plus/core/repositories/stats_repository.dart';
import 'package:fitnotes_plus/core/repositories/workout_repository.dart';
import 'package:fitnotes_plus/core/services/backup_service.dart';
import 'package:fitnotes_plus/features/settings/seasons_screen.dart';
import 'package:fitnotes_plus/shared/record_badge.dart';

Future<void> flush(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  test('automatic initials use whitespace-separated first characters and handle Unicode', () {
    expect(initialsFromName('  autumn\tstrength\ntraining '), 'AST');
    expect(initialsFromName('Let’s GO'), 'LG');
    expect(initialsFromName('énergie Été'), 'ÉÉ');
    expect(initialsFromName('e\u0301nergie training'), 'E\u0301T');
    expect(initialsFromName('여름 운동'), '여운');
    expect(initialsFromName(''), '');
    final unnamed = PrResetMarker(id: 2, date: '2025-01-01', createdAt: DateTime(2025));
    expect(unnamed.displayName, 'Season 2');
    expect(unnamed.displayInitials, 'S2');
  });

  test('season initials survive backups and older seasons acquire automatic initials on upgrade and restore', () async {
    final folder = Directory.systemTemp.createTempSync('fitnotes-season-');
    addTearDown(() => folder.deleteSync(recursive: true));
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final repo = ProgressRepository(db);
    await repo.startSeason('2025-03-01', 'Spring training', initials: '  SPR  ');
    await repo.startSeason('2025-04-01', 'Summer strength');
    final service = BackupService(db);
    final current = File('${folder.path}/current.fitnotesplus')..writeAsBytesSync(await service.backup(directory: folder));
    await db.delete(db.prResetMarkers).go();
    await service.restore(current.path);
    expect((await repo.watchSeasons().first).map((s) => s.displayInitials), ['SS', 'SPR']);
    final old = current.copySync('${folder.path}/version8.fitnotesplus');
    final raw = sqlite.sqlite3.open(old.path);
    raw.execute('ALTER TABLE pr_reset_markers DROP COLUMN initials');
    raw.execute('PRAGMA user_version = 8');
    raw.close();
    final migrated = AppDatabase(NativeDatabase(old.copySync('${folder.path}/migrated.sqlite')));
    addTearDown(migrated.close);
    await service.restore(old.path);
    for (final database in [db, migrated]) {
      final seasons = await ProgressRepository(database).watchSeasons().first;
      expect(seasons.map((s) => s.displayInitials), ['SS', 'ST']);
      expect(seasons.every((s) => s.initials == null), true);
      expect(await database.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    }
  });

  test('editing a season preserves identity and workout data while updating its PR window and automatic initials', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final repo = ProgressRepository(db);
    await repo.startSeason('2025-03-01', 'Spring training', initials: 'ST');
    await repo.startSeason('2025-04-01', 'Summer training', initials: 'SUM');
    final original = (await repo.watchSeasons().first).first;
    final spring = (await repo.watchSeasons().first).last;
    final workouts = WorkoutRepository(db);
    final exercise = (await db.select(db.exercises).get()).firstWhere((e) => e.name == 'Flat Barbell Bench Press');
    final gold = await workouts.addSet(exerciseId: exercise.id, date: '2025-01-01', rawWeight: 100, reps: 5);
    final early = await workouts.addSet(exerciseId: exercise.id, date: '2025-03-05', rawWeight: 80, reps: 5);
    final late = await workouts.addSet(exerciseId: exercise.id, date: '2025-03-20', rawWeight: 90, reps: 5);
    final sets = await db.select(db.workoutSets).get();
    await repo.updateSeason(original.id, '2025-03-10', '  Late spring  ', initials: '  ');
    final seasons = await repo.watchSeasons().first;
    final edited = seasons.first;
    expect(seasons, hasLength(2));
    expect(edited.id, original.id);
    expect(edited.createdAt, original.createdAt);
    expect(edited.note, 'Late spring');
    expect(edited.initials, isNull);
    expect(edited.displayInitials, 'LS');
    expect(await db.select(db.workoutSets).get(), sets);
    final records = Stats.recordAchievements(sets, seasons);
    expect(records[gold]!.scope, RecordScope.allTime);
    expect(records[early]!.season!.id, spring.id);
    expect(records[late]!.season!.id, edited.id);
    await expectLater(repo.updateSeason(edited.id, '2025-02-30', 'Invalid'), throwsFormatException);
    expect((await repo.watchSeasons().first).first, edited);
    await expectLater(repo.updateSeason(999, '2025-03-10', 'Missing'), throwsFormatException);
  });

  for (final custom in [false, true]) {
    testWidgets('season dialog ${custom ? 'saves custom initials' : 'previews and uses automatic initials'}', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDatabase.memory();
      final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(theme: AppTheme.light, home: const SeasonsScreen()),
        ),
      );
      await flush(tester);
      await tester.tap(find.byTooltip('Start a season'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.first, 'Autumn strength training');
      await tester.pump();
      expect(tester.widget<TextField>(fields.at(1)).decoration!.hintText, 'AST');
      expect(find.text('AST'), findsOneWidget);
      if (custom) await tester.enterText(fields.at(1), 'A26');
      await tester.tap(find.text('Start season'));
      await flush(tester);
      List<PrResetMarker>? saved;
      await tester.runAsync(() async => saved = await ProgressRepository(db).watchSeasons().first);
      expect(saved!.single.displayInitials, custom ? 'A26' : 'AST');
      expect(saved!.single.initials, custom ? 'A26' : null);
      expect(find.text(custom ? 'A26' : 'AST'), findsOneWidget);
      final trophies = find.byIcon(Icons.emoji_events_rounded);
      expect(tester.getCenter(trophies.first).dx, tester.getCenter(trophies.last).dx);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      final closed = db.close();
      await flush(tester);
      await closed;
    });
  }

  testWidgets('compact season rows open a prefilled editor, save all fields, and discard cancelled edits', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase.memory();
    final repo = ProgressRepository(db);
    late PrResetMarker original;
    await tester.runAsync(() async {
      await repo.startSeason('2025-03-01', 'Spring training', initials: 'ST');
      original = (await repo.watchSeasons().first).single;
    });
    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light, home: const SeasonsScreen()),
      ),
    );
    await flush(tester);
    final card = find.byKey(ValueKey('season-${original.id}'));
    expect(tester.getSize(card).height, lessThanOrEqualTo(80));
    expect(tester.getSize(find.widgetWithIcon(IconButton, Icons.delete_outline_rounded)).height, greaterThanOrEqualTo(48));
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.text('Edit PR season'), findsOneWidget);
    final fields = find.byType(TextField);
    expect(tester.widget<TextField>(fields.first).controller!.text, 'Spring training');
    expect(tester.widget<TextField>(fields.at(1)).controller!.text, 'ST');
    await tester.enterText(fields.first, 'Summer strength');
    await tester.enterText(fields.at(1), '');
    await tester.pump();
    expect(find.text('SS'), findsOneWidget);
    await tester.tap(find.text('2025-03-01'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to input'));
    await tester.pumpAndSettle();
    final dateField = find.descendant(of: find.byType(DatePickerDialog), matching: find.byType(TextField));
    await tester.enterText(dateField, '03/15/2025');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await flush(tester);
    late PrResetMarker saved;
    await tester.runAsync(() async => saved = (await repo.watchSeasons().first).single);
    expect(saved.id, original.id);
    expect(saved.createdAt, original.createdAt);
    expect(saved.date, '2025-03-15');
    expect(saved.note, 'Summer strength');
    expect(saved.initials, isNull);
    expect(find.text('SS'), findsOneWidget);
    await tester.tap(card);
    await tester.pumpAndSettle();
    await tester.enterText(fields.first, 'Discard this');
    await tester.enterText(fields.at(1), 'NO');
    await tester.tap(find.text('Cancel'));
    await flush(tester);
    await tester.runAsync(() async => expect((await repo.watchSeasons().first).single, saved));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.pump();
    expect(tester.takeException(), isNull);
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    final closed = db.close();
    await flush(tester);
    await closed;
  });

  testWidgets('season trophy labels remain compact at narrow widths and large text sizes', (tester) async {
    final season = PrResetMarker(id: 1, date: '2025-03-01', note: 'Autumn strength training', createdAt: DateTime(2025));
    for (final scale in [1.0, 2.0]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final scope in RecordScope.values)
                        Row(
                          children: [
                            const Expanded(child: Text('60 kg × 8 reps')),
                            RecordBadge(scope: scope, season: scope == RecordScope.season ? season : null),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('AST'), findsOneWidget);
      expect(find.byTooltip('Season record · Autumn strength training · 2025-03-01'), findsOneWidget);
      for (final badge in find.byType(RecordBadge).evaluate()) {
        expect(tester.getSize(find.byWidget(badge.widget)).width, lessThanOrEqualTo(72));
      }
      final trophies = find.byIcon(Icons.emoji_events_rounded);
      expect(tester.getCenter(trophies.first).dx, tester.getCenter(trophies.last).dx);
      expect(tester.getBottomRight(find.text('AST')).dx, lessThan(tester.getTopLeft(trophies.last).dx));
      expect(tester.takeException(), isNull);
    }
  });
}
