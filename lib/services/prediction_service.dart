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

  /// 加权移动平均：最近的周期权重最高。
  ///
  /// 对 `values` 中每个元素赋予线性递减权重——
  /// `values[n-1]`（最新）权重为 `n`，`values[n-2]` 权重为 `n-1`，
  /// …，`values[0]`（最旧）权重为 `1`。
  ///
  /// 示例：values = [23, 17, 17, 33]（从旧到新）
  /// → (23×1 + 17×2 + 17×3 + 33×4) / (1+2+3+4)
  /// = (23 + 34 + 51 + 132) / 10 = 240 / 10 = **24.0**
  static double _calculateWeightedAverage(List<int> values) {
    final n = values.length;
    if (n == 0) return defaultCycleLength.toDouble();

    // values[0] 最旧 → 权重 1；values[n-1] 最新 → 权重 n
    double weightedSum = 0;
    double weightTotal = 0;
    for (int i = 0; i < n; i++) {
      final weight = (i + 1).toDouble();
      weightedSum += values[i] * weight;
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
