import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitnotes_plus/core/services/rest_timer.dart';
import 'package:fitnotes_plus/shared/rest_timer_bar.dart';

void main() {
  testWidgets('rest timer stays compact inside a scaffold and supports pause/resume', (tester) async {
    var now = DateTime.utc(2026, 10, 7);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [restClockProvider.overrideWithValue(() => now)],
        child: MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Workout editor')),
            bottomNavigationBar: SafeArea(child: RestTimerBar()),
          ),
        ),
      ),
    );
    final container = ProviderScope.containerOf(tester.element(find.byType(RestTimerBar)));
    final timer = container.read(restTimerProvider.notifier);
    timer.start(60, label: 'Bench press');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getSize(find.byType(RestTimerBar)).height, lessThan(100));
    expect(find.text('Workout editor'), findsOneWidget);
    await tester.tap(find.byTooltip('Pause rest timer'));
    await tester.pump();
    final remaining = container.read(restTimerProvider).remaining;
    await tester.pump(const Duration(seconds: 2));
    expect(container.read(restTimerProvider).remaining, remaining);
    await tester.tap(find.text('+15s'));
    await tester.pump();
    expect(container.read(restTimerProvider).remaining, remaining + 15);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Paused · 1:15'), findsOneWidget);
    await tester.tap(find.byTooltip('Resume rest timer'));
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(container.read(restTimerProvider).remaining, 73);
    now = now.add(const Duration(seconds: 74));
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(restTimerProvider).visible, false);
    expect(find.textContaining('Rest complete'), findsNothing);
    expect(tester.getSize(find.byType(RestTimerBar)).height, 0);
    timer.stop();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
