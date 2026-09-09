import 'package:flutter/material.dart';
import '../../services/ai_health_service.dart';
import '../../constants/app_colors.dart';
import '../report_cards.dart';

/// 完整报告视图（D2 自 ai_assistant_screen 拆出）——7 部分结构 + 评分头部。
///
/// 纯展示组件：数据过期/模型切换两个提示条是否显示由调用方计算后传入
/// （判断依赖 PeriodProvider.dataVersion 等外部状态，保持本组件无 Provider 耦合）。
class AiReportView extends StatelessWidget {
  final HealthReport report;
  final AppThemeColors themeColors;

  /// 报告生成后经期数据是否已更新（显示"数据已更新"提示条）。
  final bool showDataUpdatedHint;

  /// 报告生成后模型是否已切换（显示"模型已切换"提示条）。
  final bool showModelChangedHint;

  /// 报告生成时使用的模型 ID（免责声明展示用）。
  final String modelId;

  const AiReportView({
    super.key,
    required this.report,
    required this.themeColors,
    required this.showDataUpdatedHint,
    required this.showModelChangedHint,
    required this.modelId,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spacingLg,
        AppDimens.spacingSm,
        AppDimens.spacingLg,
        100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── 健康评分头部 ───
          ReportCards.buildScoreHeader(report),
          const SizedBox(height: AppDimens.spacingSm),

          // ─── 数据更新提示 ───
          if (showDataUpdatedHint)
            ReportCards.buildDataUpdatedHint(themeColors),

          // ─── 模型已切换提示 ───
          if (showModelChangedHint)
            ReportCards.buildModelChangedHint(themeColors),

          const SizedBox(height: AppDimens.spacingLg),

          // ─── 1. 本周期概览 ───
          if (report.currentOverview.isNotEmpty)
            ReportCards.buildCurrentOverviewCard(report, themeColors),
          if (report.currentOverview.isNotEmpty)
            const SizedBox(height: AppDimens.spacingLg),

          // ─── 2. 周期趋势 ───
          if (report.cycleStats.isNotEmpty || report.cycleTrendSummary.isNotEmpty)
            ReportCards.buildCycleTrendCard(report, themeColors),
          if (report.cycleStats.isNotEmpty || report.cycleTrendSummary.isNotEmpty)
            const SizedBox(height: AppDimens.spacingLg),

          // ─── 3. 症状趋势 ───
          if (report.symptomTrends.isNotEmpty)
            ReportCards.buildSymptomTrendCard(report, themeColors),
          if (report.symptomTrends.isNotEmpty)
            const SizedBox(height: AppDimens.spacingLg),

          // ─── 4. 与过去相比 ───
          if (report.comparisonTrends.isNotEmpty)
            ReportCards.buildComparisonCard(report, themeColors),
          if (report.comparisonTrends.isNotEmpty)
            const SizedBox(height: AppDimens.spacingLg),

          // ─── 5. 值得关注的地方 ───
          if (report.attentions.isNotEmpty)
            ReportCards.buildAttentionsCard(report, themeColors),
          if (report.attentions.isNotEmpty)
            const SizedBox(height: AppDimens.spacingLg),

          // ─── 6. 下一周期建议 ───
          if (report.nextCycleSuggestions.isNotEmpty)
            ReportCards.buildNextCycleSuggestionsCard(report, themeColors),
          if (report.nextCycleSuggestions.isNotEmpty)
            const SizedBox(height: AppDimens.spacingLg),

          // ─── 7. 就医提醒 ───
          if (report.medicalReminders.isNotEmpty)
            ReportCards.buildMedicalRemindersCard(report, themeColors),
          if (report.medicalReminders.isNotEmpty)
            const SizedBox(height: AppDimens.spacingLg),

          // ─── 总结 ───
          if (report.conclusion.isNotEmpty)
            ReportCards.buildConclusionCard(report, themeColors),
          if (report.conclusion.isNotEmpty)
            const SizedBox(height: AppDimens.spacingLg),

          // ─── 免责声明 ───
          ReportCards.buildDisclaimer(context, themeColors, modelId),
        ],
      ),
    );
  }
}
