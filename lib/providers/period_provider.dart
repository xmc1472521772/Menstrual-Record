import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/period_record.dart';
import '../models/cycle_data.dart';
import '../database/period_dao.dart';
import '../database/settings_dao.dart';
import '../services/prediction_service.dart';
import '../services/notification_service.dart';
import '../utils/date_utils.dart';

/// `startPeriodWithMerge` 的返回类型。
///
/// 告知 UI 层应该执行哪种后续操作：
/// - [created]：已直接新建一段经期（间隔 > 阈值，或无最近记录）
/// - [mergedSilently]：同天/间隔 0 天，已静默合并（撤销上次结束状态）
/// - [needsConfirmation]：间隔在阈值内（1~2 天），需要弹窗让用户选择
enum PeriodStartResult {
  /// 直接新建成功
  created,
  /// 静默合并成功（撤销上次结束）
  mergedSilently,
  /// 需要弹窗确认（返回 [PeriodMergeInfo] 供 UI 使用）
  needsConfirmation,
}

/// 携带给 UI 的合并上下文信息。
class PeriodMergeInfo {
  /// 最近一条已结束的经期记录。
  final PeriodRecord lastRecord;

  /// 新经期的开始日期。
  final DateTime newStartDate;

  /// 距上次经期结束的天数。
  final int gapDays;

  PeriodMergeInfo({
    required this.lastRecord,
    required this.newStartDate,
    required this.gapDays,
  });
}

/// 将 [PeriodStartResult] 与可选的 [PeriodMergeInfo] 打包返回。
class PeriodStartOutcome {
  final PeriodStartResult result;
  final PeriodMergeInfo? mergeInfo;

