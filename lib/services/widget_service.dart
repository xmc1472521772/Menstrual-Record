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

  /// 将当前经期状态发送给原生端，更新小组件 UI。
  Future<void> updateWidget({
    required List<PeriodRecord> records,
    required CycleData? cycleData,
    required int userCycleLength,
    required int userPeriodLength,
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
    };
  }
}
