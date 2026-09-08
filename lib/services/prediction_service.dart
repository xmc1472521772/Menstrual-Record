import 'dart:math';
import '../models/period_record.dart';
import '../models/cycle_data.dart';
import '../utils/date_utils.dart';

/// 自适应预测结果（内部使用）。
class _AdaptiveResult {
  const _AdaptiveResult(this.value, this.mode, this.windowDays);
  final double value;
  final PredictionMode mode;
  final int windowDays;
}

/// 自适应混合预测引擎（Adaptive Hybrid Prediction Engine）。
///
/// 根据用户数据特征自动选择最优算法：
///
/// * **N < 3（冷启动）**：医学基线法——使用用户设置或默认 28 天。
/// * **N ≥ 3（成熟阶段）**：先评估近 6 个周期的波动率（标准差）和突变检测，
///   再分流：
///   - 高度规律（STD ≤ 3）→ WMA-6（6 期加权移动平均）
///   - 高波动 / 突变（STD > 5 或近 2 期均值偏离历史 > 7 天）→
///     WMA-3 + 剪切均值
///   - 介于两者之间 → WMA-6（默认路径）
class PredictionService {
  static const int defaultCycleLength = 28;
  static const int defaultPeriodLength = 5;

  // ─── 算法阈值常量 ──────────────────────────────────────────────

  /// 冷启动阈值：周期数 < 此值时走医学基线
  static const int _coldStartThreshold = 3;

  /// 滑动窗口最大长度
  static const int _windowMaxSize = 6;

  /// 短窗口长度（突变 / 高波动时使用）
  static const int _shortWindowSize = 3;

  /// 高波动阈值：标准差 > 此值 → 不规律用户
  static const double _volatileStdThreshold = 5.0;

  /// 突变检测阈值：近 2 期均值与历史均值偏差 > 此值（天）→ 检测到突变
  static const double _trendShiftThreshold = 7.0;

  /// 周期生理合理区间
  static const int _minCycleDays = 21;
  static const int _maxCycleDays = 45;

  static CycleData calculateCycleData(
    List<PeriodRecord> records, {
    String algorithm = 'adaptive',
    DateTime? today,
    int? userCycleLength,
    int? userPeriodLength,
  }) {
    final now = today ?? DateTime.now();

    // 冷启动/无数据时的回退值：优先使用用户设置，未提供则用默认常量。
    // 与设置页提示一致："记录不足时会使用以下默认值进行预测"。
    final fallbackCycle = (userCycleLength ?? defaultCycleLength).toDouble();
    final fallbackPeriod = (userPeriodLength ?? defaultPeriodLength).toDouble();

    if (records.isEmpty) {
      return CycleData(
        averageCycleLength: fallbackCycle,
        averagePeriodLength: fallbackPeriod,
        totalCycles: 0,
        recentPeriods: [],
        today: now,
        predictionMode: PredictionMode.baseline,
        predictionWindowDays: null,
      );
    }

    final sortedRecords = List<PeriodRecord>.from(records)
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    // ─── 收集周期长度和经期天数 ───────────────────────────────
    final cycleLengths = <int>[];
    final periodLengths = <int>[];
    final recentPeriods = <PeriodSummary>[];

    for (int i = 0; i < sortedRecords.length; i++) {
      final record = sortedRecords[i];
      final periodDays = record.periodDaysAt(now);

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

    // ─── 经期天数平均（简单平均，所有已完成记录） ─────────────
    final avgPeriod = periodLengths.isNotEmpty
        ? periodLengths.reduce((a, b) => a + b) / periodLengths.length
        : fallbackPeriod;

    // ─── 根据算法选择计算路径 ─────────────────────────────────
    late double avgCycle;
    late PredictionMode mode;
    late int windowDays;

    if (algorithm == 'simple') {
      // ── 简单平均法 ──
      if (cycleLengths.isNotEmpty) {
        avgCycle = cycleLengths.reduce((a, b) => a + b) / cycleLengths.length;
      } else {
        avgCycle = fallbackCycle;
      }
      mode = PredictionMode.simple;
      windowDays = 2;
    } else {
      // ── 自适应算法（adaptive / weighted 统一走自适应路径） ──
      final result = _adaptivePredict(cycleLengths, fallbackCycle: fallbackCycle);
      avgCycle = result.value;
      mode = result.mode;
      windowDays = result.windowDays;
    }

    // 限制在生理合理区间
    avgCycle = avgCycle.clamp(_minCycleDays.toDouble(), _maxCycleDays.toDouble());

    final lastRecord = sortedRecords.last;

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
      predictionMode: mode,
      predictionWindowDays: windowDays,
    );
  }

