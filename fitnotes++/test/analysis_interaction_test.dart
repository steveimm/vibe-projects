import 'package:drift/drift.dart' show Value;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:fitnotes_plus/app/theme.dart';
import 'package:fitnotes_plus/core/database/database.dart';
import 'package:fitnotes_plus/core/providers.dart';
import 'package:fitnotes_plus/core/repositories/workout_repository.dart';
import 'package:fitnotes_plus/core/util/dates.dart';
import 'package:fitnotes_plus/core/util/workout_analysis.dart';
import 'package:fitnotes_plus/features/progress/progress_screen.dart';
import 'package:fitnotes_plus/shared/workout_chart.dart';

Future<void> flush(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('Analysis metrics, month filters, custom range, and pie use the same workouts', (tester) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase.memory();
    final workouts = WorkoutRepository(db);
    await tester.runAsync(() async {
      final exercises = await db.select(db.exercises).get();
      final bench = exercises.firstWhere((e) => e.name == 'Flat Barbell Bench Press');
      final row = exercises.firstWhere((e) => e.name == 'Barbell Row');
      for (final entry in [
        (400, bench.id, 80.0, 4),
        (150, bench.id, 70.0, 5),
        (60, row.id, 30.0, 10),
        (5, row.id, 20.0, 10),
        (2, bench.id, 60.0, 8),
        (2, bench.id, 60.0, 8),
        (0, bench.id, 50.0, 8),
        (0, bench.id, 55.0, 6),
      ]) {
        await workouts.addSet(
          exerciseId: entry.$2,
          date: Dates.shift(Dates.today(), -entry.$1),
          rawWeight: entry.$3,
          reps: entry.$4,
        );
      }
      await workouts.addSet(exerciseId: row.id, date: Dates.today(), rawWeight: 100, reps: 10, planned: true);
      await db
          .update(db.workoutSessions)
          .write(const WorkoutSessionsCompanion(elapsedSeconds: Value(1200), runningSince: Value(null)));
    });
    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light, home: const ProgressScreen()),
      ),
    );
    await flush(tester);
    expect(find.text('Analysis'), findsOneWidget);
    expect(find.text('Training'), findsNothing);
    expect(find.text('Personal records'), findsNothing);
    expect(tester.widget<WorkoutChart>(find.byType(WorkoutChart)).points.map((p) => p.value), [200, 960, 730]);
    expect(tester.widget<PieChart>(find.byType(PieChart)).data.sections.map((s) => s.value), [4, 1]);
    expect(tester.getBottomRight(find.byType(PieChart)).dy, lessThan(850));
    for (final entry in {'3 months': 4, '6 months': 5, 'All time': 6}.entries) {
      await tester.tap(find.text(entry.key));
      await flush(tester);
      expect(tester.widget<WorkoutChart>(find.byType(WorkoutChart)).points.length, entry.value);
    }
    await tester.tap(find.text('1 month'));
    await flush(tester);
    final metric = find.byType(DropdownButtonFormField<WorkoutMetric>);
    await tester.tap(metric);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sets per workout').last);
    await flush(tester);
    expect(tester.widget<WorkoutChart>(find.byType(WorkoutChart)).points.map((p) => p.value), [1, 2, 2]);
    await tester.tap(metric);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Workout duration').last);
    await flush(tester);
    expect(tester.widget<WorkoutChart>(find.byType(WorkoutChart)).points.single.value, 20);
    await tester.tap(metric);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Volume per workout').last);
    await flush(tester);
    await tester.tap(find.byTooltip('Custom range'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.widget<WorkoutChart>(find.byType(WorkoutChart)).points.length, 3);
    await tester.tap(find.byTooltip('Custom range'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to input'));
    await tester.pumpAndSettle();
    final fields = find.descendant(of: find.byType(DateRangePickerDialog), matching: find.byType(TextField));
    await tester.enterText(fields.at(0), DateFormat('MM/dd/yyyy').format(Dates.parse(Dates.shift(Dates.today(), -5))));
    await tester.enterText(fields.at(1), DateFormat('MM/dd/yyyy').format(Dates.parse(Dates.shift(Dates.today(), -2))));
    await tester.tap(find.text('OK'));
    await flush(tester);
    expect(tester.widget<WorkoutChart>(find.byType(WorkoutChart)).points.map((p) => p.value), [200, 960]);
    expect(tester.widget<PieChart>(find.byType(PieChart)).data.sections.map((s) => s.value), [2, 1]);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    await flush(tester);
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Custom range'), findsOneWidget);
    semantics.dispose();
    expect(tester.takeException(), isNull);
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    final closed = db.close();
    await flush(tester);
    await closed;
  });
}
