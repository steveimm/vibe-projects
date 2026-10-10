import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/providers.dart';
import '../../shared/widgets.dart';
import '../../core/util/format.dart';

class RoutinesScreen extends ConsumerStatefulWidget {
  const RoutinesScreen({super.key, this.date});
  final String? date;
  @override
  ConsumerState<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends ConsumerState<RoutinesScreen> {
  final _selected = <int>{};
  bool _selecting = false, _deleting = false;

  void _toggle(int id) => setState(() {
    _selecting = true;
    if (!_selected.add(id)) _selected.remove(id);
  });

  void _finishSelection() => setState(() {
    _selecting = false;
    _selected.clear();
  });

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_selecting,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && _selecting && !_deleting) _finishSelection();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(_selecting ? '${_selected.length} selected' : 'Routines'),
        actions: [
          if (_selecting) ...[
            IconButton(
              tooltip: 'Delete selected routines',
              onPressed: _deleting || _selected.isEmpty ? null : _deleteSelected,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
            IconButton.filled(
              tooltip: 'Done',
              style: IconButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onPrimary),
              icon: const Icon(Icons.check_rounded),
              onPressed: _deleting ? null : _finishSelection,
            ),
          ],
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _selecting
          ? null
          : FloatingActionButton(
              tooltip: 'New routine',
              onPressed: _create,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.add_rounded, size: 28),
            ),
      body: ContentWidth(
        child: ref
            .watch(routinesProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => ErrorState(onRetry: () => ref.invalidate(routinesProvider)),
              data: (routines) {
                if (routines.isEmpty) {
                  return const Center(child: Text('No routines'));
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                  children: [
                    for (final routine in routines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Semantics(
                          selected: _selecting ? _selected.contains(routine.id) : null,
                          child: Card(
                            key: ValueKey('routine-${routine.id}'),
                            clipBehavior: Clip.antiAlias,
                            color: _selected.contains(routine.id) ? AppTheme.selectionColor(Theme.of(context).colorScheme) : null,
                            shape: _selected.contains(routine.id)
                                ? RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                                  )
                                : null,
                            child: ListTile(
                              enabled: !_deleting,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                              minTileHeight: 64,
                              titleTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                              title: Text(routine.name),
                              subtitleTextStyle: Theme.of(context).textTheme.bodySmall,
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  routine.notes.isEmpty
                                      ? Fmt.count(ref.watch(routineDaysProvider(routine.id)).asData?.value.length ?? 0, 'day')
                                      : routine.notes,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              trailing: Icon(
                                _selecting
                                    ? _selected.contains(routine.id)
                                          ? Icons.check_circle_rounded
                                          : Icons.radio_button_unchecked_rounded
                                    : Icons.chevron_right_rounded,
                                color: _selected.contains(routine.id) ? Theme.of(context).colorScheme.primary : null,
                              ),
                              onLongPress: _deleting
                                  ? null
                                  : () {
                                      HapticFeedback.selectionClick();
                                      _toggle(routine.id);
                                    },
                              onTap: _deleting
                                  ? null
                                  : () {
                                      if (_selecting) {
                                        _toggle(routine.id);
                                      } else {
                                        context.push(
                                          '/routine/${routine.id}${widget.date == null ? '' : '?date=${widget.date}'}',
                                        );
                                      }
                                    },
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
      ),
    ),
  );

  Future<void> _deleteSelected() async {
    final ids = _selected.toList();
    if (!await confirm(
          context,
          title: 'Delete ${Fmt.count(ids.length, 'routine')}?',
          message: 'Their days and preset sets will be removed. Logged workouts will remain.',
        ) ||
        !mounted) {
      return;
    }
    setState(() => _deleting = true);
    final ok = await attempt(context, () => ref.read(routineRepositoryProvider).deleteMany(ids));
    if (!mounted) return;
    setState(() => _deleting = false);
    if (ok) _finishSelection();
  }

  Future<void> _create() async {
    final name = await prompt(context, title: 'New routine', label: 'Name', maxLength: 100);
    if (name == null || !mounted) return;
    await attempt(context, () async {
      final id = await ref.read(routineRepositoryProvider).create(name);
      if (mounted) context.push('/routine/$id${widget.date == null ? '' : '?date=${widget.date}'}');
    });
  }
}
