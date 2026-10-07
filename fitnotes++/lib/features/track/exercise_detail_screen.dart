import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/database.dart';
import '../../core/database/tables.dart';
import '../../core/providers.dart';
import '../../core/repositories/workout_repository.dart';
import '../../core/util/format.dart';
import 'graph_tab.dart';
import 'history_tab.dart';

double? _parseDuration(String text) => Fmt.parseDuration(text)?.toDouble();

/// Exercise detail with TRACK / HISTORY / GRAPH tabs.
class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId, required this.date});

  final int exerciseId;
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exAsync = ref.watch(exerciseProvider(exerciseId));
    return exAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('$e')),
      ),
      data: (ex) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: Text(ex.name),
            actions: [
              IconButton(
                tooltip: 'Edit exercise',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context.push('/exercises/edit?id=${ex.id}'),
              ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(text: 'TRACK'),
                Tab(text: 'HISTORY'),
                Tab(text: 'GRAPH'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _TrackTab(exercise: ex, date: date),
              HistoryTab(exercise: ex),
              GraphTab(exercise: ex),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackTab extends ConsumerStatefulWidget {
  const _TrackTab({required this.exercise, required this.date});

  final Exercise exercise;
  final String date;

  @override
  ConsumerState<_TrackTab> createState() => _TrackTabState();
}

class _TrackTabState extends ConsumerState<_TrackTab> {
  double _weight = 20;
  int _reps = 10;
  double _distance = 0;
  int _duration = 0;
  int? _editingId;
  bool _prefilled = false;

  // Pulled from settings on each build.
  double _inc = 2.5;
  bool _markComplete = false;
  int _restSeconds = 60;
  bool _restAutoStart = false;
  bool _restVibrate = false;

  Timer? _restTimer;
  int _restRemaining = 0;

  WorkoutRepository get _repo => ref.read(workoutRepositoryProvider);

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).asData?.value;
    _inc = settings?.defaultWeightIncrement ?? 2.5;
    _markComplete = settings?.markSetsComplete ?? false;
    _restSeconds = settings?.restTimerSeconds ?? 60;
    _restAutoStart = settings?.restTimerAutoStart ?? false;
    _restVibrate = settings?.restTimerVibrate ?? false;

    final setsAsync = ref.watch(exerciseSetsProvider((exerciseId: widget.exercise.id, date: widget.date)));
    return setsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (sets) {
        _maybePrefill(sets);
        final prIds = ref.watch(prSetIdsProvider(widget.exercise.id));
        return Column(
          children: [
            _inputArea(),
            const Divider(height: 1),
            Expanded(child: _setList(sets, prIds)),
          ],
        );
      },
    );
  }

  void _maybePrefill(List<WorkoutSet> sets) {
    if (_prefilled || _editingId != null) return;
    if (sets.isNotEmpty) {
      final last = sets.last;
      _weight = last.rawWeight;
      _reps = last.reps;
      _distance = last.distance;
      _duration = last.durationSeconds;
    }
    _prefilled = true;
  }

  Widget _inputArea() {
    final fields = <Widget>[];
    final type = widget.exercise.type;
    if (type.hasWeight) {
      fields.add(
        _NumberStepper(
          label: 'WEIGHT (kg)',
          value: _weight,
          step: _inc,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          format: Fmt.weightValue,
          parse: (t) => double.tryParse(t.trim()),
          onChanged: (v) => setState(() => _weight = v),
        ),
      );
    }
    if (type.hasReps) {
      fields.add(
        _NumberStepper(
          label: 'REPS',
          value: _reps.toDouble(),
          step: 1,
          keyboardType: TextInputType.number,
          format: (v) => v.round().toString(),
          parse: (t) => int.tryParse(t.trim())?.toDouble(),
          onChanged: (v) => setState(() => _reps = v.round()),
        ),
      );
    }
    if (type.hasDistance) {
      fields.add(
        _NumberStepper(
          label: 'DISTANCE (m)',
          value: _distance,
          step: 50,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          format: Fmt.number,
          parse: (t) => double.tryParse(t.trim()),
          onChanged: (v) => setState(() => _distance = v),
        ),
      );
    }
    if (type.hasTime) {
      fields.add(
        _NumberStepper(
          label: 'TIME (m:ss)',
          value: _duration.toDouble(),
          step: 15,
          keyboardType: TextInputType.text,
          format: (v) => Fmt.duration(v.round()),
          parse: _parseDuration,
          onChanged: (v) => setState(() => _duration = v.round()),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        children: [
          ...fields,
          const SizedBox(height: 4),
          _restBar(),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton(onPressed: _save, child: Text(_editingId == null ? 'SAVE' : 'UPDATE')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(onPressed: _editingId == null ? null : _clear, child: const Text('CLEAR')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _setList(List<WorkoutSet> sets, Set<int> prIds) {
    if (sets.isEmpty) {
      return Center(
        child: Text('No sets yet', style: TextStyle(color: Theme.of(context).hintColor)),
      );
    }
    return ListView.separated(
      itemCount: sets.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final s = sets[i];
        final hasNote = s.note != null && s.note!.isNotEmpty;
        return ListTile(
          selected: s.id == _editingId,
          leading: CircleAvatar(radius: 14, child: Text('${i + 1}', style: const TextStyle(fontSize: 13))),
          title: Row(
            children: [
              if (prIds.contains(s.id)) ...[
                const Icon(Icons.emoji_events, size: 16, color: Colors.amber),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  describeSet(
                    type: widget.exercise.type,
                    effectiveWeight: s.rawWeight * s.weightMultiplier,
                    reps: s.reps,
                    distance: s.distance,
                    durationSeconds: s.durationSeconds,
                  ),
                ),
              ),
            ],
          ),
          subtitle: hasNote ? Text(s.note!) : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(icon: Icon(hasNote ? Icons.chat_bubble : Icons.chat_bubble_outline), onPressed: () => _editNote(s)),
              if (_markComplete) Checkbox(value: s.isComplete, onChanged: (v) => _repo.setComplete(s.id, v ?? false)),
            ],
          ),
          onTap: () => setState(() {
            _editingId = s.id;
            _weight = s.rawWeight;
            _reps = s.reps;
            _distance = s.distance;
            _duration = s.durationSeconds;
          }),
          onLongPress: () => _confirmDelete(s),
        );
      },
    );
  }

  Future<void> _save() async {
    if (_editingId == null) {
      await _repo.addSet(
        exerciseId: widget.exercise.id,
        date: widget.date,
        rawWeight: _weight,
        reps: _reps,
        distance: _distance,
        durationSeconds: _duration,
      );
      if (_restAutoStart) _startRest();
    } else {
      await _repo.updateSet(_editingId!, rawWeight: _weight, reps: _reps, distance: _distance, durationSeconds: _duration);
      setState(() => _editingId = null);
    }
  }

  void _clear() => setState(() => _editingId = null);

  Widget _restBar() {
    if (_restRemaining <= 0) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: const Icon(Icons.timer_outlined),
          label: const Text('Start rest timer'),
          onPressed: () => _startRest(),
        ),
      );
    }
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Row(
          children: [
            const Icon(Icons.timer),
            const SizedBox(width: 8),
            Text('Rest  ${Fmt.duration(_restRemaining)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton(onPressed: () => _addRest(15), child: const Text('+15s')),
            IconButton(onPressed: _stopRest, icon: const Icon(Icons.stop)),
          ],
        ),
      ),
    );
  }

  void _startRest([int? seconds]) {
    _restTimer?.cancel();
    setState(() => _restRemaining = seconds ?? _restSeconds);
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_restRemaining <= 1) {
        t.cancel();
        setState(() => _restRemaining = 0);
        if (_restVibrate) HapticFeedback.vibrate();
      } else {
        setState(() => _restRemaining -= 1);
      }
    });
  }

  void _stopRest() {
    _restTimer?.cancel();
    setState(() => _restRemaining = 0);
  }

  void _addRest(int s) => setState(() => _restRemaining += s);

  Future<void> _editNote(WorkoutSet s) async {
    final ctrl = TextEditingController(text: s.note ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Set note'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'e.g. last rep partial'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Save')),
        ],
      ),
    );
    if (result != null) {
      await _repo.setNote(s.id, result.trim().isEmpty ? null : result.trim());
    }
  }

  Future<void> _confirmDelete(WorkoutSet s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete set?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      if (_editingId == s.id) setState(() => _editingId = null);
      await _repo.deleteSet(s.id);
    }
  }
}

