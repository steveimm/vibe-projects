import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/repositories/stats_repository.dart';
import '../core/util/dates.dart';
import '../core/util/format.dart';

class ProgressChart extends StatelessWidget {
  const ProgressChart({super.key, required this.points, required this.label});
  final List<MetricPoint> points;
  final String Function(double) label;
  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final first = points.first.date;
    final span = Dates.daysBetween(first, points.last.date);
    final color = Theme.of(context).colorScheme.primary;
    final maxValue = points.map((p) => p.value).reduce(math.max);
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.15;
    return SizedBox(
      height: 250,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 12, 0),
        child: LineChart(
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 220),
          LineChartData(
            minX: span == 0 ? -1 : 0,
            maxX: span == 0 ? 1 : span.toDouble(),
            minY: 0,
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
              horizontalInterval: maxY / 4,
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
                  interval: maxY / 4,
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
                      : Padding(
                          padding: const EdgeInsets.only(top: 10),
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
