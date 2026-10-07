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

class _FitNotesAppState extends ConsumerState<FitNotesApp> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(settingsProvider, (_, settings) {
      DeviceService.call('keepAwake', {'enabled': settings.asData?.value.keepScreenOn ?? false});
    }, fireImmediately: true);
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
