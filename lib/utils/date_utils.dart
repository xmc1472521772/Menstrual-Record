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

  // ─── Integer day key helpers ─────────────────────────────────────
  //
  // Compact integer encoding of a date: year * 10000 + month * 100 + day.
  // Used as Map/Set keys to avoid per-cell string allocation in calendars.

  /// Integer day key: year * 10000 + month * 100 + day (e.g. 20260105).
  static int dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  /// Extract the year component from an integer day key.
  static int dayKeyToYear(int k) => k ~/ 10000;

  /// Extract the month component from an integer day key.
  static int dayKeyToMonth(int k) => (k % 10000) ~/ 100;

  /// Extract the day component from an integer day key.
  static int dayKeyToDay(int k) => k % 100;
}

/// 判断经期提醒是否需要重新排期（T9 抽取的纯函数）。
///
/// 供 [PeriodProvider] 在调度提醒前短路重复排期（zonedSchedule
/// 需要跨进程调用，能省则省）。按「年月日」比较，忽略时分秒：
///
/// - [predicted] 为 null（无预测）→ 不需要，调用方负责取消已有提醒；
/// - [lastScheduled] 为 null（从未排过）且有预测 → 需要；
/// - 两者日期相同 → 不需要（预测未变化）。
bool needsReschedule(DateTime? lastScheduled, DateTime? predicted) {
  if (predicted == null) return false;
  if (lastScheduled == null) return true;
  return lastScheduled.year != predicted.year ||
      lastScheduled.month != predicted.month ||
      lastScheduled.day != predicted.day;
}
