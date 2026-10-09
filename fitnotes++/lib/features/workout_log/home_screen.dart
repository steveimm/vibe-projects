import 'dart:math' as math;

import 'package:flutter/material.dart';
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

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(selectedDateProvider);
    final log = ref.watch(dayLogProvider(date));
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: AppTheme.ink, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.add_rounded, color: AppTheme.lime, size: 24),
            ),
            const SizedBox(width: 10),
            const Flexible(child: Text('FitNotes++', maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: math.max(48, MediaQuery.textScalerOf(context).scale(21) * 1.2 + 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        Dates.navLabel(date) == 'TODAY'
                            ? 'Today’s workout'
                            : DateFormat(Dates.parse(date).year == DateTime.now().year ? 'EEE, d MMM' : 'EEE, d MMM yyyy')
                                  .format(Dates.parse(date)),
                        style: Theme.of(context).textTheme.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Visibility(
                      visible: date != Dates.today(),
                      maintainSize: true,
                      maintainAnimation: true,
                      maintainState: true,
                      child: TextButton(
                        onPressed: () => ref.read(selectedDateProvider.notifier).goToday(),
                        child: const Text('Today'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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

class _DayView extends ConsumerWidget {
  const _DayView({super.key, required this.date});
  final String date;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
              SectionTitle(
                '${groups.length} ${groups.length == 1 ? 'exercise' : 'exercises'}',
                trailing: Text(
                  '${sets.length} ${sets.length == 1 ? 'set' : 'sets'}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            for (final entry in groups.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Entrance(
                  child: _ExerciseCard(date: date, exerciseId: entry.key, sets: entry.value),
                ),
              ),
            Card(
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
          ],
        );
      },
    );
  }
}

class _ExerciseCard extends ConsumerWidget {
  const _ExerciseCard({required this.date, required this.exerciseId, required this.sets});
  final String date;
  final int exerciseId;
  final List<LoggedSet> sets;
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
                  const Icon(Icons.chevron_right_rounded, size: 20),
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
