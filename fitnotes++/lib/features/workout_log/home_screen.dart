import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _editing = false;

  void _setEditing(bool value) => setState(() => _editing = value);

  @override
  Widget build(BuildContext context) {
    ref.listen(selectedDateProvider, (previous, next) {
      if (previous != next && _editing) _setEditing(false);
    });
    final date = ref.watch(selectedDateProvider);
    final log = ref.watch(dayLogProvider(date));
    return PopScope(
      canPop: !_editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _editing) _setEditing(false);
      },
      child: Scaffold(
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
                onPressed: _editing ? null : () => ref.read(selectedDateProvider.notifier).goToday(),
              ),
            IconButton(
              tooltip: 'Calendar',
              icon: const Icon(Icons.calendar_month_outlined),
              onPressed: _editing
                  ? null
                  : () async {
                      final picked = await openWorkoutCalendar(context, ref, initialDate: date);
                      if (picked != null) ref.read(selectedDateProvider.notifier).set(picked);
                    },
            ),
            AppMenuButton<String>(
              tooltip: 'Workout actions',
              enabled: !_editing,
              onSelected: (value) => _action(context, ref, date, value),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'use-routine', child: Text('Use routine')),
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
                child: IgnorePointer(
                  ignoring: _editing,
                  child: ExcludeSemantics(
                    excluding: _editing,
                    child: Opacity(
                      opacity: _editing ? 0.5 : 1,
                      child: WorkoutWeekStrip(
                        date: date,
                        firstDayOfWeek: ref.watch(settingsProvider).asData?.value.firstDayOfWeek ?? 1,
                        dayColors: workoutDayColors(ref.watch(allLogProvider).asData?.value ?? []),
                        onSelectDay: ref.read(selectedDateProvider.notifier).set,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onHorizontalDragEnd: _editing
                      ? null
                      : (details) {
                          final velocity = details.primaryVelocity ?? 0;
                          if (velocity < -100) ref.read(selectedDateProvider.notifier).next();
                          if (velocity > 100) ref.read(selectedDateProvider.notifier).previous();
                        },
                  child: AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 160),
                    child: _DayView(key: ValueKey(date), date: date, editing: _editing, onEditingChanged: _setEditing),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _action(BuildContext context, WidgetRef ref, String date, String action) async {
    final repo = ref.read(workoutRepositoryProvider);
    switch (action) {
      case 'use-routine':
        context.go('/routines?date=$date');
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
          }, success: 'Routine saved');
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
  const _DayView({super.key, required this.date, required this.editing, required this.onEditingChanged});
  final String date;
  final bool editing;
  final ValueChanged<bool> onEditingChanged;
  @override
  ConsumerState<_DayView> createState() => _DayViewState();
}

class _DayViewState extends ConsumerState<_DayView> {
  bool _savingOrder = false;
  List<int>? _order;
  final Set<int> _selected = {};

  @override
  void didUpdateWidget(covariant _DayView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editing && !widget.editing) _selected.clear();
  }

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
        _selected.removeWhere((id) => !groups.containsKey(id));
        if (listEquals(_order, groups.keys.toList())) _order = null;
        final ids = {...?_order, ...groups.keys}.where(groups.containsKey).toList();
        final scale = MediaQuery.textScalerOf(context);
        final toolbarHeight = (16 + (scale.scale(16) * 1.25 + scale.scale(12) * 1.25).clamp(48, double.infinity)).ceilToDouble();
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: WorkoutSessionCard(date: date, sets: sets, enabled: !widget.editing),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _WorkoutToolbar(
                height: toolbarHeight,
                exerciseCount: groups.length,
                setCount: sets.length,
                editing: widget.editing,
                selectedCount: _selected.length,
                onDelete: _savingOrder || _selected.isEmpty ? null : _removeSelected,
                onDone: () => widget.onEditingChanged(false),
                onAdd: () => context.push('/pick-exercise?date=$date'),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverReorderableList(
                itemCount: ids.length,
                onReorderStart: (index) {
                  HapticFeedback.selectionClick();
                  if (!widget.editing) setState(() => _selected.add(ids[index]));
                  widget.onEditingChanged(true);
                },
                onReorderItem: (oldIndex, newIndex) => _reorder(ids, oldIndex, newIndex),
                proxyDecorator: (child, index, animation) => AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) => Align(
                    key: const ValueKey('workout-drag-preview'),
                    alignment: Alignment.topCenter,
                    child: _exerciseCard(ids[index], index, groups[ids[index]]!, elevation: 6 * animation.value),
                  ),
                ),
                itemBuilder: (context, index) {
                  final id = ids[index];
                  return Padding(
                    key: ValueKey(id),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ReorderableDelayedDragStartListener(
                      index: index,
                      enabled: !_savingOrder,
                      child: _exerciseCard(id, index, groups[id]!),
                    ),
                  );
                },
              ),
            ),
            if (note != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Card(
                    child: ListTile(
                      enabled: !widget.editing,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      titleTextStyle: Theme.of(context).textTheme.titleMedium,
                      subtitleTextStyle: Theme.of(context).textTheme.bodyMedium,
                      leading: const Icon(Icons.edit_note_rounded),
                      title: const Text('Workout note'),
                      subtitle: Text(note.comment),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: widget.editing ? null : () => _editDayNote(context, ref, date),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _exerciseCard(int id, int index, List<LoggedSet> sets, {double elevation = 0}) => _ExerciseCard(
    date: widget.date,
    exerciseId: id,
    sets: sets,
    editing: widget.editing,
    selected: _selected.contains(id),
    onSelect: _savingOrder
        ? null
        : () => setState(() {
            if (!_selected.add(id)) _selected.remove(id);
          }),
    elevation: elevation,
    trailing: widget.editing
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: _selected.contains(id),
                onChanged: _savingOrder
                    ? null
                    : (value) => setState(() {
                        if (value == true) {
                          _selected.add(id);
                        } else {
                          _selected.remove(id);
                        }
                      }),
                semanticLabel: 'Select ${sets.first.exerciseName}',
              ),
              Tooltip(
                message: 'Drag up or down',
                child: Semantics(
                  label: 'Move ${sets.first.exerciseName} up or down',
                  child: ReorderableDragStartListener(
                    index: index,
                    enabled: !_savingOrder,
                    child: const SizedBox(width: 40, height: 48, child: Icon(Icons.swap_vert_rounded)),
                  ),
                ),
              ),
            ],
          )
        : null,
  );

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

  Future<void> _removeSelected() async {
    if (_savingOrder || _selected.isEmpty) return;
    final repo = ref.read(workoutRepositoryProvider);
    final ids = _selected.toList();
    setState(() => _savingOrder = true);
    final ok = await attempt(context, () async {
      final snapshot = await repo.removeExercisesFromDay(widget.date, ids);
      if (!mounted) return;
      final count = snapshot.sets.map((s) => s.exerciseId).toSet().length;
      notice(
        context,
        '${Fmt.count(count, 'exercise')} removed from this workout',
        action: SnackBarAction(label: 'Undo', onPressed: () => attempt(context, () => repo.restoreDay(snapshot))),
      );
    });
    if (mounted) {
      setState(() {
        _savingOrder = false;
        if (ok) _selected.clear();
      });
    }
  }
}

