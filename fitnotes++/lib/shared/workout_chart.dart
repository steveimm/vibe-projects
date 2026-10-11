import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/repositories/stats_repository.dart';
import '../core/util/dates.dart';
import '../core/util/format.dart';
import '../core/util/workout_analysis.dart';
import 'chart_labels.dart';

class WorkoutChart extends StatelessWidget {
  const WorkoutChart({super.key, required this.points, required this.valueLabel, this.integerAxis = false});
  final List<MetricPoint> points;
  final String Function(double) valueLabel;
  final bool integerAxis;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox(height: 180);
    final colors = Theme.of(context).colorScheme;
    final x = points.map((p) => Dates.daysBetween(points.first.date, p.date).toDouble()).toList();
    final trend = WorkoutAnalysis.trend(points.map((p) => p.value), positions: x);
    final maximum = points.fold<double>(
      math.max(1, math.max(trend?.first ?? 0, trend?.last ?? 0)),
      (n, p) => math.max(n, p.value),
    );
    final rough = maximum / 3;
    final magnitude = math.pow(10, (math.log(rough) / math.ln10).floor()).toDouble();
    var interval = [1.0, 2.0, 5.0, 10.0].firstWhere((n) => n * magnitude >= rough) * magnitude;
    if (integerAxis) interval = math.max(1, interval);
    final maxY = (maximum / interval).ceil() * interval;
    final gap = x.length < 2 ? 1.0 : [for (var i = 1; i < x.length; i++) x[i] - x[i - 1]].reduce(math.min);
    final minX = -gap / 2, maxX = x.last + gap / 2;
    final font = MediaQuery.textScalerOf(context).scale(10);
    final left = axisLabelWidth(context, [for (var i = 0; i <= (maxY / interval).round(); i++) _axisValue(i * interval)]);
    final bottom = math.max(30.0, font * 1.4 + 8);
    return SizedBox(
      height: 180,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final plotWidth = constraints.maxWidth - left;
          final barWidth = math.min(22.0, plotWidth * gap / (maxX - minX) * 0.6);
          return Stack(
            children: [
              Positioned(
                left: left,
                right: 0,
                top: 0,
                bottom: bottom,
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _WorkoutBars(points, x, minX, maxX, maxY, barWidth, colors.primary.withValues(alpha: 0.6)),
                  ),
                ),
              ),
              Positioned.fill(
                bottom: bottom,
                child: LineChart(
                  duration: Duration.zero,
                  LineChartData(
                    minX: minX,
                    maxX: maxX,
                    minY: 0,
                    maxY: maxY,
                    backgroundColor: Colors.transparent,
                    clipData: const FlClipData.all(),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [for (var i = 0; i < points.length; i++) FlSpot(x[i], points[i].value)],
                        color: Colors.transparent,
                        barWidth: 0,
                        dotData: const FlDotData(show: false),
                      ),
                      if (trend != null)
                        LineChartBarData(
                          spots: [FlSpot(x.first, trend.first), FlSpot(x.last, trend.last)],
                          color: colors.onSurfaceVariant,
                          barWidth: 2,
                          dashArray: [5, 4],
                          dotData: const FlDotData(show: false),
                        ),
                    ],
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: interval,
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: colors.outlineVariant.withValues(alpha: 0.6), strokeWidth: 1),
                    ),
                    lineTouchData: LineTouchData(
                      getTouchedSpotIndicator: (bar, indexes) => [
                        for (final _ in indexes)
                          if (bar.color == Colors.transparent)
                            TouchedSpotIndicatorData(
                              FlLine(color: colors.primary, strokeWidth: 1, dashArray: [3, 3]),
                              FlDotData(
                                getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                                  radius: 4,
                                  color: colors.primary,
                                  strokeColor: colors.surface,
                                  strokeWidth: 1,
                                ),
                              ),
                            )
                          else
                            null,
                      ],
                      touchTooltipData: LineTouchTooltipData(
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipColor: (_) => colors.inverseSurface,
                        getTooltipItems: (spots) => [
                          for (final spot in spots)
                            if (spot.barIndex == 0)
                              LineTooltipItem(
                                '${DateFormat('d MMM yyyy').format(Dates.parse(points[spot.spotIndex].date))}\n${valueLabel(points[spot.spotIndex].value)}',
                                TextStyle(color: colors.onInverseSurface, fontSize: 12, fontWeight: FontWeight.w600),
                              )
                            else
                              null,
                        ],
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: left,
                          interval: interval,
                          getTitlesWidget: (value, meta) => SideTitleWidget(
                            meta: meta,
                            space: 6,
                            fitInside: SideTitleFitInsideData.fromTitleMeta(meta, distanceFromEdge: 0),
                            child: Text(_axisValue(value), style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(left: left, right: 0, bottom: 0, height: bottom, child: _dateLabels(context, x, minX, maxX, plotWidth)),
            ],
          );
        },
      ),
    );
  }

  Widget _dateLabels(BuildContext context, List<double> x, double minX, double maxX, double width) {
    final style = TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant);
    final format = DateFormat(x.last > 365 ? 'MMM yy' : 'd MMM');
    final labels = <({String text, double left, double width})>[];
    for (final i in {0, points.length - 1, points.length ~/ 2}) {
      final text = format.format(Dates.parse(points[i].date));
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final textWidth = painter.width;
      final position = ((x[i] - minX) / (maxX - minX) * width - textWidth / 2)
          .clamp(0.0, math.max(0.0, width - textWidth))
          .toDouble();
      painter.dispose();
      if (labels.any((l) => position < l.left + l.width + 8 && position + textWidth + 8 > l.left)) continue;
      labels.add((text: text, left: position, width: textWidth));
    }
    return Stack(
      children: [
        for (final label in labels)
          Positioned(
            left: label.left,
            top: 6,
            child: Text(label.text, style: style),
          ),
      ],
    );
  }

  String _axisValue(double n) => n >= 1000000
      ? '${Fmt.number(n / 1000000, precision: 1)}M'
      : n >= 1000
      ? '${Fmt.number(n / 1000, precision: 1)}k'
      : Fmt.number(n);
}

class _WorkoutBars extends CustomPainter {
  _WorkoutBars(this.points, this.x, this.minX, this.maxX, this.maxY, this.width, this.color);
  final List<MetricPoint> points;
  final List<double> x;
  final double minX, maxX, maxY, width;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()..color = color;
    for (var i = 0; i < points.length; i++) {
      final center = (x[i] - minX) / (maxX - minX) * size.width;
      final height = points[i].value / maxY * size.height;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(center - width / 2, size.height - height, width, height),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WorkoutBars oldDelegate) =>
      points != oldDelegate.points ||
      minX != oldDelegate.minX ||
      maxX != oldDelegate.maxX ||
      maxY != oldDelegate.maxY ||
      width != oldDelegate.width ||
      color != oldDelegate.color;
}
