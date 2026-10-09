import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/util/format.dart';
import '../../core/util/onerm.dart';
import '../../shared/widgets.dart';

class ToolsScreen extends ConsumerStatefulWidget {
  const ToolsScreen({super.key});
  @override
  ConsumerState<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends ConsumerState<ToolsScreen> {
  final _weight = TextEditingController(text: '100');
  final _reps = TextEditingController(text: '5');
  late final _bar = TextEditingController(text: ref.read(unitsProvider).imperial ? '45' : '20');
  int _mode = 0;
  double _percent = 75;
  final Set<double> _excluded = {};
  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(unitsProvider);
    final weight = double.tryParse(_weight.text);
    final reps = int.tryParse(_reps.text);
    final bar = double.tryParse(_bar.text);
    final valid = weight != null && weight.isFinite && weight > 0;
    final estimate = valid && reps != null && reps >= 1 && reps < 37 ? OneRm.brzycki(weight, reps) : 0.0;
    final plates = units.imperial ? <double>[45, 35, 25, 10, 5, 2.5, 1.25] : <double>[25, 20, 15, 10, 5, 2.5, 1.25, 0.5];
    final stack = <(double, int)>[];
    var remaining = valid && bar != null && bar >= 0 && weight >= bar ? (weight - bar) / 2 : -1.0;
    if (remaining >= 0) {
      for (final plate in plates.where((p) => !_excluded.contains(p))) {
        final count = ((remaining + 0.000001) / plate).floor();
        if (count > 0) {
          stack.add((plate, count));
          remaining -= count * plate;
        }
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Workout tools')),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('1RM')),
                ButtonSegment(value: 1, label: Text('Plates')),
                ButtonSegment(value: 2, label: Text('Percent')),
              ],
              selected: {_mode},
              onSelectionChanged: (v) => setState(() => _mode = v.first),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _weight,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: _mode == 1 ? 'Target total weight' : 'Weight',
                suffixText: units.weightLabel,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            if (_mode == 0) ...[
              TextField(
                controller: _reps,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Reps',
                  helperText: 'Use 1–36 reps. Estimates are most useful at lower rep counts.',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),
              _result(
                'Estimated one-rep max',
                estimate > 0 ? '${Fmt.number(estimate)} ${units.weightLabel}' : 'Check weight and reps',
              ),
              const SectionTitle('Estimated rep maxes'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 20,
                    children: [
                      for (final n in [1, 3, 5, 8, 10, 12])
                        SizedBox(
                          width: 84,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$n ${n == 1 ? 'rep' : 'reps'}',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                estimate > 0 ? '${Fmt.number(OneRm.weightForReps(estimate, n))} ${units.weightLabel}' : '—',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Calculated using the Brzycki formula. These are estimates, not logged records.',
                style: TextStyle(fontSize: 12),
              ),
            ],
            if (_mode == 1) ...[
              TextField(
                controller: _bar,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Bar weight', suffixText: units.weightLabel),
                onChanged: (_) => setState(() {}),
              ),
              const SectionTitle('Available plate sizes'),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final p in plates)
                    FilterChip(
                      label: Text('${Fmt.number(p)} ${units.weightLabel}'),
                      selected: !_excluded.contains(p),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _excluded.remove(p);
                        } else {
                          _excluded.add(p);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (remaining < 0)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    child: Text('Enter a total weight at least as heavy as the bar.'),
                  ),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('On each side', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 16),
                        if (stack.isEmpty) const Text('Bar only'),
                        for (final item in stack)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${item.$2} × ${Fmt.number(item.$1)} ${units.weightLabel}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        Text(
                          'Total: ${Fmt.number(weight! - 2 * remaining)} ${units.weightLabel}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (remaining > 0.001)
                          Text(
                            '${Fmt.number(remaining * 2)} ${units.weightLabel} below target. Add smaller plate sizes for a closer match.',
                          ),
                      ],
                    ),
                  ),
                ),
            ],
            if (_mode == 2) ...[
              Row(
                children: [
                  Text('${_percent.round()}%', style: Theme.of(context).textTheme.headlineMedium),
                  Expanded(
                    child: Slider(
                      value: _percent,
                      min: 5,
                      max: 150,
                      divisions: 145,
                      label: '${_percent.round()}%',
                      onChanged: (v) => setState(() => _percent = v),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final p in [50, 60, 70, 75, 80, 85, 90])
                    ActionChip(label: Text('$p%'), onPressed: () => setState(() => _percent = p.toDouble())),
                ],
              ),
              const SizedBox(height: 24),
              _result(
                'Working weight',
                valid ? '${Fmt.number(weight * _percent / 100)} ${units.weightLabel}' : 'Enter a valid weight',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _result(String label, String value) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text(value, style: Theme.of(context).textTheme.headlineMedium)),
              IconButton(
                tooltip: 'Copy result',
                icon: const Icon(Icons.copy_outlined),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: value));
                  if (mounted) notice(context, 'Result copied');
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
