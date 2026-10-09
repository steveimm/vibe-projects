import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/database/tables.dart';
import '../../core/providers.dart';
import '../../core/repositories/workout_repository.dart';
import '../../core/util/dates.dart';
import 'workout_session_card.dart';
import '../../core/util/format.dart';
import '../../shared/widgets.dart';
import 'workout_calendar.dart';
import 'workout_week_strip.dart';

Future<void> startCopyWorkout(BuildContext context, WidgetRef ref, String date) async {
  final priors = await ref.read(workoutRepositoryProvider).workoutDatesBefore(date);
  if (!context.mounted) return;
  if (priors.isEmpty) {
    notice(context, 'No previous workouts to copy.');
    return;
  }
  final picked = await pickCopyDay(context, ref, initialDate: priors.first, selectableDays: priors.toSet());
  if (picked != null && context.mounted) context.push('/copy?date=$date&source=$picked');
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(selectedDateProvider);
    final log = ref.watch(dayLogProvider(date));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          date == Dates.today()
              ? 'Today'
              : DateFormat(Dates.parse(date).year == DateTime.now().year ? 'EEE, d MMM' : 'EEE, d MMM yyyy')
                    .format(Dates.parse(date)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          if (date != Dates.today())
            IconButton(
              tooltip: 'Go to today',
              icon: const Icon(Icons.today_outlined),
              onPressed: () => ref.read(selectedDateProvider.notifier).goToday(),
            ),
          IconButton(
            tooltip: 'Calendar',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () async {
              final picked = await openWorkoutCalendar(context, ref, initialDate: date);
              if (picked != null) ref.read(selectedDateProvider.notifier).set(picked);
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Workout actions',
            onSelected: (value) => _action(context, ref, date, value),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'copy', child: Text('Copy a workout')),
              const PopupMenuItem(value: 'note', child: Text('Workout note')),
              if (log.asData?.value.isNotEmpty ?? false) ...[
                const PopupMenuItem(value: 'routine', child: Text('Save as routine')),
                const PopupMenuItem(value: 'delete', child: Text('Delete this workout')),
              ],
              const PopupMenuItem(value: 'tools', child: Text('Workout calculators')),
            ],
          ),
        ],
      ),
      body: ContentWidth(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: WorkoutWeekStrip(
                date: date,
                firstDayOfWeek: ref.watch(settingsProvider).asData?.value.firstDayOfWeek ?? 1,
                dayColors: workoutDayColors(ref.watch(allLogProvider).asData?.value ?? []),
                onSelectDay: ref.read(selectedDateProvider.notifier).set,
              ),
            ),
            Expanded(
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity < -100) ref.read(selectedDateProvider.notifier).next();
                  if (velocity > 100) ref.read(selectedDateProvider.notifier).previous();
                },
                child: AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 160),
                  child: _DayView(key: ValueKey(date), date: date),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _action(BuildContext context, WidgetRef ref, String date, String action) async {
    final repo = ref.read(workoutRepositoryProvider);
    switch (action) {
      case 'copy':
        await startCopyWorkout(context, ref, date);
      case 'note':
        await _editDayNote(context, ref, date);
      case 'tools':
        context.push('/tools');
      case 'routine':
        final name = await prompt(
          context,
          title: 'Save as routine',
          label: 'Routine name',
          value: DateFormat('EEEE').format(Dates.parse(date)),
        );
        if (name != null && context.mounted) {
          await attempt(context, () async {
            await ref.read(routineRepositoryProvider).fromWorkout(date, name);
          }, success: 'Routine saved. Find it in Routines.');
        }
      case 'delete':
        if (!await confirm(
              context,
              title: 'Delete this workout?',
              message: 'Remove all sets and the workout note for ${Dates.longDate(date)}?',
            ) ||
            !context.mounted) {
          return;
        }
        await attempt(context, () async {
          final snapshot = await repo.deleteDay(date);
          if (context.mounted) {
            notice(
              context,
              'Workout deleted',
              action: SnackBarAction(label: 'Undo', onPressed: () => attempt(context, () => repo.restoreDay(snapshot))),
            );
          }
        });
    }
  }
}

Future<void> _editDayNote(BuildContext context, WidgetRef ref, String date) async {
  final current = (await ref.read(workoutRepositoryProvider).watchDayNote(date).first)?.comment ?? '';
  if (!context.mounted) return;
  final result = await prompt(
    context,
    title: 'Workout note',
    label: 'Note',
    value: current,
    optional: true,
    lines: 4,
    maxLength: 2000,
  );
  if (result != null && context.mounted) {
    await attempt(context, () => ref.read(workoutRepositoryProvider).saveDayNote(date, result));
  }
}

class _DayView extends ConsumerStatefulWidget {
  const _DayView({super.key, required this.date});
  final String date;
  @override
  ConsumerState<_DayView> createState() => _DayViewState();
}

class _DayViewState extends ConsumerState<_DayView> {
  bool _editing = false, _savingOrder = false;
  List<int>? _order;

