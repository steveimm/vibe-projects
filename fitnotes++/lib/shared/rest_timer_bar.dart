import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/rest_timer.dart';
import 'rest_alarm_access.dart';
import '../core/util/format.dart';

class RestTimerBar extends ConsumerWidget {
  const RestTimerBar({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(restTimerProvider, (previous, next) {
      if (previous?.visible != true && next.visible) unawaited(requestRestAlarmAccess(context, ref));
    });
    final timer = ref.watch(restTimerProvider);
    final control = ref.read(restTimerProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    if (!timer.visible) return const SizedBox.shrink();
    final progress = timer.total == 0 ? 0.0 : (1 - timer.remaining / timer.total).clamp(0.0, 1.0);
    return Material(
      color: colors.surfaceContainerLow,
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: progress),
                duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 200),
                builder: (_, value, _) => FractionallySizedBox(
                  widthFactor: value,
                  heightFactor: 1,
                  child: ColoredBox(color: Color.alphaBlend(colors.primary.withValues(alpha: 0.16), colors.surfaceContainerLow)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${timer.status == RestStatus.paused ? 'Paused' : 'Rest'} · ${Fmt.duration(timer.remaining)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: timer.status == RestStatus.paused ? 'Resume rest timer' : 'Pause rest timer',
                  onPressed: control.pauseOrResume,
                  icon: Icon(timer.status == RestStatus.paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                ),
                TextButton(onPressed: timer.remaining >= 3600 ? null : () => control.add(15), child: const Text('+15s')),
                IconButton(tooltip: 'Stop rest timer', onPressed: control.stop, icon: const Icon(Icons.close_rounded)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
