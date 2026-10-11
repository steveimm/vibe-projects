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
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final types = ref.watch(measurementTypesProvider);
    final measurements = ref.watch(allMeasurementsProvider);
    final units = ref.watch(unitsProvider);
    return types.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => ErrorState(onRetry: () => ref.invalidate(measurementTypesProvider)),
      data: (types) => measurements.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(onRetry: () => ref.invalidate(allMeasurementsProvider)),
        data: (all) {
          final groups = <int, List<Measurement>>{};
          for (final record in all) {
            (groups[record.typeId] ??= []).add(record);
          }
          final ordered = [...types.where((t) => groups.containsKey(t.id)), ...types.where((t) => !groups.containsKey(t.id))];
          return Scaffold(
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            floatingActionButton: AppFloatingActionButton(tooltip: 'Custom measurement', onPressed: _addType),
            body: ContentWidth(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                children: [
                  for (final type in ordered)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _history(type),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(type.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                          if (groups[type.id]?.firstOrNull case final latest?)
                                            Text(
                                              '${Fmt.number(_display(latest.value, type.unit, units))} ${_unit(type.unit, units)} · ${DateFormat('d MMM yyyy').format(Dates.parse(latest.date))}',
                                              style: Theme.of(context).textTheme.bodySmall,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Record ${type.name}',
                                  onPressed: () => _record(type, groups[type.id] ?? []),
                                  icon: const Icon(Icons.add_rounded),
                                ),
                                AppMenuButton<String>(
                                  tooltip: '${type.name} options',
                                  onSelected: (action) => _typeAction(type, action),
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'history', child: Text('History')),
                                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                                    PopupMenuItem(value: 'delete', child: Text('Delete measurement type')),
                                  ],
                                ),
                              ],
                            ),
                            if (groups[type.id] case final records?)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                                child: ProgressChart(
                                  key: ValueKey('measurement-chart-${type.id}'),
                                  height: 140,
                                  zeroBased: false,
                                  points: records.reversed
                                      .map((r) => (date: r.date, value: _display(r.value, type.unit, units)))
                                      .toList(),
                                  label: (v) => '${Fmt.number(v)} ${_unit(type.unit, units)}',
                                ),
                              ),
                          ],
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

  Future<void> _record(MeasurementType type, List<Measurement> records) => showDialog<void>(
    context: context,
    builder: (_) =>
        _MeasurementDialog(type: type, record: records.where((r) => r.date == Dates.today()).firstOrNull, quickRecord: true),
  );

  void _history(MeasurementType type) =>
      Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => _MeasurementHistory(type: type)));

  Future<void> _typeAction(MeasurementType type, String action) async {
    if (action == 'history') {
      _history(type);
    } else if (action == 'rename') {
      final name = await prompt(context, title: 'Rename measurement', label: 'Name', value: type.name, maxLength: 80);
      if (name != null && mounted) {
        await attempt(context, () => ref.read(progressRepositoryProvider).renameType(type.id, name));
      }
    } else if (action == 'delete' &&
        await confirm(
          context,
          title: 'Delete measurement type?',
          message: 'Remove ${type.name} and all of its recorded values?',
        ) &&
        mounted) {
      await attempt(context, () => ref.read(progressRepositoryProvider).deleteType(type.id));
    }
  }

  Future<void> _addType() async {
    final name = await prompt(context, title: 'Custom measurement', label: 'Name', maxLength: 80);
    if (name == null || !mounted) return;
    final units = ref.read(unitsProvider);
    final unit = await showDialog<String>(
      context: context,
      builder: (context) => AppDialog(
        title: const Text('Measurement unit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final unit in ['kg', 'cm', '%'])
              ListTile(
                contentPadding: EdgeInsets.zero,
                titleTextStyle: Theme.of(context).textTheme.bodyMedium,
                onTap: () => Navigator.pop(context, unit),
                title: Text(_unit(unit, units)),
              ),
          ],
        ),
      ),
    );
    if (unit != null && mounted) {
      await attempt(context, () async {
        final id = await ref.read(progressRepositoryProvider).addType(name, unit);
        if (mounted) await _record(MeasurementType(id: id, name: name, unit: unit), []);
      });
    }
  }
}

class _MeasurementHistory extends ConsumerWidget {
  const _MeasurementHistory({required this.type});
  final MeasurementType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(type.name)),
      body: ContentWidth(
        child: ref
            .watch(measurementsProvider(type.id))
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => ErrorState(onRetry: () => ref.invalidate(measurementsProvider(type.id))),
              data: (records) => records.isEmpty
                  ? const Center(child: Text('No measurements'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: records.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (context, i) {
                        final r = records[i];
                        return Card(
                          child: ListTile(
                            title: Text('${Fmt.number(_display(r.value, type.unit, units))} ${_unit(type.unit, units)}'),
                            subtitle: Text(
                              '${DateFormat('d MMM yyyy').format(Dates.parse(r.date))}${r.note.isEmpty ? '' : '\n${r.note}'}',
                            ),
                            onTap: () => showDialog<void>(
                              context: context,
                              builder: (_) => _MeasurementDialog(type: type, record: r),
                            ),
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
                        );
                      },
                    ),
            ),
      ),
    );
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
  const _MeasurementDialog({required this.type, this.record, this.quickRecord = false});
  final MeasurementType type;
  final Measurement? record;
  final bool quickRecord;
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
  late bool _showNote = widget.record?.note.isNotEmpty == true;
  @override
  void initState() {
    super.initState();
    _value.selection = TextSelection(baseOffset: 0, extentOffset: _value.text.length);
  }

  @override
  void dispose() {
    _value.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(unitsProvider);
    return AppDialog(
      title: Text(widget.type.name),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_date),
              trailing: const Icon(Icons.event_outlined),
              onTap: () async {
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
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Value', suffixText: _unit(widget.type.unit, units)),
              validator: (v) {
                final value = double.tryParse(v!.replaceAll(',', '.'));
                return value != null && value.isFinite && value > 0 && value <= (widget.type.unit == '%' ? 100 : 100000)
                    ? null
                    : 'Enter a valid value greater than zero.';
              },
            ),
            if (_showNote) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                maxLength: 500,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
            ] else
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Add note',
                  onPressed: () => setState(() => _showNote = true),
                  icon: const Icon(Icons.note_add_outlined),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
      ],
    );
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final units = ref.read(unitsProvider);
    final input = double.parse(_value.text.replaceAll(',', '.'));
    final unchanged = widget.record != null && _value.text == Fmt.number(_display(widget.record!.value, widget.type.unit, units));
    final value = unchanged
        ? widget.record!.value
        : widget.type.unit == 'kg'
        ? units.weightToKg(input)
        : widget.type.unit == 'cm' && units.imperial
        ? input * 2.54
        : input;
    var saved = false;
    final ok = await attempt(context, () async {
      final repo = ref.read(progressRepositoryProvider);
      var id = widget.quickRecord && _date != widget.record?.date ? null : widget.record?.id;
      if (id == null) {
        final existing = await repo.measurementOnDate(widget.type.id, _date);
        if (!mounted) return;
        if (existing != null) {
          if (!await confirm(context, title: 'Replace measurement?', message: 'Replace the entry for $_date?') || !mounted) {
            return;
          }
          id = existing.id;
        }
      }
      await repo.saveMeasurement(widget.type.id, _date, value, _note.text, id: id);
      saved = true;
    });
    if (!mounted) return;
    if (ok && saved) {
      Navigator.pop(context);
    } else {
      setState(() => _busy = false);
    }
  }
}
