import 'dart:async';

import 'package:flutter/material.dart';

import 'audio/audio_services.dart';
import 'practice_controller.dart';
import 'ui/metronome_view.dart';
import 'ui/tuner_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FretmateApp());
}

class FretmateApp extends StatefulWidget {
  const FretmateApp({super.key, this.controller});

  final PracticeController? controller;

  @override
  State<FretmateApp> createState() => _FretmateAppState();
}

class _FretmateAppState extends State<FretmateApp> {
  bool _darkMode = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fretmate',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      home: PracticeScreen(
        controller: widget.controller,
        darkMode: _darkMode,
        onToggleTheme: () => setState(() => _darkMode = !_darkMode),
      ),
    );
  }

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final canvas = dark ? const Color(0xFF121B17) : const Color(0xFFF3F6F2);
    final seed = ColorScheme.fromSeed(seedColor: const Color(0xFF187A62), brightness: brightness);
    final scheme = dark
        ? seed.copyWith(
            primary: const Color(0xFF82D5B7),
            onPrimary: const Color(0xFF003828),
            primaryContainer: const Color(0xFF234D3E),
            onPrimaryContainer: const Color(0xFFBCEED7),
            surface: const Color(0xFF1B2721),
            surfaceContainerLow: const Color(0xFF202F27),
            onSurface: const Color(0xFFE0EAE2),
            onSurfaceVariant: const Color(0xFFAFBFB4),
            outlineVariant: const Color(0xFF3C4D43),
          )
        : seed.copyWith(
            surface: Colors.white,
            primary: const Color(0xFF187A62),
            onPrimary: Colors.white,
            primaryContainer: const Color(0xFFDDEEDB),
            onPrimaryContainer: const Color(0xFF14533F),
            surfaceContainerLow: const Color(0xFFE8EEE7),
            onSurface: const Color(0xFF24352E),
            onSurfaceVariant: const Color(0xFF63716A),
            outlineVariant: const Color(0xFFDFE7E2),
          );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      textTheme: ThemeData(brightness: brightness).textTheme
          .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 56),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key, this.controller, required this.darkMode, required this.onToggleTheme});

  final PracticeController? controller;
  final bool darkMode;
  final VoidCallback onToggleTheme;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> with WidgetsBindingObserver {
  late final PracticeController controller;
  late final PageController _pages;
  late int _pageIndex;

  @override
  void initState() {
    super.initState();
    controller = widget.controller ?? PracticeController(microphone: DeviceMicrophone(), clicks: AndroidClickOutput());
    _pageIndex = controller.tab;
    _pages = PageController(initialPage: _pageIndex);
    controller.addListener(_syncPage);
    WidgetsBinding.instance.addObserver(this);
  }

  void _syncPage() {
    if (_pageIndex == controller.tab) return;
    _pageIndex = controller.tab;
    if (_pages.hasClients) {
      unawaited(_pages.animateToPage(_pageIndex, duration: const Duration(milliseconds: 220), curve: Curves.easeOut));
    }
  }

  void _onPageChanged(int index) {
    _pageIndex = index;
    unawaited(controller.selectTab(index));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      controller.resume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(controller.suspend());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(_syncPage);
    _pages.dispose();
    if (widget.controller == null) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        toolbarHeight: 52,
        titleSpacing: 16,
        title: const Text('Fretmate', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
        actions: [
          IconButton(
            key: const ValueKey('theme-toggle'),
            tooltip: widget.darkMode ? 'Switch to light mode' : 'Switch to dark mode',
            onPressed: widget.onToggleTheme,
            icon: Icon(widget.darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: _ToolTabs(controller: controller),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                key: const ValueKey('tool-pages'),
                controller: _pages,
                onPageChanged: _onPageChanged,
                itemCount: 2,
                itemBuilder: (context, index) => LayoutBuilder(
                  builder: (context, constraints) {
                    final isTuner = index == 0;
                    final contentWidth = (constraints.maxWidth - 32).clamp(0.0, 600.0);
                    final content = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (controller.error != null) ...[
                          Semantics(
                            liveRegion: true,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                controller.error!,
                                style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Expanded(
                          child: isTuner
                              ? TunerView(controller: controller, meterHeight: contentWidth / 2 + 4)
                              : MetronomeView(controller: controller),
                        ),
                      ],
                    );
                    return SingleChildScrollView(
                      key: PageStorageKey('tool-scroll-$index'),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: 600,
                            minHeight: (constraints.maxHeight - 20).clamp(0.0, double.infinity),
                          ),
                          child: IntrinsicHeight(child: content),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ToolTabs extends StatelessWidget {
  const _ToolTabs({required this.controller});

  final PracticeController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      key: const ValueKey('tool-tabs'),
      children: [
        for (final tab in ['Tuner', 'Metronome'].indexed)
          Expanded(
            child: Semantics(
              selected: controller.tab == tab.$1,
              child: TextButton(
                onPressed: () => controller.selectTab(tab.$1),
                style: TextButton.styleFrom(
                  foregroundColor: controller.tab == tab.$1 ? scheme.primary : scheme.onSurfaceVariant,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.only(top: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tab.$2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 24,
                      height: 2,
                      decoration: BoxDecoration(
                        color: controller.tab == tab.$1 ? scheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
