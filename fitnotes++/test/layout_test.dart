import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitnotes_plus/shared/widgets.dart';

void main() {
  testWidgets('large summary numbers stay separated at 200 percent text size', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 330,
                child: Row(
                  children: const [
                    Expanded(child: StatValue('Sets logged', '4')),
                    Expanded(child: StatValue('Volume · lb', '2223.53')),
                    Expanded(child: StatValue('Planned sets', '2')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final volume = tester.renderObject<RenderBox>(find.text('2223.53'));
    final planned = tester.renderObject<RenderBox>(find.text('2'));
    final right = volume.localToGlobal(Offset(volume.size.width, 0)).dx;
    final left = planned.localToGlobal(Offset.zero).dx;
    expect(right, lessThan(left));
    expect(tester.takeException(), isNull);
  });
}
