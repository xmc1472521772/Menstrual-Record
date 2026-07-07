import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/period_record.dart';
import '../models/cycle_data.dart';
import '../database/period_dao.dart';
import '../database/settings_dao.dart';
import '../services/prediction_service.dart';
import '../services/notification_service.dart';
import '../utils/date_utils.dart';

class PeriodProvider with ChangeNotifier {
  final PeriodDao _dao;
  final SettingsDao _settingsDao;
  final bool _scheduleReminders;
  final bool _autoEndEnabled;

  /// Allows injecting DAOs for testing.
  /// Set [scheduleReminders] to false in tests to avoid NotificationService calls.
  /// Set [autoEndExpiredPeriods] to false in tests to prevent the provider from
  /// auto-ending ongoing periods based on the real current date.
  PeriodProvider({
    PeriodDao? periodDao,
    SettingsDao? settingsDao,
    bool scheduleReminders = true,
    bool autoEndExpiredPeriods = true,
  })  : _dao = periodDao ?? PeriodDao(),
        _settingsDao = settingsDao ?? SettingsDao(),
        _scheduleReminders = scheduleReminders,
        _autoEndEnabled = autoEndExpiredPeriods;

  List<PeriodRecord> _records = [];
  CycleData? _cycleData;
  bool _isLoading = false;
  String _algorithm = 'simple';

  // 日类型缓存
  final Map<String, String> _dayTypeCache = {};

  List<PeriodRecord> get records => _records;
  CycleData? get cycleData => _cycleData;
  bool get isLoading => _isLoading;

  Future<void> loadRecords() async {
    _isLoading = true;
    _clearDayTypeCache();
    notifyListeners();

    try {
      _algorithm = await _settingsDao.getPredictionAlgorithm();
      _records = await _dao.getAll();
      _cycleData = PredictionService.calculateCycleData(
        _records,
        algorithm: _algorithm,
      );
      if (_autoEndEnabled) {
        await _autoEndExpiredPeriods();
      }
      await _scheduleReminderIfNeeded();
    } catch (e) {
      debugPrint('Error loading records: $e');
    }

    _isLoading = false;
    _clearDayTypeCache();
    notifyListeners();
  }

  /// Ends any ongoing period that exceeds the user's configured period length.
  /// Does NOT reload records — the caller ([loadRecords]) handles that.
  Future<void> _autoEndExpiredPeriods() async {
    final settingsPeriodLength = await _settingsDao.getPeriodLength();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 优先使用计算出的平均经期天数，如果没有历史数据则使用设置值
    int periodLength = settingsPeriodLength;
    if (_cycleData != null && _cycleData!.totalCycles > 0) {
      periodLength = _cycleData!.averagePeriodLength.round();
    }

    final ongoing = _records.where((r) => r.isOngoing).toList();
    bool changed = false;
    for (final record in ongoing) {
      final daysPassed = today.difference(record.startDateTime).inDays;
      // 超过经期天数+1天自动结束（给用户一天缓冲）
      if (daysPassed >= periodLength + 1) {
        final updated = record.copyWith(
          endDate: today.toIso8601String().split('T')[0],
          periodLength: daysPassed,
        );
        await _dao.update(updated);
        changed = true;
      }
    }

    // Only reload if we actually changed something
    if (changed) {
      _records = await _dao.getAll();
      _cycleData = PredictionService.calculateCycleData(
        _records,
        algorithm: _algorithm,
      );
    }
  }

  /// Schedules a notification reminder if a prediction is available.
  Future<void> _scheduleReminderIfNeeded() async {
    if (!_scheduleReminders) return;
    if (_cycleData?.predictedNextPeriod == null) return;

    try {
      final reminderDays = await _settingsDao.getReminderDays();
      final reminderHour = await _settingsDao.getReminderHour();

      await NotificationService().schedulePeriodReminder(
        predictedDate: _cycleData!.predictedNextPeriod!,
        reminderDays: reminderDays,
        reminderHour: reminderHour,
      );
    } catch (e) {
      debugPrint('Error scheduling reminder: $e');
    }
  }

