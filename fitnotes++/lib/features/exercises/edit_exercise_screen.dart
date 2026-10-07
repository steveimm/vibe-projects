import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/database/tables.dart';
import '../../core/providers.dart';
import '../../core/util/format.dart';
import '../../shared/widgets.dart';
import 'categories_screen.dart';

class EditExerciseScreen extends ConsumerStatefulWidget {
  const EditExerciseScreen({super.key, this.exerciseId, this.initialCategoryId});
  final int? exerciseId;
  final int? initialCategoryId;
  @override
  ConsumerState<EditExerciseScreen> createState() => _EditExerciseScreenState();
}

class _EditExerciseScreenState extends ConsumerState<EditExerciseScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _notes = TextEditingController();
  final _rest = TextEditingController();
  final _increment = TextEditingController();
  int? _category;
  Exercise? _original;
  ExerciseType _type = ExerciseType.weightAndReps;
  bool _loading = false, _saving = false, _failed = false;
  @override
  void initState() {
    super.initState();
    _category = widget.initialCategoryId;
    if (widget.exerciseId != null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final ex = await ref.read(exerciseRepositoryProvider).getExercise(widget.exerciseId!);
      if (!mounted) return;
      _original = ex;
      final units = ref.read(unitsProvider);
      _name.text = ex.name;
      _notes.text = ex.notes ?? '';
      _rest.text = ex.defaultRestTimeSeconds == null ? '' : '${ex.defaultRestTimeSeconds}';
      _increment.text = ex.weightIncrement == null ? '' : Fmt.number(units.weightFromKg(ex.weightIncrement!));
      setState(() {
        _category = ex.categoryId;
        _type = ex.type;
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

  @override
  void dispose() {
    for (final c in [_name, _notes, _rest, _increment]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(unitsProvider);
    final categories = ref.watch(categoriesProvider);
    final history = widget.exerciseId == null ? null : ref.watch(exerciseHistoryProvider(widget.exerciseId!)).asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exerciseId == null ? 'New exercise' : 'Edit exercise'),
        actions: [
          if (widget.exerciseId != null)
            IconButton(
              tooltip: 'Archive exercise',
              icon: const Icon(Icons.archive_outlined),
              onPressed: _saving ? null : _archive,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
          ? ErrorState(onRetry: _load)
          : ContentWidth(
              child: categories.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => ErrorState(onRetry: () => ref.invalidate(categoriesProvider)),
                data: (cats) {
                  _category ??= cats.firstOrNull?.id;
                  return Form(
                    key: _form,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      children: [
                        TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          maxLength: 120,
                          decoration: const InputDecoration(labelText: 'Exercise name', hintText: 'e.g. Incline dumbbell press'),
                          validator: (v) => v!.trim().isEmpty ? 'Enter an exercise name.' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                key: ValueKey(_category),
                                initialValue: _category,
                                isExpanded: true,
                                decoration: const InputDecoration(labelText: 'Category'),
                                items: [
                                  for (final c in cats)
                                    DropdownMenuItem(
                                      value: c.id,
                                      child: Row(
                                        children: [
                                          CircleAvatar(radius: 5, backgroundColor: Color(c.colorArgb)),
                                          const SizedBox(width: 10),
                                          Expanded(child: Text(c.name)),
                                        ],
                                      ),
                                    ),
                                ],
                                onChanged: (v) => setState(() => _category = v),
                                validator: (v) => v == null ? 'Choose a category.' : null,
                              ),
                            ),
                            IconButton(
                              tooltip: 'New category',
                              icon: const Icon(Icons.add_circle_outline_rounded),
                              onPressed: () async {
                                final id = await editCategory(context);
                                if (id != null && mounted) setState(() => _category = id);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<ExerciseType>(
                          initialValue: _type,
                          key: ValueKey(_type),
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'What do you track?',
                            helperText: history?.isNotEmpty == true ? 'Type is fixed to protect your workout history.' : null,
                            helperMaxLines: 2,
                          ),
                          items: [
                            for (final t in ExerciseType.values) DropdownMenuItem(value: t, child: Text(exerciseTypeLabel(t))),
                          ],
                          onChanged: history?.isNotEmpty == true ? null : (v) => setState(() => _type = v!),
                        ),
                        const SectionTitle('Defaults'),
                        Text(
                          'Leave these blank to use your settings.',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _rest,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Rest timer', suffixText: 'sec'),
                                validator: (v) =>
                                    v!.trim().isEmpty || ((int.tryParse(v) ?? 0) >= 1 && (int.tryParse(v) ?? 9999) <= 3600)
                                    ? null
                                    : 'Use 1–3600 sec',
                              ),
                            ),
                            if (_type.hasWeight) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _increment,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(labelText: 'Weight step', suffixText: units.weightLabel),
                                  validator: (v) =>
                                      v!.trim().isEmpty || ((double.tryParse(v) ?? 0) > 0 && (double.tryParse(v) ?? 999) <= 100)
                                      ? null
                                      : 'Use 0.01–100',
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SectionTitle('Technique notes'),
                        TextFormField(
                          controller: _notes,
                          maxLines: 4,
                          maxLength: 2000,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(hintText: 'Setup, cues, equipment…'),
                        ),
                        if (widget.exerciseId != null && _type.hasWeight) ...[
                          const SectionTitle('Weight multipliers'),
                          Text(
                            'Record the number on the equipment. Enabled factors multiply together to calculate effective weight. Existing sets keep their original factor.',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 12),
                          _Multipliers(exerciseId: widget.exerciseId!),
                        ],
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.check_rounded),
                          label: Text(_saving ? 'Saving…' : 'Save exercise'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    int? id = widget.exerciseId;
    final success = await attempt(context, () async {
      final repo = ref.read(exerciseRepositoryProvider);
      final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
      final increment = double.tryParse(_increment.text);
      final units = ref.read(unitsProvider);
      final kg = increment == null
          ? null
          : _original?.weightIncrement != null && _increment.text == Fmt.number(units.weightFromKg(_original!.weightIncrement!))
          ? _original!.weightIncrement
          : units.weightToKg(increment);
      if (id == null) {
        id = await repo.createExercise(
          name: _name.text.trim(),
          categoryId: _category!,
          type: _type,
          notes: notes,
          restSeconds: int.tryParse(_rest.text),
          weightIncrement: kg,
        );
      } else {
        await repo.updateExercise(
          id: id!,
          name: _name.text.trim(),
          categoryId: _category!,
          type: _type,
          notes: notes,
          restSeconds: int.tryParse(_rest.text),
          weightIncrement: kg,
        );
      }
    });
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, id);
    } else {
      setState(() => _saving = false);
    }
  }

  Future<void> _archive() async {
    if (!await confirm(
          context,
          title: 'Archive exercise?',
          message: 'This hides it from the active library. Your workouts and records remain, and you can restore it from the library menu.',
          action: 'Archive',
        ) ||
        !mounted) {
      return;
    }
    if (await attempt(context, () => ref.read(exerciseRepositoryProvider).setArchived(widget.exerciseId!, true)) && mounted) {
      Navigator.pop(context);
    }
  }
}

class _Multipliers extends ConsumerWidget {
  const _Multipliers({required this.exerciseId});
  final int exerciseId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    children: [
      for (final m in ref.watch(multipliersProvider(exerciseId)).asData?.value ?? <ExerciseMultiplier>[])
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(m.label),
            subtitle: Text('× ${Fmt.number(m.factor)}'),
            onTap: () => showDialog(
              context: context,
              builder: (_) => _MultiplierDialog(exerciseId: exerciseId, multiplier: m),
            ),
            trailing: Switch(
              value: m.enabled,
              onChanged: (v) => attempt(
                context,
                () => ref
                    .read(exerciseRepositoryProvider)
                    .saveMultiplier(id: m.id, exerciseId: exerciseId, label: m.label, factor: m.factor, enabled: v),
              ),
            ),
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add multiplier'),
          onPressed: () => showDialog(
            context: context,
            builder: (_) => _MultiplierDialog(exerciseId: exerciseId),
          ),
        ),
      ),
    ],
  );
}

class _MultiplierDialog extends ConsumerStatefulWidget {
  const _MultiplierDialog({required this.exerciseId, this.multiplier});
  final int exerciseId;
  final ExerciseMultiplier? multiplier;
  @override
  ConsumerState<_MultiplierDialog> createState() => _MultiplierDialogState();
}

class _MultiplierDialogState extends ConsumerState<_MultiplierDialog> {
  late final _label = TextEditingController(text: widget.multiplier?.label);
  late final _factor = TextEditingController(text: Fmt.number(widget.multiplier?.factor ?? 2));
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  @override
  void dispose() {
    _label.dispose();
    _factor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.multiplier == null ? 'Weight multiplier' : 'Edit multiplier'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _label,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Two dumbbells'),
              validator: (v) => v!.trim().isEmpty ? 'Enter a name.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _factor,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Multiply by', prefixText: '× '),
              validator: (v) => (double.tryParse(v!) ?? 0) > 0 && (double.tryParse(v) ?? 101) <= 100
                  ? null
                  : 'Use a number greater than 0, up to 100',
            ),
          ],
        ),
      ),
    ),
    actions: [
      if (widget.multiplier != null)
        TextButton(
          onPressed: _busy
              ? null
              : () async {
                  if (await attempt(
                        context,
                        () => ref.read(exerciseRepositoryProvider).deleteMultiplier(widget.multiplier!.id),
                      ) &&
                      context.mounted) {
                    Navigator.pop(context);
                  }
                },
          child: const Text('Delete'),
        ),
      TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(
        onPressed: _busy
            ? null
            : () async {
                if (!_form.currentState!.validate()) return;
                setState(() => _busy = true);
                final ok = await attempt(
                  context,
                  () => ref
                      .read(exerciseRepositoryProvider)
                      .saveMultiplier(
                        id: widget.multiplier?.id,
                        exerciseId: widget.exerciseId,
                        label: _label.text,
                        factor: double.parse(_factor.text),
                        enabled: widget.multiplier?.enabled ?? true,
                      ),
                );
                if (!context.mounted) return;
                if (ok) {
                  Navigator.pop(context);
                } else {
                  setState(() => _busy = false);
                }
              },
        child: const Text('Save'),
      ),
    ],
  );
}
