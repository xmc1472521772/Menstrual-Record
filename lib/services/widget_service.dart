import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/cycle_data.dart';
import '../models/period_record.dart';

/// 桌面小组件通信服务。
///
/// 负责两件事：
/// 1. 将经期数据序列化为 JSON 并通过 MethodChannel 发送给原生端更新小组件
/// 2. 接收小组件按钮操作（开始经期/结束经期/记录经量）并回调
class WidgetService {
  static const _channel = MethodChannel('com.yima.yimaflutter/widget');

  static WidgetService? _instance;
  static WidgetService get instance => _instance ??= WidgetService._();

  WidgetService._();

  /// 小组件操作回调。
  /// 当用户在桌面小组件上点击按钮时触发。
  /// [action] 为 "start_period" / "end_period" / "set_flow"。
  /// [flowLevel] 仅 set_flow 操作有值（1=少, 2=中, 3=多）。
  void Function(String action, int? flowLevel)? onWidgetAction;

  /// 初始化 MethodChannel，监听来自小组件的操作。
  void init() {
    _channel.setMethodCallHandler((call) async {
      debugPrint('[WidgetService] method call: ${call.method}');
      if (call.method == 'handleWidgetAction') {
        final args = call.arguments as Map?;
        final action = args?['action'] as String? ?? '';
        final flowLevel = args?['flowLevel'] as int?;

        // 将原生 action 转为 Flutter 层的语义 action
        String flutterAction;
        switch (action) {
          case 'com.yima.yimaflutter.ACTION_START_PERIOD':
            flutterAction = 'start_period';
            break;
          case 'com.yima.yimaflutter.ACTION_END_PERIOD':
            flutterAction = 'end_period';
            break;
          case 'com.yima.yimaflutter.ACTION_SET_FLOW':
            flutterAction = 'set_flow';
            break;
          case 'com.yima.yimaflutter.ACTION_OPEN_APP':
            flutterAction = 'open_app';
            break;
          default:
            flutterAction = action;
        }

        debugPrint('[WidgetService] widget action: $flutterAction, flow: $flowLevel');
        onWidgetAction?.call(flutterAction, flowLevel);
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

  /// 仅刷新小组件 UI（不重新写入数据）。
  Future<void> refreshWidget() async {
    try {
      await _channel.invokeMethod('refreshWidget');
    } catch (e) {
      debugPrint('[WidgetService] refreshWidget error: $e');
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
    // 查找进行中的经期
    PeriodRecord? ongoing;
    PeriodRecord? lastEnded;
    for (final r in records) {
      if (r.isOngoing) {
        ongoing = r;
        break;
      }
      if (r.endDate != null && lastEnded == null) {
        lastEnded = r;
      } else if (r.endDate != null) {
        // 取 startDate 最新的已结束记录
        if (r.startDateTime.isAfter(lastEnded!.startDateTime)) {
          lastEnded = r;
        }
      }
    }

    // 如果没有找到 ongoing 但有 lastEnded，也尝试找最新的已结束记录
    if (ongoing == null && lastEnded == null) {
      for (final r in records) {
        if (r.endDate != null) {
          if (lastEnded == null ||
              r.startDateTime.isAfter(lastEnded.startDateTime)) {
            lastEnded = r;
          }
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
        predictedDate =
            '${predicted.month}月${predicted.day}日';
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
