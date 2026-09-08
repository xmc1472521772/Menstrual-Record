import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/cycle_data.dart';
import '../models/period_record.dart';

/// 桌面小组件通信服务。
///
/// 职责：
/// 1. 将经期数据序列化为 JSON 并通过 MethodChannel 发送给原生端更新小组件
/// 2. 接收原生端「数据已变更」通知（小组件按钮操作后触发），通知 Provider 刷新
class WidgetService {
  static const _channel = MethodChannel('com.yima.yimaflutter/widget');

  static WidgetService? _instance;
  static WidgetService get instance => _instance ??= WidgetService._();

  WidgetService._();

  /// 当小组件按钮操作完成并修改了数据库后，原生端会发送 `dataChanged` 通知。
  /// Flutter 端收到后应重新加载数据。
  void Function()? onDataChanged;

  /// 初始化 MethodChannel。
  void init() {
    _channel.setMethodCallHandler((call) async {
      debugPrint('[WidgetService] method call: ${call.method}');
      if (call.method == 'dataChanged') {
        debugPrint('[WidgetService] data changed notification from native');
        onDataChanged?.call();
      }
      return null;
    });
  }

  /// 主动检查小组件是否修改了数据库。
  ///
  /// App 恢复前台时调用此方法，通过原生端检查 SharedPreferences 中的
  /// dirty 标记位。如果为 true，表示小组件在 App 后台期间修改了数据，
  /// 需要重新加载。
  /// 返回 true 表示数据已变更，需要重新加载。
  Future<bool> checkDataDirty() async {
    try {
      final dirty = await _channel.invokeMethod<bool>('checkWidgetDataDirty');
      if (dirty == true) {
        debugPrint('[WidgetService] data dirty flag was set, need reload');
      }
      return dirty ?? false;
    } catch (e) {
      debugPrint('[WidgetService] checkDataDirty error: $e');
      return false;
    }
  }

  /// 清除 dirty 标记。
  ///
  /// 当通过 MethodChannel 收到 dataChanged 通知并已重新加载数据后调用，
  /// 避免下次恢复前台时重复加载。
  Future<void> clearDataDirty() async {
    try {
      await _channel.invokeMethod<bool>('clearWidgetDataDirty');
    } catch (e) {
      debugPrint('[WidgetService] clearDataDirty error: $e');
    }
  }

  /// 将当前经期状态发送给原生端，更新小组件 UI。
  Future<void> updateWidget({
    required List<PeriodRecord> records,
    required CycleData? cycleData,
    required int userCycleLength,
    required int userPeriodLength,
    int todayFlow = 0,
  }) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final json = _buildWidgetJson(
        records: records,
        cycleData: cycleData,
        today: today,
        userCycleLength: userCycleLength,
        userPeriodLength: userPeriodLength,
        todayFlow: todayFlow,
      );

      await _channel.invokeMethod('updateWidget', {'data': jsonEncode(json)});
    } catch (e) {
      debugPrint('[WidgetService] updateWidget error: $e');
    }
  }

  /// 构建小组件数据 JSON。
  Map<String, dynamic> _buildWidgetJson({
    required List<PeriodRecord> records,
    required CycleData? cycleData,
    required DateTime today,
    required int userCycleLength,
    required int userPeriodLength,
    int todayFlow = 0,
  }) {
    PeriodRecord? ongoing;
    PeriodRecord? lastEnded;
    for (final r in records) {
      if (r.isOngoing) {
        ongoing = r;
        break;
      }
      if (r.endDate != null) {
        if (lastEnded == null ||
            r.startDateTime.isAfter(lastEnded.startDateTime)) {
          lastEnded = r;
        }
      }
    }

    bool hasOngoing = ongoing != null;
    int periodDay = 0;
    int daysUntil = -1;
    String predictedDate = '';
    String lastStart = '';
    String lastEnd = '';
    int averageCycle = 0;
    int averagePeriod = 0;
    int cycleCount = 0;

    if (cycleData != null) {
      averageCycle = cycleData.averageCycleLength.round();
      averagePeriod = cycleData.averagePeriodLength.round();
      cycleCount = cycleData.totalCycles;

      final predicted = cycleData.predictedNextPeriod;
      if (predicted != null) {
        daysUntil = predicted.difference(today).inDays;
        if (daysUntil < 0) daysUntil = 0;
        predictedDate = '${predicted.month}月${predicted.day}日';
      }
    }

    if (hasOngoing) {
      periodDay = today.difference(ongoing.startDateTime).inDays + 1;
      lastStart = ongoing.startDate;
    } else if (lastEnded != null) {
      lastStart = lastEnded.startDate;
      lastEnd = lastEnded.endDate ?? '';
    }

    return {
      'hasOngoing': hasOngoing,
      'periodDay': periodDay,
      'daysUntil': daysUntil,
      'predictedDate': predictedDate,
      'lastStart': lastStart,
      'lastEnd': lastEnd,
      'averageCycle': averageCycle,
      'averagePeriod': averagePeriod,
      'cycleCount': cycleCount,
      'todayFlow': todayFlow,
    };
  }
}
