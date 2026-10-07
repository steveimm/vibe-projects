import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/tables.dart';
import '../../core/providers.dart';
import '../../core/repositories/workout_repository.dart';
import '../../core/util/dates.dart';
import '../../core/util/format.dart';

/// A vertically-scrolling, continuous month calendar that marks each workout
/// day with its category-color dots (mirrors FitNotes). Tapping a selectable
/// day calls [onSelectDay].
class WorkoutCalendar extends StatefulWidget {
  const WorkoutCalendar({super.key, required this.dayColors, required this.onSelectDay, this.initialMonth, this.selectable});

  final Map<String, List<int>> dayColors;
  final void Function(String isoDate) onSelectDay;
  final String? initialMonth;
  final bool Function(String isoDate)? selectable;

  @override
  State<WorkoutCalendar> createState() => _WorkoutCalendarState();
}

class _WorkoutCalendarState extends State<WorkoutCalendar> {
  // Fixed sub-heights so the initial scroll offset can be computed exactly.
  static const _headerH = 48.0;
  static const _weekdayH = 26.0;
  static const _cellH = 48.0;
  static const _padH = 8.0;
  static const _weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  late final List<DateTime> _months;
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _months = _buildMonths();
    _controller = ScrollController(initialScrollOffset: _offsetTo(_initialIndex()));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<DateTime> _buildMonths() {
    final refs = <DateTime>[
      ...widget.dayColors.keys.map(Dates.parse),
      Dates.parse(widget.initialMonth ?? Dates.today()),
      Dates.parse(Dates.today()),
    ];
    var minD = refs.first, maxD = refs.first;
    for (final d in refs) {
      if (d.isBefore(minD)) minD = d;
      if (d.isAfter(maxD)) maxD = d;
    }
    final start = DateTime(minD.year, minD.month);
    final end = DateTime(maxD.year, maxD.month + 2); // small future buffer
    final out = <DateTime>[];
    var m = start;
    while (!m.isAfter(end)) {
      out.add(m);
      m = DateTime(m.year, m.month + 1);
    }
    return out;
  }

  int _weeks(DateTime m) {
    final days = DateTime(m.year, m.month + 1, 0).day;
    final leading = DateTime(m.year, m.month, 1).weekday - 1; // Mon = 0
    return ((leading + days) / 7).ceil();
  }

  double _monthHeight(DateTime m) => _headerH + _weekdayH + _weeks(m) * _cellH + _padH;

  int _initialIndex() {
    final ref = Dates.parse(widget.initialMonth ?? Dates.today());
    final i = _months.indexWhere((m) => m.year == ref.year && m.month == ref.month);
    return i < 0 ? 0 : i;
  }

  double _offsetTo(int index) {
    var o = 0.0;
    for (var i = 0; i < index; i++) {
      o += _monthHeight(_months[i]);
    }
    return o;
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(controller: _controller, itemCount: _months.length, itemBuilder: (_, i) => _monthBlock(_months[i]));
  }

  Widget _monthBlock(DateTime m) {
    final theme = Theme.of(context);
    final weeks = _weeks(m);
    final days = DateTime(m.year, m.month + 1, 0).day;
    final leading = DateTime(m.year, m.month, 1).weekday - 1;
    final cells = <int?>[...List.filled(leading, null), for (var d = 1; d <= days; d++) d];
    while (cells.length < weeks * 7) {
      cells.add(null);
    }
    return Column(
      children: [
        SizedBox(
          height: _headerH,
          child: Center(
            child: Text(Dates.monthLabel(m), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
        ),
        SizedBox(
          height: _weekdayH,
          child: Row(
            children: [
              for (final w in _weekdays)
                Expanded(
                  child: Center(
                    child: Text(w, style: TextStyle(fontSize: 11, color: theme.hintColor)),
                  ),
                ),
            ],
          ),
        ),
        for (var i = 0; i < cells.length; i += 7)
          SizedBox(
            height: _cellH,
            child: Row(children: [for (var j = i; j < i + 7; j++) Expanded(child: _cell(m, cells[j]))]),
          ),
        const SizedBox(height: _padH),
      ],
    );
  }

  Widget _cell(DateTime m, int? day) {
    if (day == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final dateStr = Dates.iso(DateTime(m.year, m.month, day));
    final colors = widget.dayColors[dateStr] ?? const <int>[];
    final isToday = dateStr == Dates.today();
    final canSelect = widget.selectable?.call(dateStr) ?? true;

    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: isToday ? BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle) : null,
          child: Text(
            '$day',
            style: TextStyle(
              color: isToday ? theme.colorScheme.onPrimary : (canSelect ? theme.colorScheme.onSurface : theme.disabledColor),
            ),
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          height: 6,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final c in colors.take(4))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    if (!canSelect) return content;
    return InkWell(onTap: () => widget.onSelectDay(dateStr), child: content);
  }
}

class _CalendarScreen extends StatefulWidget {
  const _CalendarScreen({required this.dayColors, required this.initialDate, required this.onDayTap, this.selectable});

  final Map<String, List<int>> dayColors;
  final String initialDate;
  final bool Function(String)? selectable;
  final void Function(BuildContext, String) onDayTap;

  @override
  State<_CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<_CalendarScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${widget.dayColors.length} workouts'), duration: const Duration(seconds: 2)));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: WorkoutCalendar(
        dayColors: widget.dayColors,
        initialMonth: widget.initialDate,
        selectable: widget.selectable,
        onSelectDay: (d) => widget.onDayTap(context, d),
      ),
    );
  }
}