  const PeriodStartOutcome(this.result, {this.mergeInfo});
}

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

  /// 日类型缓存。key 为整数 `yyyyMMdd`（见 [AppDateUtils.dayKey]），
  /// 相比字符串 key 可避免每次日历构建时 40+ 次字符串拼接与哈希。
  final Map<int, String> _dayTypeCache = {};

  /// 经期日索引：`yyyyMMdd -> true`。
  /// 让 [isPeriodDay] 从 O(记录数) 降为 O(1)，日历构建时收益明显。
  final Set<int> _periodDayKeys = <int>{};

  /// 单调递增的数据版本号。UI 可用 `Selector<PeriodProvider, int>` 监听它，
  /// 从而只在实际数据变化时重建，而不被其它 notifyListeners 波及。
  int _dataVersion = 0;

  /// 上一次真正下发到通知插件的预测日期。
  /// `zonedSchedule` 是跨进程调用（十毫秒级），预测日期未变时不必重复调度。
  DateTime? _lastScheduledPrediction;

  /// 是否存在进行中的经期，由 [_recalculate] 维护。
  bool _hasOngoing = false;

  List<PeriodRecord> get records => _records;
  CycleData? get cycleData => _cycleData;
  bool get isLoading => _isLoading;
  int get dataVersion => _dataVersion;

  /// 是否存在进行中的经期。缓存以避免 UI 每次构建都遍历一遍记录列表。
  bool get hasOngoingPeriod => _hasOngoing;

  Future<void> loadRecords() async {
    _isLoading = true;
    notifyListeners();

    try {
      _algorithm = await _settingsDao.getPredictionAlgorithm();
      _records = await _dao.getAll();
      _recalculate();
      if (_autoEndEnabled) {
        await _autoEndExpiredPeriods();
      }
    } catch (e) {
      debugPrint('Error loading records: $e');
    }

    _isLoading = false;
    notifyListeners();

    // 通知调度涉及 platform channel，刻意不 await —— 它不应阻塞 UI 刷新。
    _scheduleReminderIfNeeded();
  }

  /// 重算派生数据（周期预测 + 经期日索引 + 日类型缓存）。
  void _recalculate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _hasOngoing = _records.any((r) => r.isOngoing);
    _cycleData = PredictionService.calculateCycleData(
      _records,
      algorithm: _algorithm,
      today: today,
    );
    _clearDayTypeCache();
    _rebuildPeriodDayIndex(today);
    _dataVersion++;
  }

  /// 写操作后的轻量提交路径。
  ///
  /// 与 [loadRecords] 的区别：不再重新读取整张表、不再重复读取设置项、
  /// 也不再等待通知插件返回。一次写操作的成本因此只剩「一次 DB 写入 +
  /// 一次内存重算 + 一次 UI 通知」。
  void _commitMutation() {
    _recalculate();
    notifyListeners();
    _scheduleReminderIfNeeded();
  }

  /// 按 `start_date DESC` 重新排序，保持与 [PeriodDao.getAll] 一致的顺序。
  void _sortRecords() {
    _records.sort((a, b) => b.startDate.compareTo(a.startDate));
  }

  void _rebuildPeriodDayIndex(DateTime today) {
    _periodDayKeys.clear();
    if (_records.isEmpty) return;

    for (final record in _records) {
      final start = record.startDateTime;
      var cur = DateTime(start.year, start.month, start.day);

      DateTime end;
      if (record.isOngoing) {
        end = today;
      } else {
        final e = record.endDateTime;
        end = e == null ? cur : DateTime(e.year, e.month, e.day);
      }
      if (end.isBefore(cur)) continue;

      // 经期通常 3~8 天，逐天展开的成本可忽略。
      // 安全阀：防止异常数据（如 endDate 距 start_date 跨数年）导致超长循环。
      int expanded = 0;
      while (!cur.isAfter(end) && expanded < 10000) {
        _periodDayKeys.add(AppDateUtils.dayKey(cur));
        cur = DateTime(cur.year, cur.month, cur.day + 1);
        expanded++;
      }
    }
  }

  /// Ends any ongoing period that exceeds the user's configured period length.
  /// Does NOT reload records — the caller ([loadRecords]) handles that.
  Future<void> _autoEndExpiredPeriods() async {
    // 没有任何 ongoing 记录时直接返回，省掉一次设置表读取
    if (!_records.any((r) => r.isOngoing)) return;

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
          periodLength: daysPassed + 1,
        );
        await _dao.update(updated);
        // 同步内存，避免下面可能的二次全表读取
        final index = _records.indexOf(record);
        if (index >= 0) _records[index] = updated;
        changed = true;
      }
    }

    // Only reload if we actually changed something
    if (changed) {
      _records = await _dao.getAll();
      _recalculate();
    }
  }

  /// Schedules a notification reminder if a prediction is available.
  ///
  /// Safe to call without `await`: all failures are swallowed internally.
  Future<void> _scheduleReminderIfNeeded() async {
    if (!_scheduleReminders) return;
    final predicted = _cycleData?.predictedNextPeriod;
    if (predicted == null) {
      // 无预测（无任何记录）时清掉残留的已注册提醒，避免过期闹钟误弹。
      _lastScheduledPrediction = null;
      try {
        await NotificationService().cancelAll();
      } catch (e) {
        debugPrint('Error cancelling stale reminder: $e');
      }
      return;
    }

    // 预测日期未变化则跳过重复调度（zonedSchedule 需要跨进程调用）
    final last = _lastScheduledPrediction;
    if (last != null &&
        last.year == predicted.year &&
        last.month == predicted.month &&
        last.day == predicted.day) {
      return;
    }
    _lastScheduledPrediction = predicted;

    try {
      final reminderDays = await _settingsDao.getReminderDays();
      final reminderHour = await _settingsDao.getReminderHour();

      await NotificationService().schedulePeriodReminder(
        predictedDate: predicted,
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
    _recalculate();
    notifyListeners();
    _scheduleReminderIfNeeded();
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
          // 冲突检查用 [start, end) 区间：新开始日等于已有记录的结束日不算冲突，
          // 因为前一次经期的结束日和下一次经期的开始日可以是同一天。
          if ((startDate.isAfter(rStart) || AppDateUtils.isSameDay(startDate, rStart)) &&
              startDate.isBefore(rEnd)) {
            return false;
          }
        } else {
          // endDate == null but not ongoing — 数据异常，按保守策略视为冲突
          return false;
        }
      }

      final record = PeriodRecord(startDate: startStr);
      final id = await _dao.insert(record);

      // 直接更新内存，避免一次全表读取
      _records = [..._records, record.copyWith(id: id)];
      _sortRecords();
      _commitMutation();
      return true;
    } catch (e) {
      debugPrint('Error starting period: $e');
      return false;
    }
  }

  /// 带自动合并逻辑的经期开启。
  ///
  /// 根据新开始日期与最近一段已结束经期的间隔天数：
  /// - 间隔 0 天（同天）：静默合并（撤销上次结束状态）
  /// - 间隔 1~阈值天：返回 [PeriodStartResult.needsConfirmation]，
  ///   UI 弹窗让用户选择续接还是新开
  /// - 间隔 > 阈值天 或无历史记录：直接新建
  Future<PeriodStartOutcome> startPeriodWithMerge(
    DateTime startDate, {
    int? mergeThreshold,
  }) async {
    try {
      // 已有进行中的经期 → 不能再开
      if (_hasOngoing) {
        return const PeriodStartOutcome(PeriodStartResult.created);
      }

      // 获取合并阈值
      final threshold = mergeThreshold ?? await _settingsDao.getMergeThreshold();

      // 查找最近一条已结束的经期记录（startDate DESC 排序，取第一条非 ongoing 的）
      PeriodRecord? lastEnded;
      for (final r in _records) {
        if (!r.isOngoing && r.endDate != null) {
          lastEnded = r;
          break;
        }
      }

      // 无历史记录 → 直接新建
      if (lastEnded == null) {
        final ok = await startPeriod(startDate);
        return PeriodStartOutcome(
          ok ? PeriodStartResult.created : PeriodStartResult.created,
        );
      }

      // 计算间隔天数：新开始日期 - 上次经期结束日期
      final lastEndDate = lastEnded.endDateTime!;
      final lastEndDay = DateTime(
        lastEndDate.year,
        lastEndDate.month,
        lastEndDate.day,
      );
      final newStartDay = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );
      final gapDays = newStartDay.difference(lastEndDay).inDays;

      // 场景 A：同天（间隔 0 天）→ 静默合并
      if (gapDays <= 0) {
        final ok = await _mergeWithLastPeriod(startDate);
        return PeriodStartOutcome(
          ok ? PeriodStartResult.mergedSilently : PeriodStartResult.created,
        );
      }

      // 场景 B：间隔 1 ~ 阈值天 → 需要弹窗确认
      if (gapDays <= threshold) {
        return PeriodStartOutcome(
          PeriodStartResult.needsConfirmation,
          mergeInfo: PeriodMergeInfo(
            lastRecord: lastEnded,
            newStartDate: startDate,
            gapDays: gapDays,
          ),
        );
      }

      // 场景 C：间隔 > 阈值天 → 直接新建
      final ok = await startPeriod(startDate);
      return PeriodStartOutcome(
        ok ? PeriodStartResult.created : PeriodStartResult.created,
      );
    } catch (e) {
      debugPrint('Error in startPeriodWithMerge: $e');
      return const PeriodStartOutcome(PeriodStartResult.created);
    }
  }

  /// 合并：撤销上次经期的结束状态，将其恢复为进行中。
  ///
  /// 清空 endDate 和 periodLength，让该记录回到 ongoing 状态。
  Future<bool> _mergeWithLastPeriod(DateTime newStartDate) async {
    try {
      // 找到最近一条已结束的经期
      PeriodRecord? lastEnded;
      for (final r in _records) {
        if (!r.isOngoing && r.endDate != null) {
          lastEnded = r;
          break;
        }
      }
      if (lastEnded == null) return false;

      // 撤销结束状态：清空 endDate 和 periodLength
      final merged = lastEnded.copyWith(
        clearEndDate: true,
        clearPeriodLength: true,
      );
      await _dao.update(merged);
      final index = _records.indexWhere((r) => r.id == merged.id);
      if (index >= 0) {
        _records[index] = merged;
      }
      _sortRecords();
      _commitMutation();
      return true;
    } catch (e) {
      debugPrint('Error merging with last period: $e');
      return false;
    }
  }

  /// 供 UI 调用：用户选择“续接上一段”时调用。
  Future<bool> mergeWithLastPeriod(DateTime newStartDate) async {
    return _mergeWithLastPeriod(newStartDate);
  }

  /// 供 UI 调用：用户选择“开启新经期”时调用。
  /// 等价于 [startPeriod]，语义化方法名供 UI 调用。
  Future<bool> startNewPeriod(DateTime startDate) async {
    return startPeriod(startDate);
  }

  Future<bool> endPeriod(DateTime endDate) async {
    try {
      final ongoing = _records.where((r) => r.isOngoing).toList();
      if (ongoing.isEmpty) return false;

      final record = ongoing.first;
      final endStr = endDate.toIso8601String().split('T')[0];
      // Calculate periodLength from the actual dates, not record.periodDays
      // (which uses DateTime.now() for ongoing records).
      final periodLength = (endDate.difference(record.startDateTime).inDays + 1).clamp(1, 999);
      final updated = record.copyWith(
        endDate: endStr,
        periodLength: periodLength,
      );

      await _dao.update(updated);
      final index = _records.indexOf(record);
      if (index >= 0) _records[index] = updated;
      _sortRecords();
      _commitMutation();
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
        periodLength: (endDate.difference(startDate).inDays + 1).clamp(1, 999),
      );
      final id = await _dao.insert(record);
      _records = [..._records, record.copyWith(id: id)];
      _sortRecords();
      _commitMutation();
      return true;
    } catch (e) {
      debugPrint('Error saving period record: $e');
      return false;
    }
  }

  Future<bool> saveMultipleRecords(List<(DateTime, DateTime)> ranges) async {
    if (ranges.isEmpty) return true;

    try {
      final records = ranges.map((range) {
        final (start, end) = range;
        return PeriodRecord(
          startDate: start.toIso8601String().split('T')[0],
          endDate: end.toIso8601String().split('T')[0],
          periodLength: (end.difference(start).inDays + 1).clamp(1, 999),
        );
      }).toList();

      // Use batch insert for efficiency
      await _dao.insertAll(records);
      _records = [..._records, ...records];
      _sortRecords();
      _commitMutation();
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

  /// Internal helper used by both [isDateInAnyRecord] and [getRecordForDate].
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
      final index = _records.indexWhere((r) => r.id == record.id);
      if (index >= 0) {
        _records[index] = record;
      } else {
        _records = [..._records, record];
      }
      _sortRecords();
      _commitMutation();
      return true;
    } catch (e) {
      debugPrint('Error updating record: $e');
      return false;
    }
  }

  Future<void> deleteRecord(int id) async {
    try {
      await _dao.delete(id);
      _records = _records.where((r) => r.id != id).toList();
      _commitMutation();
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
      // 大小限制：防止恶意超大 JSON 导致 OOM
      if (jsonString.length > 10 * 1024 * 1024) {
        debugPrint('Import data too large (>10MB)');
        return false;
      }
      final jsonList = jsonDecode(jsonString) as List;
      final records = jsonList
          .map((json) => PeriodRecord.fromJson(json as Map<String, dynamic>))
          .toList();

      // 校验日期格式，解析失败会抛 FormatException 被外层 catch
      for (final record in records) {
        DateTime.parse(record.startDate);
        if (record.endDate != null) DateTime.parse(record.endDate!);
      }

      if (overwrite) {
        // Use atomic replaceAll to avoid data loss on failure
        await _dao.replaceAll(records);
      } else {
        // 追加模式：检测区间重叠，避免重复导入产生重叠记录
        // 不只按 startDate 去重，而是检查日期区间是否与现有记录重叠
        bool hasOverlap(PeriodRecord r) {
          final rStart = r.startDateTime;
          final rEnd = r.endDateTime ?? rStart;
          for (final existing in _records) {
            final eStart = existing.startDateTime;
            final eEnd = existing.endDateTime ?? eStart;
            // 区间 [rStart, rEnd] 与 [eStart, eEnd] 有交集
            if (rStart.isBefore(eEnd.add(const Duration(days: 1))) &&
                rEnd.isAfter(eStart.subtract(const Duration(days: 1)))) {
              return true;
            }
          }
          return false;
        }

        final newRecords = records.where((r) => !hasOverlap(r)).toList();
        if (newRecords.isEmpty) {
          // 全部重复，无需写库但仍刷新以保证状态一致
          return true;
        }
        await _dao.insertAll(newRecords);
      }

      // 导入会整体改写数据集，走完整刷新
      await loadRecords();
      return true;
    } catch (e) {
      debugPrint('Error importing data: $e');
      return false;
    }
  }

  /// O(1) 查询 —— 依赖 [_periodDayKeys] 索引。
  bool isPeriodDay(DateTime date) => _periodDayKeys.contains(AppDateUtils.dayKey(date));

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
    final key = AppDateUtils.dayKey(date);

    final cached = _dayTypeCache[key];
    if (cached != null) return cached;

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

    _dayTypeCache[key] = dayType;
    return dayType;
  }

  /// Directly checks if a date is a safe day.
  ///
  /// 注意：此方法基于简化的日历法，仅供参考，不作为避孕指导。
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
