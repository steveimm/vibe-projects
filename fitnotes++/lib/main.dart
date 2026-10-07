import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/providers.dart';
import 'core/services/device_service.dart';

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
    ref.listenManual(settingsProvider, (_, settings) {
      DeviceService.call('keepAwake', {'enabled': settings.asData?.value.keepScreenOn ?? false});
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
    );
  }
}
