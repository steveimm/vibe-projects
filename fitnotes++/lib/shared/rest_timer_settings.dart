import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/database.dart';
import '../core/providers.dart';
import '../core/services/rest_timer.dart';
import '../core/services/device_service.dart';
import '../core/util/format.dart';
import 'widgets.dart';

Future<void> showRestTimerSettings(BuildContext context, WidgetRef ref, {Exercise? exercise}) async {
  final settings = await ref.read(settingsProvider.future);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _RestTimerSettings(settings: settings, exercise: exercise),
  );
}

class _RestTimerSettings extends ConsumerStatefulWidget {
  const _RestTimerSettings({required this.settings, this.exercise});
  final AppSettingsRow settings;
  final Exercise? exercise;
  @override
  ConsumerState<_RestTimerSettings> createState() => _RestTimerSettingsState();
}

class _RestTimerSettingsState extends ConsumerState<_RestTimerSettings> {
  final _form = GlobalKey<FormState>();
  late final _duration = TextEditingController(text: Fmt.duration(widget.settings.restTimerSeconds));
  late final _exerciseDuration = TextEditingController(
    text: Fmt.duration(widget.exercise?.defaultRestTimeSeconds ?? widget.settings.restTimerSeconds),
  );
  late bool _custom = widget.exercise?.defaultRestTimeSeconds != null;
  late bool _auto = widget.settings.restTimerAutoStart;
  late bool _sound = widget.settings.restTimerSound;
  late bool _vibrate = widget.settings.restTimerVibrate;
  bool _saving = false;

  @override
  void dispose() {
    _duration.dispose();
    _exerciseDuration.dispose();
    super.dispose();
  }

  Widget _field(TextEditingController controller, String label) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.datetime,
    decoration: InputDecoration(labelText: label, suffixText: 'm:ss'),
    validator: (v) {
      final seconds = Fmt.parseDuration(v ?? '');
      return seconds != null && seconds >= 1 && seconds <= 3600 ? null : 'Use 1 second to 60 minutes.';
    },
  );

  @override
  Widget build(BuildContext context) => AppDialog(
    title: const Text('Rest timer'),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(_duration, 'Default duration'),
          if (widget.exercise != null) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Custom exercise duration'),
              subtitle: Text(widget.exercise!.name),
              value: _custom,
              onChanged: _saving ? null : (v) => setState(() => _custom = v),
            ),
            if (_custom) _field(_exerciseDuration, 'Exercise duration'),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-start after a set'),
            value: _auto,
            onChanged: _saving ? null : (v) => setState(() => _auto = v),
          ),
          Row(
            children: [
              const Expanded(child: ExcludeSemantics(child: Text('Sound'))),
              IconButton(
                tooltip: 'Preview rest sound',
                onPressed: () => DeviceService.call('previewRestSound'),
                icon: const Icon(Icons.volume_up_outlined),
              ),
              Semantics(
                label: 'Sound',
                child: Switch(value: _sound, onChanged: _saving ? null : (v) => setState(() => _sound = v)),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Vibration'),
            value: _vibrate,
            onChanged: _saving ? null : (v) => setState(() => _vibrate = v),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      TextButton(onPressed: _saving ? null : () => _save(start: false), child: const Text('Save')),
      FilledButton(onPressed: _saving ? null : () => _save(start: true), child: const Text('Start')),
    ],
  );

  Future<void> _save({required bool start}) async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final seconds = Fmt.parseDuration(_duration.text)!;
    final custom = _custom ? Fmt.parseDuration(_exerciseDuration.text)! : null;
    final ok = await attempt(
      context,
      () => ref.read(databaseProvider).transaction(() async {
        await ref
            .read(settingsRepositoryProvider)
            .update(
              AppSettingsCompanion(
                restTimerSeconds: Value(seconds),
                restTimerAutoStart: Value(_auto),
                restTimerSound: Value(_sound),
                restTimerVibrate: Value(_vibrate),
              ),
            );
        if (widget.exercise != null) {
          await ref.read(exerciseRepositoryProvider).setRestDuration(widget.exercise!.id, custom);
        }
      }),
    );
    if (!mounted) return;
    if (ok) {
      if (start) {
        ref
            .read(restTimerProvider.notifier)
            .start(custom ?? seconds, label: widget.exercise?.name ?? 'Rest', sound: _sound, vibrate: _vibrate);
      }
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
    }
  }
}
