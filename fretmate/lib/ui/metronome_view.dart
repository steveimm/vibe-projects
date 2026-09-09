import 'package:flutter/material.dart';

import '../audio/click_track.dart';
import '../practice_controller.dart';

class MetronomeView extends StatelessWidget {
  const MetronomeView({super.key, required this.controller});

  final PracticeController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Decrease tempo',
                        onPressed: controller.busy || controller.bpm == minimumTempo ? null : () => _stepTempo(-1),
                        icon: const Icon(Icons.remove_rounded),
                      ),
                      const SizedBox(width: 24),
                      Semantics(
                        label: '${controller.bpm} beats per minute',
                        child: Text(
                          '${controller.bpm}',
                          style: TextStyle(
                            fontSize: 72,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      IconButton.filledTonal(
                        tooltip: 'Increase tempo',
                        onPressed: controller.busy || controller.bpm == maximumTempo ? null : () => _stepTempo(1),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                ),
                const Text('BPM'),
                const SizedBox(height: 8),
                Slider(
                  value: controller.bpm.toDouble(),
                  min: minimumTempo.toDouble(),
                  max: maximumTempo.toDouble(),
                  divisions: maximumTempo - minimumTempo,
                  label: '${controller.bpm} BPM',
                  semanticFormatterCallback: (value) => '${value.round()} beats per minute',
                  onChanged: controller.busy ? null : (value) => controller.setTempo(value.round()),
                ),
                const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('20'), Text('300')]),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: controller.busy ? null : controller.tapTempo,
                  icon: const Icon(Icons.touch_app_outlined),
                  label: const Text('Tap tempo'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 12,
          children: [
            for (var beat = 0; beat < controller.beatsPerBar; beat++)
              Semantics(
                label: 'Beat ${beat + 1}',
                selected: controller.playing && controller.beat == beat,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  width: 42,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: controller.playing && controller.beat == beat
                        ? scheme.primary
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    border: beat == 0 && controller.accent ? Border.all(color: scheme.primary, width: 2) : null,
                  ),
                  child: Text(
                    '${beat + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: controller.playing && controller.beat == beat ? scheme.onPrimary : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('BEATS PER BAR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.3)),
        const SizedBox(height: 8),
        Row(
          spacing: 8,
          children: [
            for (final beats in [2, 3, 4, 6])
              Expanded(
                child: Semantics(
                  label: '$beats beats per bar',
                  child: ChoiceChip(
                    key: ValueKey('beats-$beats'),
                    label: Center(child: Text('$beats')),
                    showCheckmark: false,
                    selected: controller.beatsPerBar == beats,
                    onSelected: controller.busy ? null : (_) => controller.setBeats(beats),
                  ),
                ),
              ),
          ],
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Accent the first beat'),
          value: controller.accent,
          onChanged: controller.busy ? null : controller.setAccent,
        ),
        const Spacer(),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey('metronome-button'),
          onPressed: controller.busy ? null : controller.toggleMetronome,
          icon: Icon(controller.playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
          label: Text(
            controller.busy
                ? 'Please wait…'
                : controller.playing
                ? 'Stop metronome'
                : 'Start metronome',
          ),
        ),
      ],
    );
  }

  void _stepTempo(int delta) {
    controller.setTempo(controller.bpm + delta);
  }
}
