import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../shared/widgets.dart';

class RoutinesScreen extends ConsumerWidget {
  const RoutinesScreen({super.key, this.date});
  final String? date;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: const Text('Routines'),
      actions: [IconButton(tooltip: 'New routine', icon: const Icon(Icons.add_rounded), onPressed: () => _create(context, ref))],
    ),
    body: ContentWidth(
      child: ref
          .watch(routinesProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => ErrorState(onRetry: () => ref.invalidate(routinesProvider)),
            data: (routines) {
              if (routines.isEmpty) {
                return SingleChildScrollView(
                  child: EmptyState(
                    icon: Icons.view_week_outlined,
                    title: 'A plan you can repeat',
                    message:
                        'Build a routine with training days and preset sets. Leave values blank to reuse your previous session.',
                    action: FilledButton.icon(
                      onPressed: () => _create(context, ref),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create a routine'),
                    ),
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Text('Plan once. Keep showing up.', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Templates keep your favorite sessions a tap away.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  for (final routine in routines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Entrance(
                        child: Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(18),
                            leading: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.view_week_outlined),
                            ),
                            title: Text(routine.name, style: Theme.of(context).textTheme.titleMedium),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text(
                                routine.notes.isEmpty
                                    ? '${ref.watch(routineDaysProvider(routine.id)).asData?.value.length ?? 0} training days'
                                    : routine.notes,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => context.push('/routine/${routine.id}${date == null ? '' : '?date=$date'}'),
                          ),
                        ),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => _create(context, ref),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('New routine'),
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
