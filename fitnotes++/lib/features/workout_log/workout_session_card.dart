import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/providers.dart';
import '../../core/repositories/workout_repository.dart';
import '../../core/services/rest_timer.dart';
import '../../core/util/format.dart';
import '../../core/util/dates.dart';
import '../../shared/widgets.dart';

class WorkoutSessionCard extends ConsumerWidget {
  const WorkoutSessionCard({super.key, required this.date, required this.sets, this.enabled = true});
  final String date;
  final List<LoggedSet> sets;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = sets.where((s) => !s.set.isPlanned).toList();
    final volume = done.fold<double>(0, (v, s) => v + s.effectiveWeight * s.set.reps);
    final units = ref.watch(unitsProvider);
    final session = ref.watch(sessionProvider(date)).asData?.value;
    final running = session?.runningSince != null;
    final isToday = date == Dates.today();
    final theme = Theme.of(context);
    final toggleLabel = running
        ? 'Pause'
        : session == null
        ? 'Start'
        : 'Resume';
    void toggle() {
      if (!enabled || date != Dates.today()) return;
      final repo = ref.read(workoutRepositoryProvider);
      attempt(context, () => running ? repo.pauseSession(date) : repo.startSession(date));
    }

    void finish() {
      if (!enabled || date != Dates.today()) return;
      final repo = ref.read(workoutRepositoryProvider);
      final rest = ref.read(restTimerProvider.notifier);
      attempt(context, () async {
        await repo.finishSession(date);
        rest.stop();
      });
    }

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context);
          final labelHeight = textScale.scale(12) * 1.25 * (textScale.scale(1) > 1.3 ? 2 : 1);
          final canFinish = isToday && session != null && session.endedAt == null;
          final inlineFinish = canFinish && constraints.maxWidth >= 340 && MediaQuery.textScalerOf(context).scale(1) <= 1.4;
          return Row(
            children: [
              SizedBox(
                width: (constraints.maxWidth * 0.28).clamp(72.0, 120.0),
                child: Column(
                  key: const ValueKey('workout-volume'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: labelHeight,
                      child: Text(
                        'Volume · ${units.weightLabel}',
                        maxLines: 2,
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        Fmt.number(units.weightFromKg(volume)),
                        style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: ConstrainedBox(
                        key: const ValueKey('workout-duration'),
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: labelHeight,
                              child: Text(
                                'Workout time',
                                maxLines: 2,
                                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                              ),
                            ),
                            StreamBuilder<int>(
                              stream: isToday && running ? Stream.periodic(const Duration(seconds: 1), (i) => i) : null,
                              builder: (_, _) => FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  Fmt.duration(session?.durationAt(DateTime.now()) ?? 0),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isToday)
                      IconButton(
                        tooltip: toggleLabel,
                        onPressed: enabled ? toggle : null,
                        color: AppTheme.lime,
                        disabledColor: Colors.white38,
                        icon: Icon(running ? Icons.pause_rounded : Icons.play_arrow_rounded),
                      ),
                    if (inlineFinish)
                      IconButton(
                        tooltip: 'Finish',
                        onPressed: enabled ? finish : null,
                        color: Colors.white,
                        disabledColor: Colors.white38,
                        icon: const Icon(Icons.stop_rounded),
                      ),
                    AppMenuButton<String>(
                      tooltip: 'Workout timer options',
                      enabled: enabled,
                      iconColor: enabled ? Colors.white70 : Colors.white38,
                      padding: EdgeInsets.zero,
                      onSelected: (action) async {
                        if (action == 'finish') {
                          finish();
                        } else if (action == 'edit') {
                          await _edit(context, ref);
                        } else if (await confirm(
                              context,
                              title: 'Reset workout time?',
                              message: 'Set the timer to zero? Logged sets will be kept.',
                              action: 'Reset',
                            ) &&
                            context.mounted) {
                          await attempt(context, () => ref.read(workoutRepositoryProvider).resetSession(date));
                        }
                      },
                      itemBuilder: (_) => [
                        if (canFinish && !inlineFinish) const PopupMenuItem(value: 'finish', child: Text('Finish')),
                        const PopupMenuItem(value: 'edit', child: Text('Edit duration')),
                        if (session != null) const PopupMenuItem(value: 'reset', child: Text('Reset timer')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
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
