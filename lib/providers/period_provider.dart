import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/period_record.dart';
import '../models/cycle_data.dart';
import '../database/period_dao.dart';
import '../database/settings_dao.dart';
import '../services/prediction_service.dart';
import '../utils/date_utils.dart';

class PeriodProvider with ChangeNotifier {
  final PeriodDao _dao = PeriodDao();
  final SettingsDao _settingsDao = SettingsDao();

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
      await _autoEndExpiredPeriods();
    } catch (e) {
      debugPrint('Error loading records: $e');
    }

    _isLoading = false;
    _clearDayTypeCache();
    notifyListeners();
  }

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
    for (final record in ongoing) {
      final daysPassed = today.difference(record.startDateTime).inDays;
      // 超过经期天数+1天自动结束（给用户一天缓冲）
      if (daysPassed >= periodLength + 1) {
        final updated = record.copyWith(
          endDate: today.toIso8601String().split('T')[0],
          periodLength: daysPassed,
        );
        await _dao.update(updated);
      }
    }

    _records = await _dao.getAll();
    _cycleData = PredictionService.calculateCycleData(
      _records,
      algorithm: _algorithm,
    );
  }

  Future<void> setAlgorithm(String algorithm) async {
    _algorithm = algorithm;
    _cycleData = PredictionService.calculateCycleData(
      _records,
      algorithm: _algorithm,
    );
    _clearDayTypeCache();
    notifyListeners();
  }

  Future<bool> startPeriod(DateTime startDate) async {
    try {
      final existing = _records.where((r) => r.isOngoing).toList();
      if (existing.isNotEmpty) return false;

      final record = PeriodRecord(
        startDate: startDate.toIso8601String().split('T')[0],
      );

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
      final updated = record.copyWith(
        endDate: endDate.toIso8601String().split('T')[0],
        periodLength: record.periodDays,
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
      for (final (start, end) in ranges) {
        final record = PeriodRecord(
          startDate: start.toIso8601String().split('T')[0],
          endDate: end.toIso8601String().split('T')[0],
          periodLength: end.difference(start).inDays + 1,
        );
        await _dao.insert(record);
      }
      await loadRecords();
      return true;
    } catch (e) {
      debugPrint('Error saving multiple records: $e');
      return false;
    }
  }

  bool isDateInAnyRecord(DateTime date) {
    for (final record in _records) {
      if (record.isOngoing) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final startDay = DateTime(
          record.startDateTime.year,
          record.startDateTime.month,
          record.startDateTime.day,
        );
        if ((date.isAfter(startDay) || AppDateUtils.isSameDay(date, startDay)) &&
            (date.isBefore(today) || AppDateUtils.isSameDay(date, today))) {
          return true;
        }
      } else {
        if (AppDateUtils.isInRange(date, record.startDateTime, record.endDateTime!)) {
          return true;
        }
      }
    }
    return false;
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
        await _dao.deleteAll();
      }

      await _dao.insertAll(records);
      await loadRecords();
      return true;
    } catch (e) {
      debugPrint('Error importing data: $e');
      return false;
    }
  }

  bool isPeriodDay(DateTime date) {
    for (final record in _records) {
      if (record.isOngoing) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final startDate = record.startDateTime;
        final startDay = DateTime(startDate.year, startDate.month, startDate.day);
        
        if ((date.isAfter(startDay) || AppDateUtils.isSameDay(date, startDay)) &&
            (date.isBefore(today) || AppDateUtils.isSameDay(date, today))) {
          return true;
        }
      } else {
        if (AppDateUtils.isInRange(date, record.startDateTime, record.endDateTime!)) {
          return true;
        }
      }
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
    // 只在周期窗口内标记安全期（当前周期~下一预测周期+10天）
    final lastStart = _cycleData!.lastPeriodStart;
    final predicted = _cycleData!.predictedNextPeriod;
    if (lastStart == null) return false;
    final windowEnd = predicted != null
        ? predicted.add(const Duration(days: 10))
        : lastStart.add(Duration(days: _cycleData!.averageCycleLength.round() + 10));
    return !date.isBefore(lastStart) && !date.isAfter(windowEnd);
  }

  String getDayType(DateTime date) {
    // 生成缓存键
    final cacheKey = '${date.year}-${date.month}-${date.day}';
    
    // 检查缓存
    if (_dayTypeCache.containsKey(cacheKey)) {
      return _dayTypeCache[cacheKey]!;
    }
    
    // 单次计算所有条件，避免 isSafeDay 重复检查 period/predicted/ovulation/fertile
    final bool period = isPeriodDay(date);
    final bool predicted = !period && isPredictedDay(date);
    final bool ovulation = !period && !predicted && isOvulationDay(date);
    final bool fertile = !period && !predicted && !ovulation && isFertileDay(date);

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
    
    // 缓存结果
    _dayTypeCache[cacheKey] = dayType;
    
    return dayType;
  }

  /// 直接判断安全期，不再重复调用 isPeriodDay/isPredictedDay/isOvulationDay/isFertileDay
  /// 调用方必须已确认该日期不是 period/predicted/ovulation/fertile
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
  
  // 清除缓存
  void _clearDayTypeCache() {
    _dayTypeCache.clear();
  }

  PeriodRecord? getRecordForDate(DateTime date) {
    for (final record in _records) {
      if (record.isOngoing) {
        if (AppDateUtils.isSameDay(record.startDateTime, date)) {
          return record;
        }
      } else {
        if (AppDateUtils.isInRange(
          date,
          record.startDateTime,
          record.endDateTime,
        )) {
          return record;
        }
      }
    }
    return null;
  }
}
