import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../providers.dart';
import '../repositories/workout_repository.dart';

class WorkoutAutoStop {
  WorkoutAutoStop({required this.expire, DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final Future<void> Function() expire;
  final DateTime Function() _now;
  List<WorkoutSession> _sessions = const [];
  int _minutes = 15;
  bool _visible = true;
  Timer? _timer;

  void update(List<WorkoutSession> sessions, int minutes) {
    _sessions = sessions;
    _minutes = minutes;
    _schedule();
  }

  void setVisible(bool visible) {
    _visible = visible;
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    if (!_visible) return;
    DateTime? next;
    for (final session in _sessions) {
      final deadline = session.inactivityDeadline(_minutes);
      if (deadline != null && (next == null || deadline.isBefore(next))) next = deadline;
    }
    if (next == null) return;
    final deadline = next;
    final delay = Duration(milliseconds: (deadline.difference(_now()).inMicroseconds / 1000).ceil());
    _timer = Timer(delay.isNegative ? Duration.zero : delay, () async {
      _timer = null;
      if (_now().isBefore(deadline)) {
        _schedule();
        return;
      }
      try {
        await expire();
      } catch (error, stack) {
        FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'workout auto-stop'));
      }
    });
  }

  void dispose() => _timer?.cancel();
}

final workoutAutoStopProvider = Provider<WorkoutAutoStop>((ref) {
  final timer = WorkoutAutoStop(expire: ref.watch(workoutRepositoryProvider).finishInactiveSessions);
  ref.onDispose(timer.dispose);
  void update() {
    final settings = ref.read(settingsProvider).asData?.value;
    final sessions = ref.read(workoutSessionsProvider).asData?.value;
    if (settings != null && sessions != null) timer.update(sessions, settings.workoutAutoStopMinutes);
  }

  ref.listen(settingsProvider, (_, _) => update(), fireImmediately: true);
  ref.listen(workoutSessionsProvider, (_, _) => update(), fireImmediately: true);
  return timer;
});
