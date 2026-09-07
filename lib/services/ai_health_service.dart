import 'dart:convert';
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
  /// 一般提示（绿色）
  info,
  /// 需关注（黄色）
  caution,
  /// 预警（红色）
  warning,
}

/// 红旗症状（需立即就医）。
class RedFlagSymptom {
  final String symptom;
  final String description;

  const RedFlagSymptom({
    required this.symptom,
    required this.description,
  });

  factory RedFlagSymptom.fromJson(Map<String, dynamic> json) {
    return RedFlagSymptom(
      symptom: json['symptom'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }
}

/// 周期评估结果。
class CycleAssessment {
  /// 本次周期是否在正常波动范围内
  final bool isNormal;

  /// 评估说明文本
  final String explanation;

  /// 正常周期范围描述
  final String normalRange;

  /// 本次偏差天数（正=推迟，负=提前，0=正常）
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

/// 完整的AI健康报告。
class HealthReport {
  /// 报告生成时间
  final DateTime generatedAt;

  /// 个人基本信息摘要
  final Map<String, String> basicInfo;

  /// 周期评估
  final CycleAssessment cycleAssessment;

  /// 症因排查（3-4个常见因素）
  final List<CauseFactor> causeFactors;

  /// 行动建议（观察点 + 调理建议）
  final List<ActionSuggestion> actionSuggestions;

  /// 就医预警（红旗症状列表）
  final List<RedFlagSymptom> redFlags;

  /// 健康建议卡片列表
  final List<HealthAdvice> advices;

  /// 综合健康评分（0-100）
  final int healthScore;

  /// 报告摘要
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

/// AI健康分析服务。
///
/// 通过调用智谱GLM-4-flash大模型，基于用户的经期记录、周期数据和每日经量数据，
/// 进行客观、严谨的数据分析与健康提示。
///
/// 注意：此服务不给出绝对化的医疗诊断结论，
/// 仅供用户参考和日常健康管理使用。
class AIHealthService {
  /// 智谱API端点
  static const String _apiUrl =
      'https://open.bigmodel.cn/api/paas/v4/chat/completions';

  /// API Key
  static const String _apiKey = 'c6ef078858c645fa8c84b37cd48b9894.O9RJw6SrAbGtpCMW';

  /// 模型名称
  static const String _model = 'glm-4-flash';

  /// 生成完整的健康分析报告（异步，调用智谱GLM API）。
  ///
  /// 返回 null 表示数据不足无法生成报告。
  /// 抛出异常表示API调用失败。
  static Future<HealthReport?> generateReport({
    required List<PeriodRecord> records,
    required CycleData cycleData,
    required Map<int, int> dailyFlowMap,
    required int userCycleLength,
    required int userPeriodLength,
  }) async {
    if (records.isEmpty) return null;

    // ─── 1. 收集本地数据并构建用户信息文本 ───
    final dataText = _buildUserDataText(
      records, cycleData, dailyFlowMap, userCycleLength, userPeriodLength,
    );

    // ─── 2. 构建系统提示词 ───
    final systemPrompt = _buildSystemPrompt();

    // ─── 3. 构建用户消息 ───
    final userMessage = _buildUserMessage(dataText);

    // ─── 4. 调用智谱GLM API ───
    final response = await _callApi(systemPrompt, userMessage);

    // ─── 5. 解析JSON响应 ───
    return _parseResponse(response);
  }

  // ═══════════════════════════════════════════════════════════════
  //  本地数据收集
  // ═══════════════════════════════════════════════════════════════

  /// 将用户的经期记录、周期数据等整理为文本，供AI分析使用。
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

    final buffer = StringBuffer();

    // ─── 基本信息 ───
    buffer.writeln('【个人基本信息与历史数据】');
    buffer.writeln('- 上一次月经来潮日期：${lastRecord.startDate}');

    if (cycleData.totalCycles > 0) {
      buffer.writeln(
        '- 历史平均周期长度：${cycleData.averageCycleLength.toStringAsFixed(1)} 天（用户设置值：$userCycleLength 天）',
      );
      buffer.writeln(
        '- 经期持续天数：${cycleData.averagePeriodLength.toStringAsFixed(1)} 天（用户设置值：$userPeriodLength 天）',
      );
    } else {
      buffer.writeln('- 历史平均周期长度：暂无足够数据（用户设置值：$userCycleLength 天）');
      buffer.writeln('- 经期持续天数：暂无足够数据（用户设置值：$userPeriodLength 天）');
    }

    // ─── 本次记录/异常情况 ───
    buffer.write('- 本次记录/异常情况：');
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

    // ─── 历史经期记录列表 ───
    buffer.writeln('- 历史经期记录（共 ${records.length} 条）：');
    for (final record in sorted.take(10)) {
      final start = record.startDate;
      final end = record.endDate ?? '进行中';
      final days = record.periodDays;
      final flow = record.flowLevel != null
          ? '经量${_flowLevelText(record.flowLevel!)}'
          : '';
      final mood = record.mood != null ? '，情绪：${record.mood}' : '';
      final symptoms = record.symptoms != null ? '，症状：${record.symptoms}' : '';
      final notes = record.notes != null && record.notes!.isNotEmpty
          ? '，备注：${record.notes}'
          : '';
      buffer.writeln('  · $start ~ $end（$days 天）$flow$mood$symptoms$notes');
    }

    // ─── 周期长度序列 ───
    final cycleSorted = List<PeriodRecord>.from(records)
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    final cycleLengths = <int>[];
    for (int i = 1; i < cycleSorted.length; i++) {
      final diff = cycleSorted[i].startDateTime
          .difference(cycleSorted[i - 1].startDateTime)
          .inDays;
      cycleLengths.add(diff);
    }
    if (cycleLengths.isNotEmpty) {
      buffer.writeln('- 历史周期长度序列：${cycleLengths.join('、')} 天');
      final avg = cycleLengths.reduce((a, b) => a + b) / cycleLengths.length;
      buffer.writeln('- 平均周期：${avg.toStringAsFixed(1)} 天');
    }

    // ─── 每日经量数据 ───
    if (dailyFlowMap.isNotEmpty) {
      final flowValues = dailyFlowMap.values.where((v) => v > 0).toList();
      if (flowValues.isNotEmpty) {
        final avgFlow =
            flowValues.reduce((a, b) => a + b) / flowValues.length;
        buffer.writeln(
          '- 每日经量记录：共 ${flowValues.length} 天，平均经量等级 ${avgFlow.toStringAsFixed(1)}（0=无,1=少,2=中,3=多）',
        );
      }
    }

    // ─── 预测信息 ───
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

  /// 构建系统提示词——定义AI角色和分析要求。
  static String _buildSystemPrompt() {
    return '''你是一位妇产科与女性健康领域的专业助手。请根据用户提供的个人生理周期数据，进行客观、严谨的数据分析与健康提示。

【分析要求】

1. 周期评估：基于数据分析本次周期是否在正常波动范围内（说明正常范围）。
2. 症因排查：列出导致当前状况（如推迟/疼痛/流量异常）的 3-4 个常见生活或生理因素。
3. 行动建议：提供接下来的观察点（如需记录哪些指标）以及日常调理建议。
4. 就医预警：明确指出出现哪些"红旗症状"（如剧烈腹痛、异常出血等）时必须立即就医。

注意：语言请保持客观、体贴、条理清晰，不要夸大风险，也不要给出绝对化的医疗诊断结论。

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
    {"factor": "因素名称", "explanation": "详细解释"},
    {"factor": "因素名称", "explanation": "详细解释"},
    {"factor": "因素名称", "explanation": "详细解释"}
  ],
  "actionSuggestions": [
    {"observation": "观察点", "suggestion": "建议内容"},
    {"observation": "观察点", "suggestion": "建议内容"}
  ],
  "redFlags": [
    {"symptom": "红旗症状名称", "description": "详细说明何时需立即就医"},
    {"symptom": "红旗症状名称", "description": "详细说明"}
  ],
  "advices": [
    {"icon": "info", "title": "建议标题", "content": "建议内容", "type": "info"},
    {"icon": "caution", "title": "建议标题", "content": "建议内容", "type": "caution"}
  ]
}
```

字段说明：
- healthScore: 0-100的整数，基于周期规律性、经量、经期天数综合评分
- cycleAssessment.isNormal: 布尔值，本次周期是否正常
- cycleAssessment.deviationDays: 整数，正=推迟天数，负=提前天数，0=正常
- advices中的type只能是"info"（正常提示）、"caution"（需关注）、"warning"（预警）三种之一
- advices中的icon可使用"info"、"caution"、"warning"、"period"、"flow"、"cycle"等关键词
- causeFactors列出3-4个因素
- redFlags至少列出4个红旗症状''';
  }

  /// 构建用户消息——将本地数据嵌入提示词模板。
  static String _buildUserMessage(String dataText) {
    return '''请根据以下个人生理周期数据进行分析：

$dataText

请按照系统提示中的JSON格式输出完整的健康分析报告。''';
  }

  // ═══════════════════════════════════════════════════════════════
  //  API调用
  // ═══════════════════════════════════════════════════════════════

  /// 调用智谱GLM API，返回模型生成的文本内容。
  static Future<String> _callApi(String systemPrompt, String userMessage) async {
    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userMessage},
        ],
        'temperature': 0.3,
        'max_tokens': 4096,
      }),
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception(
        'AI分析请求失败（HTTP ${response.statusCode}）：${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = body['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('AI返回数据格式异常：无choices字段');
    }

    final content = choices[0]['message']['content'] as String?;
    if (content == null || content.isEmpty) {
      throw Exception('AI返回数据为空');
    }

    return content;
  }

  // ═══════════════════════════════════════════════════════════════
  //  响应解析
  // ═══════════════════════════════════════════════════════════════

  /// 解析AI返回的文本内容为HealthReport。
  static HealthReport _parseResponse(String content) {
    // 尝试从文本中提取JSON块
    String jsonStr = content;

    // 如果模型输出了markdown代码块，提取其中的JSON
    final jsonBlockMatch = RegExp(
      r'```(?:json)?\s*([\s\S]*?)```',
    ).firstMatch(content);
    if (jsonBlockMatch != null) {
      jsonStr = jsonBlockMatch.group(1)!.trim();
    } else {
      // 尝试找到第一个{和最后一个}之间的内容
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
