import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/database/database.dart';
import '../../core/import/csv_importer.dart';
import '../../core/import/fitnotes_importer.dart';
import '../../core/providers.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/device_service.dart';
import '../../core/services/rest_timer.dart';
import '../../core/util/dates.dart';
import '../../core/util/format.dart';
import '../../shared/widgets.dart';
import '../../shared/rest_sound_tile.dart';

Future<File> _recoveryFile() async => File('${(await getApplicationDocumentsDirectory()).path}/fitnotes-before-restore.sqlite');
final _recoveryProvider = FutureProvider.autoDispose((ref) async => (await _recoveryFile()).exists());

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _busy;
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final units = ref.watch(unitsProvider);
    final season = ref.watch(seasonsProvider).asData?.value.firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ContentWidth(
        child: settings.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => ErrorState(onRetry: () => ref.invalidate(settingsProvider)),
          data: (s) => ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              const SectionTitle('General'),
              Card(
                child: Column(
                  children: [
                    _tile(
                      Icons.palette_outlined,
                      'Appearance',
                      const ['Follow system', 'Light', 'Dark'][s.themeMode.clamp(0, 2)],
                      () async {
                        final choice = await _pick('Appearance', const {0: 'Follow system', 1: 'Light', 2: 'Dark'}, s.themeMode);
                        if (choice != null) await _update(AppSettingsCompanion(themeMode: Value(choice)));
                      },
                    ),
                    _tile(
                      Icons.straighten_rounded,
                      'Units',
                      s.useImperial ? 'Pounds & miles' : 'Kilograms & kilometers',
                      () async {
                        final choice = await _pick('Units', const {
                          false: 'Kilograms & kilometers',
                          true: 'Pounds & miles',
                        }, s.useImperial);
                        if (choice != null) await _update(AppSettingsCompanion(useImperial: Value(choice)));
                      },
                    ),
                  ],
                ),
              ),
              const SectionTitle('Logging'),
              Card(
                child: Column(
                  children: [
                    _tile(Icons.exposure_plus_1_rounded, 'Weight increment', units.weight(s.defaultWeightIncrement), () async {
                      final value = await prompt(
                        context,
                        title: 'Weight increment',
                        label: 'Increment (${units.weightLabel})',
                        value: Fmt.number(units.weightFromKg(s.defaultWeightIncrement)),
                        maxLength: 8,
                        keyboard: const TextInputType.numberWithOptions(decimal: true),
                        validate: (v) {
                          final n = double.tryParse(v);
                          return n != null && n.isFinite && n > 0 && n <= 100 ? null : 'Use a number greater than 0, up to 100.';
                        },
                      );
                      if (value != null) {
                        await _update(
                          AppSettingsCompanion(
                            defaultWeightIncrement: Value(
                              value == Fmt.number(units.weightFromKg(s.defaultWeightIncrement))
                                  ? s.defaultWeightIncrement
                                  : units.weightToKg(double.parse(value)),
                            ),
                          ),
                        );
                      }
                    }),
                    _switch(
                      Icons.check_box_outlined,
                      'Completion checkboxes',
                      'Show a checkbox beside each set',
                      s.markSetsComplete,
                      (v) => _update(AppSettingsCompanion(markSetsComplete: Value(v))),
                    ),
                    _switch(
                      Icons.screen_lock_portrait_outlined,
                      'Keep screen on',
                      'While the app is open',
                      s.keepScreenOn,
                      (v) => _update(AppSettingsCompanion(keepScreenOn: Value(v))),
                    ),
                  ],
                ),
              ),
              const SectionTitle('Rest timer'),
              Card(
                child: Column(
                  children: [
                    _tile(Icons.timer_outlined, 'Default duration', Fmt.duration(s.restTimerSeconds), () async {
                      final value = await prompt(
                        context,
                        title: 'Rest duration',
                        label: 'Time (m:ss or seconds)',
                        value: Fmt.duration(s.restTimerSeconds),
                        maxLength: 8,
                        keyboard: TextInputType.datetime,
                        validate: (v) => (Fmt.parseDuration(v) ?? 0) >= 1 && (Fmt.parseDuration(v) ?? 3601) <= 3600
                            ? null
                            : 'Use 1 second to 60 minutes.',
                      );
                      if (value != null) await _update(AppSettingsCompanion(restTimerSeconds: Value(Fmt.parseDuration(value)!)));
                    }),
                    _switch(
                      Icons.play_circle_outline_rounded,
                      'Auto-start after a set',
                      null,
                      s.restTimerAutoStart,
                      (v) => _update(AppSettingsCompanion(restTimerAutoStart: Value(v))),
                    ),
                    _switch(
                      Icons.volume_up_outlined,
                      'Sound',
                      null,
                      s.restTimerSound,
                      (v) => _update(AppSettingsCompanion(restTimerSound: Value(v))),
                    ),
                    if (s.restTimerSound)
                      RestSoundTile(
                        uri: s.restTimerSoundUri,
                        onChanged: (uri) => _update(AppSettingsCompanion(restTimerSoundUri: Value(uri))),
                      ),
                    _switch(
                      Icons.vibration_rounded,
                      'Vibration',
                      null,
                      s.restTimerVibrate,
                      (v) => _update(AppSettingsCompanion(restTimerVibrate: Value(v))),
                    ),
                    if (DeviceService.nativeTimers)
                      _tile(
                        Icons.notifications_outlined,
                        'Timer notifications',
                        'Android notification settings',
                        () => attempt(context, () async {
                          await DeviceService.call('notificationSettings');
                        }),
                      ),
                  ],
                ),
              ),
              const SectionTitle('Progress'),
              Card(
                child: Column(
                  children: [
                    _switch(
                      Icons.emoji_events_outlined,
                      'Highlight personal records',
                      null,
                      s.trackPersonalRecords,
                      (v) => _update(AppSettingsCompanion(trackPersonalRecords: Value(v))),
                    ),
                    _tile(
                      Icons.auto_graph_rounded,
                      'Max-weight estimate',
                      'Use sets up to ${s.estimated1rmMaxReps == 0 ? 36 : s.estimated1rmMaxReps} reps',
                      () async {
                        final value = await _pick(
                          'Max-weight estimate',
                          const {8: '8 reps', 10: '10 reps', 12: '12 reps', 15: '15 reps', 20: '20 reps', 0: '36 reps'},
                          s.estimated1rmMaxReps,
                          explanation: 'Estimates the weight you could lift once. Sets above this rep count are ignored.',
                        );
                        if (value != null) await _update(AppSettingsCompanion(estimated1rmMaxReps: Value(value)));
                      },
                    ),
                    _tile(
                      Icons.emoji_events_outlined,
                      'Manage seasons',
                      season == null
                          ? 'Tracking all-time records'
                          : '${season.note?.isNotEmpty == true ? season.note : 'Current season'} · since ${season.date}',
                      () => context.push('/seasons'),
                    ),
                  ],
                ),
              ),
              const SectionTitle('Data'),
              if (_busy != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(children: [const LinearProgressIndicator(), const SizedBox(height: 8), Text(_busy!)]),
                ),
              Card(
                child: Column(
                  children: [
                    _tile(
                      Icons.save_alt_rounded,
                      'Save full backup',
                      'Workouts, routines, measurements, and settings',
                      _busy == null ? () => _export(false) : null,
                    ),
                    _tile(
                      Icons.table_view_outlined,
                      'Export workout CSV',
                      'Logged sets in FitNotes-compatible format',
                      _busy == null ? () => _export(true) : null,
                    ),
                    _tile(
                      Icons.restore_rounded,
                      'Restore full backup',
                      'Replace data from a .fitnotesplus file',
                      _busy == null ? () => _import('restore') : null,
                    ),
                    if (ref.watch(_recoveryProvider).asData?.value == true)
                      _tile(
                        Icons.undo_rounded,
                        'Undo last restore',
                        'Recover the data saved before your last restore',
                        _busy == null ? _undoRestore : null,
                      ),
                    _tile(
                      Icons.file_download_outlined,
                      'Import FitNotes backup',
                      'Merge exercises, sets, and workout notes',
                      _busy == null ? () => _import('fitnotes') : null,
                    ),
                    _tile(
                      Icons.upload_file_outlined,
                      'Import workout CSV',
                      'Merge workouts from a CSV file',
                      _busy == null ? () => _import('csv') : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(IconData icon, String title, String subtitle, VoidCallback? tap) => Semantics(
    container: true,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      minLeadingWidth: 24,
      horizontalTitleGap: 12,
      leading: Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 19),
      onTap: tap,
      enabled: tap != null,
    ),
  );
  Widget _switch(IconData icon, String title, String? subtitle, bool value, ValueChanged<bool> change) => ListTileTheme(
    data: const ListTileThemeData(minLeadingWidth: 24, horizontalTitleGap: 12),
    child: SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      secondary: Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: change,
    ),
  );
  Future<void> _update(AppSettingsCompanion changes) =>
      attempt(context, () => ref.read(settingsRepositoryProvider).update(changes));
  Future<T?> _pick<T>(String title, Map<T, String> options, T current, {String? explanation}) => showDialog<T>(
    context: context,
    builder: (context) => AppDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (explanation != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(explanation)),
          for (final option in options.entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              titleTextStyle: Theme.of(context).textTheme.bodyMedium,
              title: Text(option.value),
              trailing: option.key == current ? const Icon(Icons.check_rounded) : null,
              onTap: () => Navigator.pop(context, option.key),
            ),
        ],
      ),
    ),
  );

  Future<void> _export(bool csv) async {
    setState(() => _busy = csv ? 'Preparing CSV…' : 'Preparing backup…');
    final backup = BackupService(ref.read(databaseProvider));
    await attempt(context, () async {
      final bytes = csv ? await backup.csv() : await backup.backup();
      final saved = await DeviceService.saveFile(
        'FitNotes-${Dates.today()}.${csv ? 'csv' : 'fitnotesplus'}',
        bytes,
        mime: csv ? 'text/csv' : 'application/octet-stream',
      );
      if (saved && mounted) notice(context, csv ? 'Workout CSV saved' : 'Full backup saved');
    });
    if (mounted) setState(() => _busy = null);
  }

  Future<void> _import(String kind) async {
    final db = ref.read(databaseProvider);
    final service = BackupService(db);
    final timer = ref.read(restTimerProvider.notifier);
    final file = await openFile();
    if (file == null || !mounted) return;
    setState(() => _busy = kind == 'csv' ? 'Importing CSV…' : 'Reading backup…');
    await attempt(context, () async {
      if (kind == 'csv') {
        final bytes = await file.readAsBytes();
        final result = await CsvImporter(db).import(utf8.decode(bytes));
        if (mounted) notice(context, '${result.sets} sets imported');
        return;
      }
      final directory = await getTemporaryDirectory();
      final temp = File('${directory.path}/fitnotes-import-${DateTime.now().microsecondsSinceEpoch}.sqlite');
      try {
        await temp.writeAsBytes(await file.readAsBytes());
        if (kind == 'fitnotes') {
          final result = await FitNotesImporter(db).importFromFile(temp.path);
          if (mounted) notice(context, '${result.sets} sets and ${result.exercises} exercises imported');
        } else {
          final counts = await service.inspect(temp.path);
          if (!mounted ||
              !await confirm(
                context,
                title: 'Restore this backup?',
                message:
                    'Replace the current data with ${Fmt.count(counts['workout_sets']!, 'set')}, ${Fmt.count(counts['routines']!, 'routine')}, and ${Fmt.count(counts['measurements']!, 'measurement')}? A recovery copy will let you undo this restore.',
                action: 'Restore',
              ) ||
              !mounted) {
            return;
          }
          final recovery = await _recoveryFile();
          await recovery.writeAsBytes(await service.backup());
          await service.restore(temp.path);
          timer.stop();
          if (mounted) ref.invalidate(_recoveryProvider);
          if (mounted) notice(context, 'Backup restored');
        }
      } finally {
        if (await temp.exists()) await temp.delete();
      }
    });
    if (mounted) setState(() => _busy = null);
  }

  Future<void> _undoRestore() async {
    if (!await confirm(
          context,
          title: 'Undo last restore?',
          message: 'Return to the data saved immediately before the last restore? Changes made since then will be replaced.',
          action: 'Recover',
        ) ||
        !mounted) {
      return;
    }
    setState(() => _busy = 'Recovering previous data…');
    await attempt(context, () async {
      final recovery = await _recoveryFile();
      await BackupService(ref.read(databaseProvider)).restore(recovery.path);
      await recovery.delete();
      ref.invalidate(_recoveryProvider);
      if (mounted) notice(context, 'Previous data recovered');
    });
    if (mounted) setState(() => _busy = null);
  }
}
