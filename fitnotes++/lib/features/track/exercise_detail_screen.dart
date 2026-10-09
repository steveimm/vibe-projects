import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/database/database.dart';
import '../../core/database/tables.dart';
import '../../core/models/set_values.dart';
import '../../core/providers.dart';
import '../../core/services/rest_timer.dart';
import '../../core/util/dates.dart';
import '../../core/util/format.dart';
import '../../shared/rest_timer_bar.dart';
import '../../shared/rest_timer_settings.dart';
import '../../shared/widgets.dart';
import 'graph_tab.dart';
import 'history_tab.dart';

class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId, required this.date, this.initialTab = 0});
  final int exerciseId;
  final int initialTab;
  final String date;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(exerciseProvider(exerciseId))
      .when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, _) => Scaffold(
          appBar: AppBar(),
          body: ErrorState(onRetry: () => ref.invalidate(exerciseProvider(exerciseId))),
        ),
        data: (exercise) => DefaultTabController(
          length: 3,
          initialIndex: initialTab,
          child: Scaffold(
            appBar: AppBar(
              title: Text(exercise.name, maxLines: 2, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              actions: [
                IconButton(
                  tooltip: 'Workout exercises',
                  icon: const Icon(Icons.format_list_bulleted_rounded),
                  onPressed: () => _switchExercise(context, ref, exercise),
                ),
                IconButton(
                  tooltip: 'Edit exercise',
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: () => context.push('/exercises/edit?id=$exerciseId'),
                ),
              ],
              bottom: TabBar(
                isScrollable: MediaQuery.textScalerOf(context).scale(1) > 1.4,
                tabAlignment: MediaQuery.textScalerOf(context).scale(1) > 1.4 ? TabAlignment.start : TabAlignment.fill,
                tabs: const [
                  Tab(text: 'Log'),
                  Tab(text: 'History'),
                  Tab(text: 'Progress'),
                ],
              ),
            ),
            body: ContentWidth(
              child: TabBarView(
                children: [
                  _TrackTab(exercise: exercise, date: date),
                  HistoryTab(exercise: exercise),
                  GraphTab(exercise: exercise),
                ],
              ),
            ),
            bottomNavigationBar: const SafeArea(top: false, child: RestTimerBar()),
          ),
        ),
      );

  Future<void> _switchExercise(BuildContext context, WidgetRef ref, Exercise exercise) async {
    await attempt(context, () async {
      final sets = await ref.read(workoutRepositoryProvider).dayLog(date);
      if (!context.mounted) return;
      final names = <int, String>{exercise.id: exercise.name};
      final counts = <int, int>{};
      for (final set in sets) {
        names[set.set.exerciseId] = set.exerciseName;
        counts.update(set.set.exerciseId, (n) => n + 1, ifAbsent: () => 1);
      }
      final selected = await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
            child: ListView(
              shrinkWrap: true,
              children: [
                const ListTile(
                  title: Text('Workout exercises', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                for (final entry in names.entries)
                  ListTile(
                    title: Text(entry.value),
                    subtitle: Text(Fmt.count(counts[entry.key] ?? 0, 'set')),
                    selected: entry.key == exerciseId,
                    trailing: entry.key == exerciseId ? const Icon(Icons.check_rounded) : null,
                    onTap: () => Navigator.pop(context, entry.key),
                  ),
                ListTile(
                  leading: const Icon(Icons.add_rounded),
                  title: const Text('Add exercise'),
                  onTap: () => Navigator.pop(context, -1),
                ),
              ],
            ),
          ),
        ),
      );
      if (!context.mounted || selected == null) return;
      if (selected == -1) {
        context.push('/pick-exercise?date=$date');
      } else if (selected != exerciseId) {
        context.push('/log/$selected?date=$date');
      }
    });
  }
}

class _TrackTab extends ConsumerStatefulWidget {
  const _TrackTab({required this.exercise, required this.date});
  final Exercise exercise;
  final String date;
  @override
  ConsumerState<_TrackTab> createState() => _TrackTabState();
}

