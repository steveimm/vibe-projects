import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:fitnotes_plus/app/theme.dart';
import 'package:fitnotes_plus/core/database/database.dart';
import 'package:fitnotes_plus/core/providers.dart';
import 'package:fitnotes_plus/core/repositories/progress_repository.dart';
import 'package:fitnotes_plus/core/util/dates.dart';
import 'package:fitnotes_plus/features/progress/body_tab.dart';
import 'package:fitnotes_plus/shared/progress_chart.dart';

Future<void> flush(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('measurement filters apply to every chart and leave recording independent of the selected range', (tester) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase.memory();
    final repo = ProgressRepository(db);
    final today = Dates.today();
    await tester.runAsync(() async {
      await db.select(db.measurementTypes).get();
      for (final entry in [(400, 80.0), (150, 79.0), (60, 78.0), (7, 77.0), (0, 76.0)]) {
        await repo.saveMeasurement(1, Dates.shift(today, -entry.$1), entry.$2, '');
      }
      await repo.saveMeasurement(2, Dates.shift(today, -150), 18, '');
    });
    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light, home: const BodyTab()),
      ),
    );
    await flush(tester);
    ProgressChart chart() => tester.widget<ProgressChart>(find.byKey(const ValueKey('measurement-chart-1')));
    expect(chart().points.map((p) => p.value), [77, 76]);
    expect(find.byKey(const ValueKey('measurement-chart-2')), findsNothing);
    for (final entry in {'3m': 3, '6m': 4, 'All': 5}.entries) {
      await tester.tap(find.text(entry.key));
      await flush(tester);
      expect(chart().points.length, entry.value);
    }
    expect(find.byKey(const ValueKey('measurement-chart-2')), findsOneWidget);
    await tester.tap(find.byTooltip('Custom range'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to input'));
    await tester.pumpAndSettle();
    final fields = find.descendant(of: find.byType(DateRangePickerDialog), matching: find.byType(TextField));
    final day = Dates.shift(today, -7);
    for (var i = 0; i < 2; i++) {
      await tester.enterText(fields.at(i), DateFormat('MM/dd/yyyy').format(Dates.parse(day)));
    }
    await tester.tap(find.text('OK'));
    await flush(tester);
    expect(chart().points, [(date: day, value: 77.0)]);
    expect(find.text(Dates.rangeLabel(day, day)), findsOneWidget);
    expect(find.textContaining('76 kg'), findsNothing);
    expect(tester.takeException(), isNull, reason: 'after first custom range');
    await tester.tap(find.byTooltip('Record Bodyweight'));
    await flush(tester);
    expect(tester.widget<TextFormField>(find.byType(TextFormField).first).controller!.text, '76');
    expect(tester.takeException(), isNull, reason: 'record dialog');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Custom range'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'reopened custom range');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(chart().points.single.date, day);
    await tester.tap(find.text('1m'));
    await flush(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    await tester.pump();
    expect(tester.takeException(), isNull);
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    final closed = db.close();
    await flush(tester);
    await closed;
  });
}
