import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/providers.dart';
import '../../core/models/season.dart';
import '../../core/util/dates.dart';
import '../../shared/widgets.dart';
import '../../shared/record_badge.dart';
import '../../core/repositories/stats_repository.dart';

class SeasonsScreen extends ConsumerWidget {
  const SeasonsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('PR seasons')),
    floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    floatingActionButton: AppFloatingActionButton(
      tooltip: 'Start a season',
      onPressed: () => showDialog(context: context, builder: (_) => const _SeasonDialog()),
    ),
    body: ContentWidth(
      child: ListTileTheme.merge(
        minTileHeight: 56,
        minVerticalPadding: 4,
        horizontalTitleGap: 8,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
          children: [
            const Card(
              child: ListTile(
                leading: SizedBox(width: 60, child: RecordBadge(scope: RecordScope.allTime, size: 20)),
                title: Text('All-time records'),
              ),
            ),
            const SizedBox(height: 6),
            ref
                .watch(seasonsProvider)
                .when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => ErrorState(onRetry: () => ref.invalidate(seasonsProvider)),
                  data: (seasons) => Column(
                    children: [
                      for (var i = 0; i < seasons.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Card(
                            key: ValueKey('season-${seasons[i].id}'),
                            child: ListTile(
                              onTap: () => showDialog(
                                context: context,
                                builder: (_) => _SeasonDialog(season: seasons[i]),
                              ),
                              leading: SizedBox(
                                width: 60,
                                child: RecordBadge(scope: RecordScope.season, season: seasons[i], size: 20),
                              ),
                              title: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(seasons[i].displayName),
                                  Text(
                                    '${seasons[i].date}${i == 0 ? ' · Current' : ''}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                tooltip: 'Remove season',
                                icon: const Icon(Icons.delete_outline_rounded),
                                onPressed: () async {
                                  if (await confirm(
                                        context,
                                        title: 'Remove season?',
                                        message:
                                            'Remove ${seasons[i].displayName}? This changes the PR dates. Your sets stay in history.',
                                        action: 'Remove',
                                      ) &&
                                      context.mounted) {
                                    await attempt(
                                      context,
                                      () => ref.read(progressRepositoryProvider).deleteSeason(seasons[i].id),
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
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

class _SeasonDialog extends ConsumerStatefulWidget {
  const _SeasonDialog({this.season});
  final PrResetMarker? season;
  @override
  ConsumerState<_SeasonDialog> createState() => _SeasonDialogState();
}

class _SeasonDialogState extends ConsumerState<_SeasonDialog> {
  late final _name = TextEditingController(text: widget.season?.note ?? '');
  late final _initials = TextEditingController(text: widget.season?.initials ?? '');
  late String _date = widget.season?.date ?? Dates.today();
  bool _busy = false;
  @override
  void dispose() {
    _name.dispose();
    _initials.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: Text(widget.season == null ? 'Start a PR season' : 'Edit PR season'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _name,
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Name (optional)', hintText: 'Autumn training', counterText: ''),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _initials,
          maxLength: 80,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: 'Initials (optional)',
            floatingLabelBehavior: FloatingLabelBehavior.always,
            hintText: initialsFromName(
              _name.text.trim().isEmpty && widget.season != null ? 'Season ${widget.season!.id}' : _name.text,
            ),
            counterText: '',
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_date),
          subtitle: const Text('Records from this day onward'),
          trailing: const Icon(Icons.event_outlined),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: Dates.parse(_date),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (date != null && mounted) setState(() => _date = Dates.iso(date));
          },
        ),
      ],
    ),
    actions: [
      TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(
        onPressed: _busy
            ? null
            : () async {
                setState(() => _busy = true);
                final ok = await attempt(context, () {
                  final repo = ref.read(progressRepositoryProvider);
                  return widget.season == null
                      ? repo.startSeason(_date, _name.text, initials: _initials.text)
                      : repo.updateSeason(widget.season!.id, _date, _name.text, initials: _initials.text);
                });
                if (!context.mounted) return;
                if (ok) {
                  Navigator.pop(context);
                } else {
                  setState(() => _busy = false);
                }
              },
        child: Text(widget.season == null ? 'Start season' : 'Save'),
      ),
    ],
  );
}