class _TrackTabState extends ConsumerState<_TrackTab> with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  final _weight = TextEditingController(text: '0');
  final _reps = TextEditingController(text: '10');
  final _distance = TextEditingController(text: '1');
  final _time = TextEditingController(text: '1:00');
  final _rpe = TextEditingController();
  double? _loadedWeight, _loadedDistance;
  String? _loadedWeightText, _loadedDistanceText;
  WorkoutSet? _editing;
  WorkoutSet? _previous;
  bool _saving = false, _touched = false;
  String? _error;
  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final c in [_weight, _reps, _distance, _time, _rpe]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _prefill() async {
    await ref.read(settingsProvider.future);
    if (!mounted) return;
    final previous = await ref.read(workoutRepositoryProvider).lastSet(widget.exercise.id, widget.date);
    if (!mounted) return;
    setState(() {
      _previous = previous;
      if (!_touched && previous != null) _fill(previous);
    });
  }

  void _fill(WorkoutSet s) {
    final units = ref.read(unitsProvider);
    _weight.text = Fmt.number(units.weightFromKg(s.rawWeight));
    _reps.text = '${s.reps}';
    _distance.text = Fmt.number(units.distanceFromMeters(s.distance), precision: 3);
    _time.text = Fmt.duration(s.durationSeconds);
    _loadedWeight = s.rawWeight;
    _loadedDistance = s.distance;
    _loadedWeightText = _weight.text;
    _loadedDistanceText = _distance.text;
    _rpe.text = s.rpe == null ? '' : Fmt.number(s.rpe!);
    _error = null;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final units = ref.watch(unitsProvider);
    final settings = ref.watch(settingsProvider).asData?.value;
    final sets = ref.watch(exerciseSetsProvider((exerciseId: widget.exercise.id, date: widget.date)));
    final prs = ref.watch(prSetIdsProvider(widget.exercise.id));
    final factors = ref.watch(multipliersProvider(widget.exercise.id)).asData?.value ?? [];
    final multiplier = _editing?.weightMultiplier ?? factors.where((m) => m.enabled).fold<double>(1, (v, m) => v * m.factor);
    final type = widget.exercise.type;
    final fields = <Widget>[
      if (type.hasWeight)
        _StepField(
          label: 'Weight',
          unit: units.weightLabel,
          controller: _weight,
          step: units.weightFromKg(widget.exercise.weightIncrement ?? settings?.defaultWeightIncrement ?? 2.5),
          onStep: (delta) => _stepCanonical(delta, weight: true),
          onChanged: _changed,
        ),
      if (type.hasReps) _StepField(label: 'Reps', controller: _reps, step: 1, integer: true, onChanged: _changed),
      if (type.hasDistance)
        _StepField(
          label: 'Distance',
          unit: units.distanceLabel,
          controller: _distance,
          step: 0.1,
          onChanged: _changed,
          onStep: (delta) => _stepCanonical(delta, weight: false),
        ),
      if (type.hasTime) _StepField(label: 'Time', unit: 'm:ss', controller: _time, step: 15, duration: true, onChanged: _changed),
    ];
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Row(
          children: [
            Icon(Icons.event_outlined, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 7),
            Text(
              DateFormat('EEE, d MMM yyyy').format(Dates.parse(widget.date)),
              style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Calculators',
              onPressed: () => context.push('/tools'),
              icon: const Icon(Icons.calculate_outlined, size: 21),
            ),
          ],
        ),
        if (widget.exercise.archived)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ListTile(
                title: const Text('Archived exercise'),
                trailing: TextButton(
                  onPressed: () =>
                      attempt(context, () => ref.read(exerciseRepositoryProvider).setArchived(widget.exercise.id, false)),
                  child: const Text('Restore'),
                ),
              ),
            ),
          ),
        if (widget.exercise.notes?.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Exercise notes'),
              leading: const Icon(Icons.lightbulb_outline_rounded),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Align(alignment: Alignment.centerLeft, child: Text(widget.exercise.notes!)),
                ),
              ],
            ),
          ),
        if (_editing != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_outlined, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Editing a set', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                TextButton(onPressed: _cancelEdit, child: const Text('Cancel')),
              ],
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) =>
              fields.length == 1 || constraints.maxWidth < 320 || MediaQuery.textScalerOf(context).scale(1) > 1.4
              ? Column(
                  children: [for (final field in fields) Padding(padding: const EdgeInsets.only(bottom: 10), child: field)],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < fields.length; i++) ...[if (i > 0) const SizedBox(width: 12), Expanded(child: fields[i])],
                  ],
                ),
        ),
        if (type.hasWeight && multiplier != 1)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '× ${Fmt.number(multiplier)} multiplier · ${units.weight(units.weightToKg(double.tryParse(_weight.text) ?? 0) * multiplier)} effective',
              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(
              width: MediaQuery.textScalerOf(context).scale(1) > 1.4 ? 160 : 116,
              child: Semantics(
                container: true,
                child: TextField(
                  controller: _rpe,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'RPE', suffixText: '/10', hintText: 'Optional', isDense: true),
                  onChanged: (_) => _changed(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                container: true,
                child: Text(
                  'Effort from 1 to 10',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _saving || settings == null || widget.exercise.archived ? null : () => _save(multiplier),
                icon: Icon(_editing == null ? Icons.add_rounded : Icons.check_rounded),
                label: Text(
                  _saving
                      ? 'Saving…'
                      : _editing == null
                      ? 'Log set'
                      : 'Update set',
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(onPressed: _saving ? null : _reset, child: const Text('Reset')),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: () => showRestTimerSettings(context, ref, exercise: widget.exercise),
                icon: const Icon(Icons.timer_outlined, size: 19),
                label: Text(
                  'Rest timer · ${Fmt.duration(widget.exercise.defaultRestTimeSeconds ?? settings?.restTimerSeconds ?? 60)}',
                ),
              ),
            ),
            if (_previous != null)
              TextButton(
                onPressed: () => setState(() {
                  _fill(_previous!);
                  _editing = null;
                  _touched = true;
                }),
                child: const Text('Last values'),
              ),
          ],
        ),
        if (_previous != null && _previous!.date != widget.date)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Last time · ${DateFormat('d MMM').format(Dates.parse(_previous!.date))} · ${describeSet(type: type, effectiveWeight: _previous!.rawWeight * _previous!.weightMultiplier, reps: _previous!.reps, distance: _previous!.distance, durationSeconds: _previous!.durationSeconds, units: units)}',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        SectionTitle(
          'This session',
          trailing: Text(
            '${sets.asData?.value.length ?? 0} ${(sets.asData?.value.length ?? 0) == 1 ? 'set' : 'sets'}',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        sets.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => ErrorState(
            onRetry: () => ref.invalidate(exerciseSetsProvider((exerciseId: widget.exercise.id, date: widget.date))),
          ),
          data: (items) => items.isEmpty
              ? const EmptyState(icon: Icons.playlist_add_check_rounded, title: 'No sets')
              : Column(
                  children: [
                    for (var i = 0; i < items.length; i++) _setCard(items[i], i, prs, units, settings?.markSetsComplete ?? false),
                  ],
                ),
        ),
      ],
    );
  }

  void _stepCanonical(double delta, {required bool weight}) {
    final units = ref.read(unitsProvider);
    final controller = weight ? _weight : _distance;
    final originalText = weight ? _loadedWeightText : _loadedDistanceText;
    final original = weight ? _loadedWeight : _loadedDistance;
    final typed = double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;
    final raw = controller.text == originalText && original != null
        ? original
        : weight
        ? units.weightToKg(typed)
        : units.distanceToMeters(typed);
    final changed = ((raw.isFinite ? raw : 0) + (weight ? units.weightToKg(delta) : units.distanceToMeters(delta))).clamp(
      0.0,
      weight ? 10000.0 : 10000000.0,
    );
    controller.text = Fmt.number(
      weight ? units.weightFromKg(changed) : units.distanceFromMeters(changed),
      precision: weight ? 2 : 3,
    );
    if (weight) {
      _loadedWeight = changed;
      _loadedWeightText = controller.text;
    } else {
      _loadedDistance = changed;
      _loadedDistanceText = controller.text;
    }
    _changed();
  }

  void _changed() => setState(() {
    _touched = true;
    _error = null;
  });
  void _reset() => setState(() {
    _editing = null;
    _weight.text = '0';
    _reps.text = '0';
    _distance.text = '0';
    _time.text = '0:00';
    _rpe.clear();
    _error = null;
    _touched = true;
  });
  void _cancelEdit() => setState(() {
    _editing = null;
    _error = null;
    if (_previous != null) _fill(_previous!);
  });

  void _startRest() {
    final settings = ref.read(settingsProvider).asData?.value;
    ref
        .read(restTimerProvider.notifier)
        .start(
          widget.exercise.defaultRestTimeSeconds ?? settings?.restTimerSeconds ?? 60,
          label: widget.exercise.name,
          sound: settings?.restTimerSound ?? true,
          vibrate: settings?.restTimerVibrate ?? false,
        );
  }

  Future<void> _save(double multiplier) async {
    final type = widget.exercise.type;
    final units = ref.read(unitsProvider);
    final weight = type.hasWeight ? double.tryParse(_weight.text.replaceAll(',', '.')) : 0.0;
    final reps = type.hasReps ? int.tryParse(_reps.text) : 0;
    final distance = type.hasDistance ? double.tryParse(_distance.text.replaceAll(',', '.')) : 0.0;
    final time = type.hasTime ? Fmt.parseDuration(_time.text) : 0;
    final rpe = _rpe.text.trim().isEmpty ? null : double.tryParse(_rpe.text);
    if (weight == null || reps == null || distance == null || time == null || (_rpe.text.isNotEmpty && rpe == null)) {
      setState(() => _error = 'Check the numbers above. Use m:ss or h:mm:ss for time.');
      return;
    }
    final values = SetValues(
      weight: _weight.text == _loadedWeightText && _loadedWeight != null ? _loadedWeight! : units.weightToKg(weight),
      reps: reps,
      distance: _distance.text == _loadedDistanceText && _loadedDistance != null
          ? _loadedDistance!
          : units.distanceToMeters(distance),
      seconds: time,
      rpe: rpe,
    );
    try {
      values.validate(type);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    final editing = _editing;
    final repo = ref.read(workoutRepositoryProvider);
    final ok = await attempt(context, () async {
      if (editing != null) {
        await repo.updateSet(
          editing.id,
          rawWeight: values.weight,
          reps: values.reps,
          distance: values.distance,
          durationSeconds: values.seconds,
          rpe: Value(rpe),
        );
      } else {
        final id = await repo.addSet(
          exerciseId: widget.exercise.id,
          date: widget.date,
          rawWeight: values.weight,
          weightMultiplier: multiplier,
          reps: values.reps,
          distance: values.distance,
          durationSeconds: values.seconds,
          rpe: rpe,
        );
        if (mounted) {
          notice(
            context,
            'Set logged',
            action: SnackBarAction(label: 'Undo', onPressed: () => attempt(context, () => repo.deleteSet(id))),
          );
        }
      }
    });
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) {
        _editing = null;
        _touched = false;
      }
    });
    if (ok) {
      if (editing != null) notice(context, 'Set updated');
      HapticFeedback.lightImpact();
      if (editing == null && (ref.read(settingsProvider).asData?.value.restTimerAutoStart ?? false)) _startRest();
      _previous = await repo.lastSet(widget.exercise.id, widget.date);
    }
  }

  Widget _setCard(WorkoutSet s, int index, Set<int> prs, Units units, bool markComplete) {
    final colors = Theme.of(context).colorScheme;
    final type = widget.exercise.type;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: _editing?.id == s.id ? colors.primaryContainer : colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _editing?.id == s.id ? colors.primary : colors.outlineVariant),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(12, 5, 4, 5),
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: colors.surfaceContainerHighest,
            child: Text(
              '${index + 1}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.onSurface),
            ),
          ),
          title: Text(
            describeSet(
              type: type,
              effectiveWeight: s.rawWeight * s.weightMultiplier,
              reps: s.reps,
              distance: s.distance,
              durationSeconds: s.durationSeconds,
              units: units,
            ),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (s.isPlanned || prs.contains(s.id) || s.rpe != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    [
                      if (s.isPlanned) 'Not completed',
                      if (prs.contains(s.id)) 'Personal record',
                      if (s.rpe != null) 'RPE ${Fmt.number(s.rpe!)}',
                    ].join(' · '),
                    style: TextStyle(fontSize: 11, color: colors.primary),
                  ),
                ),
              if (s.note?.isNotEmpty == true) Text(s.note!),
              if (s.groupName?.isNotEmpty == true)
                Text('Superset · ${s.groupName}', style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
            ],
          ),
          onTap: () => _editing?.id == s.id ? _cancelEdit() : _selectSet(s, editing: true),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (markComplete || s.isPlanned) Checkbox(value: !s.isPlanned, onChanged: (value) => _completion(s, value!)),
              AppMenuButton<String>(
                tooltip: 'Set options',
                onSelected: (action) => _setAction(s, action),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'completion', child: Text(s.isPlanned ? 'Mark complete' : 'Mark incomplete')),
                  const PopupMenuItem(value: 'edit', child: Text('Edit set')),
                  const PopupMenuItem(value: 'values', child: Text('Use values for next set')),
                  const PopupMenuItem(value: 'note', child: Text('Set note')),
                  const PopupMenuItem(value: 'group', child: Text('Superset name')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete set')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _completion(WorkoutSet set, bool complete) async {
    final repo = ref.read(workoutRepositoryProvider);
    if (!await attempt(context, () => repo.setComplete(set.id, complete)) || !mounted) return;
    notice(
      context,
      complete ? 'Set completed' : 'Set marked incomplete',
      action: SnackBarAction(label: 'Undo', onPressed: () => attempt(context, () => repo.setComplete(set.id, !complete))),
    );
    if (complete && (ref.read(settingsProvider).asData?.value.restTimerAutoStart ?? false)) _startRest();
  }

  void _selectSet(WorkoutSet set, {required bool editing}) {
    setState(() {
      _editing = editing ? set : null;
      _fill(set);
      _touched = true;
    });
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _setAction(WorkoutSet s, String action) async {
    final repo = ref.read(workoutRepositoryProvider);
    switch (action) {
      case 'completion':
        await _completion(s, s.isPlanned);
      case 'edit':
        _selectSet(s, editing: true);
      case 'values':
        _selectSet(s, editing: false);
      case 'note':
        final note = await prompt(
          context,
          title: 'Set note',
          label: 'Technique, effort, or adjustments',
          value: s.note ?? '',
          optional: true,
          lines: 3,
          maxLength: 1000,
        );
        if (note != null && mounted) await attempt(context, () => repo.setNote(s.id, note.isEmpty ? null : note));
      case 'group':
        final group = await prompt(
          context,
          title: 'Superset',
          label: 'Use the same name for grouped exercises',
          value: s.groupName ?? '',
          optional: true,
          maxLength: 40,
        );
        if (group != null && mounted) {
          await attempt(context, () => repo.setGroup(widget.exercise.id, widget.date, group.isEmpty ? null : group));
        }
      case 'delete':
        await attempt(context, () async {
          await repo.deleteSet(s.id);
          if (!mounted) return;
          if (_editing?.id == s.id) setState(() => _editing = null);
          notice(
            context,
            'Set deleted',
            action: SnackBarAction(label: 'Undo', onPressed: () => attempt(context, () => repo.restoreSets([s]))),
          );
        });
    }
  }
}

