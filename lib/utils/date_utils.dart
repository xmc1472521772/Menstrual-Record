import 'package:intl/intl.dart';

class AppDateUtils {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _displayFormat = DateFormat('yyyy年MM月dd日');
  static final DateFormat _monthFormat = DateFormat('yyyy年MM月');
  static final DateFormat _dayFormat = DateFormat('dd');

  static String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }

  static String formatDisplay(DateTime date) {
    return _displayFormat.format(date);
  }

  static String formatMonth(DateTime date) {
    return _monthFormat.format(date);
  }

  static String formatDay(DateTime date) {
    return _dayFormat.format(date);
  }

  static DateTime parseDate(String dateStr) {
    return DateTime.parse(dateStr);
  }

  static DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool isInRange(DateTime date, DateTime start, DateTime? end) {
    if (end == null) {
      return isSameDay(date, start) || date.isAfter(start);
    }
    return (date.isAfter(start) || isSameDay(date, start)) &&
        (date.isBefore(end) || isSameDay(date, end));
  }

  /// Returns the number of days from [b] to [a].
  ///
  /// Positive when [a] is after [b], negative when before.
  /// Callers that only need magnitude should use `.abs()` on the result.
  static int daysBetween(DateTime a, DateTime b) {
    return a.difference(b).inDays;
  }

  static List<DateTime> getDaysInRange(DateTime start, DateTime end) {
    final days = <DateTime>[];
    var current = startOfDay(start);
    final last = startOfDay(end);
    while (current.isBefore(last) || isSameDay(current, last)) {
      days.add(current);
      current = current.add(const Duration(days: 1));
    }
    return days;
  }
}
