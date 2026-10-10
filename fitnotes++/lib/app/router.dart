import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/util/dates.dart';
import '../features/exercises/categories_screen.dart';
import '../features/exercises/edit_exercise_screen.dart';
import '../features/exercises/exercise_list_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/routines/routine_detail_screen.dart';
import '../features/routines/routines_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/seasons_screen.dart';
import '../features/track/exercise_detail_screen.dart';
import '../features/workout_log/copy_workout_screen.dart';
import '../features/workout_log/home_screen.dart';
import 'app_shell.dart';

String _date(GoRouterState state) {
  final value = state.uri.queryParameters['date'] ?? Dates.today();
  try {
    Dates.validate(value);
    return value;
  } on FormatException {
    return Dates.today();
  }
}

Page<void> _page(GoRouterState state, Widget child) => CustomTransitionPage(
  key: state.pageKey,
  child: child,
  transitionDuration: const Duration(milliseconds: 220),
  reverseTransitionDuration: const Duration(milliseconds: 180),
  transitionsBuilder: (context, animation, secondary, child) => MediaQuery.disableAnimationsOf(context)
      ? child
      : FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0.025, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
);

final appRouter = createAppRouter();

GoRouter createAppRouter({String initialLocation = '/'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    ShellRoute(
      builder: (_, state, child) => AppShell(path: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (_, state) => NoTransitionPage(key: state.pageKey, child: const HomeScreen()),
        ),
        GoRoute(
          path: '/exercises',
          pageBuilder: (_, state) => NoTransitionPage(key: state.pageKey, child: const ExerciseListScreen()),
        ),
        GoRoute(
          path: '/routines',
          pageBuilder: (_, state) => NoTransitionPage(
            key: state.pageKey,
            child: RoutinesScreen(date: state.uri.queryParameters['date']),
          ),
        ),
        GoRoute(
          path: '/progress',
          pageBuilder: (_, state) => NoTransitionPage(key: state.pageKey, child: const ProgressScreen()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (_, state) => NoTransitionPage(key: state.pageKey, child: const SettingsScreen()),
        ),
      ],
    ),
    GoRoute(
      path: '/pick-exercise',
      pageBuilder: (_, state) => _page(
        state,
        ExerciseListScreen(pickMode: true, date: _date(state), returnSelection: state.uri.queryParameters['return'] == '1'),
      ),
    ),
    GoRoute(
      path: '/exercises/edit',
      pageBuilder: (_, state) => _page(
        state,
        EditExerciseScreen(
          exerciseId: int.tryParse(state.uri.queryParameters['id'] ?? ''),
          initialCategoryId: int.tryParse(state.uri.queryParameters['category'] ?? ''),
        ),
      ),
    ),
    GoRoute(path: '/categories', pageBuilder: (_, state) => _page(state, const CategoriesScreen())),
    GoRoute(
      path: '/routine/:id',
      pageBuilder: (_, state) =>
          _page(state, RoutineDetailScreen(id: int.parse(state.pathParameters['id']!), date: _date(state))),
    ),
    GoRoute(path: '/seasons', pageBuilder: (_, state) => _page(state, const SeasonsScreen())),
    GoRoute(
      path: '/copy',
      pageBuilder: (_, state) => _page(
        state,
        CopyWorkoutScreen(targetDate: _date(state), sourceDate: state.uri.queryParameters['source'] ?? _date(state)),
      ),
    ),
    GoRoute(
      path: '/log/:exerciseId',
      pageBuilder: (_, state) => _page(
        state,
        ExerciseDetailScreen(
          exerciseId: int.parse(state.pathParameters['exerciseId']!),
          date: _date(state),
          initialTab: (int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0).clamp(0, 2),
        ),
      ),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Page not found')),
    body: Center(
      child: FilledButton(onPressed: () => context.go('/'), child: const Text('Go to workout')),
    ),
  ),
);
