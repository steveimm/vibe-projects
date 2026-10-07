import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/database.dart';
import '../../core/providers.dart';
import '../../core/util/dates.dart';
import '../../core/util/format.dart';
import '../../shared/progress_chart.dart';
import '../../shared/widgets.dart';

class BodyTab extends ConsumerStatefulWidget {
  const BodyTab({super.key});
  @override
  ConsumerState<BodyTab> createState() => _BodyTabState();
}

class _BodyTabState extends ConsumerState<BodyTab> with AutomaticKeepAliveClientMixin {
  int? _typeId;
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final types = ref.watch(measurementTypesProvider);
    final units = ref.watch(unitsProvider);
    return types.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => ErrorState(onRetry: () => ref.invalidate(measurementTypesProvider)),
      data: (types) {
        if (!types.any((t) => t.id == _typeId)) _typeId = types.firstOrNull?.id;
        if (_typeId == null) {
          return EmptyState(
            icon: Icons.straighten_rounded,
            title: 'Track a measurement',
            message: 'Add a measurement to start a personal history.',
            action: FilledButton(onPressed: _addType, child: const Text('Add measurement')),
          );
        }
        final type = types.firstWhere((t) => t.id == _typeId);
        final records = ref.watch(measurementsProvider(_typeId!));
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: ValueKey(_typeId),
                    initialValue: _typeId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Measurement'),
                    items: [for (final t in types) DropdownMenuItem(value: t.id, child: Text(t.name))],
                    onChanged: (id) => setState(() => _typeId = id),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Measurement options',
                  onSelected: (action) async {
                    if (action == 'add') {
                      await _addType();
                      return;
                    }
                    if (action == 'rename') {
                      final name = await prompt(
                        context,
                        title: 'Rename measurement',
                        label: 'Name',
                        value: type.name,
                        maxLength: 80,
                      );
                      if (name != null && context.mounted) {
                        await attempt(context, () => ref.read(progressRepositoryProvider).renameType(type.id, name));
                      }
                      return;
                    }
                    if (action == 'delete' &&
                        await confirm(
                          context,
                          title: 'Delete measurement type?',
                          message: 'Remove ${type.name} and all of its recorded values?',
                        ) &&
                        context.mounted) {
                      await attempt(context, () => ref.read(progressRepositoryProvider).deleteType(type.id));
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'add', child: Text('Custom measurement')),
                    PopupMenuItem(value: 'rename', child: Text('Rename measurement')),
                    PopupMenuItem(value: 'delete', child: Text('Delete measurement type')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _edit(type),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Record measurement'),
            ),
            const SizedBox(height: 20),
            records.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => ErrorState(onRetry: () => ref.invalidate(measurementsProvider(_typeId!))),
              data: (records) {
                if (records.isEmpty) {
                  return const EmptyState(
                    icon: Icons.monitor_weight_outlined,
                    title: 'One entry at a time',
                    message: 'Record a value to see how it changes over time.',
                  );
                }
                final points = records.reversed.map((r) => (date: r.date, value: _display(r.value, type.unit, units))).toList();
                final label = _unit(type.unit, units);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${Fmt.number(points.last.value)} $label', style: Theme.of(context).textTheme.headlineMedium),
                            Text(
                              'Latest · ${points.last.date}',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                            ProgressChart(points: points, label: (v) => '${Fmt.number(v)} $label'),
                          ],
                        ),
                      ),
                    ),
                    const SectionTitle('History'),
                    for (final r in records)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            title: Text(
                              '${Fmt.number(_display(r.value, type.unit, units))} $label',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '${DateFormat('d MMM yyyy').format(Dates.parse(r.date))}${r.note.isEmpty ? '' : '\n${r.note}'}',
                            ),
                            onTap: () => _edit(type, r),
                            trailing: IconButton(
                              tooltip: 'Delete measurement',
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: () async {
                                if (await confirm(
                                      context,
                                      title: 'Delete measurement?',
                                      message: 'Remove the entry for ${r.date}?',
                                    ) &&
                                    context.mounted) {
                                  await attempt(context, () => ref.read(progressRepositoryProvider).deleteMeasurement(r.id));
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
          ],
        );
      },
    );
  }

  Future<void> _edit(MeasurementType type, [Measurement? record]) => showDialog(
    context: context,
    builder: (_) => _MeasurementDialog(type: type, record: record),
  );
  Future<void> _addType() async {
    final name = await prompt(context, title: 'Custom measurement', label: 'Name', maxLength: 80);
    if (name == null || !mounted) return;
    final unit = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Measurement unit'),
        children: [
          for (final unit in ['kg', 'cm', '%'])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, unit),
              child: Padding(padding: const EdgeInsets.all(12), child: Text(unit)),
            ),
        ],
      ),
    );
    if (unit != null && mounted) {
      await attempt(context, () async {
        final id = await ref.read(progressRepositoryProvider).addType(name, unit);
        if (mounted) setState(() => _typeId = id);
      });
    }
  }
}

double _display(double value, String unit, Units units) => unit == 'kg'
    ? units.weightFromKg(value)
    : unit == 'cm' && units.imperial
    ? value / 2.54
    : value;
String _unit(String unit, Units units) => unit == 'kg'
    ? units.weightLabel
    : unit == 'cm'
    ? units.lengthLabel
    : unit;

class _MeasurementDialog extends ConsumerStatefulWidget {
  const _MeasurementDialog({required this.type, this.record});
  final MeasurementType type;
  final Measurement? record;
  @override
  ConsumerState<_MeasurementDialog> createState() => _MeasurementDialogState();
}

class _MeasurementDialogState extends ConsumerState<_MeasurementDialog> {
  late String _date = widget.record?.date ?? Dates.today();
  late final _value = TextEditingController(
    text: widget.record == null ? '' : Fmt.number(_display(widget.record!.value, widget.type.unit, ref.read(unitsProvider))),
  );
  late final _note = TextEditingController(text: widget.record?.note ?? '');
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  @override
  void dispose() {
    _value.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(unitsProvider);
    return AlertDialog(
      title: Text(widget.type.name),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_date),
                trailing: const Icon(Icons.event_outlined),
                onTap: widget.record != null
                    ? null
                    : () async {
                        final day = await showDatePicker(
                          context: context,
                          initialDate: Dates.parse(_date),
                          firstDate: DateTime(1900),
                          lastDate: DateTime(2100),
                        );
                        if (day != null && mounted) setState(() => _date = Dates.iso(day));
                      },
              ),
              TextFormField(
                controller: _value,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Value', suffixText: _unit(widget.type.unit, units)),
                validator: (v) {
                  final value = double.tryParse(v!);
                  return value != null && value.isFinite && value > 0 && value <= (widget.type.unit == '%' ? 100 : 100000)
                      ? null
                      : 'Enter a valid value greater than zero.';
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _note,
                maxLength: 500,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              const Text('One entry per day. Saving replaces the value for the selected date.', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  if (!_form.currentState!.validate()) return;
                  setState(() => _busy = true);
                  final input = double.parse(_value.text);
                  final unchanged =
                      widget.record != null && _value.text == Fmt.number(_display(widget.record!.value, widget.type.unit, units));
                  final value = unchanged
                      ? widget.record!.value
                      : widget.type.unit == 'kg'
                      ? units.weightToKg(input)
                      : widget.type.unit == 'cm' && units.imperial
                      ? input * 2.54
                      : input;
                  final ok = await attempt(
                    context,
                    () => ref.read(progressRepositoryProvider).saveMeasurement(widget.type.id, _date, value, _note.text),
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
}
