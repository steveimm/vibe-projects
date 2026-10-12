import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/util/date_filter.dart';
import '../core/util/dates.dart';

Future<DateFilter?> pickChartDateRange(BuildContext context, DateFilter filter, String from, String to) async {
  final selected = await showDateRangePicker(
    context: context,
    firstDate: DateTime(1900),
    lastDate: Dates.parse(Dates.today()),
    initialDateRange: DateTimeRange(start: Dates.parse(filter.customFrom ?? from), end: Dates.parse(filter.customTo ?? to)),
    helpText: 'Custom range',
    builder: (context, child) {
      final theme = Theme.of(context);
      return Theme(
        data: theme.copyWith(
          datePickerTheme: theme.datePickerTheme.copyWith(rangePickerHeaderHeadlineStyle: theme.textTheme.titleMedium),
        ),
        child: child!,
      );
    },
  );
  return selected == null
      ? null
      : DateFilter(months: -1, customFrom: Dates.iso(selected.start), customTo: Dates.iso(selected.end));
}

class DateRangeChips extends StatelessWidget {
  const DateRangeChips({super.key, required this.months, required this.onChanged, this.onCustom, this.includeYear = false});
  final int months;
  final ValueChanged<int> onChanged;
  final VoidCallback? onCustom;
  final bool includeYear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final labelHeight = MediaQuery.textScalerOf(context).scale(14) * 1.5;
    final options = {1: '1m', 3: '3m', 6: '6m', if (includeYear) 12: '1y', 0: 'All', if (onCustom != null) -1: 'Custom'};
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360 || MediaQuery.textScalerOf(context).scale(1) > 1.1;
        return Row(
          children: [
            for (final option in options.entries) ...[
              if (option.key != options.keys.first) const SizedBox(width: 6),
              Expanded(
                child: Tooltip(
                  message: switch (option.key) {
                    -1 => 'Custom range',
                    0 => 'All',
                    1 => '1 month',
                    12 => '1 year',
                    _ => '${option.key} months',
                  },
                  excludeFromSemantics: true,
                  child: ChoiceChip(
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    selected: months == option.key,
                    selectedColor: AppTheme.selectionColor(colors),
                    side: BorderSide(color: months == option.key ? colors.primary : colors.outlineVariant),
                    label: SizedBox(
                      width: double.infinity,
                      height: labelHeight,
                      child: Center(
                        child: option.key == -1 && compact
                            ? const Icon(Icons.date_range_rounded, size: 20, semanticLabel: 'Custom range')
                            : Text(option.value, textAlign: TextAlign.center, maxLines: 1),
                      ),
                    ),
                    onSelected: (_) => option.key == -1 ? onCustom!() : onChanged(option.key),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
