import 'package:flutter/material.dart';

import '../core/database/database.dart';
import '../core/models/season.dart';
import '../core/repositories/stats_repository.dart';

class RecordBadge extends StatelessWidget {
  const RecordBadge({super.key, required this.scope, this.season, this.size = 18});
  RecordBadge.achievement(RecordAchievement achievement, {super.key, this.size = 18})
    : scope = achievement.scope,
      season = achievement.season;
  final RecordScope scope;
  final PrResetMarker? season;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final allTime = scope == RecordScope.allTime;
    final color = allTime
        ? dark
              ? const Color(0xFFE0B35A)
              : const Color(0xFFAE7A25)
        : dark
        ? const Color(0xFFC1CAD1)
        : const Color(0xFF7C8994);
    final label = allTime ? null : season?.displayInitials;
    return Tooltip(
      message: allTime
          ? 'All-time record'
          : season == null
          ? 'Season record'
          : 'Season record · ${season!.displayName} · ${season!.date}',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 72),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_rounded, size: size, color: color),
            if (label != null) ...[
              const SizedBox(width: 3),
              Flexible(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
