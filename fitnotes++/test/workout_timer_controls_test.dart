import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitnotes_plus/app/theme.dart';
import 'package:fitnotes_plus/core/database/database.dart';
import 'package:fitnotes_plus/core/providers.dart';
import 'package:fitnotes_plus/core/util/dates.dart';
import 'package:fitnotes_plus/features/workout_log/workout_session_card.dart';

void main() {
  testWidgets('past and future workouts expose only the duration menu, with no duplicate inline editor', (tester) async {
    final now = DateTime.now();
    for (final offset in [-1, 1]) {
      final date = Dates.shift(Dates.today(), offset);
      for (final state in ['empty', 'running', 'paused', 'finished']) {
        final session = state == 'empty'
            ? null
            : WorkoutSession(
                date: date,
                startedAt: now,
                elapsedSeconds: 600,
                runningSince: state == 'running' ? now : null,
                endedAt: state == 'finished' ? now : null,
              );
        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey('$offset-$state'),
            overrides: [
              settingsProvider.overrideWith((ref) => const Stream.empty()),
              sessionProvider.overrideWith((ref, date) => Stream.value(session)),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(
                body: WorkoutSessionCard(date: date, sets: const []),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final control in ['Start', 'Pause', 'Resume', 'Finish']) {
          expect(find.text(control), findsNothing);
          expect(find.byTooltip(control), findsNothing);
        }
        expect(find.byIcon(Icons.edit_outlined), findsNothing);
        await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('workout-duration'))));
        await tester.pumpAndSettle();
        expect(find.byType(TextFormField), findsNothing);
        await tester.tap(find.byTooltip('Workout timer options'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit duration'));
        await tester.pumpAndSettle();
        expect(find.text('Workout duration'), findsOneWidget);
        expect(find.byType(TextFormField), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