  /// Recalculates cycle data using the given algorithm.
  ///
  /// Note: persisting the algorithm to the database is handled by
  /// [SettingsProvider.setAlgorithm]. The UI should call both:
  ///
  /// ```dart
  /// settingsProvider.setAlgorithm(value);  // persists to DB
  /// periodProvider.setAlgorithm(value);   // recalculates predictions
  /// ```
  Future<void> setAlgorithm(String algorithm) async {
    _algorithm = algorithm;
    _cycleData = PredictionService.calculateCycleData(
      _records,
      algorithm: _algorithm,
    );
    _clearDayTypeCache();
    await _scheduleReminderIfNeeded();
    notifyListeners();
  }

  Future<bool> startPeriod(DateTime startDate) async {
    try {
      final existing = _records.where((r) => r.isOngoing).toList();
      if (existing.isNotEmpty) return false;

      // Check for date conflicts with existing records
      final startStr = startDate.toIso8601String().split('T')[0];
      for (final record in _records) {
        if (record.isOngoing) {
          final startDay = DateTime(
            record.startDateTime.year,
            record.startDateTime.month,
            record.startDateTime.day,
          );
          if (!startDate.isBefore(startDay)) return false;
        } else if (record.endDate != null) {
          final rStart = record.startDateTime;
          final rEnd = record.endDateTime!;
          if (AppDateUtils.isInRange(startDate, rStart, rEnd)) return false;
        }
      }

      final record = PeriodRecord(startDate: startStr);

      await _dao.insert(record);
      await loadRecords();
      return true;
    } catch (e) {
      debugPrint('Error starting period: $e');
      return false;
    }
  }

  Future<bool> endPeriod(DateTime endDate) async {
    try {
      final ongoing = _records.where((r) => r.isOngoing).toList();
      if (ongoing.isEmpty) return false;

      final record = ongoing.first;
      final endStr = endDate.toIso8601String().split('T')[0];
      // Calculate periodLength from the actual dates, not record.periodDays
      // (which uses DateTime.now() for ongoing records).
      final periodLength = endDate.difference(record.startDateTime).inDays + 1;
      final updated = record.copyWith(
        endDate: endStr,
        periodLength: periodLength,
      );

      await _dao.update(updated);
      await loadRecords();
      return true;
    } catch (e) {
      debugPrint('Error ending period: $e');
      return false;
    }
  }

  Future<bool> savePeriodRecord(DateTime startDate, DateTime endDate) async {
    try {
      final record = PeriodRecord(
        startDate: startDate.toIso8601String().split('T')[0],
        endDate: endDate.toIso8601String().split('T')[0],
        periodLength: endDate.difference(startDate).inDays + 1,
      );
      await _dao.insert(record);
      await loadRecords();
      return true;
    } catch (e) {
      debugPrint('Error saving period record: $e');
      return false;
    }
  }

  Future<bool> saveMultipleRecords(List<(DateTime, DateTime)> ranges) async {
    try {
      final records = ranges.map((range) {
        final (start, end) = range;
        return PeriodRecord(
          startDate: start.toIso8601String().split('T')[0],
          endDate: end.toIso8601String().split('T')[0],
          periodLength: end.difference(start).inDays + 1,
        );
      }).toList();

      // Use batch insert for efficiency
      await _dao.insertAll(records);
      await loadRecords();
      return true;
    } catch (e) {
      debugPrint('Error saving multiple records: $e');
      return false;
    }
  }

  /// Checks if [date] falls within any existing period record.
  /// Handles both completed records and ongoing ones.
  bool isDateInAnyRecord(DateTime date) {
    for (final record in _records) {
      if (_isDateInRecord(date, record)) return true;
    }
    return false;
  }

