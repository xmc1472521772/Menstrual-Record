import 'dart:math';
import 'package:flutter/material.dart';
import '../models/period_record.dart';
import '../models/cycle_data.dart';

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
}

/// 因素排查项。
class CauseFactor {
  final String factor;
  final String explanation;

  const CauseFactor({
    required this.factor,
    required this.explanation,
  });
}

/// 行动建议项。
class ActionSuggestion {
  final String observation;
  final String suggestion;

  const ActionSuggestion({
    required this.observation,
    required this.suggestion,
  });
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
}

/// AI健康分析服务。
///
/// 基于用户的经期记录、周期数据和每日经量数据，
/// 进行客观、严谨的数据分析与健康提示。
///
/// 注意：此服务不给出绝对化的医疗诊断结论，
/// 仅供用户参考和日常健康管理使用。
class AIHealthService {
  /// 医学常量
  static const int _normalCycleMin = 21;
  static const int _normalCycleMax = 35;
  static const int _normalPeriodMin = 2;
  static const int _normalPeriodMax = 8;
  static const int _cycleVariationThreshold = 7; // 周期波动超过此天数视为异常
  static const int _latePeriodThreshold = 7; // 推迟超过此天数需关注

  /// 生成完整的健康分析报告。
  static HealthReport? generateReport({
    required List<PeriodRecord> records,
    required CycleData cycleData,
    required Map<int, int> dailyFlowMap,
    required int userCycleLength,
    required int userPeriodLength,
  }) {
    if (records.isEmpty) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // ─── 1. 个人基本信息 ───
    final basicInfo = _collectBasicInfo(records, cycleData, userCycleLength, userPeriodLength);

    // ─── 2. 周期评估 ───
    final cycleAssessment = _assessCycle(records, cycleData, today);

    // ─── 3. 症因排查 ───
    final causeFactors = _analyzeCauses(records, cycleData, dailyFlowMap, cycleAssessment);

    // ─── 4. 行动建议 ───
    final actionSuggestions = _generateActionSuggestions(records, cycleData, dailyFlowMap, cycleAssessment);

    // ─── 5. 就医预警（红旗症状） ───
    final redFlags = _identifyRedFlags(records, cycleData, dailyFlowMap);

    // ─── 6. 健康建议卡片 ───
    final advices = _buildAdvices(cycleAssessment, causeFactors, actionSuggestions, redFlags, cycleData, dailyFlowMap);

    // ─── 7. 健康评分 ───
    final healthScore = _calculateHealthScore(cycleAssessment, records, cycleData, dailyFlowMap);

    // ─── 8. 摘要 ───
    final summary = _generateSummary(cycleAssessment, healthScore, cycleData);

    return HealthReport(
      generatedAt: now,
      basicInfo: basicInfo,
      cycleAssessment: cycleAssessment,
      causeFactors: causeFactors,
      actionSuggestions: actionSuggestions,
      redFlags: redFlags,
      advices: advices,
      healthScore: healthScore,
      summary: summary,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  1. 个人基本信息
  // ═══════════════════════════════════════════════════════════════

  static Map<String, String> _collectBasicInfo(
    List<PeriodRecord> records,
    CycleData cycleData,
    int userCycleLength,
    int userPeriodLength,
  ) {
    final sorted = List<PeriodRecord>.from(records)
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    final lastRecord = sorted.first;
    final lastStartDate = lastRecord.startDate;

    // 计算历史平均周期
    final avgCycle = cycleData.averageCycleLength.toStringAsFixed(0);
    final avgPeriod = cycleData.averagePeriodLength.toStringAsFixed(0);

    // 本次记录/异常情况
    String currentStatus;
    if (lastRecord.isOngoing) {
      currentStatus = '经期进行中（第${lastRecord.periodDays}天）';
    } else {
      final daysSinceLast = DateTime.now().difference(lastRecord.startDateTime).inDays;
      currentStatus = '上次经期开始于 $lastStartDate，距今 $daysSinceLast 天';
    }

    return {
      'lastPeriodDate': lastStartDate,
      'avgCycleLength': '$avgCycle 天（设置值 $userCycleLength 天）',
      'avgPeriodLength': '$avgPeriod 天（设置值 $userPeriodLength 天）',
      'currentStatus': currentStatus,
      'totalRecords': '${records.length} 次记录',
    };
  }

  // ═══════════════════════════════════════════════════════════════
  //  2. 周期评估
  // ═══════════════════════════════════════════════════════════════

  static CycleAssessment _assessCycle(
    List<PeriodRecord> records,
    CycleData cycleData,
    DateTime today,
  ) {
    final sorted = List<PeriodRecord>.from(records)
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    // 收集所有周期长度
    final cycleLengths = <int>[];
    for (int i = 1; i < sorted.length; i++) {
      final diff = sorted[i].startDateTime.difference(sorted[i - 1].startDateTime).inDays;
      cycleLengths.add(diff);
    }

    if (cycleLengths.isEmpty) {
      // 只有一条记录
      final lastRecord = sorted.last;
      final daysSince = today.difference(lastRecord.startDateTime).inDays;
      final expectedCycle = cycleData.averageCycleLength.round();
      final deviation = daysSince - expectedCycle;

      if (lastRecord.isOngoing) {
        return const CycleAssessment(
          isNormal: true,
          explanation: '当前正在经期中，周期评估将在经期结束后进行。',
          normalRange: '正常周期范围：$_normalCycleMin-$_normalCycleMax 天',
          deviationDays: 0,
        );
      }

      return CycleAssessment(
        isNormal: deviation.abs() <= _cycleVariationThreshold,
        explanation: '仅有一次记录，距上次经期开始已 $daysSince 天。'
            '${deviation > 0 ? "比预期推迟了 $deviation 天" : deviation < 0 ? "比预期提前了 ${-deviation} 天" : "与预期一致"}。',
        normalRange: '正常周期范围：$_normalCycleMin-$_normalCycleMax 天',
        deviationDays: deviation,
      );
    }

    // 计算最新周期与历史平均的偏差
    final latestCycle = cycleLengths.last;
    final avgCycle = cycleLengths.reduce((a, b) => a + b) / cycleLengths.length;
    final deviation = (latestCycle - avgCycle).round();

    // 标准差
    final variance = cycleLengths.map((v) => pow(v - avgCycle, 2)).reduce((a, b) => a + b) / cycleLengths.length;
    final stdDev = sqrt(variance);

    // 周期波动性评估
    final bool isNormalLength = latestCycle >= _normalCycleMin && latestCycle <= _normalCycleMax;
    final bool isNormalVariation = deviation.abs() <= _cycleVariationThreshold;
    final bool isNormal = isNormalLength && isNormalVariation;

    final buffer = StringBuffer();
    if (!isNormalLength) {
      if (latestCycle < _normalCycleMin) {
        buffer.write('本次周期仅 $latestCycle 天，短于正常范围下限（$_normalCycleMin 天），属于周期缩短。');
      } else {
        buffer.write('本次周期达 $latestCycle 天，超过正常范围上限（$_normalCycleMax 天），属于周期延长。');
      }
    } else {
      buffer.write('本次周期 $latestCycle 天，处于正常范围内。');
    }

    if (deviation > 0 && deviation > _cycleVariationThreshold) {
      buffer.write(' 相比历史平均推迟了 $deviation 天。');
    } else if (deviation < 0 && deviation.abs() > _cycleVariationThreshold) {
      buffer.write(' 相比历史平均提前了 ${-deviation} 天。');
    } else if (stdDev > 5) {
      buffer.write(' 历史周期波动较大（标准差 ${stdDev.toStringAsFixed(1)} 天），提示周期不太规律。');
    } else {
      buffer.write(' 周期波动在正常范围内（标准差 ${stdDev.toStringAsFixed(1)} 天）。');
    }

    return CycleAssessment(
      isNormal: isNormal,
      explanation: buffer.toString(),
      normalRange: '正常周期范围：$_normalCycleMin-$_normalCycleMax 天，正常波动范围：±$_cycleVariationThreshold 天',
      deviationDays: deviation,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  3. 症因排查
  // ═══════════════════════════════════════════════════════════════

  static List<CauseFactor> _analyzeCauses(
    List<PeriodRecord> records,
    CycleData cycleData,
    Map<int, int> dailyFlowMap,
    CycleAssessment assessment,
  ) {
    final factors = <CauseFactor>[];

    // 基于偏差方向选择不同因素
    if (assessment.deviationDays > _latePeriodThreshold) {
      // 推迟
      factors.add(const CauseFactor(
        factor: '压力与情绪因素',
        explanation: '长期精神压力、焦虑或情绪波动会影响下丘脑-垂体-卵巢轴（HPO轴）功能，导致促性腺激素释放激素脉冲频率改变，从而引起排卵延迟和月经推迟。',
      ));
      factors.add(const CauseFactor(
        factor: '体重与营养变化',
        explanation: '短期内体重显著下降（>10%）、过度节食或体脂率过低（<18%）会抑制促性腺激素分泌，导致暂时性闭经或周期延长。相反，体重快速增加也可能影响内分泌平衡。',
      ));
      factors.add(const CauseFactor(
        factor: '作息与睡眠',
        explanation: '长期熬夜、睡眠不足或昼夜节律紊乱会干扰褪黑素和皮质醇的分泌节律，间接影响生殖内分泌轴的稳定性，导致月经推迟。',
      ));
      factors.add(const CauseFactor(
        factor: '内分泌因素',
        explanation: '多囊卵巢综合征（PCOS）、甲状腺功能异常、高泌乳素血症等内分泌疾病均可表现为月经稀发或推迟。若连续3个周期以上推迟，建议就医排查。',
      ));
    } else if (assessment.deviationDays < -_cycleVariationThreshold) {
      // 提前
      factors.add(const CauseFactor(
        factor: '黄体功能不足',
        explanation: '黄体期缩短会导致周期变短。正常黄体期约12-14天，若少于10天可能影响受孕和月经规律，常见于压力、年龄增长或内分泌紊乱。',
      ));
      factors.add(const CauseFactor(
        factor: '情绪波动',
        explanation: '短期的情绪剧烈波动可能影响下丘脑功能，导致促性腺激素释放节奏改变，引起排卵提前。',
      ));
      factors.add(const CauseFactor(
        factor: '生活方式变化',
        explanation: '旅行出差（时区变化）、剧烈运动量增加、饮食结构改变等生活因素变化，都可能暂时影响周期节律。',
      ));
      factors.add(const CauseFactor(
        factor: '子宫因素',
        explanation: '子宫肌瘤、子宫内膜息肉、宫颈炎症等器质性问题可能引起非经期出血，被误认为是月经提前。若伴有异常出血模式，需就医鉴别。',
      ));
    } else {
      // 正常波动
      factors.add(const CauseFactor(
        factor: '生理性波动',
        explanation: '月经周期存在自然波动，7天以内的变化属于正常范围。情绪、睡眠、饮食的日常变化都可能轻微影响周期。',
      ));
      factors.add(const CauseFactor(
        factor: '季节与温度',
        explanation: '部分研究表明，季节变化和温度骤变可能对月经周期长度有轻微影响，尤其在春秋交替时节。',
      ));
      factors.add(const CauseFactor(
        factor: '运动强度',
        explanation: '运动强度的突然增加或减少，会通过影响体脂率和内分泌水平，对周期产生轻微影响。',
      ));
      factors.add(const CauseFactor(
        factor: '药物影响',
        explanation: '紧急避孕药、抗生素、精神类药物、中药活血化瘀类等药物可能影响近期周期。若在服用药物期间周期波动，通常为药物引起。',
      ));
    }

    // 经量异常因素
    final avgFlow = _calculateAverageFlow(dailyFlowMap);
    if (avgFlow > 0) {
      if (avgFlow > 2.5) {
        factors.add(const CauseFactor(
          factor: '经量偏多',
          explanation: '经量持续偏多可能与子宫肌瘤、子宫内膜增厚、凝血功能异常有关。建议观察是否伴有血块增多、贫血症状（乏力、头晕）。',
        ));
      } else if (avgFlow < 1.5) {
        factors.add(const CauseFactor(
          factor: '经量偏少',
          explanation: '经量持续偏少可能与子宫内膜薄、内分泌紊乱（如雌激素不足）、过度减肥或近期压力大有关。偶尔一次偏少通常无需担心。',
        ));
      }
    }

    return factors;
  }

  // ═══════════════════════════════════════════════════════════════
  //  4. 行动建议
  // ═══════════════════════════════════════════════════════════════

  static List<ActionSuggestion> _generateActionSuggestions(
    List<PeriodRecord> records,
    CycleData cycleData,
    Map<int, int> dailyFlowMap,
    CycleAssessment assessment,
  ) {
    final suggestions = <ActionSuggestion>[];

    // 观察点
    suggestions.add(const ActionSuggestion(
      observation: '记录未来1-2个周期的开始与结束日期',
      suggestion: '持续记录至少2个完整周期，以判断本次偏差是否为偶发或趋势性变化。',
    ));

    suggestions.add(const ActionSuggestion(
      observation: '关注经量变化模式',
      suggestion: '使用App的经量记录功能逐日记录经量等级，观察经量是否持续偏多或偏少。',
    ));

    if (assessment.deviationDays.abs() > _cycleVariationThreshold) {
      suggestions.add(const ActionSuggestion(
        observation: '关注伴随症状',
        suggestion: '留意是否出现腹痛、异常出血、乳房胀痛、情绪波动等伴随症状，记录在备注中供后续参考。',
      ));
    }

    suggestions.add(const ActionSuggestion(
      observation: '监测基础体温（可选）',
      suggestion: '如有条件，可每日晨起测量基础体温，帮助判断排卵是否正常发生。',
    ));

    // 调理建议
    suggestions.add(const ActionSuggestion(
      observation: '保持规律作息',
      suggestion: '尽量在23:00前入睡，保证7-8小时睡眠，维持稳定的生物钟有助于内分泌节律恢复。',
    ));

    suggestions.add(const ActionSuggestion(
      observation: '适度运动',
      suggestion: '每周进行3-5次中等强度运动（如快走、瑜伽、游泳），经期避免剧烈运动。适度运动有助于改善盆腔血液循环和情绪调节。',
    ));

    suggestions.add(const ActionSuggestion(
      observation: '均衡饮食',
      suggestion: '注意补充富含铁元素的食物（红肉、菠菜、红枣）、优质蛋白质和维生素B族。避免过度节食或暴饮暴食。',
    ));

    suggestions.add(const ActionSuggestion(
      observation: '情绪管理',
      suggestion: '尝试冥想、深呼吸或渐进式肌肉放松等减压方法。长期压力是影响月经规律的重要因素之一。',
    ));

    // 如果周期不规律
    if (!assessment.isNormal) {
      suggestions.add(const ActionSuggestion(
        observation: '就医咨询',
        suggestion: '若连续3个周期以上不规律，或本次推迟/提前超过7天且排除怀孕可能，建议就诊妇科进行内分泌检查（性激素六项、甲状腺功能等）。',
      ));
    }

    return suggestions;
  }

  // ═══════════════════════════════════════════════════════════════
  //  5. 就医预警（红旗症状）
  // ═══════════════════════════════════════════════════════════════

  static List<RedFlagSymptom> _identifyRedFlags(
    List<PeriodRecord> records,
    CycleData cycleData,
    Map<int, int> dailyFlowMap,
  ) {
    final flags = <RedFlagSymptom>[];

    flags.add(const RedFlagSymptom(
      symptom: '剧烈腹痛',
      description: '经期出现难以忍受的下腹绞痛，影响日常活动，止痛药无法缓解时需立即就医。可能是子宫内膜异位症、子宫腺肌症或卵巢囊肿扭转的信号。',
    ));

    flags.add(const RedFlagSymptom(
      symptom: '经量异常增多',
      description: '1-2小时内需更换卫生巾/卫生棉条，或排出大量血块（直径>2.5cm），可能导致贫血，需急诊处理。',
    ));

    flags.add(const RedFlagSymptom(
      symptom: '经期超长',
      description: '经期持续超过10天仍未结束，或经间期反复出血，需就医排查子宫内膜病变、息肉或激素紊乱。',
    ));

    flags.add(const RedFlagSymptom(
      symptom: '停经后出血',
      description: '已停经3个月以上再次出现阴道出血，必须就医排除子宫内膜病变。',
    ));

    flags.add(const RedFlagSymptom(
      symptom: '妊娠期出血',
      description: '确认怀孕后出现任何阴道出血，需立即就医排除先兆流产、宫外孕等。',
    ));

    flags.add(const RedFlagSymptom(
      symptom: '异常分泌物',
      description: '经期外出现大量水样、脓性或带异味分泌物，伴有发热、下腹痛时，可能是盆腔感染的表现。',
    ));

    return flags;
  }

  // ═══════════════════════════════════════════════════════════════
  //  6. 健康建议卡片
  // ═══════════════════════════════════════════════════════════════

  static List<HealthAdvice> _buildAdvices(
    CycleAssessment assessment,
    List<CauseFactor> causes,
    List<ActionSuggestion> actions,
    List<RedFlagSymptom> redFlags,
    CycleData cycleData,
    Map<int, int> dailyFlowMap,
  ) {
    final advices = <HealthAdvice>[];

    // 周期规律性建议
    if (assessment.isNormal) {
      advices.add(const HealthAdvice(
        icon: Icons.check_circle_outline_rounded,
        title: '周期正常',
        content: '您的周期在正常范围内，继续保持良好的生活习惯即可。规律作息、均衡饮食和适度运动是维持周期规律的基础。',
        type: AdviceType.info,
      ));
    } else {
      advices.add(HealthAdvice(
        icon: Icons.warning_amber_rounded,
        title: '周期波动',
        content: assessment.explanation,
        type: AdviceType.caution,
      ));
    }

    // 经量建议
    final avgFlow = _calculateAverageFlow(dailyFlowMap);
    if (avgFlow > 0) {
      if (avgFlow > 2.5) {
        advices.add(const HealthAdvice(
          icon: Icons.water_drop_rounded,
          title: '经量偏多',
          content: '近期记录的经量偏多，建议补充含铁食物（如红肉、动物肝脏、红枣），预防缺铁性贫血。若连续3个月经量偏多，建议就医检查。',
          type: AdviceType.caution,
        ));
      } else if (avgFlow < 1.5 && avgFlow > 0) {
        advices.add(const HealthAdvice(
          icon: Icons.water_drop_outlined,
          title: '经量偏少',
          content: '近期记录的经量偏少，偶尔一次偏少通常无需担心。若持续偏少并伴有其他不适，可咨询医生了解子宫内膜情况。',
          type: AdviceType.info,
        ));
      } else {
        advices.add(const HealthAdvice(
          icon: Icons.water_drop_rounded,
          title: '经量正常',
          content: '近期经量记录在正常范围内，经量适中对身体是有利的。',
          type: AdviceType.info,
        ));
      }
    }

    // 经期长度建议
    final avgPeriodLength = cycleData.averagePeriodLength;
    if (avgPeriodLength < _normalPeriodMin) {
      advices.add(const HealthAdvice(
        icon: Icons.timer_outlined,
        title: '经期偏短',
        content: '平均经期天数偏短（少于$_normalPeriodMin天），可能与子宫内膜薄、雌激素水平偏低有关。若伴有经量明显减少，建议就医咨询。',
        type: AdviceType.info,
      ));
    } else if (avgPeriodLength > _normalPeriodMax) {
      advices.add(const HealthAdvice(
        icon: Icons.timer_off_outlined,
        title: '经期偏长',
        content: '平均经期天数偏长（超过$_normalPeriodMax天），长期可能导致贫血。建议就医排查子宫内膜息肉、子宫肌瘤等问题。',
        type: AdviceType.caution,
      ));
    }

    // 预测提醒
    final daysUntil = cycleData.daysUntilPredicted;
    if (daysUntil != null) {
      if (daysUntil > 0 && daysUntil <= 3) {
        advices.add(HealthAdvice(
          icon: Icons.event_available_rounded,
          title: '经期临近',
          content: '预计 $daysUntil 天后下次经期开始，建议提前准备卫生用品，注意保暖，避免过度劳累和寒凉饮食。',
          type: AdviceType.info,
        ));
      } else if (daysUntil < 0) {
        advices.add(HealthAdvice(
          icon: Icons.error_outline_rounded,
          title: '经期已逾期',
          content: '预计经期已逾期 ${-daysUntil} 天。如有性生活，建议先排除怀孕可能。若推迟超过$_latePeriodThreshold天且排除怀孕，建议就医咨询。',
          type: AdviceType.warning,
        ));
      }
    }

    // 红旗症状提醒
    if (redFlags.isNotEmpty) {
      advices.add(HealthAdvice(
        icon: Icons.local_hospital_rounded,
        title: '就医预警',
        content: '若出现以下红旗症状，请立即就医：${redFlags.take(3).map((r) => r.symptom).join('、')}',
        type: AdviceType.warning,
      ));
    }

    return advices;
  }

  // ═══════════════════════════════════════════════════════════════
  //  7. 健康评分
  // ═══════════════════════════════════════════════════════════════

  static int _calculateHealthScore(
    CycleAssessment assessment,
    List<PeriodRecord> records,
    CycleData cycleData,
    Map<int, int> dailyFlowMap,
  ) {
    int score = 100;

    // 周期规律扣分
    if (!assessment.isNormal) {
      final deviation = assessment.deviationDays.abs();
      if (deviation > 14) {
        score -= 25;
      } else if (deviation > 7) {
        score -= 15;
      } else {
        score -= 8;
      }
    }

    // 经量异常扣分
    final avgFlow = _calculateAverageFlow(dailyFlowMap);
    if (avgFlow > 2.5) {
      score -= 10;
    } else if (avgFlow > 0 && avgFlow < 1.5) {
      score -= 5;
    }

    // 经期天数异常扣分
    final avgPeriod = cycleData.averagePeriodLength;
    if (avgPeriod < _normalPeriodMin || avgPeriod > _normalPeriodMax) {
      score -= 10;
    }

    // 记录数据量扣分（数据太少评估可信度降低）
    if (records.length < 3) {
      score -= 5;
    }

    // 周期波动扣分
    final cycleLengths = <int>[];
    final sorted = List<PeriodRecord>.from(records)
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    for (int i = 1; i < sorted.length; i++) {
      final diff = sorted[i].startDateTime.difference(sorted[i - 1].startDateTime).inDays;
      cycleLengths.add(diff);
    }
    if (cycleLengths.length >= 2) {
      final avg = cycleLengths.reduce((a, b) => a + b) / cycleLengths.length;
      final variance = cycleLengths.map((v) => pow(v - avg, 2)).reduce((a, b) => a + b) / cycleLengths.length;
      final stdDev = sqrt(variance);
      if (stdDev > 7) {
        score -= 15;
      } else if (stdDev > 5) {
        score -= 8;
      }
    }

    return score.clamp(0, 100).round();
  }

  // ═══════════════════════════════════════════════════════════════
  //  8. 摘要
  // ═══════════════════════════════════════════════════════════════

  static String _generateSummary(
    CycleAssessment assessment,
    int healthScore,
    CycleData cycleData,
  ) {
    final buffer = StringBuffer();

    // 健康评分描述
    if (healthScore >= 85) {
      buffer.write('整体周期健康状况良好。');
    } else if (healthScore >= 70) {
      buffer.write('周期健康有轻微波动，建议关注。');
    } else if (healthScore >= 50) {
      buffer.write('周期存在一定异常，建议调整生活方式并持续观察。');
    } else {
      buffer.write('周期异常较为明显，建议尽快就医咨询。');
    }

    // 周期状态
    if (assessment.deviationDays.abs() > 7) {
      buffer.write(assessment.deviationDays > 0
          ? '本次周期推迟${assessment.deviationDays}天，'
          : '本次周期提前${-assessment.deviationDays}天，');
      buffer.write('建议观察后续1-2个周期的变化趋势。');
    } else if (assessment.isNormal) {
      buffer.write('本次周期在正常范围内。');
    }

    // 预测信息
    final daysUntil = cycleData.daysUntilPredicted;
    if (daysUntil != null && daysUntil > 0) {
      buffer.write('预计下次经期还有 $daysUntil 天。');
    }

    return buffer.toString();
  }

  // ═══════════════════════════════════════════════════════════════
  //  辅助方法
  // ═══════════════════════════════════════════════════════════════

  /// 计算平均经量等级
  static double _calculateAverageFlow(Map<int, int> dailyFlowMap) {
    if (dailyFlowMap.isEmpty) return 0;
    final values = dailyFlowMap.values.where((v) => v > 0).toList();
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }
}

