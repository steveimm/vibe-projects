import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitnotes_plus/features/workout_log/workout_calendar.dart';

void main() {
  testWidgets('calendar exposes separate date targets and follows the chosen week start', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      String? selected;
      Future<void> show(int start) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WorkoutCalendar(
                key: ValueKey(start),
                initialMonth: '2026-03-02',
                firstDayOfWeek: start,
                dayColors: const {
                  '2026-03-02': [0xFF326A59],
                },
                onSelectDay: (date) => selected = date,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      final sunday = find.bySemanticsLabel(RegExp(r'^Sunday, March 1 2026'));
      final monday = find.bySemanticsLabel(RegExp(r'^Monday, March 2 2026'));
      await show(7);
      expect(tester.getCenter(sunday).dx, lessThan(tester.getCenter(monday).dx));
      await tester.tap(monday);
      expect(selected, '2026-03-02');
      await show(1);
      expect(tester.getCenter(monday).dx, lessThan(tester.getCenter(sunday).dx));
    } finally {
      semantics.dispose();
    }
  });
}