  @override
  Widget build(BuildContext context) {
    final date = widget.date;
    final log = ref.watch(dayLogProvider(date));
    final note = ref.watch(dayNoteProvider(date)).asData?.value;
    return log.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => ErrorState(onRetry: () => ref.invalidate(dayLogProvider(date))),
      data: (sets) {
        final groups = <int, List<LoggedSet>>{};
        for (final s in sets) {
          (groups[s.set.exerciseId] ??= []).add(s);
        }
        if (listEquals(_order, groups.keys.toList())) _order = null;
        final ids = {...?_order, ...groups.keys}.where(groups.containsKey).toList();
        return ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          buildDefaultDragHandles: false,
          itemCount: ids.length,
          onReorderStart: (_) {
            HapticFeedback.selectionClick();
            setState(() => _editing = true);
          },
          onReorderItem: (oldIndex, newIndex) => _reorder(ids, oldIndex, newIndex),
          header: Column(
            children: [
              WorkoutSessionCard(date: date, sets: sets),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.push('/pick-exercise?date=$date'),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add exercise'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(onPressed: () => context.go('/routines?date=$date'), child: const Text('Routine')),
                ],
              ),
              if (sets.isEmpty)
                EmptyState(
                  icon: Icons.fitness_center_rounded,
                  title: 'No sets',
                  action: TextButton.icon(
                    onPressed: () => startCopyWorkout(context, ref, date),
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Copy a previous workout'),
                  ),
                ),
              if (groups.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Row(
                    children: [
                      Expanded(child: Text(Fmt.count(groups.length, 'exercise'), style: Theme.of(context).textTheme.titleMedium)),
                      SizedBox(
                        height: 48,
                        child: _editing
                            ? TextButton(onPressed: () => setState(() => _editing = false), child: const Text('Done'))
                            : Center(
                                child: Text(
                                  Fmt.count(sets.length, 'set'),
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          itemBuilder: (context, index) {
            final id = ids[index];
            return Padding(
              key: ValueKey(id),
              padding: const EdgeInsets.only(bottom: 12),
              child: ReorderableDelayedDragStartListener(
                index: index,
                enabled: !_savingOrder,
                child: _ExerciseCard(
                  date: date,
                  exerciseId: id,
                  sets: groups[id]!,
                  trailing: _editing
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Remove ${groups[id]!.first.exerciseName} from workout',
                              onPressed: _savingOrder ? null : () => _remove(id, groups[id]!.first.exerciseName),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              enabled: !_savingOrder,
                              child: const SizedBox(width: 40, height: 48, child: Icon(Icons.drag_handle_rounded)),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
            );
          },
          footer: Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              titleTextStyle: Theme.of(context).textTheme.titleMedium,
              subtitleTextStyle: Theme.of(context).textTheme.bodyMedium,
              leading: const Icon(Icons.edit_note_rounded),
              title: Text(note == null ? 'Add a workout note' : 'Workout note'),
              subtitle: note == null ? null : Text(note.comment),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _editDayNote(context, ref, date),
            ),
          ),
        );
      },
    );
  }

  Future<void> _reorder(List<int> ids, int oldIndex, int newIndex) async {
    if (_savingOrder || oldIndex == newIndex) return;
    final order = [...ids];
    order.insert(newIndex, order.removeAt(oldIndex));
    setState(() {
      _order = order;
      _savingOrder = true;
    });
    final ok = await attempt(context, () => ref.read(workoutRepositoryProvider).reorderExercises(widget.date, order));
    if (mounted) {
      setState(() {
        _savingOrder = false;
        if (!ok) _order = null;
      });
    }
  }

  Future<void> _remove(int exerciseId, String name) async {
    final repo = ref.read(workoutRepositoryProvider);
    await attempt(context, () async {
      final snapshot = await repo.removeExerciseFromDay(widget.date, exerciseId);
      if (!mounted) return;
      notice(
        context,
        '$name removed from this workout',
        action: SnackBarAction(label: 'Undo', onPressed: () => attempt(context, () => repo.restoreDay(snapshot))),
      );
    });
  }
}

class _ExerciseCard extends ConsumerWidget {
  const _ExerciseCard({required this.date, required this.exerciseId, required this.sets, this.trailing});
  final String date;
  final int exerciseId;
  final List<LoggedSet> sets;
  final Widget? trailing;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = sets.first;
    final colors = Theme.of(context).colorScheme;
    final prs = ref.watch(prSetIdsProvider(exerciseId));
    final units = ref.watch(unitsProvider);
    final group = first.set.groupName;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/log/$exerciseId?date=$date'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 5,
                    height: 34,
                    decoration: BoxDecoration(color: Color(first.colorArgb), borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(first.exerciseName, style: Theme.of(context).textTheme.titleMedium)),
                  trailing ??
                      const SizedBox(
                        width: 88,
                        height: 48,
                        child: Align(alignment: Alignment.centerRight, child: Icon(Icons.chevron_right_rounded, size: 20)),
                      ),
                ],
              ),
              if (group != null && group.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Superset · $group', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.primary)),
                ),
              const SizedBox(height: 12),
              for (var i = 0; i < sets.length.clamp(0, 5); i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          '${i + 1}'.padLeft(2, '0'),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          describeSet(
                            type: ExerciseType.values[first.exerciseType],
                            effectiveWeight: sets[i].effectiveWeight,
                            reps: sets[i].set.reps,
                            distance: sets[i].set.distance,
                            durationSeconds: sets[i].set.durationSeconds,
                            units: units,
                          ),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: sets[i].set.isPlanned ? colors.onSurfaceVariant : colors.onSurface,
                          ),
                        ),
                      ),
                      if (sets[i].set.isPlanned)
                        Text(
                          'Not completed',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                        )
                      else if (prs.contains(sets[i].set.id))
                        const Tooltip(
                          message: 'Personal record',
                          child: Icon(Icons.emoji_events_outlined, size: 18, color: Color(0xFFAE7A25)),
                        )
                      else
                        Icon(Icons.check_rounded, size: 18, color: colors.primary),
                    ],
                  ),
                ),
              if (sets.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '+ ${sets.length - 5} more sets',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.primary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
