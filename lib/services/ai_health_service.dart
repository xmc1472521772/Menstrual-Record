import 'dart:async';
import 'dart:convert';
import 'dart:math' show sqrt;
import 'package:http/http.dart' as http;
import '../models/period_record.dart';
import '../models/cycle_data.dart';

// ═══════════════════════════════════════════════════════════════
//  数据模型
// ═══════════════════════════════════════════════════════════════

/// 问答消息项。
class ChatMessage {
  final String role;
  final String content;
  final DateTime timestamp;

  const ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });
}

/// 统计数据项（键值对形式，用于周期趋势等区域展示）。
class StatItem {
  final String label;
  final String value;

  const StatItem({
    required this.label,
    required this.value,
  });

  factory StatItem.fromJson(Map<String, dynamic> json) {
    return StatItem(
      label: json['label'] as String? ?? '',
      value: json['value'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'value': value,
      };
}

/// 趋势变化项（用于症状趋势、与过去相比等区域）。
class TrendItem {
  final String name;
  final String status;
  final String detail;

  const TrendItem({
    required this.name,
    required this.status,
    required this.detail,
  });

  factory TrendItem.fromJson(Map<String, dynamic> json) {
    return TrendItem(
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'status': status,
        'detail': detail,
      };
}

/// 关注项（用于"值得关注的地方"区域）。
class AttentionItem {
  final String title;
  final String detail;
  final String evidence;

  const AttentionItem({
    required this.title,
    required this.detail,
    required this.evidence,
  });

  factory AttentionItem.fromJson(Map<String, dynamic> json) {
    return AttentionItem(
      title: json['title'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      evidence: json['evidence'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'detail': detail,
        'evidence': evidence,
      };
}

/// 下一周期建议项。
class NextCycleSuggestion {
  final String title;
  final String detail;

  const NextCycleSuggestion({
    required this.title,
    required this.detail,
  });

  factory NextCycleSuggestion.fromJson(Map<String, dynamic> json) {
    return NextCycleSuggestion(
      title: json['title'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'detail': detail,
      };
}

/// 就医提醒项。
class MedicalReminder {
  final String condition;
  final String detail;
  final bool userMatched;

  const MedicalReminder({
    required this.condition,
    required this.detail,
    this.userMatched = false,
  });

  factory MedicalReminder.fromJson(Map<String, dynamic> json) {
    return MedicalReminder(
      condition: json['condition'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      userMatched: json['userMatched'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'condition': condition,
        'detail': detail,
        'userMatched': userMatched,
      };
}

/// 完整的AI健康报告（7 部分结构）。
class HealthReport {
  final DateTime generatedAt;

  /// 1. 本周期概览
  final String currentOverview;

  /// 2. 周期趋势 — 统计数据项
  final List<StatItem> cycleStats;
  /// 2. 周期趋势 — 趋势描述
  final String cycleTrendSummary;

  /// 3. 症状趋势
  final List<TrendItem> symptomTrends;

  /// 4. 与过去相比
  final List<TrendItem> comparisonTrends;

  /// 5. 值得关注的地方
  final List<AttentionItem> attentions;

  /// 6. 下一周期建议
  final List<NextCycleSuggestion> nextCycleSuggestions;

  /// 7. 就医提醒
  final List<MedicalReminder> medicalReminders;

  /// 总结
  final String conclusion;

  /// 健康评分（0-100）
  final int healthScore;

  const HealthReport({
    required this.generatedAt,
    required this.currentOverview,
    required this.cycleStats,
    required this.cycleTrendSummary,
    required this.symptomTrends,
    required this.comparisonTrends,
    required this.attentions,
    required this.nextCycleSuggestions,
    required this.medicalReminders,
    required this.conclusion,
    required this.healthScore,
  });

  factory HealthReport.fromJson(Map<String, dynamic> json) {
    final cycleStatsRaw = json['cycleStats'] as List? ?? [];
    final cycleStats = cycleStatsRaw
        .map((e) => StatItem.fromJson(e as Map<String, dynamic>))
        .toList();

    final symptomTrendsRaw = json['symptomTrends'] as List? ?? [];
    final symptomTrends = symptomTrendsRaw
        .map((e) => TrendItem.fromJson(e as Map<String, dynamic>))
        .toList();

    final comparisonTrendsRaw = json['comparisonTrends'] as List? ?? [];
    final comparisonTrends = comparisonTrendsRaw
        .map((e) => TrendItem.fromJson(e as Map<String, dynamic>))
        .toList();

    final attentionsRaw = json['attentions'] as List? ?? [];
    final attentions = attentionsRaw
        .map((e) => AttentionItem.fromJson(e as Map<String, dynamic>))
        .toList();

    final nextCycleRaw = json['nextCycleSuggestions'] as List? ?? [];
    final nextCycleSuggestions = nextCycleRaw
        .map((e) => NextCycleSuggestion.fromJson(e as Map<String, dynamic>))
        .toList();

    final medicalRaw = json['medicalReminders'] as List? ?? [];
    final medicalReminders = medicalRaw
        .map((e) => MedicalReminder.fromJson(e as Map<String, dynamic>))
        .toList();

    return HealthReport(
      generatedAt: DateTime.now(),
      currentOverview: json['currentOverview'] as String? ?? '',
      cycleStats: cycleStats,
      cycleTrendSummary: json['cycleTrendSummary'] as String? ?? '',
      symptomTrends: symptomTrends,
      comparisonTrends: comparisonTrends,
      attentions: attentions,
      nextCycleSuggestions: nextCycleSuggestions,
      medicalReminders: medicalReminders,
      conclusion: json['conclusion'] as String? ?? '',
      healthScore: (json['healthScore'] as num?)?.toInt() ?? 75,
    );
  }

  Map<String, dynamic> toJson() => {
        'generatedAt': generatedAt.toIso8601String(),
        'currentOverview': currentOverview,
        'cycleStats': cycleStats.map((e) => e.toJson()).toList(),
        'cycleTrendSummary': cycleTrendSummary,
        'symptomTrends': symptomTrends.map((e) => e.toJson()).toList(),
        'comparisonTrends': comparisonTrends.map((e) => e.toJson()).toList(),
        'attentions': attentions.map((e) => e.toJson()).toList(),
        'nextCycleSuggestions':
            nextCycleSuggestions.map((e) => e.toJson()).toList(),
        'medicalReminders': medicalReminders.map((e) => e.toJson()).toList(),
        'conclusion': conclusion,
        'healthScore': healthScore,
      };
}

// ═══════════════════════════════════════════════════════════════
//  AI健康分析服务
// ═══════════════════════════════════════════════════════════════

/// AI健康分析服务。
///
/// 通过调用智谱GLM-4-flash大模型，基于用户的经期记录、周期数据和每日经量数据，
/// 进行客观、严谨的数据分析与健康提示。
class AIHealthService {
  /// 智谱API端点
  static const String _apiUrl =
      'https://open.bigmodel.cn/api/paas/v4/chat/completions';

  /// API Key —— 从编译时环境变量读取，避免硬编码
  static const String _apiKey = String.fromEnvironment(
    'GLM_API_KEY',
    defaultValue: '',
  );

  /// 模型名称
  static const String _model = 'glm-4-flash';

  /// API Key 是否已配置
  static bool get isConfigured => _apiKey.isNotEmpty;

  // ─── 健康报告生成 ──────────────────────────────────────────────

  /// 生成完整的健康分析报告（异步，调用智谱GLM API）。
  static Future<HealthReport?> generateReport({
    required List<PeriodRecord> records,
    required CycleData cycleData,
    required Map<int, int> dailyFlowMap,
    required int userCycleLength,
    required int userPeriodLength,
  }) async {
    if (records.isEmpty) return null;

    final dataText = _buildUserDataText(
      records, cycleData, dailyFlowMap, userCycleLength, userPeriodLength,
    );
    final systemPrompt = _buildSystemPrompt();
    final userMessage = _buildUserMessage(dataText);
    final response = await _callApi(systemPrompt, userMessage);
    return _parseResponse(response);
  }

  // ─── 问答功能 ──────────────────────────────────────────────────

  /// 基于用户经期数据进行限定域问答。
  ///
  /// [chatHistory] 为之前的对话历史（不含本次问题）。
  /// 返回AI的回答文本。
  static Future<String> askQuestion({
    required String question,
    required List<PeriodRecord> records,
    required CycleData cycleData,
    required Map<int, int> dailyFlowMap,
    required int userCycleLength,
    required int userPeriodLength,
    List<ChatMessage> chatHistory = const [],
  }) async {
    final dataText = _buildUserDataText(
      records, cycleData, dailyFlowMap, userCycleLength, userPeriodLength,
    );

    final systemPrompt = _buildQASystemPrompt(dataText);

    // 构建消息列表（历史 + 当前问题）
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    // 加入历史对话（最多最近6轮）
    final recentHistory = chatHistory.length > 12
        ? chatHistory.sublist(chatHistory.length - 12)
        : chatHistory;
    for (final msg in recentHistory) {
      messages.add({'role': msg.role, 'content': msg.content});
    }

    // 当前问题
    messages.add({'role': 'user', 'content': question});

    return _callApiWithMessages(messages);
  }

  // ═══════════════════════════════════════════════════════════════
  //  本地数据收集
  // ═══════════════════════════════════════════════════════════════

  static String _buildUserDataText(
    List<PeriodRecord> records,
    CycleData cycleData,
    Map<int, int> dailyFlowMap,
    int userCycleLength,
    int userPeriodLength,
  ) {
    final sorted = List<PeriodRecord>.from(records)
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    final lastRecord = sorted.first;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 按时间正序排列，用于计算周期长度序列
    final chronological = List<PeriodRecord>.from(records)
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    // 计算周期长度序列
    final cycleLengths = <int>[];
    for (int i = 1; i < chronological.length; i++) {
      final diff = chronological[i].startDateTime
          .difference(chronological[i - 1].startDateTime)
          .inDays;
      cycleLengths.add(diff);
    }

    // 计算经期天数序列
    final periodDays = chronological.map((r) => r.periodDays).toList();

    final buffer = StringBuffer();

    // ═══════════════════════════════════════════════════════════════
    //  一、基本信息
    // ═══════════════════════════════════════════════════════════════
    buffer.writeln('【个人基本信息与历史数据】');
    buffer.writeln('- 上一次月经来潮日期：${lastRecord.startDate}');
    buffer.writeln('- 总记录条数：${records.length} 条');
    buffer.writeln('- 总周期数：${cycleData.totalCycles} 个');

    if (cycleData.totalCycles > 0) {
      buffer.writeln(
        '- 历史平均周期长度：${cycleData.averageCycleLength.toStringAsFixed(1)} 天（用户设置值：$userCycleLength 天）',
      );
      buffer.writeln(
        '- 平均经期持续天数：${cycleData.averagePeriodLength.toStringAsFixed(1)} 天（用户设置值：$userPeriodLength 天）',
      );
    } else {
      buffer.writeln('- 历史平均周期长度：暂无足够数据（用户设置值：$userCycleLength 天）');
      buffer.writeln('- 平均经期持续天数：暂无足够数据（用户设置值：$userPeriodLength 天）');
    }

    buffer.write('- 当前状态：');
    if (lastRecord.isOngoing) {
      buffer.writeln('经期进行中（第${lastRecord.periodDays}天）');
    } else {
      final daysSinceLast = today.difference(lastRecord.startDateTime).inDays;
      final expectedCycle = cycleData.averageCycleLength.round();
      final deviation = daysSinceLast - expectedCycle;
      if (deviation > 0) {
        buffer.writeln('距上次经期开始已 $daysSinceLast 天，比预期推迟了 $deviation 天');
      } else if (deviation < 0) {
        buffer.writeln('距上次经期开始已 $daysSinceLast 天，比预期提前了 ${-deviation} 天');
      } else {
        buffer.writeln('距上次经期开始已 $daysSinceLast 天，与预期一致');
      }
    }

    // ═══════════════════════════════════════════════════════════════
    //  二、周期趋势分析
    // ═══════════════════════════════════════════════════════════════
    buffer.writeln('');
    buffer.writeln('【周期趋势分析】');

    if (cycleLengths.length >= 2) {
      final minCycle = cycleLengths.reduce((a, b) => a < b ? a : b);
      final maxCycle = cycleLengths.reduce((a, b) => a > b ? a : b);
      final avgCycle = cycleLengths.reduce((a, b) => a + b) / cycleLengths.length;

      buffer.writeln('- 周期长度范围：最短 $minCycle 天，最长 $maxCycle 天');
      buffer.writeln('- 周期长度波动：${maxCycle - minCycle} 天');

      // 标准差计算（衡量规律性）
      final variance = cycleLengths
              .map((l) => (l - avgCycle) * (l - avgCycle))
              .reduce((a, b) => a + b) /
          cycleLengths.length;
      final stdDev = sqrt(variance);
      buffer.writeln('- 周期标准差：${stdDev.toStringAsFixed(1)} 天');
      if (stdDev < 2) {
        buffer.writeln('- 周期规律性评估：非常规律（标准差 < 2 天）');
      } else if (stdDev < 5) {
        buffer.writeln('- 周期规律性评估：基本规律（标准差 2-5 天）');
      } else {
        buffer.writeln('- 周期规律性评估：波动较大（标准差 > 5 天），建议关注');
      }

      buffer.writeln('- 历史周期长度序列：${cycleLengths.join('、')} 天');

      // 近3次 vs 历史
      if (cycleLengths.length >= 4) {
        final recent3 = cycleLengths.sublist(cycleLengths.length - 3);
        final recentAvg =
            recent3.reduce((a, b) => a + b) / recent3.length;
        final earlierAvg = cycleLengths
                .sublist(0, cycleLengths.length - 3)
                .reduce((a, b) => a + b) /
            (cycleLengths.length - 3);
        final trend = recentAvg - earlierAvg;
        if (trend.abs() >= 2) {
          buffer.writeln(
            '- 近3次平均 ${recentAvg.toStringAsFixed(1)} 天 vs 历史 ${earlierAvg.toStringAsFixed(1)} 天，${trend > 0 ? "有延长趋势" : "有缩短趋势"}',
          );
        } else {
          buffer.writeln(
            '- 近3次平均 ${recentAvg.toStringAsFixed(1)} 天 vs 历史 ${earlierAvg.toStringAsFixed(1)} 天，趋势稳定',
          );
        }
      }
    } else {
      buffer.writeln('- 周期趋势数据不足（需至少2个完整周期）');
    }

    // ═══════════════════════════════════════════════════════════════
    //  三、经期天数趋势分析
    // ═══════════════════════════════════════════════════════════════
    buffer.writeln('');
    buffer.writeln('【经期天数趋势分析】');

    if (periodDays.length >= 2) {
      final minDays = periodDays.reduce((a, b) => a < b ? a : b);
      final maxDays = periodDays.reduce((a, b) => a > b ? a : b);
      final avgDays = periodDays.reduce((a, b) => a + b) / periodDays.length;
      buffer.writeln('- 经期天数范围：最短 $minDays 天，最长 $maxDays 天');
      buffer.writeln('- 平均经期天数：${avgDays.toStringAsFixed(1)} 天');
      buffer.writeln('- 经期天数序列：${periodDays.join('、')} 天');

      // 最近一次 vs 平均
      final lastDays = periodDays.last;
      final diff = lastDays - avgDays;
      if (diff.abs() >= 2) {
        buffer.writeln(
          '- 最近一次经期 $lastDays 天 vs 平均 ${avgDays.toStringAsFixed(1)} 天，${diff > 0 ? "偏长" : "偏短"}',
        );
      }
    }

    // ═══════════════════════════════════════════════════════════════
    //  四、经量分析（含每日明细）
    // ═══════════════════════════════════════════════════════════════
    buffer.writeln('');
    buffer.writeln('【经量分析】');

    if (dailyFlowMap.isNotEmpty) {
      final flowValues = dailyFlowMap.values.where((v) => v > 0).toList();
      if (flowValues.isNotEmpty) {
        final avgFlow =
            flowValues.reduce((a, b) => a + b) / flowValues.length;
        buffer.writeln(
          '- 每日经量记录：共 ${flowValues.length} 天，平均经量等级 ${avgFlow.toStringAsFixed(1)}（0=无,1=少,2=中,3=多）',
        );

        // 经量分布
        final flow1 = flowValues.where((v) => v == 1).length;
        final flow2 = flowValues.where((v) => v == 2).length;
        final flow3 = flowValues.where((v) => v == 3).length;
        buffer.writeln('- 经量分布：偏少 $flow1 天，正常 $flow2 天，偏多 $flow3 天');

        // 最近一次经量
        final lastFlowLevel = lastRecord.flowLevel;
        if (lastFlowLevel != null) {
          buffer.writeln('- 最近一次经量：${_flowLevelText(lastFlowLevel)}');
        }

        // 每日经量明细（日期 -> 经量等级）
        buffer.writeln('- 每日经量明细（日期：经量等级）：');
        final sortedFlows = dailyFlowMap.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        for (final entry in sortedFlows) {
          final dateInt = entry.key;
          final year = dateInt ~/ 10000;
          final month = (dateInt % 10000) ~/ 100;
          final day = dateInt % 100;
          final dateStr = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
          final level = entry.value;
          if (level > 0) {
            buffer.writeln('    $dateStr：${_flowLevelText(level)}（等级$level）');
          }
        }
      }
    } else {
      buffer.writeln('- 暂无每日经量记录');
    }

    // ═══════════════════════════════════════════════════════════════
    //  五、情绪与症状模式
    // ═══════════════════════════════════════════════════════════════
    buffer.writeln('');
    buffer.writeln('【情绪与症状模式】');

    final moodCount = <String, int>{};
    final symptomCount = <String, int>{};
    for (final r in records) {
      if (r.mood != null && r.mood!.isNotEmpty) {
        moodCount[r.mood!] = (moodCount[r.mood!] ?? 0) + 1;
      }
      if (r.symptoms != null && r.symptoms!.isNotEmpty) {
        symptomCount[r.symptoms!] = (symptomCount[r.symptoms!] ?? 0) + 1;
      }
    }

    if (moodCount.isNotEmpty) {
      final sortedMoods = moodCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      buffer.writeln(
        '- 情绪记录：${sortedMoods.map((e) => "${e.key}(${e.value}次)").join("、")}',
      );
    }

    if (symptomCount.isNotEmpty) {
      final sortedSymptoms = symptomCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      buffer.writeln(
        '- 症状记录：${sortedSymptoms.map((e) => "${e.key}(${e.value}次)").join("、")}',
      );
    }

    // ═══════════════════════════════════════════════════════════════
    //  六、预测信息
    // ═══════════════════════════════════════════════════════════════
    buffer.writeln('');
    buffer.writeln('【预测信息】');

    if (cycleData.predictedNextPeriod != null) {
      final predicted = cycleData.predictedNextPeriod!;
      final daysUntil = cycleData.daysUntilPredicted;
      buffer.writeln('- 预测下次经期开始日期：${predicted.toIso8601String().split('T')[0]}');
      if (daysUntil != null) {
        if (daysUntil > 0) {
          buffer.writeln('- 距下次经期还有 $daysUntil 天');
        } else if (daysUntil == 0) {
          buffer.writeln('- 今天是预测经期开始日');
        } else {
          buffer.writeln('- 预测经期已逾期 ${-daysUntil} 天');
        }
      }

      // 排卵期与易孕期
      final ovulation = cycleData.ovulationDay;
      final fertileStart = cycleData.fertileWindowStart;
      final fertileEnd = cycleData.fertileWindowEnd;
      if (ovulation != null) {
        buffer.writeln('- 预测排卵日：${ovulation.toIso8601String().split('T')[0]}');
      }
      if (fertileStart != null && fertileEnd != null) {
        buffer.writeln(
          '- 易孕窗口：${fertileStart.toIso8601String().split('T')[0]} ~ ${fertileEnd.toIso8601String().split('T')[0]}',
        );
      }

      // 当前周期日
      final cycleDay = cycleData.currentCycleDay;
      if (cycleDay > 0) {
        buffer.writeln('- 当前周期第 $cycleDay 天');
      }

      // 预测窗口
      final windowStart = cycleData.predictionWindowStart;
      final windowEnd = cycleData.predictionWindowEnd;
      if (windowStart != null && windowEnd != null && cycleData.predictionWindowDays != null) {
        buffer.writeln(
          '- 预测窗口：±${cycleData.predictionWindowDays! ~/ 2} 天（${windowStart.toIso8601String().split('T')[0]} ~ ${windowEnd.toIso8601String().split('T')[0]}）',
        );
      }
    } else {
      buffer.writeln('- 暂无足够数据进行预测');
    }

    // ═══════════════════════════════════════════════════════════════
    //  七、全部经期记录明细（含所有字段）
    // ═══════════════════════════════════════════════════════════════
    buffer.writeln('');
    buffer.writeln('【全部经期记录明细（共${records.length}次）】');
    for (final record in sorted) {
      final start = record.startDate;
      final end = record.endDate ?? '进行中';
      final days = record.periodDays;
      buffer.writeln('  · 第${sorted.indexOf(record) + 1}次：$start ~ $end（$days 天）');
      buffer.writeln('    - 经期天数：$days 天');
      buffer.writeln('    - 周期长度：${record.cycleLength?.toString() ?? '未知'} 天');
      buffer.writeln('    - 整体经量等级：${record.flowLevel != null ? '${_flowLevelText(record.flowLevel!)}（等级${record.flowLevel}）' : '未设置'}');
      buffer.writeln('    - 情绪状态：${record.mood ?? '未记录'}');
      buffer.writeln('    - 症状记录：${record.symptoms ?? '无'}');
      final notes = record.notes != null && record.notes!.isNotEmpty ? record.notes : '无';
      buffer.writeln('    - 备注：$notes');
      // 附带该次经期内的每日经量明细
      final recordStart = record.startDateTime;
      final recordEnd = record.endDateTime ?? DateTime.now();
      final dailyFlowsForRecord = <String, String>{};
      for (final entry in dailyFlowMap.entries) {
        final dateInt = entry.key;
        final year = dateInt ~/ 10000;
        final month = (dateInt % 10000) ~/ 100;
        final day = dateInt % 100;
        final date = DateTime(year, month, day);
        if ((date.isAfter(recordStart) || date.isAtSameMomentAs(recordStart)) &&
            (date.isBefore(recordEnd) || date.isAtSameMomentAs(recordEnd)) &&
            entry.value > 0) {
          final dateStr = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
          dailyFlowsForRecord[dateStr] = '${_flowLevelText(entry.value)}（等级${entry.value}）';
        }
      }
      if (dailyFlowsForRecord.isNotEmpty) {
        buffer.writeln('    - 本次每日经量：');
        final flowEntries = dailyFlowsForRecord.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        for (final fe in flowEntries) {
          buffer.writeln('      ${fe.key}：${fe.value}');
        }
      }
    }

    return buffer.toString();
  }

  static String _flowLevelText(int level) {
    return switch (level) {
      0 => '无',
      1 => '偏少',
      2 => '正常',
      3 => '偏多',
      _ => '未知',
    };
  }

  // ═══════════════════════════════════════════════════════════════
  //  提示词构建
  // ═══════════════════════════════════════════════════════════════

  /// 构建健康报告的系统提示词。
  static String _buildSystemPrompt() {
    return '''你是一名专业、谨慎、友好的经期健康数据分析助手。

你的任务是：根据用户提供的全部经期相关历史数据，生成一份清晰、个性化、易理解的经期记录分析报告。

你只能根据用户实际提供的数据进行分析，不得虚构、补充或猜测用户没有记录的信息。

一、你的分析目标

请综合分析用户的历史经期数据，包括但不限于：

月经开始日期、结束日期
经期持续天数
月经周期长度
每个周期之间的变化
周期规律性
经量记录
痛经、腹痛、腰酸、头痛、疲劳等经期相关症状
PMS/经前症状
情绪变化
睡眠情况
排卵相关记录（如有）
体重、基础体温、运动、饮食等关联数据（如有）
用户备注
用户曾经记录的异常情况

分析时优先使用长期趋势，同时关注近期变化。

二、分析原则

1. 先描述数据，再进行解释
先客观总结用户的数据特点，例如：
- 最近几个月平均周期是多少天
- 周期是否稳定
- 经期平均持续多少天
- 与历史平均值相比，近期是否发生明显变化
- 哪些症状最常出现
- 哪些指标变化最明显
不要一上来直接下结论。

2. 重视趋势，而不是单次异常
一次与平时不同的记录，不应直接判断为异常。
如果存在变化，应尽量结合多个周期进行分析，并说明：
- 这是短期波动还是持续变化
- 变化幅度有多大
- 数据是否足够支持这一判断
当数据量不足时，应明确说明"目前记录较少，暂时难以判断长期规律"。

3. 不进行疾病诊断
你不是医生，不得根据经期数据直接诊断疾病。
不得使用类似：
- "你患有……"
- "这说明你得了……"
- "你一定是……"
- "你的激素水平异常"
- "你存在某种疾病"
等确定性医疗结论。
可以使用：
- "从记录来看……"
- "可能与……有关"
- "这一变化值得继续观察"
- "如果这种情况持续出现，可以考虑咨询医生"
- "仅凭经期记录无法判断具体原因"

4. 不要过度解读
只有在数据能够支持的情况下才进行推断。
例如：
如果周期波动明显，可以描述为："过去几次周期长度存在一定波动。"
而不是直接解释为："你的激素水平不稳定。"
如果用户记录了疼痛，可以描述："痛经在多个周期中都有记录。"
而不是直接判断："你的疼痛属于某种疾病。"

三、报告结构

请按照以下结构生成报告，每一部分都严格对应JSON中的字段：

1. 本周期概览（currentOverview字段）
简要总结最近一次经期：
- 周期长度
- 经期持续时间
- 经量（如果有）
- 主要症状
- 与用户历史平均水平相比是否有明显变化
使用简洁、自然的语言。

2. 周期趋势（cycleStats数组 + cycleTrendSummary字段）
分析过去若干周期，cycleStats为数组，每项包含label和value：
- 平均周期长度（label:"平均周期", value:"XX天"）
- 最短周期（label:"最短周期", value:"XX天"）
- 最长周期（label:"最长周期", value:"XX天"）
- 周期波动范围（label:"波动范围", value:"XX天"）
- 平均经期天数（label:"平均经期", value:"XX天"）
- 周期规律性（label:"规律性", value:"非常规律/基本规律/波动较大"）
cycleTrendSummary为文字描述，帮助用户理解这些数字意味着什么，以及最近是否出现变化趋势。
如果数据不足，cycleStats可以只有少量项或为空，cycleTrendSummary应说明数据不足。

3. 症状趋势（symptomTrends数组）
总结用户最常出现的症状，每项包含name、status、detail：
- name: 症状名称（如"痛经""腹胀""腰酸""乳房胀痛""头痛""疲劳""情绪波动""睡眠变化"等）
- status: 出现频率或趋势（如"经常出现""偶尔出现""近期增加""近期减少""稳定"）
- detail: 具体描述
指出哪些症状较稳定，哪些症状近期有所增加或减少。
如果用户没有症状记录，symptomTrends为空数组。

4. 与过去相比（comparisonTrends数组）
重点回答"最近和以前相比，有什么变化？"，每项包含name、status、detail：
- name: 对比维度（如"周期长度""经期天数""症状""经量""周期稳定性"）
- status: 变化状态（如"变长""变短""稳定""增加""减少""无明显变化"）
- detail: 具体描述
如果没有明显变化，也应该明确告诉用户"目前没有发现明显变化，整体与过去记录较为接近。"

5. 值得关注的地方（attentions数组）
列出用户可能值得继续观察的变化，每项包含title、detail、evidence：
- title: 关注点名称
- detail: 具体描述
- evidence: 依据说明
注意：
- 不要把正常波动直接称为异常
- 不要制造焦虑
- 每一个提醒都要尽量说明依据
- 当数据不足时，要明确说明数据不足

6. 下一周期建议（nextCycleSuggestions数组）
根据用户实际数据给出个性化记录建议，每项包含title、detail：
- title: 建议标题
- detail: 具体建议内容
建议必须与用户数据相关，不要输出千篇一律的健康建议。

7. 就医提醒（medicalReminders数组）
只有当用户记录中出现值得进一步关注的情况时才给出就医建议，每项包含condition、detail、userMatched：
- condition: 需关注的情况
- detail: 温和的就医建议
- userMatched: 布尔值，用户当前数据是否已符合该情况
不要仅凭一次轻微变化就建议就医。

四、语言风格

整体风格：温和、专业、清晰、有关怀感、不制造焦虑、不使用过度医学化的语言、不说教、不夸大风险。
报告应该像一个"懂数据、懂经期、但不会替医生下诊断"的健康助手。
优先使用用户容易理解的自然语言。

五、数据不足时的处理

如果用户数据不足：
- 不要强行分析
- 明确告诉用户目前可以分析什么
- 明确哪些结论暂时无法得出
- 不得虚构统计数据

六、统计要求

在有足够数据时，尽可能计算并使用：
- 平均值
- 中位数（必要时）
- 最小值
- 最大值
- 波动范围
- 与历史平均值的差异
- 最近3个周期与更长期平均值的差异
涉及百分比或变化幅度时，必须基于实际数据计算，不得估算。
如果数据量太少，不要输出没有意义的统计结果。

七、时间范围

分析时同时关注：
- 最近一个周期：用于解释当前情况
- 最近3个周期：用于观察近期趋势
- 更长历史数据：用于判断个人基线和长期变化
如果不同时间范围得到的结论不同，应优先说明这种差异。

八、结论要求

报告最后给出一个简短的总结（conclusion字段），用2～4句话回答：
- 目前整体情况怎么样
- 最近最明显的变化是什么
- 用户接下来最值得关注什么
总结必须基于已有数据，不要重复整篇报告。

九、安全边界

严格遵守以下要求：
- 不诊断疾病。
- 不推测用户的激素水平、卵巢功能、子宫状况等无法从记录直接得出的医学结论。
- 不把排卵日期、受孕概率等信息描述成确定事实，除非数据本身足以支持。
- 不向用户保证"正常""没问题"之类绝对医疗结论。
- 不因为数据异常就制造恐慌。
- 当存在明显异常且持续发生时，应建议用户考虑咨询专业医生。
- 如果用户数据与结论冲突，以数据为准。
- 如果无法确定原因，要明确说明"不确定原因"，不要编造解释。

十、最终输出要求

最终报告要做到："数据准确 + 趋势清晰 + 个性化 + 易懂 + 有行动建议 + 医疗表达谨慎"。
不要单纯把数据重新排列，而是要帮助用户理解："我的经期过去怎么样 → 最近发生了什么变化 → 这意味着什么 → 我接下来可以关注什么。"

请以JSON格式输出分析报告，严格遵循以下结构（不要输出JSON以外的任何文本）：

```json
{
  "healthScore": 75,
  "currentOverview": "本周期概览文本",
  "cycleStats": [
    {"label": "平均周期", "value": "28天"},
    {"label": "最短周期", "value": "26天"},
    {"label": "最长周期", "value": "30天"},
    {"label": "波动范围", "value": "4天"},
    {"label": "平均经期", "value": "5天"},
    {"label": "规律性", "value": "非常规律"}
  ],
  "cycleTrendSummary": "周期趋势文字描述",
  "symptomTrends": [
    {"name": "痛经", "status": "经常出现", "detail": "在多个周期中都有记录"}
  ],
  "comparisonTrends": [
    {"name": "周期长度", "status": "稳定", "detail": "与过去相比无明显变化"}
  ],
  "attentions": [
    {"title": "关注点", "detail": "描述", "evidence": "依据"}
  ],
  "nextCycleSuggestions": [
    {"title": "建议标题", "detail": "具体建议"}
  ],
  "medicalReminders": [
    {"condition": "需关注的情况", "detail": "就医建议", "userMatched": false}
  ],
  "conclusion": "总结文本，2-4句话"
}
```

字段说明：
- healthScore: 0-100的整数，基于周期规律性、经量、经期天数综合评分
- currentOverview: 文本，本周期概览
- cycleStats: 数组，每项含label和value
- cycleTrendSummary: 文本，周期趋势解读
- symptomTrends: 数组，每项含name、status、detail
- comparisonTrends: 数组，每项含name、status、detail
- attentions: 数组，每项含title、detail、evidence
- nextCycleSuggestions: 数组，每项含title、detail
- medicalReminders: 数组，每项含condition、detail、userMatched
- conclusion: 文本，2-4句话总结

当数据不足时，对应数组可以为空，文本字段应说明数据不足。''';
  }

  /// 构建用户消息。
  static String _buildUserMessage(String dataText) {
    return '''请根据以下个人生理周期数据进行分析：

$dataText

请按照系统提示中的JSON格式输出完整的健康分析报告。''';
  }

  /// 构建问答模式的系统提示词。
  static String _buildQASystemPrompt(String dataText) {
    return '''你是一名专业、谨慎、友好的经期健康数据分析助手，正在与用户进行一对一的问答对话。

以下是用户的完整个人生理周期数据（包含全部经期记录、每日经量明细、情绪、症状、备注等所有字段）：

$dataText

【重要提示】
- 你可以访问上述数据中的所有字段，包括每次经期的开始/结束日期、天数、周期长度、整体经量等级、每日经量明细（日期对应的具体经量等级：0=无,1=少,2=中,3=多）、情绪状态、症状记录、备注等。
- 当用户询问经量相关问题时，请直接引用具体的每日经量数据来回答，例如"2024-01-15：偏少（等级1）"。
- 当用户询问症状、情绪等问题时，同样引用具体记录中的数据。

【回答规则】
1. 仅回答与经期、月经周期、女性生殖健康相关的问题。
2. 如果用户的问题与经期健康完全无关（如天气、美食、科技等），请礼貌地说明你只能回答经期健康相关问题，并引导用户提问。
3. 回答要结合用户的实际数据进行分析，给出个性化建议。引用具体数据时请标明日期和数值。
4. 你不是医生，不得根据经期数据直接诊断疾病。不得使用"你患有""你得了"等确定性医疗结论。
5. 语言保持温和、专业、清晰、有关怀感，不要夸大风险，不要给出绝对化的医疗诊断结论。
6. 回答控制在200-400字以内，条理清晰。
7. 如涉及红旗症状（剧烈腹痛、异常出血等），提醒用户及时就医。''';
  }

  // ═══════════════════════════════════════════════════════════════
  //  流式问答
  // ═══════════════════════════════════════════════════════════════

  /// 基于用户经期数据进行流式问答。
  ///
  /// 返回一个 [Stream<String>]，逐块产出AI回答的文本片段。
  /// 当流结束时，Stream 自动关闭。
  static Stream<String> askQuestionStream({
    required String question,
    required List<PeriodRecord> records,
    required CycleData cycleData,
    required Map<int, int> dailyFlowMap,
    required int userCycleLength,
    required int userPeriodLength,
    List<ChatMessage> chatHistory = const [],
  }) async* {
    final dataText = _buildUserDataText(
      records, cycleData, dailyFlowMap, userCycleLength, userPeriodLength,
    );

    final systemPrompt = _buildQASystemPrompt(dataText);

    // 构建消息列表（历史 + 当前问题）
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    // 加入历史对话（最多最近12条）
    final recentHistory = chatHistory.length > 12
        ? chatHistory.sublist(chatHistory.length - 12)
        : chatHistory;
    for (final msg in recentHistory) {
      messages.add({'role': msg.role, 'content': msg.content});
    }

    // 当前问题
    messages.add({'role': 'user', 'content': question});

    yield* _callApiStream(messages);
  }

  // ═══════════════════════════════════════════════════════════════
  //  API调用
  // ═══════════════════════════════════════════════════════════════

  /// 调用智谱GLM API（单轮：system + user），返回模型生成的文本内容。
  static Future<String> _callApi(String systemPrompt, String userMessage) async {
    return _callApiWithMessages([
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userMessage},
    ]);
  }

  /// 调用智谱GLM API（多轮消息），返回模型生成的文本内容。
  static Future<String> _callApiWithMessages(
    List<Map<String, String>> messages,
  ) async {
    if (_apiKey.isEmpty) {
      throw Exception('API Key 未配置，请使用 --dart-define=GLM_API_KEY=xxx 编译');
    }

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': messages,
        'temperature': 0.3,
        'max_tokens': 4096,
      }),
    ).timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      final errorBody = response.body;
      throw Exception(
        'AI请求失败（HTTP ${response.statusCode}）${errorBody.isNotEmpty ? ': $errorBody' : ''}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = body['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('AI返回数据格式异常');
    }

    final content = choices[0]['message']['content'] as String?;
    if (content == null || content.isEmpty) {
      throw Exception('AI返回数据为空');
    }

    return content;
  }

  /// 调用智谱GLM API（流式SSE），逐块 yield 回答文本。
  static Stream<String> _callApiStream(
    List<Map<String, String>> messages,
  ) async* {
    if (_apiKey.isEmpty) {
      throw Exception('API Key 未配置，请使用 --dart-define=GLM_API_KEY=xxx 编译');
    }

    final request = http.Request('POST', Uri.parse(_apiUrl));
    request.headers['Content-Type'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $_apiKey';
    request.headers['Accept'] = 'text/event-stream';
    request.body = jsonEncode({
      'model': _model,
      'messages': messages,
      'temperature': 0.3,
      'max_tokens': 4096,
      'stream': true,
    });

    final client = http.Client();
    final response = await client.send(request)
        .timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      client.close();
      throw Exception('AI请求失败（HTTP ${response.statusCode}）');
    }

    // SSE 数据格式：以 data: 开头，每行一个 JSON chunk
    // 最后一个 chunk 的 data: [DONE] 表示结束
    var buffer = '';
    await for (final chunk in response.stream.transform(
      utf8.decoder,
    )) {
      buffer += chunk;

      // 按行分割处理
      while (buffer.contains('\n')) {
        final newlineIndex = buffer.indexOf('\n');
        final line = buffer.substring(0, newlineIndex).trim();
        buffer = buffer.substring(newlineIndex + 1);

        if (line.isEmpty) continue;
        if (!line.startsWith('data:')) continue;

        final data = line.substring(5).trim();
        if (data == '[DONE]') {
          client.close();
          return;
        }

        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final choices = json['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final delta = choices[0]['delta'] as Map<String, dynamic>?;
            final content = delta?['content'] as String?;
            if (content != null && content.isNotEmpty) {
              yield content;
            }
          }
        } catch (_) {
          // 忽略无法解析的 chunk
        }
      }
    }

    // 处理 buffer 中可能残留的最后一行
    final lastLine = buffer.trim();
    if (lastLine.startsWith('data:')) {
      final data = lastLine.substring(5).trim();
      if (data.isNotEmpty && data != '[DONE]') {
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final choices = json['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final delta = choices[0]['delta'] as Map<String, dynamic>?;
            final content = delta?['content'] as String?;
            if (content != null && content.isNotEmpty) {
              yield content;
            }
          }
        } catch (_) {
          // 忽略
        }
      }
    }

    client.close();
  }

  // ═══════════════════════════════════════════════════════════════
  //  响应解析
  // ═══════════════════════════════════════════════════════════════

  static HealthReport _parseResponse(String content) {
    String jsonStr = content;

    final jsonBlockMatch = RegExp(
      r'```(?:json)?\s*([\s\S]*?)```',
    ).firstMatch(content);
    if (jsonBlockMatch != null) {
      jsonStr = jsonBlockMatch.group(1)!.trim();
    } else {
      final firstBrace = content.indexOf('{');
      final lastBrace = content.lastIndexOf('}');
      if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
        jsonStr = content.substring(firstBrace, lastBrace + 1);
      }
    }

    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return HealthReport.fromJson(json);
  }
}