import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/ai_health_service.dart';
import '../providers/period_provider.dart';
import '../providers/settings_provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../constants/app_theme.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  HealthReport? _report;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    // 延迟一帧后自动生成报告，让页面先完成首次渲染
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateReport();
    });
  }

  Future<void> _generateReport() async {
    final provider = context.read<PeriodProvider>();
    final settings = context.read<SettingsProvider>();

    if (provider.records.isEmpty || provider.cycleData == null) {
      return;
    }

    setState(() => _isAnalyzing = true);

    // 模拟分析延迟（500ms），让用户看到分析动画
    await Future.delayed(const Duration(milliseconds: 500));

    final report = AIHealthService.generateReport(
      records: provider.records,
      cycleData: provider.cycleData!,
      dailyFlowMap: provider.dailyFlowMap,
      userCycleLength: settings.cycleLength,
      userPeriodLength: settings.periodLength,
    );

    if (mounted) {
      setState(() {
        _report = report;
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.aiAssistant),
        actions: [
          if (_report != null && !_isAnalyzing)
            IconButton(
              onPressed: _generateReport,
              icon: const Icon(Icons.refresh_rounded, size: 22),
              color: AppColors.ink,
              tooltip: AppStrings.aiRegenerateReport,
            ),
          const SizedBox(width: AppDimens.spacingSm),
        ],
      ),
      body: Consumer2<PeriodProvider, SettingsProvider>(
        builder: (context, provider, settings, _) {
          if (provider.records.isEmpty || provider.cycleData == null) {
            return _buildEmptyState(context);
          }

          if (_isAnalyzing) {
            return _buildAnalyzingState(context);
          }

          if (_report == null) {
            return _buildGenerateButton(context);
          }

          return _buildReport(context);
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Empty state
  // ═══════════════════════════════════════════════════════════════

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacing3xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: BorderRadius.circular(AppDimens.radius2xl),
              ),
              child: const Icon(
                Icons.psychology_outlined,
                size: 44,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(height: AppDimens.spacingXl),
            Text(
              AppStrings.aiNoDataTitle,
              style: AppTheme.headingSmall.copyWith(
                color: context.themeColors.onSurface,
              ),
            ),
            const SizedBox(height: AppDimens.spacingSm),
            Text(
              AppStrings.aiNoDataSubtitle,
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(
                color: context.themeColors.onSurfaceTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Analyzing state
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAnalyzingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: AppColors.brandPrimary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: AppDimens.spacingXl),
          Text(
            AppStrings.aiAnalyzing,
            style: AppTheme.bodyLarge.copyWith(
              color: context.themeColors.onSurfaceSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Generate button (initial state with data but no report)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildGenerateButton(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacing3xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: BorderRadius.circular(AppDimens.radius2xl),
              ),
              child: const Icon(
                Icons.health_and_safety_outlined,
                size: 44,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(height: AppDimens.spacingXl),
            ElevatedButton.icon(
              onPressed: _generateReport,
              icon: const Icon(Icons.auto_awesome, size: 20),
              label: const Text(AppStrings.aiGenerateReport),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Full report
  // ═══════════════════════════════════════════════════════════════

  Widget _buildReport(BuildContext context) {
    final report = _report!;
    final themeColors = context.themeColors;

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
          _buildScoreHeader(context, report),
          const SizedBox(height: AppDimens.spacingLg),

          // ─── 报告摘要 ───
          _buildSummaryCard(context, report, themeColors),
          const SizedBox(height: AppDimens.spacingLg),

          // ─── 基本信息 ───
          _buildBasicInfoCard(context, report, themeColors),
          const SizedBox(height: AppDimens.spacingLg),

          // ─── 周期评估 ───
          _buildCycleAssessmentCard(context, report, themeColors),
          const SizedBox(height: AppDimens.spacingLg),

          // ─── 症因排查 ───
          _buildCauseAnalysisCard(context, report, themeColors),
          const SizedBox(height: AppDimens.spacingLg),

          // ─── 行动建议 ───
          _buildActionSuggestionsCard(context, report, themeColors),
          const SizedBox(height: AppDimens.spacingLg),

          // ─── 就医预警 ───
          _buildRedFlagsCard(context, report, themeColors),
          const SizedBox(height: AppDimens.spacingLg),

          // ─── 健康建议 ───
          ..._buildAdviceCards(context, report, themeColors),

          // ─── 免责声明 ───
          const SizedBox(height: AppDimens.spacingLg),
          _buildDisclaimer(context, themeColors),
        ],
      ),
    );
  }

  // ─── 健康评分头部 ──────────────────────────────────────────────

  Widget _buildScoreHeader(BuildContext context, HealthReport report) {
    final score = report.healthScore;
    final scoreColor = _scoreColor(score);
    final scoreLabel = _scoreLabel(score);

    return Container(
      padding: const EdgeInsets.all(AppDimens.spacingXl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scoreColor, scoreColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spacingMd,
                  vertical: AppDimens.spacingXs + 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.insights_rounded, color: AppColors.white, size: 14),
                    const SizedBox(width: AppDimens.spacingXs),
                    Text(
                      AppStrings.aiHealthReport,
                      style: AppTheme.labelMedium.copyWith(color: AppColors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spacingLg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$score',
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: AppDimens.spacingXs),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '/ 100',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppColors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.spacingMd),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  scoreLabel,
                  style: AppTheme.titleLarge.copyWith(color: AppColors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spacingSm),
          Text(
            '${AppStrings.aiReportTime}：${DateFormat('yyyy-MM-dd HH:mm').format(report.generatedAt)}',
            style: AppTheme.bodySmall.copyWith(
              color: AppColors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 85) return AppColors.success;
    if (score >= 70) return AppColors.brandPrimary;
    if (score >= 50) return AppColors.warning;
    return AppColors.error;
  }

  String _scoreLabel(int score) {
    if (score >= 85) return '健康';
    if (score >= 70) return '良好';
    if (score >= 50) return '需关注';
    return '需就医';
  }

  // ─── 报告摘要 ──────────────────────────────────────────────────

  Widget _buildSummaryCard(
    BuildContext context,
    HealthReport report,
    var themeColors,
  ) {
    return _ReportCard(
      title: AppStrings.aiReportSummary,
      icon: Icons.summarize_rounded,
      themeColors: themeColors,
      child: Text(
        report.summary,
        style: AppTheme.bodyMedium.copyWith(
          color: themeColors.onSurfaceSecondary,
          height: 1.6,
        ),
      ),
    );
  }

  // ─── 基本信息 ──────────────────────────────────────────────────

  Widget _buildBasicInfoCard(
    BuildContext context,
    HealthReport report,
    var themeColors,
  ) {
    final info = report.basicInfo;
    final entries = <(String, String)>[
      (AppStrings.aiLastPeriodDate, info['lastPeriodDate'] ?? '-'),
      (AppStrings.aiAvgCycleLength, info['avgCycleLength'] ?? '-'),
      (AppStrings.aiAvgPeriodLength, info['avgPeriodLength'] ?? '-'),
      (AppStrings.aiCurrentStatus, info['currentStatus'] ?? '-'),
      (AppStrings.aiTotalRecords, info['totalRecords'] ?? '-'),
    ];

    return _ReportCard(
      title: AppStrings.aiBasicInfo,
      icon: Icons.person_outline_rounded,
      themeColors: themeColors,
      child: Column(
        children: entries.map((e) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimens.spacingSm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    e.$1,
                    style: AppTheme.bodySmall.copyWith(
                      color: themeColors.onSurfaceTertiary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    e.$2,
                    style: AppTheme.bodyMedium.copyWith(
                      color: themeColors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── 周期评估 ──────────────────────────────────────────────────

  Widget _buildCycleAssessmentCard(
    BuildContext context,
    HealthReport report,
    var themeColors,
  ) {
    final assessment = report.cycleAssessment;
    final bool isNormal = assessment.isNormal;
    final Color statusColor = isNormal ? AppColors.success : AppColors.warning;
    final String statusLabel = isNormal ? AppStrings.aiOnTrack : 
        (assessment.deviationDays > 0 ? AppStrings.aiDaysLate : AppStrings.aiDaysEarly);

    return _ReportCard(
      title: AppStrings.aiCycleAssessment,
      icon: Icons.analytics_outlined,
      themeColors: themeColors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 状态标签
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spacingMd,
                  vertical: AppDimens.spacingXs + 2,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isNormal ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                      color: statusColor,
                      size: 14,
                    ),
                    const SizedBox(width: AppDimens.spacingXs),
                    Text(
                      assessment.deviationDays == 0 
                          ? statusLabel 
                          : '$statusLabel ${assessment.deviationDays.abs()} 天',
                      style: AppTheme.labelMedium.copyWith(color: statusColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spacingMd),
          // 评估说明
          Text(
            assessment.explanation,
            style: AppTheme.bodyMedium.copyWith(
              color: themeColors.onSurfaceSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppDimens.spacingMd),
          // 正常范围
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spacingMd,
              vertical: AppDimens.spacingSm,
            ),
            decoration: BoxDecoration(
              color: themeColors.surfaceTile,
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: themeColors.onSurfaceTertiary),
                const SizedBox(width: AppDimens.spacingXs),
                Expanded(
                  child: Text(
                    assessment.normalRange,
                    style: AppTheme.bodySmall.copyWith(
                      color: themeColors.onSurfaceTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 症因排查 ──────────────────────────────────────────────────

  Widget _buildCauseAnalysisCard(
    BuildContext context,
    HealthReport report,
    var themeColors,
  ) {
    return _ReportCard(
      title: AppStrings.aiCauseAnalysis,
      icon: Icons.search_rounded,
      themeColors: themeColors,
      child: Column(
        children: report.causeFactors.asMap().entries.map((entry) {
          final idx = entry.key;
          final factor = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: idx < report.causeFactors.length - 1 ? AppDimens.spacingMd : 0,
            ),
            child: _buildFactorItem(factor, themeColors, idx + 1),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFactorItem(CauseFactor factor, var themeColors, int index) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.brandPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimens.radiusFull),
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: AppTheme.labelMedium.copyWith(
              color: AppColors.brandPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AppDimens.spacingMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                factor.factor,
                style: AppTheme.titleMedium.copyWith(
                  color: themeColors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppDimens.spacingXs),
              Text(
                factor.explanation,
                style: AppTheme.bodySmall.copyWith(
                  color: themeColors.onSurfaceSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── 行动建议 ──────────────────────────────────────────────────

  Widget _buildActionSuggestionsCard(
    BuildContext context,
    HealthReport report,
    var themeColors,
  ) {
    return _ReportCard(
      title: AppStrings.aiActionSuggestions,
      icon: Icons.tips_and_updates_outlined,
      themeColors: themeColors,
      child: Column(
        children: report.actionSuggestions.asMap().entries.map((entry) {
          final idx = entry.key;
          final suggestion = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: idx < report.actionSuggestions.length - 1 ? AppDimens.spacingMd : 0,
            ),
            child: _buildSuggestionItem(suggestion, themeColors),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSuggestionItem(ActionSuggestion suggestion, var themeColors) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spacingMd),
      decoration: BoxDecoration(
        color: themeColors.surfaceTile.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.visibility_outlined, size: 14, color: AppColors.brandPrimary),
              const SizedBox(width: AppDimens.spacingXs),
              Text(
                AppStrings.aiObservation,
                style: AppTheme.labelMedium.copyWith(
                  color: AppColors.brandPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spacingXs),
          Text(
            suggestion.observation,
            style: AppTheme.bodySmall.copyWith(
              color: themeColors.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppDimens.spacingSm),
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded, size: 14, color: AppColors.success),
              const SizedBox(width: AppDimens.spacingXs),
              Text(
                AppStrings.aiSuggestion,
                style: AppTheme.labelMedium.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spacingXs),
          Text(
            suggestion.suggestion,
            style: AppTheme.bodySmall.copyWith(
              color: themeColors.onSurfaceSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 就医预警 ──────────────────────────────────────────────────

  Widget _buildRedFlagsCard(
    BuildContext context,
    HealthReport report,
    var themeColors,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_hospital_rounded, color: AppColors.error, size: 20),
              const SizedBox(width: AppDimens.spacingSm),
              Text(
                AppStrings.aiRedFlags,
                style: AppTheme.titleLarge.copyWith(
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spacingSm),
          Text(
            '出现以下「红旗症状」时必须立即就医：',
            style: AppTheme.bodySmall.copyWith(
              color: themeColors.onSurfaceSecondary,
            ),
          ),
          const SizedBox(height: AppDimens.spacingMd),
          Column(
            children: report.redFlags.asMap().entries.map((entry) {
              final idx = entry.key;
              final flag = entry.value;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: idx < report.redFlags.length - 1 ? AppDimens.spacingSm : 0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.flag_rounded, size: 14, color: AppColors.error.withValues(alpha: 0.7)),
                    const SizedBox(width: AppDimens.spacingSm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            flag.symptom,
                            style: AppTheme.titleMedium.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            flag.description,
                            style: AppTheme.bodySmall.copyWith(
                              color: themeColors.onSurfaceSecondary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── 健康建议卡片 ──────────────────────────────────────────────

  List<Widget> _buildAdviceCards(
    BuildContext context,
    HealthReport report,
    var themeColors,
  ) {
    return report.advices.map((advice) {
      final (bgColor, iconColor) = _adviceColors(advice.type);
      return Padding(
        padding: const EdgeInsets.only(bottom: AppDimens.spacingLg),
        child: Container(
          padding: const EdgeInsets.all(AppDimens.spacingLg),
          decoration: BoxDecoration(
            color: themeColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(
              color: iconColor.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                ),
                child: Icon(advice.icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: AppDimens.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      advice.title,
                      style: AppTheme.titleMedium.copyWith(
                        color: iconColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppDimens.spacingXs),
                    Text(
                      advice.content,
                      style: AppTheme.bodySmall.copyWith(
                        color: themeColors.onSurfaceSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  (Color, Color) _adviceColors(AdviceType type) {
    return switch (type) {
      AdviceType.info => (AppColors.success.withValues(alpha: 0.1), AppColors.success),
      AdviceType.caution => (AppColors.warning.withValues(alpha: 0.1), AppColors.warning),
      AdviceType.warning => (AppColors.error.withValues(alpha: 0.1), AppColors.error),
    };
  }

  // ─── 免责声明 ──────────────────────────────────────────────────

  Widget _buildDisclaimer(BuildContext context, var themeColors) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spacingMd),
      decoration: BoxDecoration(
        color: themeColors.surfaceTile.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: themeColors.onSurfaceTertiary),
          const SizedBox(width: AppDimens.spacingSm),
          Expanded(
            child: Text(
              AppStrings.aiDisclaimer,
              style: AppTheme.bodySmall.copyWith(
                color: themeColors.onSurfaceTertiary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Reusable report card widget
// ═══════════════════════════════════════════════════════════════════

class _ReportCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final dynamic themeColors;

  const _ReportCard({
    required this.title,
    required this.icon,
    required this.child,
    required this.themeColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spacingLg),
      decoration: BoxDecoration(
        color: themeColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: themeColors.divider.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.brandPrimary),
              const SizedBox(width: AppDimens.spacingSm),
              Text(
                title,
                style: AppTheme.titleLarge.copyWith(
                  color: themeColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spacingMd),
          child,
        ],
      ),
    );
  }
}
