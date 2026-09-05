/// 预测算法的运行模式标签，供 UI 展示。
enum PredictionMode {
  /// 医学基线（数据不足时的默认值）
  baseline,
  /// 自适应加权移动平均（规律用户）
  wmaRegular,
  /// 短窗口加权 + 剪切均值（波动大 / 检测到突变）
  wmaVolatile,
  /// 简单平均（全部历史算术平均）
  simple,
}

class CycleData {
  final double averageCycleLength;
  final double averagePeriodLength;
  final int totalCycles;
  final DateTime? lastPeriodStart;
  final DateTime? predictedNextPeriod;
  final List<PeriodSummary> recentPeriods;

  /// 当前预测所使用的算法模式，用于 UI 展示。
  final PredictionMode predictionMode;

  /// 预测窗口的天数范围（不规律用户区间更宽）。
  /// null 表示无法计算（数据不足）。
  final int? predictionWindowDays;

  /// 计算时的「今天」，用于 daysUntilPredicted / currentCycleDay 的稳定取值。
  /// 避免每次 getter 调用 DateTime.now() 导致同一帧内可能不一致。
  final DateTime _today;

  CycleData({
    required this.averageCycleLength,
    required this.averagePeriodLength,
    required this.totalCycles,
    this.lastPeriodStart,
    this.predictedNextPeriod,
    required this.recentPeriods,
    this.predictionMode = PredictionMode.simple,
    this.predictionWindowDays,
    DateTime? today,
  }) : _today = today ?? DateTime.now();

  /// Returns the number of days until the predicted next period.
  /// Returns `null` when [predictedNextPeriod] is null (no prediction available).
  /// Returns a negative integer when the predicted date has already passed.
  ///
  /// Uses date-only comparison (strips time-of-day) so that the result is
  /// stable throughout the day regardless of the current hour.
  int? get daysUntilPredicted {
    if (predictedNextPeriod == null) return null;
    final today = DateTime(_today.year, _today.month, _today.day);
    final predicted = DateTime(
      predictedNextPeriod!.year,
      predictedNextPeriod!.month,
      predictedNextPeriod!.day,
    );
    return predicted.difference(today).inDays;
  }

  /// Returns the current cycle day (1-based).
  ///
  /// Uses date-only comparison (strips time-of-day) so that the result is
  /// stable throughout the day regardless of the current hour.
  int get currentCycleDay {
    if (lastPeriodStart == null) return 0;
    final today = DateTime(_today.year, _today.month, _today.day);
    final start = DateTime(
      lastPeriodStart!.year,
      lastPeriodStart!.month,
      lastPeriodStart!.day,
    );
    return today.difference(start).inDays + 1;
  }

  DateTime? get ovulationDay {
    if (predictedNextPeriod == null) return null;
    // 排卵期通常在下次月经前14天
    return predictedNextPeriod!.subtract(const Duration(days: 14));
  }

  DateTime? get fertileWindowStart {
    if (ovulationDay == null) return null;
    // 易孕期开始：排卵期前5天
    return ovulationDay!.subtract(const Duration(days: 5));
  }

  DateTime? get fertileWindowEnd {
    if (ovulationDay == null) return null;
    // 易孕期结束：排卵期后4天
    return ovulationDay!.add(const Duration(days: 4));
  }

  /// 预测窗口的起始日期（predictedNextPeriod - windowDays/2）。
  DateTime? get predictionWindowStart {
    if (predictedNextPeriod == null || predictionWindowDays == null) {
      return null;
    }
    return predictedNextPeriod!
        .subtract(Duration(days: predictionWindowDays! ~/ 2));
  }

  /// 预测窗口的结束日期（predictedNextPeriod + windowDays/2）。
  DateTime? get predictionWindowEnd {
    if (predictedNextPeriod == null || predictionWindowDays == null) {
      return null;
    }
    return predictedNextPeriod!
        .add(Duration(days: predictionWindowDays! ~/ 2));
  }

  bool isOvulationDay(DateTime date) {
    if (ovulationDay == null) return false;
    return date.year == ovulationDay!.year &&
        date.month == ovulationDay!.month &&
        date.day == ovulationDay!.day;
  }

  bool isFertileDay(DateTime date) {
    if (fertileWindowStart == null || fertileWindowEnd == null) return false;
    return (date.isAfter(fertileWindowStart!) ||
            date.isAtSameMomentAs(fertileWindowStart!)) &&
        (date.isBefore(fertileWindowEnd!) ||
            date.isAtSameMomentAs(fertileWindowEnd!));
  }
}

class PeriodSummary {
  final DateTime startDate;
  final DateTime? endDate;
  final int periodDays;
  final int? cycleLength;

  PeriodSummary({
    required this.startDate,
    this.endDate,
    required this.periodDays,
    this.cycleLength,
  });
}
