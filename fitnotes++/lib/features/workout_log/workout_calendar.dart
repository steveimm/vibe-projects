import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets.dart';
import 'workout_day_dots.dart';

import '../../core/database/tables.dart';
import '../../core/providers.dart';
import '../../core/repositories/workout_repository.dart';
import '../../core/util/dates.dart';
import '../../core/util/format.dart';

/// A vertically-scrolling, continuous month calendar that marks each workout
/// day with its category-color dots (mirrors FitNotes). Tapping a selectable
/// day calls [onSelectDay].
class WorkoutCalendar extends StatefulWidget {
  const WorkoutCalendar({
    super.key,
    required this.dayColors,
    required this.onSelectDay,
    this.initialMonth,
    this.selectable,
    this.firstDayOfWeek = 1,
  });

  final Map<String, List<int>> dayColors;
  final void Function(String isoDate) onSelectDay;
  final String? initialMonth;
  final int firstDayOfWeek;
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
    final start = DateTime(minD.year, minD.month - 12);
    final end = DateTime(maxD.year, maxD.month + 12); // small future buffer
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
    final leading = (DateTime(m.year, m.month, 1).weekday - widget.firstDayOfWeek + 7) % 7; // Mon = 0
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
    final leading = (DateTime(m.year, m.month, 1).weekday - widget.firstDayOfWeek + 7) % 7;
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
              for (final w in List.generate(7, (i) => _weekdays[(widget.firstDayOfWeek - 1 + i) % 7]))
                Expanded(
                  child: Center(
                    child: Text(w, style: TextStyle(fontSize: 11, height: 1, color: theme.hintColor)),
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
    final selected = canSelect && dateStr == (widget.initialMonth ?? Dates.today());

    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.primary : null,
            shape: BoxShape.circle,
            border: isToday && !selected && canSelect ? Border.all(color: theme.colorScheme.primary) : null,
          ),
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: 14,
              height: 1,
              color: selected ? theme.colorScheme.onPrimary : (canSelect ? theme.colorScheme.onSurface : theme.disabledColor),
            ),
          ),
        ),
        const SizedBox(height: 3),
        WorkoutDayDots(colors: colors),
      ],
    );

    return Semantics(
      container: true,
      button: true,
      enabled: canSelect,
      selected: selected,
      label: '${Dates.longDate(dateStr)}${colors.isEmpty ? '' : ', workout day'}',
      onTap: canSelect ? () => widget.onSelectDay(dateStr) : null,
      child: ExcludeSemantics(
        child: canSelect ? InkWell(onTap: () => widget.onSelectDay(dateStr), child: content) : content,
      ),
    );
  }
}

class _CalendarScreen extends ConsumerStatefulWidget {
  const _CalendarScreen({required this.dayColors, required this.initialDate, required this.onDayTap, this.selectable});
  final Map<String, List<int>> dayColors;
  final String initialDate;
  final bool Function(String)? selectable;
  final void Function(BuildContext, String) onDayTap;
  @override
  ConsumerState<_CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<_CalendarScreen> {
  late Map<String, List<int>> _colors = widget.dayColors;
  int? _category, _exercise;
  bool _loading = false;
  int _request = 0;
  Future<void> _filter() async {
    final request = ++_request;
    setState(() => _loading = true);
    final ok = await attempt(context, () async {
      final colors = await ref
          .read(workoutRepositoryProvider)
          .workoutDayCategoryColors(categoryId: _category, exerciseId: _exercise);
      if (mounted && request == _request) setState(() => _colors = colors);
    });
    if (mounted && request == _request) {
      setState(() {
        _loading = false;
        if (!ok) _colors = {};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = ref.watch(settingsProvider).asData?.value.firstDayOfWeek ?? 1;
    final categories = ref.watch(categoriesProvider).asData?.value ?? [];
    final exercises = ref.watch(allExercisesProvider).asData?.value ?? [];
    final count = _colors.keys.where((d) => widget.selectable?.call(d) ?? true).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectable == null ? 'Calendar' : 'Choose a source day'),
        actions: [
          IconButton(
            tooltip: 'Jump to date',
            icon: const Icon(Icons.date_range_outlined),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: Dates.parse(widget.initialDate),
                firstDate: DateTime(1900),
                lastDate: DateTime(2100),
                selectableDayPredicate: widget.selectable == null ? null : (d) => widget.selectable!(Dates.iso(d)),
              );
              if (date != null && context.mounted) widget.onDayTap(context, Dates.iso(date));
            },
          ),
        ],
      ),
      body: ContentWidth(
        child: Column(
          children: [
            if (widget.selectable == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _category ?? 0,
                        key: ValueKey(_category),
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Category', isDense: true),
                        items: [
                          const DropdownMenuItem(value: 0, child: Text('All categories')),
                          for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name)),
                        ],
                        onChanged: (v) {
                          _category = v == 0 ? null : v;
                          _exercise = null;
                          _filter();
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: 'Filter by exercise',
                      icon: const Icon(Icons.filter_list_rounded),
                      onPressed: () async {
                        final id = await context.push<int>('/pick-exercise?return=1');
                        if (id != null && mounted) {
                          _exercise = id;
                          _category = null;
                          _filter();
                        }
                      },
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$count workout ${count == 1 ? 'day' : 'days'}',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                  if (_exercise != null)
                    Flexible(
                      child: InputChip(
                        label: Text(
                          exercises.where((e) => e.id == _exercise).firstOrNull?.name ?? 'Exercise',
                          overflow: TextOverflow.ellipsis,
                        ),
                        onDeleted: () {
                          _exercise = null;
                          _filter();
                        },
                      ),
                    ),
                ],
              ),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: WorkoutCalendar(
                key: ValueKey('$firstDay:$_category:$_exercise'),
                dayColors: _colors,
                initialMonth: widget.initialDate,
                firstDayOfWeek: firstDay,
                selectable: widget.selectable,
                onSelectDay: (d) => widget.onDayTap(context, d),
              ),
            ),
          ],
        ),
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
    builder: (_) => _DayDetailDialog(date: date, sets: sets, units: ref.read(unitsProvider)),
  );
}

class _DayDetailDialog extends StatelessWidget {
  const _DayDetailDialog({required this.date, required this.sets, required this.units});
  final Units units;
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
    return AppDialog(
      title: Text(Dates.longDate(date), style: TextStyle(color: accent)),
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
    units: units,
  );
}
