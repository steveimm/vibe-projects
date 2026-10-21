import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/database/database.dart';
import '../../core/database/tables.dart';
import '../../core/models/set_values.dart';
import '../../core/providers.dart';
import '../../core/repositories/stats_repository.dart';
import '../../core/services/rest_timer.dart';
import '../../core/util/dates.dart';
import '../../core/util/format.dart';
import '../../shared/rest_timer_bar.dart';
import '../../shared/rest_timer_settings.dart';
import '../../shared/set_number.dart';
import '../../shared/widgets.dart';
import '../../shared/record_badge.dart';
import 'graph_tab.dart';
import 'history_tab.dart';

class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({
    super.key,
    required this.exerciseId,
    required this.date,
    this.initialTab = 0,
    this.returnToWorkout = false,
  });
  final int exerciseId;
  final int initialTab;
  final String date;
  final bool returnToWorkout;
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
              title: Text(exercise.name, maxLines: 2, overflow: TextOverflow.ellipsis),
              actions: [
                IconButton(
                  tooltip: 'Workout exercises',
                  icon: const Icon(Icons.format_list_bulleted_rounded),
                  onPressed: () => _switchExercise(context, ref, exercise),
                ),
                IconButton(
                  tooltip: 'Edit exercise',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    dismissKeyboard();
                    context.push('/exercises/edit?id=$exerciseId');
                  },
                ),
                if (exercise.notes?.isNotEmpty == true)
                  IconButton(
                    tooltip: 'Exercise notes',
                    icon: const Icon(Icons.notes_rounded),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => AppDialog(
                        title: const Text('Exercise notes'),
                        content: Text(exercise.notes!),
                        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
                      ),
                    ),
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
            body: TabBarView(
              children: [
                _TrackTab(exercise: exercise, date: date, returnToWorkout: returnToWorkout),
                ContentWidth(child: HistoryTab(exercise: exercise)),
                GraphTab(exercise: exercise),
              ],
            ),
            bottomNavigationBar: const SafeArea(top: false, child: RestTimerBar()),
          ),
        ),
      );

  Future<void> _switchExercise(BuildContext context, WidgetRef ref, Exercise exercise) async {
    await attempt(context, () async {
      final sets = await ref.read(workoutRepositoryProvider).dayLog(date);
      if (!context.mounted) return;
      final names = <int, String>{};
      final counts = <int, int>{};
      for (final set in sets) {
        names[set.set.exerciseId] = set.exerciseName;
        counts.update(set.set.exerciseId, (n) => n + 1, ifAbsent: () => 1);
      }
      names.putIfAbsent(exercise.id, () => exercise.name);
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
              ],
            ),
          ),
        ),
      );
      if (!context.mounted || selected == null) return;
      if (selected != exerciseId) {
        context.push('/log/$selected?date=$date${returnToWorkout ? '&returnToWorkout=1' : ''}');
      }
    });
  }
}

class _TrackTab extends ConsumerStatefulWidget {
  const _TrackTab({required this.exercise, required this.date, required this.returnToWorkout});
  final Exercise exercise;
  final String date;
  final bool returnToWorkout;
  @override
  ConsumerState<_TrackTab> createState() => _TrackTabState();
}

