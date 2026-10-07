import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/tables.dart';
import '../../core/providers.dart';
import '../../core/repositories/workout_repository.dart';
import '../../core/util/dates.dart';
import '../../core/util/format.dart';
import 'workout_calendar.dart';

/// Copy flow: pick a source day from the shared dotted calendar (only days with
/// a prior workout are selectable), then open the granular copy screen.
Future<void> startCopyWorkout(BuildContext context, WidgetRef ref, String date) async {
  final messenger = ScaffoldMessenger.of(context);
  final priors = await ref.read(workoutRepositoryProvider).workoutDatesBefore(date);
  if (priors.isEmpty) {
    messenger.showSnackBar(const SnackBar(content: Text('No previous workouts to copy')));
    return;
  }
  if (!context.mounted) return;
  final picked = await pickCopyDay(context, ref, initialDate: priors.first, selectableDays: priors.toSet());
  if (picked == null || !context.mounted) return;
  context.push('/copy?date=$date&source=$picked');
}

/// The Workout Log home. Days are pages in a [PageView] so swipes animate and
/// vertical scrolling never changes the day.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Swipe right => tomorrow, swipe left => yesterday.
  static const _basePage = 100000;
  late final String _baseDate;
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _baseDate = Dates.today();
    _controller = PageController(initialPage: _pageFor(ref.read(selectedDateProvider)));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _pageFor(String iso) => _basePage + Dates.daysBetween(_baseDate, iso);
  String _dateFor(int page) => Dates.shift(_baseDate, page - _basePage);

  @override
  Widget build(BuildContext context) {
    // Keep the PageView in sync when the date changes from buttons/calendar.
    ref.listen<String>(selectedDateProvider, (_, next) {
      if (!_controller.hasClients) return;
      final target = _pageFor(next);
      final current = (_controller.page ?? _controller.initialPage.toDouble()).round();
      if (current == target) return;
      if ((current - target).abs() > 1) {
        _controller.jumpToPage(target);
      } else {
        _controller.animateToPage(target, duration: const Duration(milliseconds: 260), curve: Curves.easeInOut);
      }
    });

    final date = ref.watch(selectedDateProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('FitNotes++'),
        actions: [
          IconButton(tooltip: 'Calendar', icon: const Icon(Icons.calendar_month_outlined), onPressed: () => _openCalendar(date)),
          IconButton(
            tooltip: 'Add exercise',
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/exercises?pick=1&date=$date'),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'copy':
                  startCopyWorkout(context, ref, date);
                case 'exercises':
                  context.push('/exercises');
                case 'settings':
                  context.push('/settings');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'copy', child: Text('Copy Workout')),
              PopupMenuItem(value: 'exercises', child: Text('All Exercises')),
              PopupMenuItem(value: 'settings', child: Text('Settings')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _DateBar(date: date),
          const Divider(height: 1),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (p) => ref.read(selectedDateProvider.notifier).set(_dateFor(p)),
              itemBuilder: (_, page) => _DayPage(date: _dateFor(page)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCalendar(String date) async {
    final picked = await openWorkoutCalendar(context, ref, initialDate: date);
    if (picked != null) {
      ref.read(selectedDateProvider.notifier).set(picked);
    }
  }
}

class _DateBar extends ConsumerWidget {
  const _DateBar({required this.date});
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(selectedDateProvider.notifier);
    return Row(
      children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: notifier.previous),
        Expanded(
          child: Center(
            child: TextButton(
              onPressed: notifier.goToday,
              child: Text(Dates.navLabel(date), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ),
          ),
        ),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: notifier.next),
      ],
    );
  }
}

/// One day's log, shown as a PageView page.
class _DayPage extends ConsumerWidget {
  const _DayPage({required this.date});
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(dayLogProvider(date));
    return log.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load workout:\n$e', textAlign: TextAlign.center),
        ),
      ),
      data: (sets) => sets.isEmpty ? _EmptyLog(date: date) : _DayLog(date: date, sets: sets),
    );
  }
}

class _EmptyLog extends ConsumerWidget {
  const _EmptyLog({required this.date});
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Workout Log Empty', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).hintColor)),
          const SizedBox(height: 32),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.add),
            label: const Text('Start New Workout'),
            onPressed: () => context.push('/exercises?pick=1&date=$date'),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            icon: const Icon(Icons.copy_all_outlined),
            label: const Text('Copy Previous Workout'),
            onPressed: () => startCopyWorkout(context, ref, date),
          ),
        ],
      ),
    );
  }
}

class _DayLog extends StatelessWidget {
  const _DayLog({required this.date, required this.sets});
  final String date;
  final List<LoggedSet> sets;

  @override
  Widget build(BuildContext context) {
    final order = <int>[];
    final groups = <int, List<LoggedSet>>{};
    for (final s in sets) {
      groups
          .putIfAbsent(s.set.exerciseId, () {
            order.add(s.set.exerciseId);
            return <LoggedSet>[];
          })
          .add(s);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 80),
      children: [for (final id in order) _ExerciseGroup(date: date, exerciseId: id, sets: groups[id]!)],
    );
  }
}

class _ExerciseGroup extends ConsumerWidget {
  const _ExerciseGroup({required this.date, required this.exerciseId, required this.sets});
  final String date;
  final int exerciseId;
  final List<LoggedSet> sets;

  static const _maxShown = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = sets.first;
    final type = ExerciseType.values[first.exerciseType];
    final accent = Theme.of(context).colorScheme.primary;
    final trackPr = ref.watch(settingsProvider).asData?.value.trackPersonalRecords ?? true;
    final prIds = trackPr ? ref.watch(prSetIdsProvider(exerciseId)) : const <int>{};
    final shown = sets.length > _maxShown ? sets.sublist(0, _maxShown) : sets;
    final extra = sets.length - shown.length;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/log/$exerciseId?date=$date'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text(
                first.exerciseName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Container(height: 1.5, color: accent),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Column(
                children: [
                  for (final s in shown) _SetRow(type: type, logged: s, accent: accent, isPr: prIds.contains(s.set.id)),
                  if (extra > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '$extra more',
                          style: TextStyle(color: Theme.of(context).hintColor, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({required this.type, required this.logged, required this.accent, required this.isPr});
  final ExerciseType type;
  final LoggedSet logged;
  final Color accent;
  final bool isPr;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 30, child: isPr ? Icon(Icons.emoji_events, size: 20, color: accent) : null),
          for (final col in _columns()) Expanded(child: _valueUnit(context, col.$1, col.$2)),
        ],
      ),
    );
  }

  List<(String, String)> _columns() => setColumns(
    type: type,
    weight: logged.effectiveWeight,
    reps: logged.set.reps,
    distance: logged.set.distance,
    seconds: logged.set.durationSeconds,
  );

  Widget _valueUnit(BuildContext context, String value, String unit) {
    final scheme = Theme.of(context).colorScheme;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: scheme.onSurface),
          ),
          if (unit.isNotEmpty)
            TextSpan(
              text: ' $unit',
              style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
            ),
        ],
      ),
      textAlign: TextAlign.right,
    );
  }
}
