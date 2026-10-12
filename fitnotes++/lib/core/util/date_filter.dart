import 'workout_analysis.dart';

class DateFilter {
  const DateFilter({this.months = 1, this.customFrom, this.customTo});
  final int months;
  final String? customFrom, customTo;

  DateFilter withMonths(int value) => DateFilter(months: value, customFrom: customFrom, customTo: customTo);

  ({String from, String to}) range(String today, Iterable<String> dates) {
    if (months == -1) return (from: customFrom!, to: customTo!);
    final earliest = dates.where((date) => date.compareTo(today) <= 0).fold(today, (a, b) => a.compareTo(b) < 0 ? a : b);
    return (from: months == 0 ? earliest : WorkoutAnalysis.monthsBefore(today, months), to: today);
  }

  bool get isCustom => months == -1;
}
