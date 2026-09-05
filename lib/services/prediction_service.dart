import '../models/period_record.dart';
import '../models/cycle_data.dart';
import '../utils/date_utils.dart';

class PredictionService {
  static const int defaultCycleLength = 28;
  static const int defaultPeriodLength = 5;

  static CycleData calculateCycleData(
    List<PeriodRecord> records, {
    String algorithm = 'simple',
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();

    if (records.isEmpty) {
      return CycleData(
        averageCycleLength: defaultCycleLength.toDouble(),
        averagePeriodLength: defaultPeriodLength.toDouble(),
        totalCycles: 0,
        recentPeriods: [],
        today: now,
      );
    }

    final sortedRecords = List<PeriodRecord>.from(records)
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    final cycleLengths = <int>[];
    final periodLengths = <int>[];
    final recentPeriods = <PeriodSummary>[];

    for (int i = 0; i < sortedRecords.length; i++) {
      final record = sortedRecords[i];
      final periodDays = record.periodDaysAt(now);

      // Only include completed records in the period length average.
      // Ongoing records use DateTime.now() for periodDays which would skew
      // the average — but we still add them to recentPeriods for display.
      if (!record.isOngoing) {
        periodLengths.add(periodDays);
      }

      int? cycleLength;
      if (i > 0) {
        cycleLength = AppDateUtils.daysBetween(
          record.startDateTime,
          sortedRecords[i - 1].startDateTime,
        );
        cycleLengths.add(cycleLength);
      }

      recentPeriods.add(PeriodSummary(
        startDate: record.startDateTime,
        endDate: record.endDateTime,
        periodDays: periodDays,
        cycleLength: cycleLength,
      ));
    }

    double avgCycle;
    double avgPeriod;

    if (algorithm == 'weighted' && cycleLengths.length >= 2) {
      avgCycle = _calculateWeightedAverage(cycleLengths);
    } else if (cycleLengths.isNotEmpty) {
      avgCycle = cycleLengths.reduce((a, b) => a + b) / cycleLengths.length;
    } else {
      avgCycle = defaultCycleLength.toDouble();
    }

    avgPeriod = periodLengths.isNotEmpty
        ? periodLengths.reduce((a, b) => a + b) / periodLengths.length
        : defaultPeriodLength.toDouble();

    final lastRecord = sortedRecords.last;

    // 无论最后一条记录是否结束，都基于其开始日期 + 平均周期来预测下一次经期。
    // - 已结束：预测下一次经期 ✓
    // - 进行中：预测下一次经期（而非本次）✓
    final predictedNext = lastRecord.startDateTime.add(
      Duration(days: avgCycle.round()),
    );

    return CycleData(
      averageCycleLength: avgCycle,
      averagePeriodLength: avgPeriod,
      totalCycles: cycleLengths.length,
      lastPeriodStart: lastRecord.startDateTime,
      predictedNextPeriod: predictedNext,
      recentPeriods: recentPeriods.reversed.toList(),
      today: now,
    );
  }

  /// 加权移动平均：取最近 [windowSize] 个周期，最近的权重最高。
  ///
  /// 这是一种**滑动窗口**算法——只用最近几个周期，而非全部历史。
  /// 窗口内使用线性递减权重：最新权重为 `n`，次新为 `n-1`，…，最旧为 `1`。
  ///
  /// 示例：全部周期 = [..., 38, 40, 33, 17, 17, 23]（从旧到新）
  /// 取最近 6 个 → [38, 40, 33, 17, 17, 23]
  /// → (38×1 + 40×2 + 33×3 + 17×4 + 17×5 + 23×6) / (1+2+3+4+5+6)
  /// = (38 + 80 + 99 + 68 + 85 + 138) / 21 = 508 / 21 ≈ **24.2**
  ///
  /// 如果窗口内数据不足 2 个，回退到简单平均。
  static double _calculateWeightedAverage(List<int> values) {
    if (values.isEmpty) return defaultCycleLength.toDouble();

    // 滑动窗口：只取最近 windowSize 个周期
    const windowSize = 6;
    final window = values.length > windowSize
        ? values.sublist(values.length - windowSize)
        : values;
    final n = window.length;
    if (n < 2) {
      return window.first.toDouble();
    }

    // window[0] 最旧 → 权重 1；window[n-1] 最新 → 权重 n
    double weightedSum = 0;
    double weightTotal = 0;
    for (int i = 0; i < n; i++) {
      final weight = (i + 1).toDouble();
      weightedSum += window[i] * weight;
      weightTotal += weight;
    }

    return weightedSum / weightTotal;
  }

  static DateTime? predictNextPeriod(
    List<PeriodRecord> records, {
    String algorithm = 'simple',
  }) {
    final cycleData = calculateCycleData(records, algorithm: algorithm);
    return cycleData.predictedNextPeriod;
  }

  static List<DateTime> getPredictedPeriodDays(
    List<PeriodRecord> records, {
    String algorithm = 'simple',
    int? periodLength,
  }) {
    final cycleData = calculateCycleData(records, algorithm: algorithm);
    if (cycleData.predictedNextPeriod == null) return [];

    final length = periodLength ?? cycleData.averagePeriodLength.round();
    final days = <DateTime>[];

    for (int i = 0; i < length; i++) {
      days.add(cycleData.predictedNextPeriod!.add(Duration(days: i)));
    }

    return days;
  }

  static DateTime? getOvulationDay(
    List<PeriodRecord> records, {
    String algorithm = 'simple',
  }) {
    final cycleData = calculateCycleData(records, algorithm: algorithm);
    return cycleData.ovulationDay;
  }

  static List<DateTime> getFertileWindowDays(
    List<PeriodRecord> records, {
    String algorithm = 'simple',
  }) {
    final cycleData = calculateCycleData(records, algorithm: algorithm);
    if (cycleData.fertileWindowStart == null || cycleData.fertileWindowEnd == null) {
      return [];
    }

    final days = <DateTime>[];
    var current = cycleData.fertileWindowStart!;
    final end = cycleData.fertileWindowEnd!;

    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      days.add(current);
      current = current.add(const Duration(days: 1));
    }

    return days;
  }
}
