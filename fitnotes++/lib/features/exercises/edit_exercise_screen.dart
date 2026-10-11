import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import '../../core/database/tables.dart';
import '../../core/providers.dart';
import '../../core/models/weight_multiplier.dart';
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
  WeightUnit? _weightUnit;
  final _multipliers = <MultiplierValue>[];
  double? _incrementKg;
  String? _incrementText;
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
      final repo = ref.read(exerciseRepositoryProvider);
      final ex = await repo.getExercise(widget.exerciseId!);
      final multipliers = await repo.watchMultipliers(ex.id).first;
      await ref.read(settingsProvider.future);
      if (!mounted) return;
      _weightUnit = ex.weightUnit;
      _multipliers
        ..clear()
        ..addAll(multipliers.map((m) => (label: m.label, factor: m.factor, enabled: m.enabled)));
      final units = ref.read(unitsProvider).withWeightUnit(_weightUnit);
      _name.text = ex.name;
      _notes.text = ex.notes ?? '';
      _rest.text = ex.defaultRestTimeSeconds == null ? '' : '${ex.defaultRestTimeSeconds}';
      _increment.text = ex.weightIncrement == null ? '' : Fmt.number(units.weightFromKg(ex.weightIncrement!));
      _incrementKg = ex.weightIncrement;
      _incrementText = _increment.text;
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
    final systemUnits = ref.watch(unitsProvider);
    final units = systemUnits.withWeightUnit(_weightUnit);
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
      floatingActionButton: _loading || _failed
          ? null
          : AppFloatingActionButton(tooltip: 'Save exercise', icon: Icons.check_rounded, onPressed: _saving ? null : _save),
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
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                      children: [
                        TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          maxLength: 120,
                          decoration: const InputDecoration(labelText: 'Exercise name', counterText: ''),
                          validator: (v) => v!.trim().isEmpty ? 'Enter an exercise name.' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                key: ValueKey(_category),
                                onTap: _dismissKeyboard,
                                initialValue: _category,
                                isExpanded: true,
                                decoration: const InputDecoration(labelText: 'Body part'),
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
                        const SizedBox(height: 12),
                        DropdownButtonFormField<ExerciseType>(
                          onTap: _dismissKeyboard,
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
                        if (_type.hasWeight) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            key: ValueKey(_weightUnit),
                            onTap: _dismissKeyboard,
                            isExpanded: true,
                            initialValue: _weightUnit?.index ?? -1,
                            decoration: const InputDecoration(labelText: 'Weight unit'),
                            items: [
                              DropdownMenuItem(
                                value: -1,
                                child: Text(
                                  'Use app setting (${systemUnits.weightLabel})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const DropdownMenuItem(value: 0, child: Text('kg')),
                              const DropdownMenuItem(value: 1, child: Text('lb')),
                            ],
                            onChanged: (value) => _changeWeightUnit(value == -1 ? null : WeightUnit.values[value!]),
                          ),
                          Row(
                            children: [
                              Expanded(child: Text('Multipliers', style: Theme.of(context).textTheme.titleMedium)),
                              IconButton.filledTonal(
                                tooltip: 'Add multiplier',
                                onPressed: () => _editMultiplier(),
                                icon: const Icon(Icons.add_rounded),
                              ),
                            ],
                          ),
                          for (var i = 0; i < _multipliers.length; i++)
                            Card(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: ListTile(
                                title: Row(
                                  children: [
                                    Expanded(child: Text(_multipliers[i].label)),
                                    const SizedBox(width: 8),
                                    Text('× ${Fmt.number(_multipliers[i].factor, precision: 6)}'),
                                  ],
                                ),
                                onTap: () => _editMultiplier(i),
                                trailing: Switch(
                                  value: _multipliers[i].enabled,
                                  onChanged: (value) => setState(
                                    () => _multipliers[i] = (
                                      label: _multipliers[i].label,
                                      factor: _multipliers[i].factor,
                                      enabled: value,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                        const SectionTitle('Defaults'),
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
                        const SizedBox(height: 12),
                        ExpansionTile(
                          title: const Text('Notes'),
                          tilePadding: EdgeInsets.zero,
                          initiallyExpanded: _notes.text.isNotEmpty,
                          children: [
                            TextFormField(
                              controller: _notes,
                              maxLines: 3,
                              maxLength: 2000,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(labelText: 'Technique notes'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
    FocusManager.instance.applyFocusChangesIfNeeded();
  }

  void _changeWeightUnit(WeightUnit? unit) {
    final systemUnits = ref.read(unitsProvider);
    final typed = double.tryParse(_increment.text);
    final kg = _increment.text == _incrementText && _incrementKg != null
        ? _incrementKg
        : typed == null
        ? null
        : systemUnits.withWeightUnit(_weightUnit).weightToKg(typed);
    setState(() {
      _weightUnit = unit;
      if (kg != null) {
        _increment.text = Fmt.number(systemUnits.withWeightUnit(unit).weightFromKg(kg));
        _incrementKg = kg;
        _incrementText = _increment.text;
      }
    });
  }

  Future<void> _editMultiplier([int? index]) async {
    _dismissKeyboard();
    final others = [
      for (var i = 0; i < _multipliers.length; i++)
        if (i != index) _multipliers[i],
    ];
    final value = await showDialog<MultiplierValue>(
      context: context,
      builder: (_) => _MultiplierDialog(
        value: index == null ? null : _multipliers[index],
        others: others,
        defaultName: nextMultiplierName(others.map((m) => m.label)),
        onDelete: index == null ? null : () => setState(() => _multipliers.removeAt(index)),
      ),
    );
    if (value == null || !mounted) return;
    setState(() {
      if (index == null) {
        _multipliers.add(value);
      } else {
        _multipliers[index] = value;
      }
    });
  }

  Future<void> _save() async {
    if (_form.currentState?.validate() != true) return;
    _dismissKeyboard();
    setState(() => _saving = true);
    int? id = widget.exerciseId;
    final success = await attempt(context, () async {
      final repo = ref.read(exerciseRepositoryProvider);
      final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
      final increment = double.tryParse(_increment.text);
      final units = ref.read(unitsProvider).withWeightUnit(_weightUnit);
      final kg = increment == null
          ? null
          : _incrementKg != null && _increment.text == _incrementText
          ? _incrementKg
          : units.weightToKg(increment);
      if (id == null) {
        id = await repo.createExercise(
          name: _name.text.trim(),
          categoryId: _category!,
          type: _type,
          notes: notes,
          restSeconds: int.tryParse(_rest.text),
          weightIncrement: kg,
          weightUnit: Value(_weightUnit),
          multipliers: List.of(_multipliers),
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
          weightUnit: Value(_weightUnit),
          multipliers: List.of(_multipliers),
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

class _MultiplierDialog extends StatefulWidget {
  const _MultiplierDialog({required this.defaultName, required this.others, this.value, this.onDelete});
  final String defaultName;
  final List<MultiplierValue> others;
  final MultiplierValue? value;
  final VoidCallback? onDelete;
  @override
  State<_MultiplierDialog> createState() => _MultiplierDialogState();
}

class _MultiplierDialogState extends State<_MultiplierDialog> {
  late final _label = TextEditingController(text: widget.value?.label);
  late final _factor = TextEditingController(text: Fmt.number(widget.value?.factor ?? 1, precision: 6));
  final _form = GlobalKey<FormState>();

  double? get _factorValue => widget.value != null && _factor.text == Fmt.number(widget.value!.factor, precision: 6)
      ? widget.value!.factor
      : double.tryParse(_factor.text.replaceAll(',', '.'));

  @override
  void dispose() {
    _label.dispose();
    _factor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: Text(widget.value == null ? 'Add multiplier' : 'Edit multiplier'),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _factor,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Multiply by', prefixText: '× '),
            validator: (_) {
              final factor = _factorValue;
              if (factor == null) return 'Enter a number.';
              try {
                validateMultipliers([...widget.others, (label: '', factor: factor, enabled: widget.value?.enabled ?? true)]);
                return null;
              } on FormatException catch (error) {
                return error.message;
              }
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _label,
            maxLength: 80,
            decoration: InputDecoration(labelText: 'Name (optional)', hintText: widget.defaultName, counterText: ''),
          ),
        ],
      ),
    ),
    actions: [
      if (widget.onDelete != null)
        TextButton(
          onPressed: () {
            widget.onDelete!();
            Navigator.pop(context);
          },
          child: const Text('Delete'),
        ),
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          Navigator.pop(context, (
            label: _label.text.trim().isEmpty ? widget.defaultName : _label.text.trim(),
            factor: _factorValue!,
            enabled: widget.value?.enabled ?? true,
          ));
        },
        child: const Text('Save'),
      ),
    ],
  );
}
