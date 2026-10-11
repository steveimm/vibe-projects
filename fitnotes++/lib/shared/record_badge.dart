import 'package:flutter/material.dart';

import '../core/repositories/stats_repository.dart';

class RecordBadge extends StatelessWidget {
  const RecordBadge({super.key, required this.scope, this.size = 18});
  final RecordScope scope;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final allTime = scope == RecordScope.allTime;
    return Tooltip(
      message: allTime ? 'All-time record' : 'Current-season record',
      child: Icon(
        Icons.emoji_events_rounded,
        size: size,
        color: allTime
            ? dark
                  ? const Color(0xFFE0B35A)
                  : const Color(0xFFAE7A25)
            : dark
            ? const Color(0xFFC1CAD1)
            : const Color(0xFF7C8994),
      ),
    );
  }
}
