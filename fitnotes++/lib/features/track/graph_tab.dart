import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/database/tables.dart';
import '../../core/providers.dart';
import '../../core/repositories/stats_repository.dart';
import '../../core/util/dates.dart';
import '../../core/util/format.dart';
import '../../core/util/onerm.dart';
import '../../core/util/workout_analysis.dart';
import '../../shared/date_range_chips.dart';
import '../../shared/progress_chart.dart';
import '../../shared/widgets.dart';
import '../../shared/record_badge.dart';

class GraphTab extends ConsumerStatefulWidget {
  const GraphTab({super.key, required this.exercise});
  final Exercise exercise;
  @override
  ConsumerState<GraphTab> createState() => _GraphTabState();
}

class _GraphTabState extends ConsumerState<GraphTab> with AutomaticKeepAliveClientMixin {
  GraphMetric? _metric;
  int _months = 0, _atReps = 5;
  bool _currentSeason = true, _estimated = false;
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final metrics = GraphMetric.forType(widget.exercise.type);
    if (!metrics.contains(_metric)) _metric = metrics.first;
    final units = ref.watch(unitsProvider);
    final history = ref.watch(exerciseHistoryProvider(widget.exercise.id));
    final season = ref.watch(seasonsProvider).asData?.value.firstOrNull;
    final since = _months == 0 ? Stats.allTime : WorkoutAnalysis.monthsBefore(Dates.today(), _months);
    final cap = ref.watch(settingsProvider).asData?.value.estimated1rmMaxReps ?? 0;
    return history.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => ErrorState(onRetry: () => ref.invalidate(exerciseHistoryProvider(widget.exercise.id))),
      data: (sets) {
        final points = Stats.graph(
          sets.where((s) => s.date.compareTo(Dates.today()) <= 0).toList(),
          _metric!,
          sinceDate: since,
          max1rmReps: cap,
          atReps: _atReps,
        ).map((p) => (date: p.date, value: metricDisplayValue(_metric!, p.value, units))).toList();
        final logged = sets.where((s) => !s.isPlanned).toList();
        return Scaffold(
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          floatingActionButton: AppFloatingActionButton(
            tooltip: 'Add goal',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => _GoalDialog(exercise: widget.exercise),
            ),
          ),
          body: ContentWidth(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
              children: [
                DropdownButtonFormField<GraphMetric>(
                  initialValue: _metric,
                  key: ValueKey(_metric),
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Progress metric'),
                  items: [for (final m in metrics) DropdownMenuItem(value: m, child: Text(m.label))],
                  onChanged: (m) => setState(() => _metric = m),
                ),
                if (_metric == GraphMetric.weightAtReps)
                  Row(
                    children: [
                      const Expanded(child: Text('Rep count')),
                      IconButton(
                        tooltip: 'Fewer reps',
                        onPressed: _atReps <= 1 ? null : () => setState(() => _atReps--),
                        icon: const Icon(Icons.remove_rounded),
                      ),
                      Text('$_atReps'),
                      IconButton(
                        tooltip: 'More reps',
                        onPressed: _atReps >= 100 ? null : () => setState(() => _atReps++),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                DateRangeChips(months: _months, includeYear: true, onChanged: (value) => setState(() => _months = value)),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: points.isEmpty
                        ? EmptyState(
                            icon: Icons.show_chart_rounded,
                            title: logged.isEmpty ? 'No logged sets yet' : 'No matching data',
                            message: _metric == GraphMetric.maxSpeed || _metric == GraphMetric.bestPace
                                ? 'Speed and pace need both distance and time in the same set.'
                                : _metric == GraphMetric.estimated1rm
                                ? 'Estimates need a positive weight and reps within your configured limit.'
                                : _metric == GraphMetric.weightAtReps
                                ? 'No logged sets with $_atReps reps in this range.'
                                : null,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                metricLabel(_metric!, points.last.value, units),
                                style: Theme.of(context).textTheme.headlineMedium,
                              ),
                              Text(
                                points.last.date,
                                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                              ProgressChart(height: 200, points: points, label: (v) => metricLabel(_metric!, v, units)),
                            ],
                          ),
                  ),
                ),
                if (_metric == GraphMetric.estimated1rm)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Estimated weight for one rep. Uses sets of up to ${cap == 0 ? 36 : cap} reps.',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                if (widget.exercise.type.hasWeight && widget.exercise.type.hasReps) ...[
                  const SectionTitle('Rep records'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Actual'),
                        selected: !_estimated,
                        onSelected: (_) => setState(() => _estimated = false),
                      ),
                      ChoiceChip(
                        label: const Text('Estimated'),
                        selected: _estimated,
                        onSelected: (_) => setState(() => _estimated = true),
                      ),
                      ChoiceChip(
                        label: const Text('All time'),
                        avatar: const RecordBadge(scope: RecordScope.allTime),
                        selected: !_currentSeason || season == null,
                        onSelected: (_) => setState(() => _currentSeason = false),
                      ),
                      if (season != null)
                        ChoiceChip(
                          label: const Text('Current season'),
                          avatar: const RecordBadge(scope: RecordScope.currentSeason),
                          selected: _currentSeason,
                          onSelected: (_) => setState(() => _currentSeason = true),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _records(logged, units, _currentSeason ? season?.date ?? Stats.allTime : Stats.allTime, cap),
                ],
                const SectionTitle('Goals'),
                _goals(logged, units, cap),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _records(List<WorkoutSet> sets, Units units, String since, int cap) {
    final actual = Stats.repMaxes(sets, sinceDate: since);
    final estimates = Stats.graph(sets, GraphMetric.estimated1rm, sinceDate: since, max1rmReps: cap);
    final best = estimates.fold<double>(0, (v, p) => math.max(v, p.value));
    if (actual.isEmpty) {
      return const Card(
        child: Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20), child: Text('No personal records')),
      );
    }
    final reps = _estimated ? List.generate(15, (i) => i + 1) : (actual.keys.toList()..sort());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 16,
          children: [
            for (final rep in reps)
              SizedBox(
                width: 90,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$rep ${rep == 1 ? 'rep' : 'reps'}',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _estimated && best == 0 ? '—' : units.weight(_estimated ? OneRm.weightForReps(best, rep) : actual[rep]!),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _goals(List<WorkoutSet> sets, Units units, int cap) {
    final goals = ref.watch(goalsProvider(widget.exercise.id));
    return goals.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => ErrorState(onRetry: () => ref.invalidate(goalsProvider(widget.exercise.id))),
      data: (goals) => goals.isEmpty
          ? const Card(
              child: Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20), child: Text('No goals')),
            )
          : Column(
              children: [
                for (final goal in goals)
                  Builder(
                    builder: (context) {
                      final metric = GraphMetric.values.where((m) => m.name == goal.metric).firstOrNull;
                      if (metric == null) return const SizedBox.shrink();
                      final values = Stats.graph(sets, metric, max1rmReps: cap).map((p) => p.value).toList();
                      final best = values.isEmpty ? 0.0 : values.reduce(metric == GraphMetric.bestPace ? math.min : math.max);
                      final progress = best == 0
                          ? 0.0
                          : (metric == GraphMetric.bestPace ? goal.target / best : best / goal.target).clamp(0.0, 1.0);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 6, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${metric.label} · ${metricLabel(metric, metricDisplayValue(metric, goal.target, units), units)}',
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Edit goal',
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      onPressed: () => showDialog(
                                        context: context,
                                        builder: (_) => _GoalDialog(exercise: widget.exercise, goal: goal),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete goal',
                                      icon: const Icon(Icons.close_rounded, size: 18),
                                      onPressed: () async {
                                        if (await confirm(
                                              context,
                                              title: 'Delete goal?',
                                              message: 'Your workout history will be kept.',
                                            ) &&
                                            context.mounted) {
                                          await attempt(context, () => ref.read(progressRepositoryProvider).deleteGoal(goal.id));
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                LinearProgressIndicator(value: progress, minHeight: 6, borderRadius: BorderRadius.circular(8)),
                                const SizedBox(height: 8),
                                Text(
                                  progress >= 1
                                      ? 'Target reached'
                                      : '${metricLabel(metric, metricDisplayValue(metric, best, units), units)} so far${goal.targetDate == null ? '' : ' · by ${goal.targetDate}'}',
                                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
    );
  }
}

class _GoalDialog extends ConsumerStatefulWidget {
  const _GoalDialog({required this.exercise, this.goal});
  final Exercise exercise;
  final ExerciseGoal? goal;
  @override
  ConsumerState<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends ConsumerState<_GoalDialog> {
  late GraphMetric _metric =
      GraphMetric.values.where((m) => m.name == widget.goal?.metric).firstOrNull ??
      GraphMetric.forType(widget.exercise.type).first;
  late final _target = TextEditingController(text: _initialTarget());
  String _initialTarget() {
    if (widget.goal == null) return '';
    final value = metricDisplayValue(_metric, widget.goal!.target, ref.read(unitsProvider));
    return _metric.isTime || _metric == GraphMetric.bestPace ? Fmt.duration(value.round()) : Fmt.number(value);
  }

  final _form = GlobalKey<FormState>();
  late String? _date = widget.goal?.targetDate;
  bool _busy = false;
  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(unitsProvider);
    final time = _metric.isTime || _metric == GraphMetric.bestPace;
    return AppDialog(
      title: Text(widget.goal == null ? 'Set a goal' : 'Edit goal'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<GraphMetric>(
              initialValue: _metric,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Metric'),
              items: [
                for (final m in GraphMetric.forType(widget.exercise.type).where((m) => m != GraphMetric.weightAtReps))
                  DropdownMenuItem(value: m, child: Text(m.label)),
              ],
              onChanged: (v) => setState(() {
                _metric = v!;
                _target.clear();
              }),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _target,
              keyboardType: time ? TextInputType.datetime : const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: time ? 'Target (m:ss)' : 'Target', suffixText: metricUnit(_metric, units)),
              validator: (v) {
                final value = time ? Fmt.parseDuration(v!)?.toDouble() : double.tryParse(v!);
                return value != null && value.isFinite && value > 0 ? null : 'Enter a valid target greater than zero.';
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_date ?? 'Target date (optional)'),
              trailing: _date == null
                  ? const Icon(Icons.event_outlined)
                  : IconButton(
                      tooltip: 'Clear target date',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => _date = null),
                    ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _date == null ? DateTime.now().add(const Duration(days: 90)) : Dates.parse(_date!),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (date != null && mounted) setState(() => _date = Dates.iso(date));
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  if (!_form.currentState!.validate()) return;
                  setState(() => _busy = true);
                  final value = time ? Fmt.parseDuration(_target.text)!.toDouble() : double.parse(_target.text);
                  final ok = await attempt(
                    context,
                    () => ref
                        .read(progressRepositoryProvider)
                        .saveGoal(
                          widget.exercise.id,
                          _metric.name,
                          widget.goal != null && widget.goal!.metric == _metric.name && _target.text == _initialTarget()
                              ? widget.goal!.target
                              : metricCanonicalValue(_metric, value, units),
                          _date,
                          id: widget.goal?.id,
                        ),
                  );
                  if (!context.mounted) return;
                  if (ok) {
                    Navigator.pop(context);
                  } else {
                    setState(() => _busy = false);
                  }
                },
          child: const Text('Save goal'),
        ),
      ],
    );
  }
}
