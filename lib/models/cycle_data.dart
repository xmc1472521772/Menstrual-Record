class CycleData {
  final double averageCycleLength;
  final double averagePeriodLength;
  final int totalCycles;
  final DateTime? lastPeriodStart;
  final DateTime? predictedNextPeriod;
  final List<PeriodSummary> recentPeriods;

  CycleData({
    required this.averageCycleLength,
    required this.averagePeriodLength,
    required this.totalCycles,
    this.lastPeriodStart,
    this.predictedNextPeriod,
    required this.recentPeriods,
  });

  int get daysUntilPredicted {
    if (predictedNextPeriod == null) return 0;
    return predictedNextPeriod!.difference(DateTime.now()).inDays;
  }

  int get currentCycleDay {
    if (lastPeriodStart == null) return 0;
    return DateTime.now().difference(lastPeriodStart!).inDays + 1;
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

  bool isSafeDay(DateTime date) {
    if (lastPeriodStart == null) return false;
    // 安全期：除了经期、易孕期之外的日子
    // 这里简化处理：如果不在经期、排卵期、易孕期，则为安全期
    return !isOvulationDay(date) && !isFertileDay(date);
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
