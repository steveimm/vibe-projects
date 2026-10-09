import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/providers.dart';
import '../../core/repositories/workout_repository.dart';
import '../../core/services/rest_timer.dart';
import '../../core/util/format.dart';
import '../../shared/widgets.dart';

class WorkoutSessionCard extends ConsumerWidget {
  const WorkoutSessionCard({super.key, required this.date, required this.sets});
  final String date;
  final List<LoggedSet> sets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = sets.where((s) => !s.set.isPlanned).toList();
    final volume = done.fold<double>(0, (v, s) => v + s.effectiveWeight * s.set.reps);
    final units = ref.watch(unitsProvider);
    final session = ref.watch(sessionProvider(date)).asData?.value;
    final running = session?.runningSince != null;
    final repo = ref.read(workoutRepositoryProvider);
    final theme = Theme.of(context);
    final controlStyle = TextButton.styleFrom(
      foregroundColor: AppTheme.lime,
      minimumSize: const Size(56, 40),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
    final toggleLabel = running
        ? 'Pause'
        : session == null
        ? 'Start'
        : 'Resume';
    void toggle() => attempt(context, () => running ? repo.pauseSession(date) : repo.startSession(date));
    void finish() => attempt(context, () async {
      await repo.finishSession(date);
      ref.read(restTimerProvider.notifier).stop();
    });
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.ink, Color(0xFF2C5040)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: StatValue('Sets', '${done.length}', inverse: true, centered: true)),
              Expanded(
                child: StatValue(
                  'Volume · ${units.weightLabel}',
                  Fmt.number(units.weightFromKg(volume)),
                  inverse: true,
                  centered: true,
                ),
              ),
            ],
          ),
          const Divider(height: 16, color: Colors.white24),
          LayoutBuilder(
            builder: (context, constraints) {
              final iconControls = MediaQuery.textScalerOf(context).scale(14) > 20 || constraints.maxWidth < 280;
              return Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: 'Edit workout duration',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _edit(context, ref),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Workout time', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
                              StreamBuilder<int>(
                                stream: running ? Stream.periodic(const Duration(seconds: 1), (i) => i) : null,
                                builder: (_, _) => FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        Fmt.duration(session?.durationAt(DateTime.now()) ?? 0),
                                        style: theme.textTheme.titleLarge?.copyWith(
                                          color: Colors.white,
                                          fontFeatures: [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.edit_outlined, size: 14, color: Colors.white70),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (iconControls)
                    IconButton(
                      tooltip: toggleLabel,
                      onPressed: toggle,
                      color: AppTheme.lime,
                      icon: Icon(running ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    )
                  else
                    TextButton(style: controlStyle, onPressed: toggle, child: Text(toggleLabel)),
                  if (session != null && session.endedAt == null)
                    if (iconControls)
                      IconButton(tooltip: 'Finish', onPressed: finish, color: Colors.white, icon: const Icon(Icons.stop_rounded))
                    else
                      TextButton(
                        style: controlStyle.copyWith(foregroundColor: const WidgetStatePropertyAll(Colors.white)),
                        onPressed: finish,
                        child: const Text('Finish'),
                      ),
                  PopupMenuButton<String>(
                    tooltip: 'Workout timer options',
                    iconColor: Colors.white70,
                    padding: EdgeInsets.zero,
                    onSelected: (action) async {
                      if (action == 'edit') {
                        await _edit(context, ref);
                      } else if (await confirm(
                            context,
                            title: 'Reset workout time?',
                            message: 'Set the timer to zero? Logged sets will be kept.',
                            action: 'Reset',
                          ) &&
                          context.mounted) {
                        await attempt(context, () => repo.resetSession(date));
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit duration')),
                      if (session != null) const PopupMenuItem(value: 'reset', child: Text('Reset timer')),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final session = ref.read(sessionProvider(date)).asData?.value;
    final value = await prompt(
      context,
      title: 'Workout duration',
      label: 'Time (h:mm:ss or m:ss)',
      value: Fmt.duration(session?.durationAt(DateTime.now()) ?? 0),
      keyboard: TextInputType.datetime,
      maxLength: 10,
      validate: (v) {
        final seconds = Fmt.parseDuration(v);
        return seconds != null && seconds <= 604800 ? null : 'Use a duration between 0 and 168 hours.';
      },
    );
    if (value != null && context.mounted) {
      await attempt(context, () => ref.read(workoutRepositoryProvider).editSessionDuration(date, Fmt.parseDuration(value)!));
    }
  }
}
