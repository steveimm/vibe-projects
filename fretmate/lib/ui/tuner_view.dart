import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../practice_controller.dart';
import '../tuning.dart';
import 'practice_button.dart';

class TunerView extends StatelessWidget {
  const TunerView({super.key, required this.controller, required this.meterHeight});

  final PracticeController controller;
  final double meterHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _TuningSelector(controller: controller)),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('Auto'),
              selected: controller.selectedString == null,
              onSelected: (_) => controller.selectString(null),
              showCheckmark: false,
              side: BorderSide.none,
              backgroundColor: scheme.surfaceContainerLow,
              selectedColor: scheme.primaryContainer,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: controller.selectedString == null ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
              ),
              shape: const StadiumBorder(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 96,
                child: _StringColumn(
                  controller: controller,
                  strings: controller.strings.take(3).toList().reversed.toList(),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(child: _DetectionPanel(controller: controller)),
              const SizedBox(width: 6),
              SizedBox(
                width: 96,
                child: _StringColumn(controller: controller, strings: controller.strings.skip(3).toList()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        _PitchMeter(controller: controller, height: meterHeight),
        const SizedBox(height: 4),
        PracticeButton(
          buttonKey: const ValueKey('listen-button'),
          onPressed: controller.busy ? null : controller.toggleTuner,
          icon: controller.listening ? Icons.stop_rounded : Icons.mic_rounded,
          label: controller.busy && controller.tab == 0
              ? 'Please wait…'
              : controller.listening
              ? 'Stop'
              : 'Listen',
        ),
      ],
    );
  }
}

class _TuningSelector extends StatelessWidget {
  const _TuningSelector({required this.controller});

  final PracticeController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<TuningPreset>(
      key: const ValueKey('tuning-selector'),
      tooltip: 'Choose tuning',
      initialValue: controller.tuning,
      onSelected: controller.selectTuning,
      position: PopupMenuPosition.under,
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      itemBuilder: (context) => [
        for (final tuning in tuningPresets)
          PopupMenuItem(
            key: ValueKey('tuning-${tuning.name}'),
            value: tuning,
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tuning.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    tuning.noteSummary,
                    style: TextStyle(fontSize: 12, letterSpacing: 1.2, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    controller.tuningName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    controller.tuningNotes,
                    style: TextStyle(fontSize: 12, letterSpacing: 1.8, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.keyboard_arrow_down_rounded, color: scheme.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}

class _StringColumn extends StatelessWidget {
  const _StringColumn({required this.controller, required this.strings});

  final PracticeController controller;
  final List<GuitarString> strings;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < strings.length; i++) ...[
        if (i > 0) const SizedBox(height: 8),
        _StringButton(
          string: strings[i],
          selected: controller.target?.number == strings[i].number,
          onTap: () => controller.lockAndPlayString(strings[i]),
          onRaise: strings[i].midiNote < maximumTuningNote ? () => controller.adjustString(strings[i].number, 1) : null,
          onLower: strings[i].midiNote > minimumTuningNote
              ? () => controller.adjustString(strings[i].number, -1)
              : null,
        ),
      ],
    ],
  );
}

class _StringButton extends StatelessWidget {
  const _StringButton({
    required this.string,
    required this.selected,
    required this.onTap,
    required this.onRaise,
    required this.onLower,
  });

  final GuitarString string;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onRaise;
  final VoidCallback? onLower;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? scheme.onPrimary : scheme.onSurface;
    final arrows = SizedBox(
      width: 48,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final raise in [true, false])
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                key: ValueKey('string-${string.number}-${raise ? 'up' : 'down'}'),
                tooltip: '${raise ? 'Raise' : 'Lower'} string ${string.number} by one semitone',
                onPressed: raise ? onRaise : onLower,
                color: selected ? foreground : scheme.onSurfaceVariant,
                iconSize: 18,
                icon: Icon(raise ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded),
              ),
            ),
        ],
      ),
    );
    return Material(
      key: ValueKey('string-card-${string.number}'),
      color: selected ? scheme.primary : scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          if (string.number >= 4) arrows,
          Expanded(
            child: Semantics(
              key: ValueKey('string-${string.number}'),
              button: true,
              selected: selected,
              label:
                  'Lock and play string ${string.number}, ${string.label}, ${string.frequency.toStringAsFixed(1)} hertz',
              child: InkWell(
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 96),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
                    child: ExcludeSemantics(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${string.number}',
                            style: TextStyle(fontSize: 11, color: selected ? foreground : scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text.rich(
                              TextSpan(
                                text: string.note,
                                children: [TextSpan(text: '${string.octave}', style: const TextStyle(fontSize: 13))],
                              ),
                              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w600, color: foreground),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (string.number < 4) arrows,
        ],
      ),
    );
  }
}

