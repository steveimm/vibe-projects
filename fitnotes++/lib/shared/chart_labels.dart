import 'package:flutter/material.dart';

double axisLabelWidth(BuildContext context, Iterable<String> labels) {
  var width = 0.0;
  for (final label in labels) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: DefaultTextStyle.of(context).style.copyWith(fontSize: 10)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    if (painter.width > width) width = painter.width;
    painter.dispose();
  }
  return width + 8;
}