  // ─── 自适应预测核心 ────────────────────────────────────────────

  /// 三段式自适应算法入口。
  static _AdaptiveResult _adaptivePredict(
    List<int> cycleLengths, {
    required double fallbackCycle,
  }) {
    final n = cycleLengths.length;

    // ── 阶段 1：冷启动（N < 3） ──
    if (n == 0) {
      return _AdaptiveResult(
        fallbackCycle,
        PredictionMode.baseline,
        5, // 冷启动时窗口稍宽
      );
    }

    if (n < _coldStartThreshold) {
      // N=1~2：简单算术平均，限制在 21~35 天
      final avg = cycleLengths.reduce((a, b) => a + b) / n;
      return _AdaptiveResult(
        avg.clamp(21.0, 35.0),
        PredictionMode.baseline,
        4,
      );
    }

    // ── 阶段 2：成熟阶段（N ≥ 3） ──
    // 取最近最多 6 个周期进行分析
    final recent = cycleLengths.length > _windowMaxSize
        ? cycleLengths.sublist(cycleLengths.length - _windowMaxSize)
        : cycleLengths;
    final recentN = recent.length;

    // 标准差
    final mean = recent.reduce((a, b) => a + b) / recentN;
    final variance =
        recent.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / recentN;
    final std = sqrt(variance);

    // ── 突变检测：近 2 次平均值 vs 历史均值 ──
    final recent2 = cycleLengths.sublist(
      cycleLengths.length - 2,
    );
    final recent2Avg = recent2.reduce((a, b) => a + b) / 2;

    double historicalAvg;
    if (cycleLengths.length > 2) {
      final historical = cycleLengths.sublist(
        0,
        cycleLengths.length - 2,
      );
      historicalAvg =
          historical.reduce((a, b) => a + b) / historical.length;
    } else {
      historicalAvg = mean;
    }

    final isTrendShift = (recent2Avg - historicalAvg).abs() > _trendShiftThreshold;

    // ── 阶段 3：算法分流 ──
    if (isTrendShift || std > _volatileStdThreshold) {
      // 高波动 / 突变 → WMA-3 + 剪切均值
      return _predictVolatile(cycleLengths, fallbackCycle: fallbackCycle);
    } else {
      // 规律 / 轻度波动 → WMA-6
      return _predictRegular(recent);
    }
  }

  /// 规律用户：6 期加权移动平均（WMA-6）。
  ///
  /// 窗口内线性递增权重：最旧 1, …, 最新 n。
  /// 规律用户窗口窄（±1 天）。
  static _AdaptiveResult _predictRegular(List<int> window) {
    final n = window.length;
    if (n < 2) {
      return _AdaptiveResult(
        window.first.toDouble(),
        PredictionMode.wmaRegular,
        2,
      );
    }

    double weightedSum = 0;
    double weightTotal = 0;
    for (int i = 0; i < n; i++) {
      final weight = (i + 1).toDouble();
      weightedSum += window[i] * weight;
      weightTotal += weight;
    }

    final value = weightedSum / weightTotal;
    return _AdaptiveResult(value, PredictionMode.wmaRegular, 2);
  }