class _TrackTabState extends ConsumerState<_TrackTab> with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  final _weight = TextEditingController(text: '0');
  final _reps = TextEditingController(text: '10');
  final _distance = TextEditingController(text: '1');
  final _time = TextEditingController(text: '1:00');
  double? _loadedWeight, _loadedDistance;
  String? _loadedWeightText, _loadedDistanceText;
  WorkoutSet? _editing;
  WorkoutSet? _previous;
  bool _saving = false, _touched = false, _savedSet = false;
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
    for (final c in [_weight, _reps, _distance, _time]) {
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
    final units = ref.read(unitsProvider).withWeightUnit(widget.exercise.weightUnit);
    _weight.text = Fmt.number(units.weightFromKg(s.rawWeight));
    _reps.text = '${s.reps}';
    _distance.text = Fmt.number(units.distanceFromMeters(s.distance), precision: 3);
    _time.text = Fmt.duration(s.durationSeconds);
    _loadedWeight = s.rawWeight;
    _loadedDistance = s.distance;
    _loadedWeightText = _weight.text;
    _loadedDistanceText = _distance.text;
    _error = null;
  }

  @override
  void didUpdateWidget(covariant _TrackTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercise.weightUnit == widget.exercise.weightUnit) return;
    final systemUnits = ref.read(unitsProvider);
    final typed = double.tryParse(_weight.text.replaceAll(',', '.'));
    if (typed == null || !typed.isFinite) return;
    final kg = _weight.text == _loadedWeightText && _loadedWeight != null
        ? _loadedWeight!
        : systemUnits.withWeightUnit(oldWidget.exercise.weightUnit).weightToKg(typed);
    _weight.text = Fmt.number(systemUnits.withWeightUnit(widget.exercise.weightUnit).weightFromKg(kg));
    _loadedWeight = kg;
    _loadedWeightText = _weight.text;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final systemUnits = ref.watch(unitsProvider);
    final units = systemUnits.withWeightUnit(widget.exercise.weightUnit);
    final settings = ref.watch(settingsProvider).asData?.value;
    final sets = ref.watch(exerciseSetsProvider((exerciseId: widget.exercise.id, date: widget.date)));
    final prs = ref.watch(recordBadgesProvider(widget.exercise.id));
    final factorData = ref.watch(multipliersProvider(widget.exercise.id));
    final factors = factorData.asData?.value ?? [];
    final activeFactors = factors.where((m) => m.enabled).toList();
    final currentMultiplier = activeFactors.fold<double>(1, (v, m) => v * m.factor);
    final multiplier = _editing?.weightMultiplier ?? currentMultiplier;
    final savedMultiplier = _editing != null && multiplier != currentMultiplier;
    final bodyweightData = widget.exercise.includeBodyweight && _editing == null
        ? ref.watch(bodyweightProvider(widget.date))
        : null;
    final missingBodyweight = widget.exercise.includeBodyweight && _editing == null && bodyweightData?.asData?.value == null;
    final bodyweight =
        _editing?.bodyweight ?? (widget.exercise.includeBodyweight ? bodyweightData?.asData?.value?.value ?? 0.0 : 0.0);
    final typedWeight = double.tryParse(_weight.text.replaceAll(',', '.'));
    final effectiveWeight = typedWeight == null || !typedWeight.isFinite || missingBodyweight
        ? null
        : _weightInKg(units, typedWeight) * multiplier + bodyweight;
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
    final editor = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.exercise.archived)
          Row(
            children: [
              const Expanded(child: Text('Archived exercise')),
              IconButton(
                tooltip: 'Restore exercise',
                icon: const Icon(Icons.unarchive_outlined),
                onPressed: () =>
                    attempt(context, () => ref.read(exerciseRepositoryProvider).setArchived(widget.exercise.id, false)),
              ),
            ],
          ),
        LayoutBuilder(
          builder: (context, constraints) =>
              fields.length == 1 || constraints.maxWidth < 280 || MediaQuery.textScalerOf(context).scale(1) > 1.4
              ? Column(
                  children: [for (final field in fields) Padding(padding: const EdgeInsets.only(bottom: 4), child: field)],
                )
              : Row(
                  children: [
                    for (var i = 0; i < fields.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: fields[i])],
                  ],
                ),
        ),
        if (type.hasWeight &&
            effectiveWeight != null &&
            (units.weightImperial || activeFactors.isNotEmpty || savedMultiplier || bodyweight > 0))
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                [
                  if (units.weightImperial) '× 0.45 (lb to kg)',
                  if (savedMultiplier)
                    '× ${Fmt.number(multiplier, precision: 6)} (Saved multiplier)'
                  else
                    for (final factor in activeFactors) '× ${Fmt.number(factor.factor, precision: 6)} (${factor.label})',
                  if (bodyweight > 0) '+ ${Fmt.weight(bodyweight)} (Bodyweight)',
                  '= ${Fmt.weight(effectiveWeight)}',
                ].join(' '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        if (missingBodyweight && bodyweightData?.hasValue == true)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Record bodyweight on or before ${widget.date} in Progress.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
    final restControl = Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        container: true,
        child: Tooltip(
          message: 'Rest timer',
          child: TextButton.icon(
            onPressed: () => showRestTimerSettings(context, ref, exercise: widget.exercise),
            icon: const Icon(Icons.timer_outlined, size: 20),
            label: Text(Fmt.duration(widget.exercise.defaultRestTimeSeconds ?? settings?.restTimerSeconds ?? 60)),
          ),
        ),
      ),
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_editing != null) ...[
          IconButton.filledTonal(
            tooltip: 'Delete set',
            onPressed: _saving ? null : () => _setAction(_editing!, 'delete'),
            style: IconButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
            ),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          const SizedBox(width: 8),
        ],
        AppFloatingActionButton(
          tooltip: _editing == null ? 'Log set' : 'Update set',
          onPressed: _saving || settings == null || !factorData.hasValue || missingBodyweight || widget.exercise.archived
              ? null
              : _save,
          icon: _editing == null ? Icons.add_rounded : Icons.check_rounded,
        ),
      ],
    );
    Widget rows({bool shrinkWrap = false}) => sets.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          ErrorState(onRetry: () => ref.invalidate(exerciseSetsProvider((exerciseId: widget.exercise.id, date: widget.date)))),
      data: (items) => ListView.separated(
        controller: shrinkWrap ? null : _scroll,
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 4),
        itemBuilder: (_, i) => _setCard(items[i], i, prs, systemUnits, settings?.markSetsComplete ?? false),
      ),
    );
    final tabs = DefaultTabController.of(context);
    return ListenableBuilder(
      listenable: tabs,
      builder: (_, child) => PopScope(
        canPop: !_saving && !(widget.returnToWorkout && _savedSet) && (_editing == null || tabs.index != 0),
        onPopInvokedWithResult: (didPop, _) {
          if (didPop || _saving) return;
          if (_editing != null && tabs.index == 0) {
            _cancelEdit();
          } else if (widget.returnToWorkout && _savedSet) {
            context.go('/');
          }
        },
        child: child!,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: actions,
        body: ContentWidth(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxHeight < 160) {
                  return SingleChildScrollView(
                    key: const ValueKey('compact-log-scroll'),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [editor, restControl, rows(shrinkWrap: true)]),
                  );
                }
                return Column(
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: constraints.maxHeight - 104),
                      child: SingleChildScrollView(child: editor),
                    ),
                    restControl,
                    Expanded(child: rows()),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _stepCanonical(double delta, {required bool weight}) {
    final units = ref.read(unitsProvider).withWeightUnit(widget.exercise.weightUnit);
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
  void _cancelEdit() {
    FocusScope.of(context).unfocus();
    setState(() {
      _editing = null;
      _error = null;
      if (_previous != null) _fill(_previous!);
    });
  }

  void _startRest() {
    final settings = ref.read(settingsProvider).asData?.value;
    ref
        .read(restTimerProvider.notifier)
        .start(
          widget.exercise.defaultRestTimeSeconds ?? settings?.restTimerSeconds ?? 60,
          label: widget.exercise.name,
          sound: settings?.restTimerSound ?? true,
          soundUri: settings?.restTimerSoundUri,
          vibrate: settings?.restTimerVibrate ?? false,
        );
  }

  double _weightInKg(Units units, double value) =>
      _weight.text == _loadedWeightText && _loadedWeight != null ? _loadedWeight! : units.weightToKg(value);

  Future<void> _save() async {
    final type = widget.exercise.type;
    final units = ref.read(unitsProvider).withWeightUnit(widget.exercise.weightUnit);
    final weight = type.hasWeight ? double.tryParse(_weight.text.replaceAll(',', '.')) : 0.0;
    final reps = type.hasReps ? int.tryParse(_reps.text) : 0;
    final distance = type.hasDistance ? double.tryParse(_distance.text.replaceAll(',', '.')) : 0.0;
    final time = type.hasTime ? Fmt.parseDuration(_time.text) : 0;
    if (weight == null || reps == null || distance == null || time == null) {
      setState(() => _error = 'Check the numbers above. Use m:ss or h:mm:ss for time.');
      return;
    }
    final values = SetValues(
      weight: _weightInKg(units, weight),
      reps: reps,
      distance: _distance.text == _loadedDistanceText && _loadedDistance != null
          ? _loadedDistance!
          : units.distanceToMeters(distance),
      seconds: time,
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
        );
      } else {
        await repo.addSet(
          exerciseId: widget.exercise.id,
          date: widget.date,
          rawWeight: values.weight,
          reps: values.reps,
          distance: values.distance,
          durationSeconds: values.seconds,
        );
      }
    });
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) {
        _savedSet = true;
        _editing = null;
        _touched = false;
      }
    });
    if (ok) {
      HapticFeedback.lightImpact();
      if (editing == null &&
          widget.date == Dates.today() &&
          (ref.read(settingsProvider).asData?.value.restTimerAutoStart ?? false)) {
        _startRest();
      }
      final previous = await repo.lastSet(widget.exercise.id, widget.date);
      if (mounted) setState(() => _previous = previous);
    }
  }

  Widget _setCard(WorkoutSet s, int index, Map<int, RecordAchievement> prs, Units units, bool markComplete) {
    final colors = Theme.of(context).colorScheme;
    final selected = _editing?.id == s.id;
    return Card(
      key: ValueKey('logged-set-${s.id}'),
      color: selected ? AppTheme.selectionColor(colors) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? colors.primary : colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _saving ? null : () => _selectSet(s),
        child: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Row(
            children: [
              SetNumber(number: index + 1, loggedAt: s.loggedAt),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      describeSet(
                        type: widget.exercise.type,
                        effectiveWeight: s.effectiveWeight,
                        reps: s.reps,
                        distance: s.distance,
                        durationSeconds: s.durationSeconds,
                        units: units,
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (s.note?.isNotEmpty == true) Text(s.note!, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              if (prs.containsKey(s.id))
                Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: RecordBadge.achievement(prs[s.id]!)),
              if (markComplete || s.isPlanned)
                Checkbox(value: !s.isPlanned, semanticLabel: 'Complete set ${index + 1}', onChanged: (v) => _completion(s, v!))
              else if (!prs.containsKey(s.id))
                SizedBox(
                  width: 48,
                  child: Tooltip(
                    message: 'Completed',
                    child: Icon(Icons.check_rounded, size: 18, color: colors.primary),
                  ),
                ),
              AppMenuButton<String>(
                tooltip: 'Set ${index + 1} options',
                enabled: !_saving,
                onSelected: (action) => _setAction(s, action),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'completion', child: Text(s.isPlanned ? 'Mark complete' : 'Mark incomplete')),
                  const PopupMenuItem(value: 'note', child: Text('Set note')),
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
    if (complete) {
      setState(() {
        _previous = set.copyWith(isComplete: true, isPlanned: false);
        if (!_touched && _editing == null) _fill(_previous!);
      });
    }
    HapticFeedback.selectionClick();
    if (complete && widget.date == Dates.today() && (ref.read(settingsProvider).asData?.value.restTimerAutoStart ?? false)) {
      _startRest();
    }
  }

  void _selectSet(WorkoutSet set) {
    if (_editing?.id == set.id) return;
    setState(() {
      _editing = set;
      _fill(set);
      _touched = true;
    });
  }

  Future<void> _setAction(WorkoutSet s, String action) async {
    final repo = ref.read(workoutRepositoryProvider);
    switch (action) {
      case 'completion':
        await _completion(s, s.isPlanned);
      case 'note':
        final note = await prompt(
          context,
          title: 'Set note',
          label: 'Note',
          value: s.note ?? '',
          optional: true,
          lines: 3,
          maxLength: 1000,
        );
        if (note != null && mounted) await attempt(context, () => repo.setNote(s.id, note.isEmpty ? null : note));
      case 'delete':
        if (!await confirm(context, title: 'Delete set?', message: 'Remove this set from the workout?') || !mounted) return;
        setState(() => _saving = true);
        await attempt(context, () async {
          await repo.deleteSet(s.id);
          final previous = await repo.lastSet(widget.exercise.id, widget.date);
          if (!mounted) return;
          FocusScope.of(context).unfocus();
          setState(() {
            _previous = previous;
            _editing = null;
            _error = null;
            if (previous != null) _fill(previous);
          });
        });
        if (mounted) setState(() => _saving = false);
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

  TextStyle _numberStyle(BuildContext context, double width) {
    final style = Theme.of(context).textTheme.bodyLarge!.copyWith(fontSize: 22, fontWeight: FontWeight.w700);
    final painter = TextPainter(
      text: TextSpan(text: controller.text.isEmpty ? '0' : controller.text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final textWidth = painter.width;
    painter.dispose();
    return style.copyWith(fontSize: textWidth <= width - 8 ? 22 : (22 * (width - 8) / textWidth).clamp(14.0, 22.0));
  }

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
    child: Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Decrease $label',
              onPressed: () => _bump(-step),
              icon: const Icon(Icons.remove_rounded, size: 19),
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$label${unit.isEmpty ? '' : ' · $unit'}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            IconButton(tooltip: 'Increase $label', onPressed: () => _bump(step), icon: const Icon(Icons.add_rounded, size: 19)),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: Semantics(
            label: '$label $unit',
            container: true,
            child: SizedBox(
              height: MediaQuery.textScalerOf(context).scale(22) * (Theme.of(context).textTheme.bodyLarge!.height ?? 1) + 8,
              child: LayoutBuilder(
                builder: (context, constraints) => TextField(
                  controller: controller,
                  textAlign: TextAlign.center,
                  textAlignVertical: TextAlignVertical.center,
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
                  style: _numberStyle(context, constraints.maxWidth),
                  decoration: const InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                    hintText: '0',
                  ),
                  onChanged: (_) => onChanged(),
                  onTap: () => controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