class _StepField extends StatelessWidget {
  const _StepField({
    required this.label,
    required this.controller,
    required this.step,
    required this.onChanged,
    this.onStep,
    this.unit = '',
    this.integer = false,
    this.duration = false,
  });
  final String label, unit;
  final TextEditingController controller;
  final double step;
  final bool integer, duration;
  final VoidCallback onChanged;
  final ValueChanged<double>? onStep;
  void _bump(double delta) {
    if (onStep != null) {
      onStep!(delta);
      HapticFeedback.selectionClick();
      return;
    }
    final value = duration
        ? Fmt.parseDuration(controller.text)?.toDouble()
        : double.tryParse(controller.text.replaceAll(',', '.'));
    final next = ((value?.isFinite == true ? value! : 0) + delta).clamp(0.0, duration ? 604800.0 : 10000.0);
    controller.text = duration
        ? Fmt.duration(next.round())
        : integer
        ? next.round().toString()
        : Fmt.number(next);
    onChanged();
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
      child: Column(
        children: [
          Text(
            '$label${unit.isEmpty ? '' : ' · $unit'}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton(
                tooltip: 'Decrease $label',
                onPressed: () => _bump(-step),
                icon: const Icon(Icons.remove_rounded, size: 19),
              ),
              Expanded(
                child: Semantics(
                  label: '$label $unit',
                  container: true,
                  child: TextField(
                    controller: controller,
                    textAlign: TextAlign.center,
                    keyboardType: duration ? TextInputType.datetime : TextInputType.numberWithOptions(decimal: !integer),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(
                          duration
                              ? '[0-9:-]'
                              : integer
                              ? '[0-9-]'
                              : '[0-9.,-]',
                        ),
                      ),
                    ],
                    style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      hintText: '0',
                    ),
                    onChanged: (_) => onChanged(),
                    onTap: () => controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length),
                  ),
                ),
              ),
              IconButton(tooltip: 'Increase $label', onPressed: () => _bump(step), icon: const Icon(Icons.add_rounded, size: 19)),
            ],
          ),
        ],
      ),
    ),
  );
}
