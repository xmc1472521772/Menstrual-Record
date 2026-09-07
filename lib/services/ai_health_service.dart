import 'dart:async';
import 'dart:convert';
import 'dart:math' show sqrt;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/period_record.dart';
import '../models/cycle_data.dart';

/// 将字符串映射为IconData。
IconData _iconFromString(String str, AdviceType type) {
  final s = str.toLowerCase();
  if (s.contains('period') || s.contains('cycle')) {
    return Icons.calendar_today_rounded;
  }
  if (s.contains('flow') || s.contains('water')) {
    return Icons.water_drop_rounded;
  }
  if (s.contains('warning') || s.contains('hospital') || s.contains('flag')) {
    return Icons.local_hospital_rounded;
  }
  if (s.contains('caution')) {
    return Icons.warning_amber_rounded;
  }
  if (s.contains('check') || s.contains('success')) {
    return Icons.check_circle_outline_rounded;
  }
  if (s.contains('timer') || s.contains('time')) {
    return Icons.timer_outlined;
  }
  if (s.contains('event')) {
    return Icons.event_available_rounded;
  }
  // 默认图标按type区分
  return switch (type) {
    AdviceType.info => Icons.info_outline_rounded,
    AdviceType.caution => Icons.warning_amber_rounded,
    AdviceType.warning => Icons.error_outline_rounded,
  };
}

// ═══════════════════════════════════════════════════════════════
//  数据模型
// ═══════════════════════════════════════════════════════════════

/// AI健康分析报告中的单条建议项。
class HealthAdvice {
  final IconData icon;
  final String title;
  final String content;
  final AdviceType type;

  const HealthAdvice({
    required this.icon,
    required this.title,
    required this.content,
    required this.type,
  });

  factory HealthAdvice.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'info';
    final type = switch (typeStr) {
      'warning' => AdviceType.warning,
      'caution' => AdviceType.caution,
      _ => AdviceType.info,
    };
    final iconStr = json['icon'] as String? ?? 'info';
    final icon = _iconFromString(iconStr, type);
    return HealthAdvice(
      icon: icon,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      type: type,
    );
  }
}

/// 建议类型，用于卡片配色区分。
enum AdviceType {
  info,
  caution,
  warning,
}

/// 红旗症状（需立即就医）。
class RedFlagSymptom {
  final String symptom;
  final String description;
  final bool userMatched;

  const RedFlagSymptom({
    required this.symptom,
    required this.description,
    this.userMatched = false,
  });

  factory RedFlagSymptom.fromJson(Map<String, dynamic> json) {
    return RedFlagSymptom(
      symptom: json['symptom'] as String? ?? '',
      description: json['description'] as String? ?? '',
      userMatched: json['userMatched'] as bool? ?? false,
    );
  }
}

/// 周期评估结果。
class CycleAssessment {
  final bool isNormal;
  final String explanation;
  final String normalRange;
  final int deviationDays;

  const CycleAssessment({
    required this.isNormal,
    required this.explanation,
    required this.normalRange,
    required this.deviationDays,
  });

