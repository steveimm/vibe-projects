import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/database/database.dart';
import '../../core/database/tables.dart';
import '../../core/providers.dart';
import '../../core/util/dates.dart';
import '../../core/util/format.dart';
import '../../shared/widgets.dart';

class RoutineDetailScreen extends ConsumerStatefulWidget {
  const RoutineDetailScreen({super.key, required this.id, this.date});
  final int id;
  final String? date;
  @override
  ConsumerState<RoutineDetailScreen> createState() => _RoutineDetailScreenState();
}

class _RoutineDetailScreenState extends ConsumerState<RoutineDetailScreen> {
  int? _dayId;
  bool _logging = false, _reordering = false;
  List<int>? _order;
  @override
  Widget build(BuildContext context) {
    final routine = ref.watch(routinesProvider).asData?.value.where((r) => r.id == widget.id).firstOrNull;
    final days = ref.watch(routineDaysProvider(widget.id));
    final exercises = {for (final e in ref.watch(allExercisesProvider).asData?.value ?? <Exercise>[]) e.id: e};
    final String date = widget.date ?? ref.watch<String>(selectedDateProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(routine?.name ?? 'Routine'),
        actions: [
          if (routine != null)
            AppMenuButton<String>(
              tooltip: 'Routine options',
              onSelected: (action) => _routineAction(routine, action),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename routine')),
                PopupMenuItem(value: 'notes', child: Text('Routine notes')),
                PopupMenuItem(value: 'delete', child: Text('Delete routine')),
              ],
            ),
        ],
      ),
      body: days.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(onRetry: () => ref.invalidate(routineDaysProvider(widget.id))),
        data: (days) {
          if (!days.any((d) => d.id == _dayId)) _dayId = days.firstOrNull?.id;
          final sets = _dayId == null ? null : ref.watch(routineSetsProvider(_dayId!));
          final items = sets?.asData?.value ?? <RoutineSet>[];
          final groups = <int, List<RoutineSet>>{};
          for (final set in items) {
            (groups[set.exerciseId] ??= []).add(set);
          }
          if (listEquals(_order, groups.keys.toList())) _order = null;
          final ids = {...?_order, ...groups.keys}.where(groups.containsKey).toList();
          return Scaffold(
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            floatingActionButton: AppFloatingActionButton(
              tooltip: 'Add exercise',
              onPressed: _dayId == null || _logging || _reordering ? null : _addExercise,
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: items.isEmpty || _logging || _reordering ? null : () => _log(date),
                  icon: _logging
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.playlist_add_rounded),
                  label: Text(
                    date == Dates.today() ? 'Add to today' : 'Add to ${DateFormat('d MMM yyyy').format(Dates.parse(date))}',
                  ),
                ),
              ),
            ),
            body: ContentWidth(
              child: Column(
                children: [
                  if (routine != null && routine.notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          onTap: () => _routineAction(routine, 'notes'),
                          child: Text(routine.notes, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final day in days)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                      label: Text(day.name),
                                      selected: day.id == _dayId,
                                      selectedColor: AppTheme.selectionColor(Theme.of(context).colorScheme),
                                      onSelected: _logging || _reordering
                                          ? null
                                          : (_) => setState(() {
                                              _dayId = day.id;
                                              _order = null;
                                            }),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Add day',
                          onPressed: _logging || _reordering ? null : _addDay,
                          icon: const Icon(Icons.add_rounded),
                        ),
                        if (_dayId != null)
                          AppMenuButton<String>(
                            tooltip: 'Day options',
                            enabled: !_logging && !_reordering,
                            onSelected: (value) => _dayAction(days.firstWhere((d) => d.id == _dayId), value),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'rename', child: Text('Rename day')),
                              PopupMenuItem(value: 'delete', child: Text('Delete day')),
                            ],
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${Fmt.count(groups.length, 'exercise')} · ${Fmt.count(items.length, 'set')}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: sets?.isLoading == true
                        ? const Center(child: CircularProgressIndicator())
                        : sets?.hasError == true
                        ? ErrorState(onRetry: () => ref.invalidate(routineSetsProvider(_dayId!)))
                        : ReorderableListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                            buildDefaultDragHandles: false,
                            itemCount: ids.length,
                            onReorderItem: (from, to) => _reorder(groups, ids, from, to),
                            proxyDecorator: (_, index, animation) => AnimatedBuilder(
                              animation: animation,
                              builder: (_, _) => _exerciseCard(
                                exercises[ids[index]],
                                groups[ids[index]]!,
                                index,
                                ids,
                                groups,
                                date,
                                dragging: true,
                                elevation: animation.value * 4,
                              ),
                            ),
                            itemBuilder: (_, i) => Padding(
                              key: ValueKey(ids[i]),
                              padding: const EdgeInsets.only(bottom: 8),
                              child: ReorderableDelayedDragStartListener(
                                index: i,
                                enabled: !_logging && !_reordering,
                                child: _exerciseCard(exercises[ids[i]], groups[ids[i]]!, i, ids, groups, date),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _exerciseCard(
    Exercise? exercise,
    List<RoutineSet> sets,
    int index,
    List<int> ids,
    Map<int, List<RoutineSet>> groups,
    String date, {
    bool dragging = false,
    double elevation = 0,
  }) {
    final enabled = !_logging && !_reordering && !dragging;
    return Card(
      elevation: elevation,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    exercise?.name ?? 'Exercise',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Add set for ${exercise?.name ?? 'exercise'}',
                  onPressed: enabled
                      ? () => attempt(context, () => ref.read(routineRepositoryProvider).duplicateSet(sets.last.id))
                      : null,
                  icon: const Icon(Icons.add_rounded),
                ),
                ReorderableDragStartListener(
                  index: index,
                  enabled: enabled,
                  child: const Tooltip(
                    message: 'Drag to reorder exercise',
                    child: SizedBox(width: 40, height: 48, child: Icon(Icons.unfold_more_rounded, size: 22)),
                  ),
                ),
                AppMenuButton<String>(
                  tooltip: '${exercise?.name ?? 'Exercise'} options',
                  enabled: enabled,
                  onSelected: (action) async {
                    if (action == 'up') {
                      await _reorder(groups, ids, index, index - 1);
                      return;
                    }
                    if (action == 'down') {
                      await _reorder(groups, ids, index, index + 1);
                      return;
                    }
                    if (action == 'delete' &&
                        await confirm(
                          context,
                          title: 'Remove exercise?',
                          message: 'Remove ${exercise?.name ?? 'this exercise'} from this routine day?',
                        ) &&
                        mounted) {
                      await attempt(context, () => ref.read(routineRepositoryProvider).deleteSets(sets.map((s) => s.id)));
                    }
                  },
                  itemBuilder: (_) => [
                    if (index > 0) const PopupMenuItem(value: 'up', child: Text('Move up')),
                    if (index < ids.length - 1) const PopupMenuItem(value: 'down', child: Text('Move down')),
                    const PopupMenuItem(value: 'delete', child: Text('Remove exercise')),
                  ],
                ),
              ],
            ),
          ),
          for (var i = 0; i < sets.length; i++)
            InkWell(
              onTap: !enabled || exercise == null
                  ? null
                  : () => showDialog(
                      context: context,
                      builder: (_) => _PresetDialog(set: sets[i], exercise: exercise, siblings: sets, date: date),
                    ),
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Row(
                  children: [
                    SizedBox(width: 24, child: Text('${i + 1}', style: Theme.of(context).textTheme.bodySmall)),
                    Expanded(
                      child: Text(
                        _description(
                          sets[i],
                          ref.watch(unitsProvider).withWeightUnit(exercise?.weightUnit),
                          exercise?.type ?? ExerciseType.weightAndReps,
                        ),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    AppMenuButton<String>(
                      tooltip: '${exercise?.name ?? 'Exercise'} set ${i + 1} options',
                      enabled: enabled,
                      onSelected: (action) {
                        if (action == 'up' || action == 'down') {
                          attempt(
                            context,
                            () => ref
                                .read(routineRepositoryProvider)
                                .swapSetOrder(sets[i].id, sets[action == 'up' ? i - 1 : i + 1].id),
                          );
                        } else {
                          _setAction(sets[i], action);
                        }
                      },
                      itemBuilder: (_) => [
                        if (i > 0) const PopupMenuItem(value: 'up', child: Text('Move up')),
                        if (i < sets.length - 1) const PopupMenuItem(value: 'down', child: Text('Move down')),
                        const PopupMenuItem(value: 'duplicate', child: Text('Duplicate set')),
                        const PopupMenuItem(value: 'delete', child: Text('Delete set')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _reorder(Map<int, List<RoutineSet>> groups, List<int> ids, int from, int to) async {
    if (_reordering || _logging || from == to) return;
    final order = [...ids];
    order.insert(to, order.removeAt(from));
    setState(() {
      _reordering = true;
      _order = order;
    });
    final ok = await attempt(
      context,
      () => ref.read(routineRepositoryProvider).reorder([for (final id in order) ...groups[id]!.map((s) => s.id)]),
    );
    if (mounted) {
      setState(() {
        _reordering = false;
        if (!ok) _order = null;
      });
    }
  }

  Future<void> _setAction(RoutineSet set, String action) async {
    final repo = ref.read(routineRepositoryProvider);
    if (action == 'duplicate') {
      await attempt(context, () => repo.duplicateSet(set.id));
    } else if (await confirm(context, title: 'Delete set?', message: 'Remove this set from the routine?') && mounted) {
      await attempt(context, () => repo.deleteSet(set.id));
    }
  }

  String _description(RoutineSet s, Units units, ExerciseType type) {
    final values = [
      if (type.hasWeight && s.rawWeight != null) units.weight(s.rawWeight!),
      if (type.hasReps && s.reps != null) '${s.reps} reps',
      if (type.hasDistance && s.distance != null) units.distance(s.distance!),
      if (type.hasTime && s.durationSeconds != null) Fmt.duration(s.durationSeconds!),
    ];
    return values.isEmpty ? 'Last values' : values.join(' × ');
  }

  Future<void> _addDay() async {
    final name = await prompt(context, title: 'Training day', label: 'Name', maxLength: 100);
    if (name != null && mounted) {
      await attempt(context, () async {
        final id = await ref.read(routineRepositoryProvider).addDay(widget.id, name);
        if (mounted) setState(() => _dayId = id);
      });
    }
  }

  Future<void> _addExercise() async {
    final dayId = _dayId;
    final id = await context.push<int>('/pick-exercise?return=1');
    if (id == null || !mounted || dayId == null) return;
    final count = await prompt(
      context,
      title: 'Number of sets',
      label: 'Sets',
      value: '3',
      maxLength: 2,
      keyboard: TextInputType.number,
      validate: (v) => (int.tryParse(v) ?? 0) >= 1 && (int.tryParse(v) ?? 100) <= 30 ? null : 'Choose 1–30 sets.',
    );
    if (count != null && mounted) {
      await attempt(context, () => ref.read(routineRepositoryProvider).addExercise(dayId, id, count: int.parse(count)));
    }
  }

  Future<void> _log(String date) async {
    setState(() => _logging = true);
    final ok = await attempt(context, () async {
      await ref.read(routineRepositoryProvider).logDay(_dayId!, date);
      ref.read(selectedDateProvider.notifier).set(date);
    });
    if (!mounted) return;
    if (ok) {
      context.go('/');
    } else {
      setState(() => _logging = false);
    }
  }

  Future<void> _dayAction(RoutineDay day, String action) async {
    if (action == 'rename') {
      final name = await prompt(context, title: 'Rename day', label: 'Name', value: day.name, maxLength: 100);
      if (name != null && mounted) await attempt(context, () => ref.read(routineRepositoryProvider).renameDay(day.id, name));
    } else if (await confirm(
          context,
          title: 'Delete this training day?',
          message: 'Remove its preset sets? Your logged workouts stay unchanged.',
        ) &&
        mounted) {
      await attempt(context, () => ref.read(routineRepositoryProvider).deleteDay(day.id));
    }
  }

  Future<void> _routineAction(Routine routine, String action) async {
    if (action == 'delete') {
      if (!await confirm(
            context,
            title: 'Delete routine?',
            message: 'Remove ${routine.name} and its training days? Logged workouts will remain.',
          ) ||
          !mounted) {
        return;
      }
      if (await attempt(context, () => ref.read(routineRepositoryProvider).delete(routine.id)) && mounted) context.pop();
    } else {
      final notes = action == 'notes';
      final value = await prompt(
        context,
        title: notes ? 'Routine notes' : 'Rename routine',
        label: notes ? 'Notes' : 'Name',
        value: notes ? routine.notes : routine.name,
        optional: notes,
        lines: notes ? 4 : 1,
        maxLength: notes ? 2000 : 100,
      );
      if (value != null && mounted) {
        await attempt(
          context,
          () =>
              ref.read(routineRepositoryProvider).update(routine.id, notes ? routine.name : value, notes ? value : routine.notes),
        );
      }
    }
  }
}

final _lastSetProvider = FutureProvider.autoDispose.family<WorkoutSet?, ExerciseDateKey>(
  (ref, key) => ref.watch(workoutRepositoryProvider).lastSet(key.exerciseId, key.date),
);

class _PresetDialog extends ConsumerStatefulWidget {
  const _PresetDialog({required this.set, required this.exercise, required this.siblings, required this.date});
  final RoutineSet set;
  final Exercise exercise;
  final List<RoutineSet> siblings;
  final String date;
  @override
  ConsumerState<_PresetDialog> createState() => _PresetDialogState();
}

class _PresetDialogState extends ConsumerState<_PresetDialog> {
  final _form = GlobalKey<FormState>();
  late final _weight = TextEditingController(
    text: widget.set.rawWeight == null
        ? ''
        : Fmt.number(ref.read(unitsProvider).withWeightUnit(widget.exercise.weightUnit).weightFromKg(widget.set.rawWeight!)),
  );
  late final _reps = TextEditingController(text: widget.set.reps?.toString() ?? '');
  late final _distance = TextEditingController(
    text: widget.set.distance == null
        ? ''
        : Fmt.number(
            ref.read(unitsProvider).withWeightUnit(widget.exercise.weightUnit).distanceFromMeters(widget.set.distance!),
            precision: 6,
          ),
  );
  late final _time = TextEditingController(
    text: widget.set.durationSeconds == null ? '' : Fmt.duration(widget.set.durationSeconds!),
  );
  bool _all = false, _saving = false;
  @override
  void dispose() {
    for (final c in [_weight, _reps, _distance, _time]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.exercise.type;
    final units = ref.watch(unitsProvider).withWeightUnit(widget.exercise.weightUnit);
    final lastSet = ref.watch(_lastSetProvider((exerciseId: widget.exercise.id, date: widget.date)));
    final previous = lastSet.asData?.value;
    final fields = <Widget>[
      if (type.hasWeight)
        _field(
          _weight,
          'Weight (${units.weightLabel})',
          hint: lastSet.hasValue ? Fmt.number(units.weightFromKg(previous?.rawWeight ?? 0)) : null,
          zero: true,
        ),
      if (type.hasReps) _field(_reps, 'Reps', hint: lastSet.hasValue ? '${previous?.reps ?? 10}' : null, integer: true),
      if (type.hasDistance)
        _field(
          _distance,
          'Distance (${units.distanceLabel})',
          hint: lastSet.hasValue ? Fmt.number(units.distanceFromMeters(previous?.distance ?? 1000), precision: 3) : null,
        ),
      if (type.hasTime)
        TextFormField(
          controller: _time,
          keyboardType: TextInputType.datetime,
          decoration: InputDecoration(
            labelText: 'Time (m:ss)',
            hintText: lastSet.hasValue ? Fmt.duration(previous?.durationSeconds ?? 60) : null,
          ),
          validator: (v) => v!.isEmpty || (Fmt.parseDuration(v) ?? 0) > 0 ? null : 'Enter a valid time.',
        ),
    ];
    return AppDialog(
      title: Text(widget.exercise.name),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (MediaQuery.sizeOf(context).width < 352 || MediaQuery.textScalerOf(context).scale(1) > 1.4)
              Column(
                children: [for (final field in fields) Padding(padding: const EdgeInsets.only(bottom: 8), child: field)],
              )
            else
              Row(
                children: [
                  for (var i = 0; i < fields.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: fields[i])],
                ],
              ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Blank fields use the shown values.', style: TextStyle(fontSize: 12)),
            ),
            if (widget.siblings.length > 1)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Apply to all ${widget.siblings.length} sets'),
                value: _all,
                onChanged: (v) => setState(() => _all = v!),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label, {String? hint, bool zero = false, bool integer = false}) =>
      TextFormField(
        controller: ctrl,
        keyboardType: TextInputType.numberWithOptions(decimal: !integer),
        decoration: InputDecoration(labelText: label, hintText: hint),
        validator: (v) {
          if (v!.isEmpty) return null;
          final n = integer ? int.tryParse(v)?.toDouble() : double.tryParse(v);
          return n != null && n.isFinite && (zero ? n >= 0 : n > 0) && n <= 10000 ? null : 'Enter a valid positive number.';
        },
      );
  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final units = ref.read(unitsProvider).withWeightUnit(widget.exercise.weightUnit);
    final weight = double.tryParse(_weight.text), distance = double.tryParse(_distance.text);
    final changes = RoutineSetsCompanion(
      rawWeight: Value(
        weight == null
            ? null
            : widget.set.rawWeight != null && _weight.text == Fmt.number(units.weightFromKg(widget.set.rawWeight!))
            ? widget.set.rawWeight
            : units.weightToKg(weight),
      ),
      reps: Value(int.tryParse(_reps.text)),
      distance: Value(
        distance == null
            ? null
            : widget.set.distance != null &&
                  _distance.text == Fmt.number(units.distanceFromMeters(widget.set.distance!), precision: 6)
            ? widget.set.distance
            : units.distanceToMeters(distance),
      ),
      durationSeconds: Value(_time.text.isEmpty ? null : Fmt.parseDuration(_time.text)),
    );
    final ok = await attempt(
      context,
      () => ref.read(databaseProvider).transaction(() async {
        for (final s in _all ? widget.siblings : [widget.set]) {
          await ref.read(routineRepositoryProvider).updateSet(s.id, changes);
        }
      }),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
    }
  }
}
