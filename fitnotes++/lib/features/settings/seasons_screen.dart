import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
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
        minTileHeight: 64,
        minVerticalPadding: 8,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
          children: [
            const Text('A season tracks personal records from a chosen date without deleting past workouts.'),
            const SizedBox(height: 12),
            const Card(
              child: ListTile(
                leading: RecordBadge(scope: RecordScope.allTime, size: 24),
                title: Text('All-time records'),
              ),
            ),
            const SizedBox(height: 8),
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
                            child: ListTile(
                              leading: i == 0
                                  ? const RecordBadge(scope: RecordScope.currentSeason, size: 24)
                                  : const Icon(Icons.history_rounded),
                              title: Text(
                                seasons[i].note?.isNotEmpty == true ? seasons[i].note! : 'Season ${seasons.length - i}',
                              ),
                              subtitle: Text('Since ${seasons[i].date}${i == 0 ? ' · Current season' : ''}'),
                              trailing: IconButton(
                                tooltip: 'Remove reset',
                                icon: const Icon(Icons.delete_outline_rounded),
                                onPressed: () async {
                                  if (await confirm(
                                        context,
                                        title: 'Remove this reset?',
                                        message: 'The previous season will apply if this is the current reset. Your workouts remain unchanged.',
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
  const _SeasonDialog();
  @override
  ConsumerState<_SeasonDialog> createState() => _SeasonDialogState();
}

class _SeasonDialogState extends ConsumerState<_SeasonDialog> {
  final _name = TextEditingController();
  String _date = Dates.today();
  bool _busy = false;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: const Text('Start a PR season'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _name,
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Name (optional)', hintText: 'e.g. Autumn training'),
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
                final ok = await attempt(context, () => ref.read(progressRepositoryProvider).startSeason(_date, _name.text));
                if (!context.mounted) return;
                if (ok) {
                  Navigator.pop(context);
                } else {
                  setState(() => _busy = false);
                }
              },
        child: const Text('Start season'),
      ),
    ],
  );
}