class _WorkoutToolbar extends SliverPersistentHeaderDelegate {
  const _WorkoutToolbar({
    required this.height,
    required this.exerciseCount,
    required this.setCount,
    required this.editing,
    required this.selectedCount,
    required this.onDelete,
    required this.onDone,
    required this.onAdd,
  });
  final double height;
  final int exerciseCount, setCount, selectedCount;
  final VoidCallback? onDelete;
  final bool editing;
  final VoidCallback onDone, onAdd;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  bool shouldRebuild(covariant _WorkoutToolbar oldDelegate) => true;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    return SizedBox(
      height: height,
      child: Material(
        key: const ValueKey('workout-list-toolbar'),
        color: theme.colorScheme.surface,
        elevation: overlapsContent ? 2 : 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      editing ? '$selectedCount selected' : Fmt.count(exerciseCount, 'exercise'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(height: 1.25),
                    ),
                    Text(
                      Fmt.count(setCount, 'set'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (editing) ...[
                IconButton(
                  tooltip: 'Delete selected exercises',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
                const SizedBox(width: 8),
                IconButton.filled(tooltip: 'Done', onPressed: onDone, icon: const Icon(Icons.check_rounded)),
              ] else
                IconButton.filled(tooltip: 'Add exercise', onPressed: onAdd, icon: const Icon(Icons.add_rounded)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseCard extends ConsumerWidget {
  const _ExerciseCard({
    required this.date,
    required this.exerciseId,
    required this.sets,
    required this.editing,
    required this.selected,
    required this.onSelect,
    this.elevation = 0,
    this.trailing,
  });
  final String date;
  final int exerciseId;
  final List<LoggedSet> sets;
  final Widget? trailing;
  final bool editing, selected;
  final VoidCallback? onSelect;
  final double elevation;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = sets.first;
    final colors = Theme.of(context).colorScheme;
    final prs = ref.watch(prSetIdsProvider(exerciseId));
    final units = ref.watch(unitsProvider);
    final group = first.set.groupName;
    return Semantics(
      selected: editing ? selected : null,
      child: Card(
        color: editing && selected ? AppTheme.selectionColor(colors) : null,
        shape: editing && selected
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: colors.primary, width: 2),
              )
            : null,
        elevation: elevation,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: editing ? onSelect : () => context.push('/log/$exerciseId?date=$date'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                    child: Text(
                      'Superset · $group',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.primary),
                    ),
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
      ),
    );
  }
}
