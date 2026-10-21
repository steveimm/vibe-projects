import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/device_service.dart';
import '../core/services/rest_timer.dart';
import 'widgets.dart';

final restAlarmAccessProvider = FutureProvider.autoDispose((ref) async {
  final access = await DeviceService.call<Map>('restAlarmAccess');
  return (supported: access?['supported'] == true, allowed: access?['allowed'] == true);
});

bool _requesting = false;

Future<void> requestRestAlarmAccess(BuildContext context, WidgetRef ref) async {
  if (!DeviceService.nativeTimers || _requesting) return;
  _requesting = true;
  try {
    final prompt = await DeviceService.call<bool>('claimRestAlarmPrompt') ?? false;
    if (!prompt || !context.mounted || !ref.read(restTimerProvider).visible) return;
    if (await confirm(
      context,
      title: 'Allow alarms & reminders',
      message: 'Needed for rest alerts to ring while the screen is locked.',
      action: 'Open settings',
    )) {
      await DeviceService.call('restAlarmSettings');
    }
  } finally {
    _requesting = false;
  }
}