/// Browse calendar (top-bar icon). Tapping a workout day shows its workout with
/// a Go To action; tapping an empty day jumps straight there. Returns the day
/// to navigate to (or null).
Future<String?> openWorkoutCalendar(BuildContext context, WidgetRef ref, {required String initialDate}) async {
  final colors = await ref.read(workoutRepositoryProvider).workoutDayCategoryColors();
  if (!context.mounted) return null;
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => _CalendarScreen(
        dayColors: colors,
        initialDate: initialDate,
        onDayTap: (ctx, d) async {
          if (colors.containsKey(d)) {
            final go = await _showDayDetail(ctx, ref, d);
            if (go == true && ctx.mounted) Navigator.of(ctx).pop(d);
          } else {
            Navigator.of(ctx).pop(d);
          }
        },
      ),
    ),
  );
}

/// Copy day-picker: only [selectableDays] are tappable; tapping returns the day.
Future<String?> pickCopyDay(
  BuildContext context,
  WidgetRef ref, {
  required String initialDate,
  required Set<String> selectableDays,
}) async {
  final colors = await ref.read(workoutRepositoryProvider).workoutDayCategoryColors();
  if (!context.mounted) return null;
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => _CalendarScreen(
        dayColors: colors,
        initialDate: initialDate,
        selectable: selectableDays.contains,
        onDayTap: (ctx, d) => Navigator.of(ctx).pop(d),
      ),
    ),
  );
}

Future<bool?> _showDayDetail(BuildContext context, WidgetRef ref, String date) async {
  final sets = await ref.read(workoutRepositoryProvider).dayLog(date);
  if (!context.mounted) return null;
  return showDialog<bool>(
    context: context,
    builder: (_) => _DayDetailDialog(date: date, sets: sets),
  );
}

class _DayDetailDialog extends StatelessWidget {
  const _DayDetailDialog({required this.date, required this.sets});
  final String date;
  final List<LoggedSet> sets;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final order = <int>[];
    final groups = <int, List<LoggedSet>>{};
    for (final s in sets) {
      groups
          .putIfAbsent(s.set.exerciseId, () {
            order.add(s.set.exerciseId);
            return <LoggedSet>[];
          })
          .add(s);
    }
    return AlertDialog(
      title: Text(Dates.longDate(date), style: TextStyle(color: accent)),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: sets.isEmpty
            ? const Text('No workout on this day')
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [for (final id in order) ..._exerciseBlock(context, groups[id]!, accent)],
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Go To')),
      ],
    );
  }

  List<Widget> _exerciseBlock(BuildContext context, List<LoggedSet> ex, Color accent) {
    final type = ExerciseType.values[ex.first.exerciseType];
    return [
      Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: Text(ex.first.exerciseName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      Container(height: 1.5, color: accent),
      for (final s in ex)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              for (final col in _columns(type, s))
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: col.$1,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        if (col.$2.isNotEmpty)
                          TextSpan(
                            text: ' ${col.$2}',
                            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                          ),
                      ],
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
            ],
          ),
        ),
    ];
  }

  List<(String, String)> _columns(ExerciseType type, LoggedSet s) => setColumns(
    type: type,
    weight: s.effectiveWeight,
    reps: s.set.reps,
    distance: s.set.distance,
    seconds: s.set.durationSeconds,
  );
}
