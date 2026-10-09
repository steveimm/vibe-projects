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
        bottom: const TabBar(
          tabs: [
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
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final entry in const {7: '7 days', 30: '30 days', 90: '90 days', 0: 'All time'}.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _days == entry.key,
                    onSelected: (_) => setState(() => _days = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Row(
                  children: [
                    Expanded(child: StatValue('Workouts', '${dates.length}')),
                    Expanded(child: StatValue('Logged sets', '${selected.length}')),
                    Expanded(child: StatValue('Volume · ${units.weightLabel}', Fmt.number(units.weightFromKg(volume)))),
                  ],
                ),
              ),
            ),
            const SectionTitle('The last two weeks'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    for (var i = 13; i >= 0; i--)
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final date = Dates.shift(Dates.today(), -i);
                            final count = logged.where((s) => s.set.date == date).length;
                            return Tooltip(
                              message: '${Dates.longDate(date)} · $count sets',
                              child: Column(
                                children: [
                                  Container(
                                    height: 40,
                                    margin: const EdgeInsets.symmetric(horizontal: 2),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(5),
                                      color: count == 0
                                          ? Theme.of(context).colorScheme.surfaceContainerHighest
                                          : Theme.of(context).colorScheme.primary.withValues(
                                              alpha: count < 5
                                                  ? 0.45
                                                  : count < 15
                                                  ? 0.7
                                                  : 1,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${Dates.parse(date).day}',
                                    style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (selected.isEmpty)
              EmptyState(
                icon: Icons.insights_outlined,
                title: 'No completed sets',
                action: FilledButton(onPressed: () => context.go('/'), child: const Text('Go to workout')),
              ),
            if (counts.isNotEmpty) ...[
              const SectionTitle('Training balance'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      for (final entry in (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(categories[entry.key]?.name ?? 'Category')),
                                  Text('${entry.value} sets', style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 8),
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
            if (ref.watch(settingsProvider).asData?.value.trackPersonalRecords ?? true) ...[
              SectionTitle(
                'Recent records',
                trailing: season == null
                    ? null
                    : Text('This season', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
              ),
              if (records.isEmpty)
                const Card(
                  child: Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20), child: Text('No personal records')),
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
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFFFEAC4).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.emoji_events_outlined, color: Color(0xFF966715)),
        ),
        title: Text(record.exerciseName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${describeSet(type: ExerciseType.values[record.exerciseType], effectiveWeight: record.effectiveWeight, reps: record.set.reps, distance: record.set.distance, durationSeconds: record.set.durationSeconds, units: ref.watch(unitsProvider))}\n${DateFormat('d MMM yyyy').format(Dates.parse(record.set.date))}',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push('/log/${record.set.exerciseId}?date=${record.set.date}&tab=2'),
      ),
    ),
  );
}
