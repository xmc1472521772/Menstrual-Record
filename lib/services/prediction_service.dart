import '../models/period_record.dart';
import '../models/cycle_data.dart';
import '../utils/date_utils.dart';

class PredictionService {
  static const int defaultCycleLength = 28;
  static const int defaultPeriodLength = 5;

  static CycleData calculateCycleData(
    List<PeriodRecord> records, {
    String algorithm = 'simple',
  }) {
    if (records.isEmpty) {
      return CycleData(
        averageCycleLength: defaultCycleLength.toDouble(),
        averagePeriodLength: defaultPeriodLength.toDouble(),
        totalCycles: 0,
        recentPeriods: [],
      );
    }

    final sortedRecords = List<PeriodRecord>.from(records)
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    final cycleLengths = <int>[];
    final periodLengths = <int>[];
    final recentPeriods = <PeriodSummary>[];

    for (int i = 0; i < sortedRecords.length; i++) {
      final record = sortedRecords[i];
      final periodDays = record.periodDays;
      periodLengths.add(periodDays);

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

    if (algorithm == 'weighted' && cycleLengths.length >= 3) {
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
    DateTime? predictedNext;
    
    // 如果最后一条记录是正在进行中的经期，则不计算预测
    // 或者使用前一条记录来计算预测
    if (lastRecord.isOngoing) {
      if (sortedRecords.length > 1) {
        final previousRecord = sortedRecords[sortedRecords.length - 2];
        predictedNext = previousRecord.startDateTime.add(
          Duration(days: avgCycle.round()),
        );
      } else {
        predictedNext = null;
      }
    } else {
      predictedNext = lastRecord.startDateTime.add(
        Duration(days: avgCycle.round()),
      );
    }

    return CycleData(
      averageCycleLength: avgCycle,
      averagePeriodLength: avgPeriod,
      totalCycles: cycleLengths.length,
      lastPeriodStart: lastRecord.startDateTime,
      predictedNextPeriod: predictedNext,
      recentPeriods: recentPeriods.reversed.toList(),
    );
  }

  static double _calculateWeightedAverage(List<int> values) {
    if (values.length <= 4) {
      final weights = [0.4, 0.3, 0.2, 0.1];
      double weightedSum = 0;
      double weightTotal = 0;

      for (int i = 0; i < values.length; i++) {
        final weight = weights[i];
        weightedSum += values[values.length - 1 - i] * weight;
        weightTotal += weight;
      }

      return weightedSum / weightTotal;
    } else {
      final lastFour = values.sublist(values.length - 4);
      return _calculateWeightedAverage(lastFour);
    }
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
