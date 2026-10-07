import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/rest_timer.dart';
import '../core/util/format.dart';

class RestTimerBar extends ConsumerWidget {
  const RestTimerBar({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(restTimerProvider);
    final control = ref.read(restTimerProvider.notifier);
    final color = Theme.of(context).colorScheme;
    return AnimatedSize(
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 180),
      alignment: Alignment.bottomCenter,
      child: !timer.visible
          ? const SizedBox.shrink()
          : Material(
              color: color.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 38,
                      height: 38,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ExcludeSemantics(
                            child: CircularProgressIndicator(
                              value: timer.total == 0 ? 0 : (timer.remaining / timer.total).clamp(0, 1),
                              strokeWidth: 3,
                              color: color.onSecondaryContainer,
                              backgroundColor: color.onSecondaryContainer.withValues(alpha: 0.15),
                            ),
                          ),
                          Icon(
                            timer.status == RestStatus.finished ? Icons.check_rounded : Icons.timer_outlined,
                            size: 19,
                            color: color.onSecondaryContainer,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            timer.status == RestStatus.finished
                                ? 'Rest complete'
                                : '${Fmt.duration(timer.remaining)}${timer.status == RestStatus.paused ? ' · paused' : ' · rest'}',
                            style: TextStyle(fontWeight: FontWeight.w700, color: color.onSecondaryContainer),
                          ),
                          Text(
                            timer.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: color.onSecondaryContainer),
                          ),
                        ],
                      ),
                    ),
                    if (timer.status != RestStatus.finished)
                      IconButton(
                        tooltip: timer.status == RestStatus.paused ? 'Resume timer' : 'Pause timer',
                        onPressed: control.pauseOrResume,
                        icon: Icon(timer.status == RestStatus.paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                      ),
                    TextButton(onPressed: timer.remaining >= 3600 ? null : () => control.add(15), child: const Text('+15s')),
                    IconButton(tooltip: 'Dismiss timer', onPressed: control.stop, icon: const Icon(Icons.close_rounded)),
                  ],
                ),
              ),
            ),
    );
  }
}
