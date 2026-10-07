import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_service.dart';

final restClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

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
  DateTime _now() => ref.read(restClockProvider)();
  Timer? _ticker;
  bool _sound = true, _vibrate = false, _visible = true;
  int _generation = 0;

  @override
  RestState build() {
    ref.onDispose(() => _ticker?.cancel());
    Future.microtask(sync);
    return const RestState();
  }

  Future<void> sync() async {
    if (!DeviceService.nativeTimers) return;
    final generation = _generation;
    final saved = await DeviceService.call<Map>('getRest');
    if (!ref.mounted || generation != _generation) return;
    if (saved == null) {
      _ticker?.cancel();
      state = const RestState();
      return;
    }
    final paused = saved['paused'] == true;
    final deadline = DateTime.fromMillisecondsSinceEpoch(saved['deadline'] as int);
    _sound = saved['sound'] as bool;
    _vibrate = saved['vibrate'] as bool;
    final remaining = paused
        ? saved['remaining'] as int
        : (deadline.difference(_now()).inMilliseconds / 1000).ceil().clamp(0, 3600);
    state = RestState(
      status: paused
          ? RestStatus.paused
          : saved['finished'] == true || remaining == 0
          ? RestStatus.finished
          : RestStatus.running,
      remaining: remaining,
      total: saved['total'] as int,
      label: saved['label'] as String,
      deadline: paused ? null : deadline,
    );
    _tick();
  }

  void setVisible(bool visible) {
    _visible = visible;
    if (visible) {
      _tick();
      unawaited(sync());
    } else {
      _ticker?.cancel();
    }
  }

  void start(int seconds, {String label = 'Rest', bool sound = true, bool vibrate = false}) {
    _generation++;
    _sound = sound;
    _vibrate = vibrate;
    final duration = seconds.clamp(1, 3600);
    state = RestState(
      status: RestStatus.running,
      remaining: duration,
      total: duration,
      label: label,
      deadline: _now().add(Duration(seconds: duration)),
    );
    _schedule();
    _tick();
  }

  void _refresh() {
    if (state.status != RestStatus.running) return;
    final left = (state.deadline!.difference(_now()).inMilliseconds / 1000).ceil().clamp(0, 3600);
    if (left == state.remaining && left > 0) return;
    state = RestState(
      status: left == 0 ? RestStatus.finished : RestStatus.running,
      remaining: left,
      total: state.total,
      label: state.label,
      deadline: state.deadline,
    );
    if (left == 0) _ticker?.cancel();
  }

  void _tick() {
    _ticker?.cancel();
    _refresh();
    if (_visible && state.status == RestStatus.running) {
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _refresh());
    }
  }

  void pauseOrResume() {
    _generation++;
    if (state.status == RestStatus.running) {
      _refresh();
      if (state.status == RestStatus.finished) return;
      _ticker?.cancel();
      state = RestState(status: RestStatus.paused, remaining: state.remaining, total: state.total, label: state.label);
      _persistPause();
    } else if (state.status == RestStatus.paused) {
      state = RestState(
        status: RestStatus.running,
        remaining: state.remaining,
        total: state.total,
        label: state.label,
        deadline: _now().add(Duration(seconds: state.remaining)),
      );
      _schedule();
      _tick();
    }
  }

  void add(int seconds) {
    _refresh();
    if (state.status == RestStatus.finished) {
      start(seconds, label: state.label, sound: _sound, vibrate: _vibrate);
      return;
    }
    if (state.status == RestStatus.idle) return;
    _generation++;
    final remaining = (state.remaining + seconds).clamp(1, 3600);
    state = RestState(
      status: state.status,
      remaining: remaining,
      total: state.total + remaining - state.remaining,
      label: state.label,
      deadline: state.status == RestStatus.running ? _now().add(Duration(seconds: remaining)) : null,
    );
    if (state.status == RestStatus.running) {
      _schedule();
    } else if (state.status == RestStatus.paused) {
      _persistPause();
    }
  }

  void configureAlerts({required bool sound, required bool vibrate}) {
    _generation++;
    _sound = sound;
    _vibrate = vibrate;
    if (state.status == RestStatus.running) _schedule();
    if (state.status == RestStatus.paused) _persistPause();
  }

  void stop() {
    _generation++;
    _ticker?.cancel();
    DeviceService.call('cancelRest');
    state = const RestState();
  }

  void _persistPause() => unawaited(
    DeviceService.call('pauseRest', {
      'remaining': state.remaining,
      'total': state.total,
      'label': state.label,
      'sound': _sound,
      'vibrate': _vibrate,
    }),
  );
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
