import 'package:intl/intl.dart';

/// Calendar-day helpers. Dates are stored as `yyyy-MM-dd` strings (matching
/// FitNotes) to keep day grouping/equality timezone-proof.
class Dates {
  Dates._();

  static final DateFormat _iso = DateFormat('yyyy-MM-dd');

  static String iso(DateTime d) => _iso.format(d);
  static DateTime parse(String isoDate) => DateTime.parse(isoDate);
  static void validate(String value) {
    final date = DateTime.tryParse(value);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) || date == null || iso(date) != value) {
      throw const FormatException('Choose a valid calendar date.');
    }
  }

  static String today() => iso(DateTime.now());

  static String shift(String isoDate, int days) =>
      iso(DateTime(parse(isoDate).year, parse(isoDate).month, parse(isoDate).day + days));

  /// Short, human label for the date navigation bar.
  static String navLabel(String isoDate) {
    final d = parse(isoDate);
    final now = DateTime.now();
    final start = DateTime.utc(now.year, now.month, now.day);
    final diff = DateTime.utc(d.year, d.month, d.day).difference(start).inDays;
    if (diff == 0) return 'TODAY';
    if (diff == -1) return 'YESTERDAY';
    if (diff == 1) return 'TOMORROW';
    return DateFormat('EEE, d MMM yyyy').format(d).toUpperCase();
  }

  /// Long header used for grouped history sections.
  static String sectionHeader(String isoDate) => DateFormat('EEEE, d MMMM yyyy').format(parse(isoDate)).toUpperCase();

  /// Calendar month header, e.g. "MAY 2026".
  static String monthLabel(DateTime month) => DateFormat('MMMM yyyy').format(month).toUpperCase();

  /// Day-detail title, e.g. "Wednesday, May 13 2026".
  static String longDate(String isoDate) => DateFormat('EEEE, MMMM d yyyy').format(parse(isoDate));

  /// Whole calendar days from [from] to [to] (negative if [to] is earlier).
  static int daysBetween(String from, String to) {
    final a = parse(from);
    final b = parse(to);
    return DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
  }
}
