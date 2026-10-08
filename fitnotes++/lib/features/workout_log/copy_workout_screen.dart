import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/tables.dart';
import '../../core/providers.dart';
import '../../core/repositories/workout_repository.dart';
import '../../core/util/format.dart';
import '../../shared/widgets.dart';
import 'workout_calendar.dart';

class CopyWorkoutScreen extends ConsumerStatefulWidget {
  const CopyWorkoutScreen({super.key, required this.targetDate, required this.sourceDate});
  final String targetDate, sourceDate;
  @override
  ConsumerState<CopyWorkoutScreen> createState() => _CopyWorkoutScreenState();
}

class _CopyWorkoutScreenState extends ConsumerState<CopyWorkoutScreen> {
  late String _source = widget.sourceDate;
  bool _loading = true, _failed = false, _copying = false;
  List<LoggedSet> _sets = [];
  final Set<int> _selected = {};
  @override
  void initState() {
    super.initState();
    _load(_source);
  }

  Future<void> _load(String date) async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final sets = await ref.read(workoutRepositoryProvider).dayLog(date);
      if (!mounted) return;
      setState(() {
        _source = date;
        _sets = sets;
        _selected
          ..clear()
          ..addAll(sets.map((s) => s.set.id));
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _changeSource() async {
    final dates = await ref.read(workoutRepositoryProvider).workoutDatesBefore(widget.targetDate);
    if (!mounted) return;
    final date = await pickCopyDay(context, ref, initialDate: _source, selectableDays: dates.toSet());
    if (date != null && mounted) await _load(date);
  }

  @override
  Widget build(BuildContext context) {
    final groups = <int, List<LoggedSet>>{};
    for (final s in _sets) {
      (groups[s.set.exerciseId] ??= []).add(s);
    }
    final units = ref.watch(unitsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Copy workout')),
      body: ContentWidth(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _failed
            ? ErrorState(onRetry: () => _load(_source))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.history_rounded),
                          title: Text('From $_source'),
                          trailing: const Icon(Icons.edit_calendar_outlined),
                          onTap: _copying ? null : _changeSource,
                        ),
                        const Divider(indent: 16, endIndent: 16),
                        ListTile(leading: const Icon(Icons.event_available_outlined), title: Text('To ${widget.targetDate}')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Check off copied sets as you complete them. Only completed sets count in Progress.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Select all · ${_sets.length} sets'),
                    value: _sets.isNotEmpty && _selected.length == _sets.length,
                    onChanged: _copying
                        ? null
                        : (v) => setState(() {
                            _selected.clear();
                            if (v == true) _selected.addAll(_sets.map((s) => s.set.id));
                          }),
                  ),
                  for (final group in groups.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: Column(
                          children: [
                            CheckboxListTile(
                              title: Text(group.first.exerciseName, style: const TextStyle(fontWeight: FontWeight.w700)),
                              value: group.every((s) => _selected.contains(s.set.id)),
                              onChanged: _copying
                                  ? null
                                  : (v) => setState(() {
                                      final ids = group.map((s) => s.set.id);
                                      if (v == true) {
                                        _selected.addAll(ids);
                                      } else {
                                        _selected.removeAll(ids);
                                      }
                                    }),
                            ),
                            const Divider(indent: 16, endIndent: 16),
                            for (final s in group)
                              CheckboxListTile(
                                title: Text(
                                  describeSet(
                                    type: ExerciseType.values[s.exerciseType],
                                    effectiveWeight: s.effectiveWeight,
                                    reps: s.set.reps,
                                    distance: s.set.distance,
                                    durationSeconds: s.set.durationSeconds,
                                    units: units,
                                  ),
                                ),
                                value: _selected.contains(s.set.id),
                                onChanged: _copying
                                    ? null
                                    : (v) => setState(() {
                                        if (v == true) {
                                          _selected.add(s.set.id);
                                        } else {
                                          _selected.remove(s.set.id);
                                        }
                                      }),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton.icon(
            onPressed: _selected.isEmpty || _copying || _loading ? null : _copy,
            icon: const Icon(Icons.copy_rounded),
            label: Text(_copying ? 'Copying…' : 'Copy ${_selected.length} sets'),
          ),
        ),
      ),
    );
  }

  Future<void> _copy() async {
    setState(() => _copying = true);
    final ok = await attempt(context, () async {
      final ids = _sets.where((s) => _selected.contains(s.set.id)).map((s) => s.set.id).toList();
      final count = await ref.read(workoutRepositoryProvider).copySetsToDate(ids, widget.targetDate);
      if (mounted) notice(context, '$count sets copied');
    });
    if (!mounted) return;
    if (ok) {
      ref.read(selectedDateProvider.notifier).set(widget.targetDate);
      context.pop();
    } else {
      setState(() => _copying = false);
    }
  }
}
