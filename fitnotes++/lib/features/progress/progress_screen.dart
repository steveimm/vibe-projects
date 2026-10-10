import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/database/database.dart';
import '../../core/database/tables.dart';
import '../../core/providers.dart';
import '../../core/repositories/stats_repository.dart';
import '../../core/repositories/workout_repository.dart';
import '../../core/util/dates.dart';
import '../../core/util/format.dart';
import '../../shared/widgets.dart';
import 'body_tab.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        actions: [
          IconButton(
            tooltip: 'Workout calculators',
            icon: const Icon(Icons.calculate_outlined),
            onPressed: () => context.push('/tools'),
          ),
        ],
        bottom: TabBar(
          isScrollable: MediaQuery.textScalerOf(context).scale(1) > 1.4,
          tabAlignment: MediaQuery.textScalerOf(context).scale(1) > 1.4 ? TabAlignment.start : TabAlignment.fill,
          tabs: const [
            Tab(text: 'Training'),
            Tab(text: 'Measurements'),
          ],
        ),
      ),
      body: const ContentWidth(child: TabBarView(children: [_TrainingOverview(), BodyTab()])),
    ),
  );
}

class _TrainingOverview extends ConsumerStatefulWidget {
  const _TrainingOverview();
  @override
  ConsumerState<_TrainingOverview> createState() => _TrainingOverviewState();
}

class _TrainingOverviewState extends ConsumerState<_TrainingOverview> with AutomaticKeepAliveClientMixin {
  int _days = 30;
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final log = ref.watch(allLogProvider);
    final units = ref.watch(unitsProvider);
    final exercises = {for (final e in ref.watch(allExercisesProvider).asData?.value ?? <Exercise>[]) e.id: e};
    final categories = {for (final c in ref.watch(categoriesProvider).asData?.value ?? <Category>[]) c.id: c};
    final season = ref.watch(seasonsProvider).asData?.value.firstOrNull;
    return log.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => ErrorState(onRetry: () => ref.invalidate(allLogProvider)),
      data: (all) {
        final logged = all.where((s) => !s.set.isPlanned).toList();
        final since = _days == 0 ? Stats.allTime : Dates.shift(Dates.today(), -_days + 1);
        final selected = logged
            .where((s) => s.set.date.compareTo(since) >= 0 && s.set.date.compareTo(Dates.today()) <= 0)
            .toList();
        final dates = selected.map((s) => s.set.date).toSet();
        final volume = selected.fold<double>(0, (v, s) => v + s.effectiveWeight * s.set.reps);
        final counts = <int, int>{};
        for (final s in selected) {
          final c = exercises[s.set.exerciseId]?.categoryId;
          if (c != null) counts.update(c, (n) => n + 1, ifAbsent: () => 1);
        }
        final groups = <int, List<WorkoutSet>>{};
        for (final s in logged) {
          (groups[s.set.exerciseId] ??= []).add(s.set);
        }
        final prIds = <int>{};
        for (final entry in groups.entries) {
          prIds.addAll(
            Stats.personalRecordSetIds(
              entry.value,
              type: exercises[entry.key]?.type ?? ExerciseType.weightAndReps,
              sinceDate: season?.date ?? Stats.allTime,
            ),
          );
        }
        final records = selected.where((s) => prIds.contains(s.set.id)).take(5).toList();
        final activityStart = _days == 0 ? (dates.toList()..sort()).firstOrNull ?? Dates.shift(Dates.today(), -6) : since;
        final activity = Stats.activity(selected.map((s) => s.set).toList(), from: activityStart, to: Dates.today());
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 320 || MediaQuery.textScalerOf(context).scale(1) > 1.2;
                return Row(
                  children: [
                    for (final entry in const {7: '7 days', 30: '30 days', 90: '90 days', 0: 'All time'}.entries)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Tooltip(
                            message: entry.value,
                            excludeFromSemantics: true,
                            child: ChoiceChip(
                              padding: EdgeInsets.zero,
                              labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                              showCheckmark: false,
                              label: Text(compact ? (entry.key == 0 ? 'All' : '${entry.key}d') : entry.value, maxLines: 1),
                              selected: _days == entry.key,
                              onSelected: (_) => setState(() => _days = entry.key),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(child: StatValue('Workouts', '${dates.length}')),
                    Expanded(child: StatValue('Sets', '${selected.length}')),
                    Expanded(child: StatValue('Volume · ${units.weightLabel}', Fmt.number(units.weightFromKg(volume)))),
                  ],
                ),
              ),
            ),
            const SectionTitle('Sets'),
            _ActivityChart(buckets: activity),
            if (selected.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No completed sets in this period')),
            if (counts.isNotEmpty) ...[
              const SectionTitle('Training balance'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      for (final entry in (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(categories[entry.key]?.name ?? 'Category')),
                                  Text('${entry.value} sets', style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: entry.value / selected.length,
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(8),
                                color: Color(categories[entry.key]?.colorArgb ?? 0xFF326A59),
                                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            if (records.isNotEmpty && (ref.watch(settingsProvider).asData?.value.trackPersonalRecords ?? true)) ...[
              SectionTitle(
                'Personal records',
                trailing: season == null
                    ? null
                    : Text('This season', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
              ),
              for (final record in records) _RecordTile(record: record),
            ],
          ],
        );
      },
    );
  }
}

class _RecordTile extends ConsumerWidget {
  const _RecordTile({required this.record});
  final LoggedSet record;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Card(
      child: ListTile(
        title: Text(record.exerciseName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${describeSet(type: ExerciseType.values[record.exerciseType], effectiveWeight: record.effectiveWeight, reps: record.set.reps, distance: record.set.distance, durationSeconds: record.set.durationSeconds, units: ref.watch(unitsProvider))} · ${DateFormat('d MMM yyyy').format(Dates.parse(record.set.date))}',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push('/log/${record.set.exerciseId}?date=${record.set.date}&tab=2'),
      ),
    ),
  );
}

class _ActivityChart extends StatelessWidget {
  const _ActivityChart({required this.buckets});
  final List<ActivityBucket> buckets;

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final maxCount = buckets.fold<int>(1, (n, b) => math.max(n, b.sets));
    String dateLabel(String date) => DateFormat('d MMM yy').format(Dates.parse(date));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SizedBox(
              height: 70,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final bucket in buckets)
                    Expanded(
                      child: Tooltip(
                        triggerMode: TooltipTriggerMode.tap,
                        message:
                            '${dateLabel(bucket.start)}${bucket.start == bucket.end ? '' : ' – ${dateLabel(bucket.end)}'} · ${bucket.sets} sets',
                        child: Semantics(
                          label: '${bucket.start} to ${bucket.end}: ${bucket.sets} sets',
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            height: math.max(3, 70 * bucket.sets / maxCount),
                            decoration: BoxDecoration(
                              color: bucket.sets == 0 ? colors.surfaceContainerHighest : colors.primary,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    DateFormat('d MMM yy').format(Dates.parse(buckets.first.start)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    DateFormat('d MMM yy').format(Dates.parse(buckets.last.end)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
