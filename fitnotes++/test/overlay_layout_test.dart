import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitnotes_plus/app/theme.dart';
import 'package:fitnotes_plus/shared/widgets.dart';

void main() {
  testWidgets('form dialogs keep actions reachable with a keyboard and large text on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final scale in [1.0, 2.0]) {
      String? saved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale), viewInsets: const EdgeInsets.only(bottom: 260)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  saved = await prompt(context, title: 'Workout duration', label: 'Time (h:mm:ss or m:ss)', value: '25:00');
                },
                child: const Text('Edit duration'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit duration'));
      await tester.pumpAndSettle();
      expect(find.text('Save').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextFormField), '30:00');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved, '30:00');
      expect(tester.takeException(), isNull);
    }
  });
}
