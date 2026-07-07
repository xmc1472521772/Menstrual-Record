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

  /// Returns the number of days until the predicted next period.
  /// Returns `null` when [predictedNextPeriod] is null (no prediction available).
  /// Returns a negative integer when the predicted date has already passed.
  int? get daysUntilPredicted {
    if (predictedNextPeriod == null) return null;
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
