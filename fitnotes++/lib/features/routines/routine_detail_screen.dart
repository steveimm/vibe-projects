import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  bool _logging = false;
  @override
  Widget build(BuildContext context) {
    final routine = ref.watch(routinesProvider).asData?.value.where((r) => r.id == widget.id).firstOrNull;
    final days = ref.watch(routineDaysProvider(widget.id));
    final exercises = {for (final e in ref.watch(allExercisesProvider).asData?.value ?? <Exercise>[]) e.id: e};
    final date = widget.date ?? ref.watch(selectedDateProvider) ?? Dates.today();
    return Scaffold(
      appBar: AppBar(
        title: Text(routine?.name ?? 'Routine'),
        actions: [
          if (routine != null)
            PopupMenuButton<String>(
              onSelected: (action) => _routineAction(routine, action),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename routine')),
                PopupMenuItem(value: 'notes', child: Text('Routine notes')),
                PopupMenuItem(value: 'delete', child: Text('Delete routine')),
              ],
            ),
        ],
      ),
      body: ContentWidth(
        child: days.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => ErrorState(onRetry: () => ref.invalidate(routineDaysProvider(widget.id))),
          data: (days) {
            if (!days.any((d) => d.id == _dayId)) _dayId = days.firstOrNull?.id;
            final sets = _dayId == null ? null : ref.watch(routineSetsProvider(_dayId!));
            final items = sets?.asData?.value ?? <RoutineSet>[];
            return Column(
              children: [
                if (routine?.notes.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Align(alignment: Alignment.centerLeft, child: Text(routine!.notes)),
                  ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      for (final day in days)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(day.name),
                            selected: day.id == _dayId,
                            onSelected: (_) => setState(() => _dayId = day.id),
                          ),
                        ),
                      ActionChip(avatar: const Icon(Icons.add_rounded, size: 18), label: const Text('Day'), onPressed: _addDay),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SectionTitle(
                    '${items.length} planned sets',
                    trailing: _dayId == null
                        ? null
                        : PopupMenuButton<String>(
                            tooltip: 'Day options',
                            onSelected: (value) => _dayAction(days.firstWhere((d) => d.id == _dayId), value),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'rename', child: Text('Rename day')),
                              PopupMenuItem(value: 'delete', child: Text('Delete day')),
                            ],
                          ),
                  ),
                ),
                Expanded(
                  child: sets?.isLoading == true
                      ? const Center(child: CircularProgressIndicator())
                      : sets?.hasError == true
                      ? ErrorState(onRetry: () => ref.invalidate(routineSetsProvider(_dayId!)))
                      : items.isEmpty
                      ? SingleChildScrollView(
                          child: EmptyState(
                            icon: Icons.playlist_add_rounded,
                            title: 'Build this training day',
                            message: 'Add exercises, set your targets, and drag the handles to arrange the order.',
                            action: FilledButton.icon(
                              onPressed: _dayId == null ? _addDay : _addExercise,
                              icon: const Icon(Icons.add_rounded),
                              label: Text(_dayId == null ? 'Add training day' : 'Add exercise'),
                            ),
                          ),
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          buildDefaultDragHandles: false,
                          itemCount: items.length,
                          onReorderItem: (oldIndex, newIndex) async {
                            final ids = items.map((s) => s.id).toList();
                            ids.insert(newIndex, ids.removeAt(oldIndex));
                            await attempt(context, () => ref.read(routineRepositoryProvider).reorder(ids));
                          },
                          itemBuilder: (_, i) {
                            final s = items[i];
                            final ex = exercises[s.exerciseId];
                            return Padding(
                              key: ValueKey(s.id),
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Card(
                                child: ListTile(
                                  leading: ReorderableDragStartListener(
                                    index: i,
                                    child: const SizedBox(width: 32, height: 48, child: Icon(Icons.drag_indicator_rounded)),
                                  ),
                                  title: Text(ex?.name ?? 'Exercise'),
                                  subtitle: Text(_description(s, ref.watch(unitsProvider))),
                                  onTap: ex == null
                                      ? null
                                      : () => showDialog(
                                          context: context,
                                          builder: (_) => _PresetDialog(
                                            set: s,
                                            exercise: ex,
                                            siblings: items.where((v) => v.exerciseId == s.exerciseId).toList(),
                                          ),
                                        ),
                                  trailing: IconButton(
                                    tooltip: 'Remove set',
                                    icon: const Icon(Icons.remove_circle_outline_rounded),
                                    onPressed: () => attempt(context, () => ref.read(routineRepositoryProvider).deleteSet(s.id)),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _dayId == null ? null : _addExercise,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Exercise'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: items.isEmpty || _logging ? null : () => _log(date),
                          child: Text(
                            _logging
                                ? 'Adding…'
                                : date == Dates.today()
                                ? 'Log to today'
                                : 'Log to ${date.substring(5)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SafeArea(top: false, child: SizedBox(height: 4)),
              ],
            );
          },
        ),
      ),
    );
  }

  String _description(RoutineSet s, Units units) {
    final values = [
      if (s.rawWeight != null) units.weight(s.rawWeight!),
      if (s.reps != null) '${s.reps} reps',
      if (s.distance != null) units.distance(s.distance!),
      if (s.durationSeconds != null) Fmt.duration(s.durationSeconds!),
    ];
    return '${values.isEmpty ? 'Reuse previous values' : values.join(' × ')}${s.groupName == null ? '' : '\nSuperset · ${s.groupName}'}';
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
    final id = await context.push<int>('/pick-exercise?return=1');
    if (id == null || !mounted || _dayId == null) return;
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
      await attempt(context, () => ref.read(routineRepositoryProvider).addExercise(_dayId!, id, count: int.parse(count)));
    }
  }

  Future<void> _log(String date) async {
    setState(() => _logging = true);
    final ok = await attempt(context, () async {
      final count = await ref.read(routineRepositoryProvider).logDay(_dayId!, date);
      ref.read(selectedDateProvider.notifier).set(date);
      if (mounted) notice(context, '$count planned sets added. Mark them complete as you train.');
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

class _PresetDialog extends ConsumerStatefulWidget {
  const _PresetDialog({required this.set, required this.exercise, required this.siblings});
  final RoutineSet set;
  final Exercise exercise;
  final List<RoutineSet> siblings;
  @override
  ConsumerState<_PresetDialog> createState() => _PresetDialogState();
}

class _PresetDialogState extends ConsumerState<_PresetDialog> {
  final _form = GlobalKey<FormState>();
  late final _weight = TextEditingController(
    text: widget.set.rawWeight == null ? '' : Fmt.number(ref.read(unitsProvider).weightFromKg(widget.set.rawWeight!)),
  );
  late final _reps = TextEditingController(text: widget.set.reps?.toString() ?? '');
  late final _distance = TextEditingController(
    text: widget.set.distance == null
        ? ''
        : Fmt.number(ref.read(unitsProvider).distanceFromMeters(widget.set.distance!), precision: 6),
  );
  late final _time = TextEditingController(
    text: widget.set.durationSeconds == null ? '' : Fmt.duration(widget.set.durationSeconds!),
  );
  late final _group = TextEditingController(text: widget.set.groupName ?? '');
  bool _all = false, _saving = false;
  @override
  void dispose() {
    for (final c in [_weight, _reps, _distance, _time, _group]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.exercise.type;
    final units = ref.watch(unitsProvider);
    return AlertDialog(
      title: Text(widget.exercise.name),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Blank values reuse your last session. With no history, defaults are 0 weight, 10 reps, 1 km, and 1 minute.',
              ),
              const SizedBox(height: 16),
              if (type.hasWeight) _field(_weight, 'Weight (${units.weightLabel})', zero: true),
              if (type.hasReps) _field(_reps, 'Reps', integer: true),
              if (type.hasDistance) _field(_distance, 'Distance (${units.distanceLabel})'),
              if (type.hasTime)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _time,
                    decoration: const InputDecoration(labelText: 'Time (h:mm:ss)'),
                    validator: (v) => v!.isEmpty || (Fmt.parseDuration(v) ?? 0) > 0 ? null : 'Enter a valid time.',
                  ),
                ),
              TextFormField(
                controller: _group,
                maxLength: 40,
                decoration: const InputDecoration(labelText: 'Superset name (optional)'),
              ),
              if (widget.siblings.length > 1)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Apply to every set of this exercise'),
                  value: _all,
                  onChanged: (v) => setState(() => _all = v!),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label, {bool zero = false, bool integer = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: ctrl,
      keyboardType: TextInputType.numberWithOptions(decimal: !integer),
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        if (v!.isEmpty) return null;
        final n = integer ? int.tryParse(v)?.toDouble() : double.tryParse(v);
        return n != null && n.isFinite && (zero ? n >= 0 : n > 0) && n <= 10000 ? null : 'Enter a valid positive number.';
      },
    ),
  );
  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final units = ref.read(unitsProvider);
    final weight = double.tryParse(_weight.text), distance = double.tryParse(_distance.text);
    final changes = RoutineSetsCompanion(
      rawWeight: Value(weight == null ? null : units.weightToKg(weight)),
      reps: Value(int.tryParse(_reps.text)),
      distance: Value(distance == null ? null : units.distanceToMeters(distance)),
      durationSeconds: Value(_time.text.isEmpty ? null : Fmt.parseDuration(_time.text)),
      groupName: Value(_group.text.trim().isEmpty ? null : _group.text.trim()),
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