  /// Internal helper used by both [isDateInAnyRecord] and [isPeriodDay].
  bool _isDateInRecord(DateTime date, PeriodRecord record) {
    if (record.isOngoing) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final startDay = DateTime(
        record.startDateTime.year,
        record.startDateTime.month,
        record.startDateTime.day,
      );
      return (date.isAfter(startDay) || AppDateUtils.isSameDay(date, startDay)) &&
          (date.isBefore(today) || AppDateUtils.isSameDay(date, today));
    } else {
      return AppDateUtils.isInRange(
          date, record.startDateTime, record.endDateTime!);
    }
  }

  Future<bool> updateRecord(PeriodRecord record) async {
    try {
      await _dao.update(record);
      await loadRecords();
      return true;
    } catch (e) {
      debugPrint('Error updating record: $e');
      return false;
    }
  }

  Future<void> deleteRecord(int id) async {
    try {
      await _dao.delete(id);
      await loadRecords();
    } catch (e) {
      debugPrint('Error deleting record: $e');
    }
  }

  Future<String> exportData() async {
    final jsonList = _records.map((r) => r.toJson()).toList();
    return jsonEncode(jsonList);
  }

  Future<bool> importData(String jsonString, {bool overwrite = false}) async {
    try {
      final jsonList = jsonDecode(jsonString) as List;
      final records = jsonList
          .map((json) => PeriodRecord.fromJson(json as Map<String, dynamic>))
          .toList();

      if (overwrite) {
        // Use atomic replaceAll to avoid data loss on failure
        await _dao.replaceAll(records);
      } else {
        await _dao.insertAll(records);
      }

      await loadRecords();
      return true;
    } catch (e) {
      debugPrint('Error importing data: $e');
      return false;
    }
  }

  bool isPeriodDay(DateTime date) {
    for (final record in _records) {
      if (_isDateInRecord(date, record)) return true;
    }
    return false;
  }

  bool isPredictedDay(DateTime date) {
    if (_cycleData?.predictedNextPeriod == null) return false;
    final predicted = _cycleData!.predictedNextPeriod!;
    final periodLength = _cycleData!.averagePeriodLength.round();
    final endDate = predicted.add(Duration(days: periodLength - 1));
    return AppDateUtils.isInRange(date, predicted, endDate);
  }

  bool isOvulationDay(DateTime date) {
    if (_cycleData == null) return false;
    return _cycleData!.isOvulationDay(date);
  }

  bool isFertileDay(DateTime date) {
    if (_cycleData == null) return false;
    return _cycleData!.isFertileDay(date);
  }

  bool isSafeDay(DateTime date) {
    if (_cycleData == null) return false;
    if (isPeriodDay(date) || isPredictedDay(date)) return false;
    if (isOvulationDay(date) || isFertileDay(date)) return false;
    final lastStart = _cycleData!.lastPeriodStart;
    final predicted = _cycleData!.predictedNextPeriod;
    if (lastStart == null) return false;
    final windowEnd = predicted != null
        ? predicted.add(const Duration(days: 10))
        : lastStart.add(Duration(days: _cycleData!.averageCycleLength.round() + 10));
    return !date.isBefore(lastStart) && !date.isAfter(windowEnd);
  }

  String getDayType(DateTime date) {
    final cacheKey = '${date.year}-${date.month}-${date.day}';

    if (_dayTypeCache.containsKey(cacheKey)) {
      return _dayTypeCache[cacheKey]!;
    }

    final bool period = isPeriodDay(date);
    final bool predicted = !period && isPredictedDay(date);
    final bool ovulation = !period && !predicted && isOvulationDay(date);
    final bool fertile =
        !period && !predicted && !ovulation && isFertileDay(date);

    String dayType;
    if (period) {
      dayType = 'period';
    } else if (predicted) {
      dayType = 'predicted';
    } else if (ovulation) {
      dayType = 'ovulation';
    } else if (fertile) {
      dayType = 'fertile';
    } else if (_isSafeDayDirect(date)) {
      dayType = 'safe';
    } else {
      dayType = 'normal';
    }

    _dayTypeCache[cacheKey] = dayType;
    return dayType;
  }

  /// Directly checks if a date is a safe day.
  /// Caller must have already confirmed the date is not period/predicted/ovulation/fertile.
  bool _isSafeDayDirect(DateTime date) {
    if (_cycleData == null) return false;
    final lastStart = _cycleData!.lastPeriodStart;
    final predicted = _cycleData!.predictedNextPeriod;
    if (lastStart == null) return false;
    final windowEnd = predicted != null
        ? predicted.add(const Duration(days: 10))
        : lastStart.add(Duration(days: _cycleData!.averageCycleLength.round() + 10));
    return !date.isBefore(lastStart) && !date.isAfter(windowEnd);
  }

  void _clearDayTypeCache() {
    _dayTypeCache.clear();
  }

  PeriodRecord? getRecordForDate(DateTime date) {
    for (final record in _records) {
      if (_isDateInRecord(date, record)) {
        return record;
      }
    }
    return null;
  }
}
