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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.ink, Color(0xFF2C5040)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: StatValue('Completed sets', '${done.length}', inverse: true)),
              Expanded(child: StatValue('Volume · ${units.weightLabel}', Fmt.number(units.weightFromKg(volume)), inverse: true)),
            ],
          ),
          const Divider(height: 32, color: Colors.white24),
          Row(
            children: [
              const Expanded(
                child: Text('Workout time', style: TextStyle(color: Colors.white70)),
              ),
              if (session != null)
                Text(
                  running
                      ? 'Running'
                      : session.endedAt == null
                      ? 'Paused'
                      : 'Finished',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              PopupMenuButton<String>(
                tooltip: 'Workout timer options',
                iconColor: Colors.white70,
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
          ),
          Wrap(
            spacing: 12,
            children: [
              StreamBuilder<int>(
                stream: running ? Stream.periodic(const Duration(seconds: 1), (i) => i) : null,
                builder: (_, _) => TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.white, padding: EdgeInsets.zero),
                  onPressed: () => _edit(context, ref),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(
                    Fmt.duration(session?.durationAt(DateTime.now()) ?? 0),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppTheme.lime),
                onPressed: () => attempt(context, () => running ? repo.pauseSession(date) : repo.startSession(date)),
                icon: Icon(running ? Icons.pause_rounded : Icons.play_arrow_rounded),
                label: Text(
                  running
                      ? 'Pause'
                      : session == null
                      ? 'Start'
                      : 'Resume',
                ),
              ),
              if (session != null && session.endedAt == null)
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: () => attempt(context, () async {
                    await repo.finishSession(date);
                    ref.read(restTimerProvider.notifier).stop();
                  }),
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Finish'),
                ),
            ],
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
