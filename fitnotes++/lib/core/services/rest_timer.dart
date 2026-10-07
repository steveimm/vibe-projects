import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_service.dart';

enum RestStatus { idle, running, paused, finished }

class RestState {
  const RestState({this.status = RestStatus.idle, this.remaining = 0, this.total = 0, this.label = 'Rest', this.deadline});
  final RestStatus status;
  final int remaining;
  final int total;
  final String label;
  final DateTime? deadline;
  bool get visible => status != RestStatus.idle;
}

class RestTimerController extends Notifier<RestState> {
  Timer? _ticker;
  bool _sound = true;
  bool _vibrate = false;

  @override
  RestState build() {
    ref.onDispose(() => _ticker?.cancel());
    Future.microtask(_restore);
    return const RestState();
  }

  Future<void> _restore() async {
    final saved = await DeviceService.call<Map>('getRest');
    if (!ref.mounted || saved == null || state.status != RestStatus.idle) return;
    final deadline = DateTime.fromMillisecondsSinceEpoch(saved['deadline'] as int);
    _sound = saved['sound'] as bool;
    _vibrate = saved['vibrate'] as bool;
    state = RestState(
      status: RestStatus.running,
      remaining: deadline.difference(DateTime.now()).inSeconds,
      total: saved['total'] as int,
      label: saved['label'] as String,
      deadline: deadline,
    );
    _tick();
  }

  void start(int seconds, {String label = 'Rest', bool sound = true, bool vibrate = false}) {
    _sound = sound;
    _vibrate = vibrate;
    final duration = seconds.clamp(1, 3600);
    state = RestState(
      status: RestStatus.running,
      remaining: duration,
      total: duration,
      label: label,
      deadline: DateTime.now().add(Duration(seconds: duration)),
    );
    _schedule();
    _tick();
  }

  void _tick() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (state.status != RestStatus.running) return;
      final left = (state.deadline!.difference(DateTime.now()).inMilliseconds / 1000).ceil().clamp(0, 3600);
      if (left == state.remaining) return;
      state = RestState(
        status: left == 0 ? RestStatus.finished : RestStatus.running,
        remaining: left,
        total: state.total,
        label: state.label,
        deadline: state.deadline,
      );
      if (left == 0) _ticker?.cancel();
    });
  }

  void pauseOrResume() {
    if (state.status == RestStatus.running) {
      _ticker?.cancel();
      DeviceService.call('cancelRest');
      state = RestState(status: RestStatus.paused, remaining: state.remaining, total: state.total, label: state.label);
    } else if (state.status == RestStatus.paused) {
      state = RestState(
        status: RestStatus.running,
        remaining: state.remaining,
        total: state.total,
        label: state.label,
        deadline: DateTime.now().add(Duration(seconds: state.remaining)),
      );
      _schedule();
      _tick();
    }
  }

  void add(int seconds) {
    if (state.status == RestStatus.finished) {
      start(seconds, label: state.label, sound: _sound, vibrate: _vibrate);
      return;
    }
    final remaining = (state.remaining + seconds).clamp(1, 3600);
    state = RestState(
      status: state.status,
      remaining: remaining,
      total: state.total + seconds,
      label: state.label,
      deadline: state.status == RestStatus.running ? DateTime.now().add(Duration(seconds: remaining)) : null,
    );
    if (state.status == RestStatus.running) _schedule();
  }

  void stop() {
    _ticker?.cancel();
    DeviceService.call('cancelRest');
    state = const RestState();
  }

  void _schedule() => unawaited(
    DeviceService.call('scheduleRest', {
      'deadline': state.deadline!.millisecondsSinceEpoch,
      'total': state.total,
      'label': state.label,
      'sound': _sound,
      'vibrate': _vibrate,
    }),
  );
}

final restTimerProvider = NotifierProvider<RestTimerController, RestState>(RestTimerController.new);
