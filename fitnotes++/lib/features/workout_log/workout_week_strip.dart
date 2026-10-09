import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/util/dates.dart';
import 'workout_day_dots.dart';

class WorkoutWeekStrip extends StatefulWidget {
  const WorkoutWeekStrip({
    super.key,
    required this.date,
    required this.firstDayOfWeek,
    required this.dayColors,
    required this.onSelectDay,
  });
  final String date;
  final int firstDayOfWeek;
  final Map<String, List<int>> dayColors;
  final ValueChanged<String> onSelectDay;

  @override
  State<WorkoutWeekStrip> createState() => _WorkoutWeekStripState();
}

class _WorkoutWeekStripState extends State<WorkoutWeekStrip> {
  static const _origin = 10000;
  late String _anchor = _weekStart(widget.date);
  final _controller = PageController(initialPage: _origin);

  String _weekStart(String date) => Dates.shift(date, -((Dates.parse(date).weekday - widget.firstDayOfWeek + 7) % 7));

  @override
  void didUpdateWidget(WorkoutWeekStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    var page = _origin + Dates.daysBetween(_anchor, _weekStart(widget.date)) ~/ 7;
    if (oldWidget.firstDayOfWeek != widget.firstDayOfWeek || page < 0) {
      _anchor = _weekStart(widget.date);
      page = _origin;
    }
    if (_controller.hasClients && (_controller.page ?? _origin).round() != page) _controller.jumpToPage(page);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context);
    final numberHeight = math.max(28.0, scale.scale(16) * 1.25 + 4);
    return SizedBox(
      height: scale.scale(12) + numberHeight + 19,
      child: PageView.builder(
        controller: _controller,
        onPageChanged: (page) {
          final first = Dates.shift(_anchor, (page - _origin) * 7);
          final day = Dates.shift(first, (Dates.parse(widget.date).weekday - widget.firstDayOfWeek + 7) % 7);
          if (day != widget.date) widget.onSelectDay(day);
        },
        itemBuilder: (context, page) {
          final first = Dates.shift(_anchor, (page - _origin) * 7);
          return Row(
            key: ValueKey(first),
            children: [for (var i = 0; i < 7; i++) Expanded(child: _day(context, Dates.shift(first, i), numberHeight))],
          );
        },
      ),
    );
  }

  Widget _day(BuildContext context, String day, double numberHeight) {
    final theme = Theme.of(context);
    final selected = day == widget.date;
    final colors = widget.dayColors[day] ?? const <int>[];
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: '${Dates.longDate(day)}${colors.isEmpty ? '' : ', workout day'}',
      onTap: () => widget.onSelectDay(day),
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => widget.onSelectDay(day),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                Text(
                  DateFormat('E').format(Dates.parse(day)).substring(0, 1),
                  style: theme.textTheme.bodySmall?.copyWith(height: 1, color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Container(
                  height: numberHeight,
                  constraints: const BoxConstraints(minWidth: 30),
                  alignment: Alignment.center,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: selected ? theme.colorScheme.primary : null,
                    borderRadius: BorderRadius.circular(8),
                    border: day == Dates.today() && !selected ? Border.all(color: theme.colorScheme.primary) : null,
                  ),
                  child: Text(
                    '${Dates.parse(day).day}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      height: 1.25,
                      color: selected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                WorkoutDayDots(colors: colors),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