class _DetectionPanel extends StatelessWidget {
  const _DetectionPanel({required this.controller});

  final PracticeController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cents = controller.cents;
    final reading = controller.referencePlaying
        ? ' '
        : cents == null
        ? controller.listening
              ? 'Listening…'
              : ' '
        : '${controller.inTune ? 'In tune · ' : ''}${cents > 0 ? '+' : ''}${cents.toStringAsFixed(0)} cents';
    return Padding(
      key: const ValueKey('detection-panel'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            controller.selectedString == null ? 'Detected note' : 'Locked note',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 126,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(
                  text: controller.target?.note ?? '–',
                  children: [
                    if (controller.target != null)
                      TextSpan(text: '${controller.target!.octave}', style: const TextStyle(fontSize: 42)),
                  ],
                ),
                style: TextStyle(
                  fontSize: 120,
                  height: 1.05,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -4,
                  color: scheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            controller.frequency == null ? '— Hz' : '${controller.frequency!.toStringAsFixed(1)} Hz',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            reading,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: controller.inTune ? scheme.primary : scheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _PitchMeter extends StatelessWidget {
  const _PitchMeter({required this.controller, required this.height});

  final PracticeController controller;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cents = controller.cents;
    return Semantics(
      label: cents == null
          ? 'No pitch detected'
          : '${cents.abs().toStringAsFixed(0)} cents ${cents < 0 ? 'flat' : 'sharp'}',
      child: SizedBox(
        key: const ValueKey('pitch-meter'),
        height: height,
        width: double.infinity,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: (cents ?? 0).clamp(-50.0, 50.0)),
          duration: const Duration(milliseconds: 160),
          builder: (context, value, _) => CustomPaint(
            painter: _TuningMeter(
              cents: value,
              active: cents != null,
              color: scheme.primary,
              tickColor: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _TuningMeter extends CustomPainter {
  const _TuningMeter({required this.cents, required this.active, required this.color, required this.tickColor});

  final double cents;
  final bool active;
  final Color color;
  final Color tickColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height - 8);
    final radius = math.min(size.width / 2 - 6, size.height - 8);
    const start = math.pi * 1.05;
    const sweep = math.pi * 0.9;
    Offset point(double angle, double inset) => center + Offset(math.cos(angle), math.sin(angle)) * (radius - inset);
    final arc = Rect.fromCircle(center: center, radius: radius - 8);

    canvas.drawArc(
      arc,
      start,
      sweep,
      false,
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..color = tickColor.withValues(alpha: 0.07),
    );
    canvas.drawArc(arc, math.pi * 1.455, math.pi * 0.09, false, paint..color = color.withValues(alpha: 0.2));
    for (var tick = 0; tick <= 40; tick++) {
      final angle = start + tick / 40 * sweep;
      final major = tick % 5 == 0;
      canvas.drawLine(
        point(angle, 0),
        point(angle, major ? 17 : 8),
        paint
          ..color = tick == 20 ? color : tickColor.withValues(alpha: major ? 0.8 : 0.4)
          ..strokeWidth = major ? 1.5 : 1,
      );
    }
    if (!active) return;
    final angle = start + (cents + 50) / 100 * sweep;
    final direction = Offset(math.cos(angle), math.sin(angle));
    final normal = Offset(-direction.dy, direction.dx);
    final tip = point(angle, 20);
    final base = tip - direction * 12;
    canvas.drawLine(
      center,
      base,
      paint
        ..color = color
        ..strokeWidth = 2.5,
    );
    final head = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((base + normal * 5).dx, (base + normal * 5).dy)
      ..lineTo((base - normal * 5).dx, (base - normal * 5).dy)
      ..close();
    canvas.drawPath(head, paint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_TuningMeter oldDelegate) =>
      cents != oldDelegate.cents ||
      active != oldDelegate.active ||
      color != oldDelegate.color ||
      tickColor != oldDelegate.tickColor;
}