  /// 高波动 / 突变用户：WMA-3 + 剪切均值。
  ///
  /// 1. 取最近 3 个周期。
  /// 2. 如果 3 个数据中存在明显离群值（与中位数偏差 > 1.5×IQR），先剔除。
  /// 3. 对剩余数据做加权平均（权重 0.2, 0.3, 0.5）。
  /// 4. 窗口更宽（±3 天），反映不确定性。
  static _AdaptiveResult _predictVolatile(
    List<int> cycleLengths, {
    required double fallbackCycle,
  }) {
    // 取最近 3 个周期
    final window = cycleLengths.length >= _shortWindowSize
        ? cycleLengths.sublist(cycleLengths.length - _shortWindowSize)
        : cycleLengths;
    final n = window.length;

    if (n == 0) {
      return _AdaptiveResult(
        fallbackCycle,
        PredictionMode.wmaVolatile,
        6,
      );
    }

    if (n == 1) {
      return _AdaptiveResult(
        window[0].toDouble(),
        PredictionMode.wmaVolatile,
        6,
      );
    }

    // 剪切均值：剔除极端离群值
    final trimmed = _trimOutliers(window);

    if (trimmed.length == 1) {
      return _AdaptiveResult(
        trimmed[0].toDouble(),
        PredictionMode.wmaVolatile,
        6,
      );
    }

    // 对剪切后的数据做加权平均（权重 0.2, 0.3, 0.5）
    final weights = [0.2, 0.3, 0.5];
    double weightedSum = 0;
    for (int i = 0; i < trimmed.length; i++) {
      // 如果只有 2 个数据，用 0.3 和 0.7 的权重
      final w = trimmed.length == 2 ? [0.3, 0.7][i] : weights[i];
      weightedSum += trimmed[i] * w;
    }

    return _AdaptiveResult(weightedSum, PredictionMode.wmaVolatile, 6);
  }

  /// 离群值剔除：基于 IQR（四分位距）方法。
  ///
  /// 如果某个值与中位数的偏差超过 1.5×IQR，视为离群值并剔除。
  static List<int> _trimOutliers(List<int> values) {
    if (values.length <= 2) return List.from(values);

    final sorted = List<int>.from(values)..sort();

    // Q1 和 Q3
    final q1 = _percentile(sorted, 0.25);
    final q3 = _percentile(sorted, 0.75);
    final iqr = q3 - q1;

    // 中位数
    final median = _percentile(sorted, 0.5);

    // 离群值边界
    final lowerBound = median - 1.5 * iqr;
    final upperBound = median + 1.5 * iqr;

    // 如果 IQR == 0（所有值相同或只有两种值），不做剔除
    if (iqr == 0) return List.from(values);

    return values.where((v) => v >= lowerBound && v <= upperBound).toList();
  }

  /// 计算分位数（最近邻插值法）。
  static double _percentile(List<int> sorted, double p) {
    final n = sorted.length;
    if (n == 0) return 0;
    if (n == 1) return sorted[0].toDouble();

    final index = (n - 1) * p;
    final lower = index.floor();
    final upper = index.ceil();

    if (lower == upper) return sorted[lower].toDouble();

    return sorted[lower] + (sorted[upper] - sorted[lower]) * (index - lower);
  }

  // ─── 便捷静态方法 ──────────────────────────────────────────────

  static DateTime? predictNextPeriod(
    List<PeriodRecord> records, {
    String algorithm = 'adaptive',
  }) {
    final cycleData = calculateCycleData(records, algorithm: algorithm);
    return cycleData.predictedNextPeriod;
  }

  static List<DateTime> getPredictedPeriodDays(
    List<PeriodRecord> records, {
    String algorithm = 'adaptive',
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
    String algorithm = 'adaptive',
  }) {
    final cycleData = calculateCycleData(records, algorithm: algorithm);
    return cycleData.ovulationDay;
  }

  static List<DateTime> getFertileWindowDays(
    List<PeriodRecord> records, {
    String algorithm = 'adaptive',
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