/// A label + inline-editable number with tight −/+ buttons either side.
class _NumberStepper extends StatefulWidget {
  const _NumberStepper({
    required this.label,
    required this.value,
    required this.step,
    required this.format,
    required this.parse,
    required this.onChanged,
    required this.keyboardType,
  });

  final String label;
  final double value;
  final double step;
  final String Function(double) format;
  final double? Function(String) parse;
  final ValueChanged<double> onChanged;
  final TextInputType keyboardType;

  @override
  State<_NumberStepper> createState() => _NumberStepperState();
}

class _NumberStepperState extends State<_NumberStepper> {
  late final TextEditingController _controller = TextEditingController(text: widget.format(widget.value));

  @override
  void didUpdateWidget(covariant _NumberStepper old) {
    super.didUpdateWidget(old);
    // Resync only when the value changed externally (buttons / prefill / edit),
    // never while the user is typing the same value.
    if (widget.value != old.value && widget.parse(_controller.text) != widget.value) {
      _controller.text = widget.format(widget.value);
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _bump(double delta) {
    final v = widget.value + delta;
    widget.onChanged(v < 0 ? 0 : v);
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Divider(color: accent, thickness: 1.2, height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _btn(Icons.remove, () => _bump(-widget.step)),
              const SizedBox(width: 14),
              SizedBox(
                width: 150,
                child: TextField(
                  controller: _controller,
                  textAlign: TextAlign.center,
                  keyboardType: widget.keyboardType,
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 6)),
                  onChanged: (t) {
                    final v = widget.parse(t);
                    if (v != null) widget.onChanged(v < 0 ? 0 : v);
                  },
                ),
              ),
              const SizedBox(width: 14),
              _btn(Icons.add, () => _bump(widget.step)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: 56,
      height: 48,
      child: FilledButton.tonal(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Icon(icon),
      ),
    );
  }
}
