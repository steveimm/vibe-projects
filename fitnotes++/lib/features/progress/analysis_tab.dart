import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/providers.dart';
import '../../core/util/date_filter.dart';
import '../../core/util/dates.dart';
import '../../core/util/format.dart';
import '../../core/util/workout_analysis.dart';
import '../../shared/date_range_chips.dart';
import '../../shared/widgets.dart';
import '../../shared/workout_chart.dart';

class AnalysisTab extends ConsumerStatefulWidget {
  const AnalysisTab({super.key});
  @override
  ConsumerState<AnalysisTab> createState() => _AnalysisTabState();
}

class _AnalysisTabState extends ConsumerState<AnalysisTab> with AutomaticKeepAliveClientMixin {
  DateFilter _filter = const DateFilter();
  WorkoutMetric _metric = WorkoutMetric.volume;
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final all = ref.watch(allLogProvider);
    final units = ref.watch(unitsProvider);
    final sessions = ref.watch(workoutSessionsProvider).asData?.value ?? <WorkoutSession>[];
    final exercises = {for (final e in ref.watch(allExercisesProvider).asData?.value ?? <Exercise>[]) e.id: e};
    final categories = {for (final c in ref.watch(categoriesProvider).asData?.value ?? <Category>[]) c.id: c};
    return all.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => ErrorState(onRetry: () => ref.invalidate(allLogProvider)),
      data: (all) {
        final today = Dates.today();
        final (:from, :to) = _filter.range(today, all.where((s) => !s.set.isPlanned).map((s) => s.set.date));
        final selected = all
            .where((s) => !s.set.isPlanned && s.set.date.compareTo(from) >= 0 && s.set.date.compareTo(to) <= 0)
            .toList();
        final counts = <int, int>{};
        for (final entry in selected) {
          final id = exercises[entry.set.exerciseId]?.categoryId;
          if (id != null) counts.update(id, (v) => v + 1, ifAbsent: () => 1);
        }
        final timed =
            _metric == WorkoutMetric.duration &&
            sessions.any(
              (s) => s.runningSince != null && s.date == today && s.date.compareTo(from) >= 0 && s.date.compareTo(to) <= 0,
            );
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          children: [
            DateRangeChips(
              months: _filter.months,
              onChanged: (value) => setState(() => _filter = _filter.withMonths(value)),
              onCustom: () => _pickRange(from, to),
            ),
            DropdownButtonFormField<WorkoutMetric>(
              key: ValueKey(_metric),
              initialValue: _metric,
              isExpanded: true,
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              items: [
                for (final metric in WorkoutMetric.values)
                  DropdownMenuItem(
                    value: metric,
                    child: Text(metric.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _metric = value);
              },
            ),
            const SizedBox(height: 8),
            StreamBuilder<int>(
              stream: timed && TickerMode.valuesOf(context).enabled
                  ? Stream<int>.periodic(const Duration(seconds: 1), (i) => i)
                  : null,
              builder: (context, _) {
                final points =
                    WorkoutAnalysis.points(
                          selected.map((s) => s.set),
                          _metric,
                          from: from,
                          to: to,
                          sessions: sessions,
                          now: DateTime.now(),
                        )
                        .where((p) => p.value.isFinite)
                        .map(
                          (p) => (
                            date: p.date,
                            value: _metric == WorkoutMetric.volume
                                ? units.weightFromKg(p.value)
                                : _metric == WorkoutMetric.duration
                                ? p.value / 60
                                : p.value,
                          ),
                        )
                        .toList();
                final label = _metric == WorkoutMetric.volume
                    ? units.weightLabel
                    : _metric == WorkoutMetric.duration
                    ? 'Minutes'
                    : '';
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        SizedBox(
                          height: MediaQuery.textScalerOf(context).scale(12) * 1.5 < 24
                              ? 24
                              : MediaQuery.textScalerOf(context).scale(12) * 1.5,
                          child: Row(
                            children: [
                              Expanded(
                                child: Tooltip(
                                  message: '$from – $to',
                                  child: Text(
                                    Dates.rangeLabel(from, to),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              ),
                              if (label.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Text(label, style: Theme.of(context).textTheme.bodySmall),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (points.isEmpty)
                          SizedBox(
                            height: 180,
                            child: Center(
                              child: Text(
                                _metric == WorkoutMetric.duration
                                    ? 'No workout times recorded in this range'
                                    : 'No logged workouts in this range',
                              ),
                            ),
                          )
                        else
                          WorkoutChart(
                            key: ValueKey((_metric, from, to)),
                            points: points,
                            integerAxis: _metric == WorkoutMetric.sets || _metric == WorkoutMetric.reps,
                            valueLabel: (v) => _metric == WorkoutMetric.duration
                                ? Fmt.duration((v * 60).round())
                                : '${Fmt.number(v)} ${_metric == WorkoutMetric.volume ? units.weightLabel : _metric.name}',
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (counts.isNotEmpty) ...[
              const SectionTitle('Training balance'),
              _BalancePie(counts: counts, categories: categories),
            ],
          ],
        );
      },
    );
  }

  Future<void> _pickRange(String from, String to) async {
    final selected = await pickChartDateRange(context, _filter, from, to);
    if (selected != null && mounted) setState(() => _filter = selected);
  }
}

class _BalancePie extends StatelessWidget {
  const _BalancePie({required this.counts, required this.categories});
  final Map<int, int> counts;
  final Map<int, Category> categories;
  @override
  Widget build(BuildContext context) {
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);
    final pie = SizedBox.square(
      dimension: 160,
      child: PieChart(
        duration: Duration.zero,
        PieChartData(
          centerSpaceRadius: 0,
          sectionsSpace: entries.length == 1 ? 0 : 2,
          pieTouchData: PieTouchData(enabled: false),
          borderData: FlBorderData(show: false),
          sections: [
            for (final entry in entries)
              PieChartSectionData(
                value: entry.value.toDouble(),
                radius: 76,
                color: Color(categories[entry.key]?.colorArgb ?? 0xFF7F8C8D),
                showTitle: false,
              ),
          ],
        ),
      ),
    );
    final legend = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: Color(categories[entry.key]?.colorArgb ?? 0xFF7F8C8D), shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    categories[entry.key]?.name ?? 'Category',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${Fmt.count(entry.value, 'set')} · ${Fmt.number(entry.value / total * 100, precision: 1)}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: pie),
            const SizedBox(height: 8),
            legend,
          ],
        ),
      ),
    );
  }
}
