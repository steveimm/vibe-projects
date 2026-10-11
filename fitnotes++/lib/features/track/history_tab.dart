import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/database/database.dart';
import '../../core/providers.dart';
import '../../core/util/dates.dart';
import '../../core/util/format.dart';
import '../../shared/widgets.dart';
import '../../shared/record_badge.dart';

class HistoryTab extends ConsumerWidget {
  const HistoryTab({super.key, required this.exercise});
  final Exercise exercise;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(exerciseHistoryProvider(exercise.id));
    final prs = ref.watch(recordBadgesProvider(exercise.id));
    final units = ref.watch(unitsProvider);
    return history.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => ErrorState(onRetry: () => ref.invalidate(exerciseHistoryProvider(exercise.id))),
      data: (sets) {
        if (sets.isEmpty) {
          return const SingleChildScrollView(
            child: EmptyState(icon: Icons.history_rounded, title: 'No history'),
          );
        }
        final days = <String, List<WorkoutSet>>{};
        for (final s in sets) {
          (days[s.date] ??= []).add(s);
        }
        final entries = days.entries.toList();
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          itemCount: entries.length,
          itemBuilder: (_, i) {
            final entry = entries[i];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(
                  DateFormat('EEE, d MMM yyyy').format(Dates.parse(entry.key)),
                  trailing: TextButton(
                    onPressed: () => context.push('/log/${exercise.id}?date=${entry.key}'),
                    child: const Text('Open'),
                  ),
                ),
                Card(
                  child: Column(
                    children: [
                      for (var j = 0; j < entry.value.length; j++) ...[
                        if (j > 0) const Divider(indent: 16, endIndent: 16),
                        ListTile(
                          minTileHeight: 48,
                          minVerticalPadding: 4,
                          leading: Text(
                            '${j + 1}'.padLeft(2, '0'),
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                          title: Text(
                            describeSet(
                              type: exercise.type,
                              effectiveWeight: entry.value[j].effectiveWeight,
                              reps: entry.value[j].reps,
                              distance: entry.value[j].distance,
                              durationSeconds: entry.value[j].durationSeconds,
                              units: units,
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: entry.value[j].isPlanned
                              ? const Text('Not completed')
                              : entry.value[j].note?.isNotEmpty == true
                              ? Text(entry.value[j].note!)
                              : null,
                          trailing: prs.containsKey(entry.value[j].id) ? RecordBadge(scope: prs[entry.value[j].id]!) : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
