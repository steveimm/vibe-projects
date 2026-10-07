import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'app/calendar_localizations.dart';
import 'core/providers.dart';
import 'core/services/device_service.dart';
import 'core/services/rest_timer.dart';

void main() {
  runApp(const ProviderScope(child: FitNotesApp()));
}

class FitNotesApp extends ConsumerStatefulWidget {
  const FitNotesApp({super.key});

  @override
  ConsumerState<FitNotesApp> createState() => _FitNotesAppState();
}

class _FitNotesAppState extends ConsumerState<FitNotesApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(settingsProvider, (previous, settings) {
      final value = settings.asData?.value;
      DeviceService.call('keepAwake', {'enabled': value?.keepScreenOn ?? false});
      final old = previous?.asData?.value;
      if (old != null &&
          value != null &&
          (old.restTimerSound != value.restTimerSound || old.restTimerVibrate != value.restTimerVibrate)) {
        ref.read(restTimerProvider.notifier).configureAlerts(sound: value.restTimerSound, vibrate: value.restTimerVibrate);
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(restTimerProvider.notifier).setVisible(state == AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed) ref.read(selectedDateProvider.notifier).refreshToday();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).asData?.value;
    final themeMode = switch (settings?.themeMode) {
      1 => ThemeMode.light,
      2 => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return MaterialApp.router(
      title: 'FitNotes++',
      localizationsDelegates: [CalendarLocalizationsDelegate(settings?.firstDayOfWeek ?? 1)],
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
    );
  }
}
