import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../shared/rest_timer_bar.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child, required this.path});
  final Widget child;
  final String path;
  static const paths = ['/', '/routines', '/progress', '/settings'];
  @override
  Widget build(BuildContext context) {
    final index = paths.indexWhere((p) => p == '/' ? path == p : path.startsWith(p));
    return PopScope(
      canPop: path == '/',
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/');
      },
      child: Scaffold(
        body: child,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const RestTimerBar(),
            NavigationBar(
              selectedIndex: index < 0 ? 0 : index,
              onDestinationSelected: (i) => context.go(paths[i]),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.sports_gymnastics_outlined),
                  selectedIcon: Icon(Icons.sports_gymnastics_rounded),
                  label: 'Workout',
                ),
                NavigationDestination(
                  icon: Icon(Icons.view_week_outlined),
                  selectedIcon: Icon(Icons.view_week_rounded),
                  label: 'Routines',
                ),
                NavigationDestination(
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights_rounded),
                  label: 'Progress',
                ),
                NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune_rounded), label: 'Settings'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
