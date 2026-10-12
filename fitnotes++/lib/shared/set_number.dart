import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SetNumber extends StatelessWidget {
  const SetNumber({super.key, required this.number, this.loggedAt});
  final int number;
  final DateTime? loggedAt;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    final measure = TextPainter(
      text: TextSpan(text: '00:00', style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = math.max(44.0, measure.width + 8);
    measure.dispose();
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$number', style: style),
          if (loggedAt case final time?)
            Tooltip(
              message: DateFormat('d MMM yyyy, HH:mm:ss').format(time.toLocal()),
              child: Text(DateFormat.Hm().format(time.toLocal()), style: style),
            ),
        ],
      ),
    );
  }
}