  factory CycleAssessment.fromJson(Map<String, dynamic> json) {
    return CycleAssessment(
      isNormal: json['isNormal'] as bool? ?? true,
      explanation: json['explanation'] as String? ?? '',
      normalRange: json['normalRange'] as String? ?? '正常周期范围：21-35天',
      deviationDays: (json['deviationDays'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 因素排查项。
class CauseFactor {
  final String factor;
  final String explanation;

  const CauseFactor({
    required this.factor,
    required this.explanation,
  });

  factory CauseFactor.fromJson(Map<String, dynamic> json) {
    return CauseFactor(
      factor: json['factor'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
    );
  }
}

/// 行动建议项。
class ActionSuggestion {
  final String observation;
  final String suggestion;

  const ActionSuggestion({
    required this.observation,
    required this.suggestion,
  });

  factory ActionSuggestion.fromJson(Map<String, dynamic> json) {
    return ActionSuggestion(
      observation: json['observation'] as String? ?? '',
      suggestion: json['suggestion'] as String? ?? '',
    );
  }
}

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

/// 完整的AI健康报告。
class HealthReport {
  final DateTime generatedAt;
  final Map<String, String> basicInfo;
  final CycleAssessment cycleAssessment;
  final List<CauseFactor> causeFactors;
  final List<ActionSuggestion> actionSuggestions;
  final List<RedFlagSymptom> redFlags;
  final List<HealthAdvice> advices;
  final int healthScore;
  final String summary;

  const HealthReport({
    required this.generatedAt,
    required this.basicInfo,
    required this.cycleAssessment,
    required this.causeFactors,
    required this.actionSuggestions,
    required this.redFlags,
    required this.advices,
    required this.healthScore,
    required this.summary,
  });

  factory HealthReport.fromJson(Map<String, dynamic> json) {
    final basicInfoRaw = json['basicInfo'] as Map<String, dynamic>? ?? {};
    final basicInfo = basicInfoRaw.map(
      (k, v) => MapEntry(k, v?.toString() ?? '-'),
    );

    final causesRaw = json['causeFactors'] as List? ?? [];
    final causes = causesRaw
        .map((e) => CauseFactor.fromJson(e as Map<String, dynamic>))
        .toList();

    final actionsRaw = json['actionSuggestions'] as List? ?? [];
    final actions = actionsRaw
        .map((e) => ActionSuggestion.fromJson(e as Map<String, dynamic>))
        .toList();

    final flagsRaw = json['redFlags'] as List? ?? [];
    final flags = flagsRaw
        .map((e) => RedFlagSymptom.fromJson(e as Map<String, dynamic>))
        .toList();

    final advicesRaw = json['advices'] as List? ?? [];
    final advices = advicesRaw
        .map((e) => HealthAdvice.fromJson(e as Map<String, dynamic>))
        .toList();

    return HealthReport(
      generatedAt: DateTime.now(),
      basicInfo: basicInfo,
      cycleAssessment: CycleAssessment.fromJson(
        json['cycleAssessment'] as Map<String, dynamic>? ?? {},
      ),
      causeFactors: causes,
      actionSuggestions: actions,
      redFlags: flags,
      advices: advices,
      healthScore: (json['healthScore'] as num?)?.toInt() ?? 75,
      summary: json['summary'] as String? ?? '',
    );
  }
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
    //  四、经量分析
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
    //  七、近期记录明细
    // ═══════════════════════════════════════════════════════════════
    buffer.writeln('');
    buffer.writeln('【近期经期记录明细（最近10次）】');
    for (final record in sorted.take(10)) {
      final start = record.startDate;
      final end = record.endDate ?? '进行中';
      final days = record.periodDays;
      final flow = record.flowLevel != null
          ? '，经量${_flowLevelText(record.flowLevel!)}'
          : '';
      final mood = record.mood != null ? '，情绪：${record.mood}' : '';
      final symptoms = record.symptoms != null ? '，症状：${record.symptoms}' : '';
      final notes = record.notes != null && record.notes!.isNotEmpty
          ? '，备注：${record.notes}'
          : '';
      buffer.writeln('  · $start ~ $end（$days 天）$flow$mood$symptoms$notes');
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
    return '''你是一位妇产科与女性健康领域的专业助手。请根据用户提供的个人生理周期数据，进行客观、严谨的数据分析与健康提示。

【分析要求】

1. 周期评估：基于数据分析本次周期是否在正常波动范围内（说明正常范围）。
2. 症因排查：列出导致当前状况（如推迟/疼痛/流量异常）的 3-4 个常见生活或生理因素。
3. 行动建议：提供接下来的观察点（如需记录哪些指标）以及日常调理建议。
4. 就医预警：明确指出出现哪些"红旗症状"（如剧烈腹痛、异常出血等）时必须立即就医。

注意：语言请保持客观、体贴、条理清晰，不要夸大风险，也不要给出绝对化的医疗诊断结论。

【就医预警个性化要求】
在redFlags中，如果用户当前数据已符合某个红旗症状的条件，请将该症状的userMatched字段设为true，并在description中标注"⚠️ 您当前已符合此症状"。例如：
- 如果用户当前经期持续超过10天，"经期超长"的userMatched设为true
- 如果用户经量均值>2.5（偏多），"经量异常增多"的userMatched设为true
- 如果用户周期推迟超过35天，"停经后出血"的userMatched设为true
未匹配的症状userMatched设为false。

请以JSON格式输出分析报告，严格遵循以下结构（不要输出JSON以外的任何文本）：

```json
{
  "summary": "报告摘要文本，2-3句话概括整体健康状况",
  "healthScore": 75,
  "basicInfo": {
    "lastPeriodDate": "上次月经来潮日期",
    "avgCycleLength": "历史平均周期长度描述",
    "avgPeriodLength": "经期持续天数描述",
    "currentStatus": "本次记录/异常情况描述",
    "totalRecords": "历史记录条数"
  },
  "cycleAssessment": {
    "isNormal": true,
    "explanation": "周期评估详细说明",
    "normalRange": "正常周期范围说明",
    "deviationDays": 0
  },
  "causeFactors": [
    {"factor": "因素名称", "explanation": "详细解释"}
  ],
  "actionSuggestions": [
    {"observation": "观察点", "suggestion": "建议内容"}
  ],
  "redFlags": [
    {"symptom": "红旗症状名称", "description": "详细说明何时需立即就医", "userMatched": false}
  ],
  "advices": [
    {"icon": "info", "title": "建议标题", "content": "建议内容", "type": "info"}
  ]
}
```

字段说明：
- healthScore: 0-100的整数，基于周期规律性、经量、经期天数综合评分
- cycleAssessment.isNormal: 布尔值，本次周期是否正常
- cycleAssessment.deviationDays: 整数，正=推迟天数，负=提前天数，0=正常
- redFlags中的userMatched: 布尔值，用户当前数据是否已符合该症状
- advices中的type只能是"info"（正常提示）、"caution"（需关注）、"warning"（预警）三种之一
- advices中的icon可使用"info"、"caution"、"warning"、"period"、"flow"、"cycle"等关键词
- causeFactors列出3-4个因素
- redFlags至少列出4个红旗症状''';
  }

  /// 构建用户消息。
  static String _buildUserMessage(String dataText) {
    return '''请根据以下个人生理周期数据进行分析：

$dataText

请按照系统提示中的JSON格式输出完整的健康分析报告。''';
  }

  /// 构建问答模式的系统提示词。
  static String _buildQASystemPrompt(String dataText) {
    return '''你是一位妇产科与女性健康领域的专业助手，正在与用户进行一对一的问答对话。

以下是用户的个人生理周期数据：

$dataText

【回答规则】
1. 仅回答与经期、月经周期、女性生殖健康相关的问题。
2. 如果用户的问题与经期健康完全无关（如天气、美食、科技等），请礼貌地说明你只能回答经期健康相关问题，并引导用户提问。
3. 回答要结合用户的实际数据进行分析，给出个性化建议。
4. 语言保持客观、体贴、条理清晰，不要夸大风险，不要给出绝对化的医疗诊断结论。
5. 回答控制在200-400字以内，条理清晰。
6. 如涉及红旗症状（剧烈腹痛、异常出血等），提醒用户及时就医。''';
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
