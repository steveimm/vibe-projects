import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../shared/widgets.dart';
import '../../core/util/format.dart';

class RoutinesScreen extends ConsumerWidget {
  const RoutinesScreen({super.key, this.date});
  final String? date;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: const Text('Routines'),
      actions: [
        IconButton.filled(
          tooltip: 'New routine',
          style: IconButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onPrimary),
          icon: const Icon(Icons.add_rounded),
          onPressed: () => _create(context, ref),
        ),
      ],
    ),
    body: ContentWidth(
      child: ref
          .watch(routinesProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => ErrorState(onRetry: () => ref.invalidate(routinesProvider)),
            data: (routines) {
              if (routines.isEmpty) {
                return const Center(child: Text('No routines'));
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                children: [
                  for (final routine in routines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          minTileHeight: 64,
                          titleTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          title: Text(routine.name),
                          subtitleTextStyle: Theme.of(context).textTheme.bodySmall,
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              routine.notes.isEmpty
                                  ? Fmt.count(ref.watch(routineDaysProvider(routine.id)).asData?.value.length ?? 0, 'day')
                                  : routine.notes,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push('/routine/${routine.id}${date == null ? '' : '?date=$date'}'),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
    ),
  );

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await prompt(context, title: 'New routine', label: 'Name', maxLength: 100);
    if (name == null || !context.mounted) return;
    await attempt(context, () async {
      final id = await ref.read(routineRepositoryProvider).create(name);
      if (context.mounted) context.push('/routine/$id${date == null ? '' : '?date=$date'}');
    });
  }
}
