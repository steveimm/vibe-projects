import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/repositories/stats_repository.dart';
import '../core/util/dates.dart';
import '../core/util/format.dart';

class ProgressChart extends StatelessWidget {
  const ProgressChart({super.key, required this.points, required this.label, this.height = 250, this.zeroBased = true});
  final List<MetricPoint> points;
  final double height;
  final bool zeroBased;
  final String Function(double) label;
  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final first = points.first.date;
    final span = Dates.daysBetween(first, points.last.date);
    final color = Theme.of(context).colorScheme.primary;
    final maxValue = points.map((p) => p.value).reduce(math.max);
    final minValue = points.map((p) => p.value).reduce(math.min);
    final padding = math.max((maxValue - minValue) * 0.15, math.max(maxValue.abs() * 0.01, 0.1));
    final lower = zeroBased ? 0.0 : math.max(0.0, minValue - padding);
    final upper = zeroBased ? (maxValue <= 0 ? 1.0 : maxValue * 1.15) : maxValue + padding;
    final roughStep = (upper - lower) / 3;
    final magnitude = math.pow(10, (math.log(roughStep) / math.ln10).floor()).toDouble();
    final interval = [1.0, 2.0, 5.0, 10.0].firstWhere((n) => n * magnitude >= roughStep) * magnitude;
    final minY = (lower / interval).floor() * interval;
    final maxY = (upper / interval).ceil() * interval;
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 12, 0),
        child: LineChart(
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 220),
          LineChartData(
            minX: span == 0 ? -1 : 0,
            maxX: span == 0 ? 1 : span.toDouble(),
            minY: minY,
            maxY: maxY,
            lineBarsData: [
              LineChartBarData(
                spots: [for (final p in points) FlSpot(Dates.daysBetween(first, p.date).toDouble(), p.value)],
                isCurved: false,
                color: color,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(show: points.length < 15),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0.01)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: interval,
              getDrawingHorizontalLine: (_) => FlLine(
                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7),
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
            ),
            borderData: FlBorderData(show: false),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItems: (spots) => [
                  for (final spot in spots)
                    LineTooltipItem(
                      '${DateFormat('d MMM yyyy').format(Dates.parse(points[spot.spotIndex.clamp(0, points.length - 1)].date))}\n${label(spot.y)}',
                      const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 42,
                  interval: interval,
                  getTitlesWidget: (value, meta) => Text(
                    value >= 1000 ? '${Fmt.number(value / 1000)}k' : Fmt.number(value),
                    style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  interval: math.max(1, (span / 3).ceil()).toDouble(),
                  getTitlesWidget: (value, meta) => value < 0 || value > span || (span == 0 && value != 0)
                      ? const SizedBox.shrink()
                      : SideTitleWidget(
                          meta: meta,
                          space: 8,
                          fitInside: SideTitleFitInsideData.fromTitleMeta(meta, distanceFromEdge: 0),
                          child: Text(
                            DateFormat(span > 365 ? 'MMM yy' : 'M/d').format(Dates.parse(Dates.shift(first, value.round()))),
                            style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double metricDisplayValue(GraphMetric metric, double value, Units units) {
  if (metric.isWeight) return units.weightFromKg(value);
  if (metric.isDistance) return units.distanceFromMeters(value);
  if (metric == GraphMetric.maxSpeed) return value * (units.imperial ? 2.2369362921 : 3.6);
  if (metric == GraphMetric.bestPace) return value * (units.imperial ? 1.609344 : 1);
  return value;
}

double metricCanonicalValue(GraphMetric metric, double value, Units units) {
  if (metric.isWeight) return units.weightToKg(value);
  if (metric.isDistance) return units.distanceToMeters(value);
  if (metric == GraphMetric.maxSpeed) return value / (units.imperial ? 2.2369362921 : 3.6);
  if (metric == GraphMetric.bestPace) return value / (units.imperial ? 1.609344 : 1);
  return value;
}

String metricUnit(GraphMetric metric, Units units) {
  if (metric == GraphMetric.workoutVolume) return '${units.weightLabel}·reps';
  if (metric.isWeight) return units.weightLabel;
  if (metric.isDistance) return units.distanceLabel;
  if (metric == GraphMetric.maxSpeed) return '${units.distanceLabel}/h';
  if (metric == GraphMetric.bestPace) return '/${units.distanceLabel}';
  if (metric.isTime) return '';
  return 'reps';
}

String metricLabel(GraphMetric metric, double displayValue, Units units) =>
    '${metric.isTime || metric == GraphMetric.bestPace ? Fmt.duration(displayValue.round()) : Fmt.number(displayValue)} ${metricUnit(metric, units)}'
        .trim();
