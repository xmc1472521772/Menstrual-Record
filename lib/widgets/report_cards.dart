import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/ai_health_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../constants/app_theme.dart';

/// AI 健康报告的展示组件集合（P1-6 从 ai_assistant_screen.dart 迁出）。
///
/// 纯静态构建函数：接收报告数据与主题色快照，不依赖任何 Provider。
/// 涵盖评分头部、数据更新/模型切换提示、7 部分报告卡片与免责声明。
class ReportCards {
  ReportCards._();

  // ─── 数据更新提示 ──────────────────────────────────────────────

  static Widget buildDataUpdatedHint(AppThemeColors themeColors) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.spacingSm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spacingMd,
        vertical: AppDimens.spacingSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.update_rounded, size: 14, color: AppColors.warning),
          const SizedBox(width: AppDimens.spacingXs),
          Expanded(
            child: Text(
              AppStrings.aiDataUpdatedHint,
              style: AppTheme.bodySmall.copyWith(color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 模型已切换提示 ──────────────────────────────────────────────

  static Widget buildModelChangedHint(AppThemeColors themeColors) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.spacingSm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spacingMd,
        vertical: AppDimens.spacingSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.brandPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: Border.all(
          color: AppColors.brandPrimary.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.swap_horiz_rounded,
              size: 14, color: AppColors.brandPrimary),
          const SizedBox(width: AppDimens.spacingXs),
          Expanded(
            child: Text(
              AppStrings.aiModelChangedHint,
              style: AppTheme.bodySmall.copyWith(color: AppColors.brandPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 健康评分头部 ──────────────────────────────────────────────

  static Widget buildScoreHeader(HealthReport report) {
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
                    const Icon(Icons.insights_rounded,
                        color: AppColors.white, size: 14),
                    const SizedBox(width: AppDimens.spacingXs),
                    Text(
                      AppStrings.aiHealthReport,
                      style:
                          AppTheme.labelMedium.copyWith(color: AppColors.white),
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

  static Color _scoreColor(int score) {
    if (score >= 85) return AppColors.success;
    if (score >= 70) return AppColors.brandPrimary;
    if (score >= 50) return AppColors.warning;
    return AppColors.error;
  }

  static String _scoreLabel(int score) {
    if (score >= 85) return AppStrings.scoreHealthy;
    if (score >= 70) return AppStrings.scoreGood;
    if (score >= 50) return AppStrings.scoreNeedsAttention;
    return AppStrings.scoreNeedsDoctor;
  }

  // ─── 1. 本周期概览 ─────────────────────────────────────────────

  static Widget buildCurrentOverviewCard(
    HealthReport report,
    AppThemeColors themeColors,
  ) {
    return _ReportCard(
      title: AppStrings.aiSectionCurrentOverview,
      icon: Icons.today_rounded,
      themeColors: themeColors,
      child: Text(
        report.currentOverview,
        style: AppTheme.bodyMedium.copyWith(
          color: themeColors.onSurfaceSecondary,
          height: 1.6,
        ),
      ),
    );
  }

  // ─── 2. 周期趋势 ───────────────────────────────────────────────

  static Widget buildCycleTrendCard(
    HealthReport report,
    AppThemeColors themeColors,
  ) {
    return _ReportCard(
      title: AppStrings.aiSectionCycleTrend,
      icon: Icons.trending_up_rounded,
      themeColors: themeColors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (report.cycleStats.isNotEmpty) ...[
            Wrap(
              spacing: AppDimens.spacingSm,
              runSpacing: AppDimens.spacingSm,
              children: report.cycleStats.map((stat) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spacingMd,
                    vertical: AppDimens.spacingSm,
                  ),
                  decoration: BoxDecoration(
                    color: themeColors.surfaceTile,
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        stat.label,
                        style: AppTheme.bodySmall.copyWith(
                          color: themeColors.onSurfaceTertiary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stat.value,
                        style: AppTheme.titleMedium.copyWith(
                          color: themeColors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            if (report.cycleTrendSummary.isNotEmpty)
              const SizedBox(height: AppDimens.spacingMd),
          ],
          if (report.cycleTrendSummary.isNotEmpty)
            Text(
              report.cycleTrendSummary,
              style: AppTheme.bodyMedium.copyWith(
                color: themeColors.onSurfaceSecondary,
                height: 1.6,
              ),
            ),
        ],
      ),
    );
  }

  // ─── 3. 症状趋势 ───────────────────────────────────────────────

  static Widget buildSymptomTrendCard(
    HealthReport report,
    AppThemeColors themeColors,
  ) {
    return _ReportCard(
      title: AppStrings.aiSectionSymptomTrend,
      icon: Icons.healing_rounded,
      themeColors: themeColors,
      child: Column(
        children: report.symptomTrends.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: idx < report.symptomTrends.length - 1
                  ? AppDimens.spacingMd
                  : 0,
            ),
            child: _buildTrendItem(item, themeColors),
          );
        }).toList(),
      ),
    );
  }

  // ─── 4. 与过去相比 ─────────────────────────────────────────────

  static Widget buildComparisonCard(
    HealthReport report,
    AppThemeColors themeColors,
  ) {
    return _ReportCard(
      title: AppStrings.aiSectionComparison,
      icon: Icons.compare_arrows_rounded,
      themeColors: themeColors,
      child: Column(
        children: report.comparisonTrends.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: idx < report.comparisonTrends.length - 1
                  ? AppDimens.spacingMd
                  : 0,
            ),
            child: _buildTrendItem(item, themeColors),
          );
        }).toList(),
      ),
    );
  }

  static Widget _buildTrendItem(TrendItem item, AppThemeColors themeColors) {
    final statusColor = _trendStatusColor(item.status);
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
              Expanded(
                child: Text(
                  item.name,
                  style: AppTheme.titleMedium.copyWith(
                    color: themeColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.spacingSm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spacingSm,
                  vertical: AppDimens.spacingXs,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                ),
                child: Text(
                  item.status,
                  style: AppTheme.labelMedium.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spacingXs),
          Text(
            item.detail,
            style: AppTheme.bodySmall.copyWith(
              color: themeColors.onSurfaceSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  static Color _trendStatusColor(String status) {
    if (status.contains('增加') ||
        status.contains('变长') ||
        status.contains('减少') ||
        status.contains('变短')) {
      return AppColors.warning;
    }
    if (status.contains('稳定') || status.contains('无明显变化')) {
      return AppColors.success;
    }
    return AppColors.brandPrimary;
  }

  // ─── 5. 值得关注的地方 ─────────────────────────────────────────

  static Widget buildAttentionsCard(
    HealthReport report,
    AppThemeColors themeColors,
  ) {
    return _ReportCard(
      title: AppStrings.aiSectionAttentions,
      icon: Icons.visibility_outlined,
      themeColors: themeColors,
      child: Column(
        children: report.attentions.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: idx < report.attentions.length - 1
                  ? AppDimens.spacingMd
                  : 0,
            ),
            child: _buildAttentionItem(item, themeColors),
          );
        }).toList(),
      ),
    );
  }

  static Widget _buildAttentionItem(
      AttentionItem item, AppThemeColors themeColors) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active_outlined,
                  size: 16, color: AppColors.warning),
              const SizedBox(width: AppDimens.spacingXs),
              Expanded(
                child: Text(
                  item.title,
                  style: AppTheme.titleMedium.copyWith(
                    color: themeColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spacingXs),
          Text(
            item.detail,
            style: AppTheme.bodySmall.copyWith(
              color: themeColors.onSurfaceSecondary,
              height: 1.5,
            ),
          ),
          if (item.evidence.isNotEmpty) ...[
            const SizedBox(height: AppDimens.spacingXs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spacingSm,
                vertical: AppDimens.spacingXs,
              ),
              decoration: BoxDecoration(
                color: themeColors.surfaceTile,
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.fact_check_outlined,
                      size: 12, color: themeColors.onSurfaceTertiary),
                  const SizedBox(width: AppDimens.spacingXs),
                  Expanded(
                    child: Text(
                      '${AppStrings.aiEvidence}：${item.evidence}',
                      style: AppTheme.bodySmall.copyWith(
                        color: themeColors.onSurfaceTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── 6. 下一周期建议 ───────────────────────────────────────────

  static Widget buildNextCycleSuggestionsCard(
    HealthReport report,
    AppThemeColors themeColors,
  ) {
    return _ReportCard(
      title: AppStrings.aiSectionNextCycleSuggestions,
      icon: Icons.tips_and_updates_outlined,
      themeColors: themeColors,
      child: Column(
        children: report.nextCycleSuggestions.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: idx < report.nextCycleSuggestions.length - 1
                  ? AppDimens.spacingMd
                  : 0,
            ),
            child: _buildSuggestionItem(item, themeColors, idx + 1),
          );
        }).toList(),
      ),
    );
  }

  static Widget _buildSuggestionItem(
      NextCycleSuggestion item, AppThemeColors themeColors, int index) {
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
                item.title,
                style: AppTheme.titleMedium.copyWith(
                  color: themeColors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppDimens.spacingXs),
              Text(
                item.detail,
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

  // ─── 7. 就医提醒 ───────────────────────────────────────────────

  static Widget buildMedicalRemindersCard(
    HealthReport report,
    AppThemeColors themeColors,
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
              const Icon(Icons.local_hospital_rounded,
                  color: AppColors.error, size: 20),
              const SizedBox(width: AppDimens.spacingSm),
              Text(
                AppStrings.aiSectionMedicalReminders,
                style: AppTheme.titleLarge.copyWith(
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spacingMd),
          Column(
            children: report.medicalReminders.asMap().entries.map((entry) {
              final idx = entry.key;
              final reminder = entry.value;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: idx < report.medicalReminders.length - 1
                      ? AppDimens.spacingSm
                      : 0,
                ),
                child: _buildMedicalReminderItem(reminder, themeColors),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  static Widget _buildMedicalReminderItem(
      MedicalReminder reminder, AppThemeColors themeColors) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spacingSm),
      margin: const EdgeInsets.only(bottom: AppDimens.spacingSm),
      decoration: BoxDecoration(
        color: reminder.userMatched
            ? AppColors.error.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: reminder.userMatched
            ? Border.all(color: AppColors.error.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            reminder.userMatched
                ? Icons.priority_high_rounded
                : Icons.flag_rounded,
            size: 14,
            color: AppColors.error.withValues(alpha: 0.7),
          ),
          const SizedBox(width: AppDimens.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        reminder.condition,
                        style: AppTheme.titleMedium.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (reminder.userMatched) ...[
                      const SizedBox(width: AppDimens.spacingXs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusFull),
                        ),
                        child: const Text(
                          '⚠️ ${AppStrings.aiYouMatched}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  reminder.detail,
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
  }

  // ─── 总结 ──────────────────────────────────────────────────────

  static Widget buildConclusionCard(
    HealthReport report,
    AppThemeColors themeColors,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spacingLg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.brandPrimary.withValues(alpha: 0.06),
            AppColors.brandPrimary.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(
          color: AppColors.brandPrimary.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.summarize_rounded,
                  color: AppColors.brandPrimary, size: 20),
              const SizedBox(width: AppDimens.spacingSm),
              Text(
                AppStrings.aiSectionConclusion,
                style: AppTheme.titleLarge.copyWith(
                  color: AppColors.brandPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spacingMd),
          Text(
            report.conclusion,
            style: AppTheme.bodyMedium.copyWith(
              color: themeColors.onSurface,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 免责声明 ──────────────────────────────────────────────────

  /// [modelId] 为报告生成时使用的模型 ID，用于展示对应模型的免责声明。
  static Widget buildDisclaimer(
    BuildContext context,
    AppThemeColors themeColors,
    String modelId,
  ) {
    final disclaimerText = AIHealthService.disclaimerFor(modelId);
    return Container(
      padding: const EdgeInsets.all(AppDimens.spacingMd),
      decoration: BoxDecoration(
        color: themeColors.surfaceTile.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 16, color: themeColors.onSurfaceTertiary),
          const SizedBox(width: AppDimens.spacingSm),
          Expanded(
            child: Text(
              disclaimerText,
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
  final AppThemeColors themeColors;

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
