import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/cycle_data.dart';
import '../providers/period_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/ai_assistant_provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../constants/app_theme.dart';
import '../widgets/cycle_chart.dart';
import '../widgets/health_score_trend_chart.dart';
import '../widgets/period_length_chart.dart';
import '../widgets/year_heatmap.dart';
import '../widgets/common_widgets.dart';
import 'ai_assistant_screen.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  /// 每页显示的历史记录条数
  static const int _pageSize = 5;

  /// 当前显示的记录条数（页数 × _pageSize）
  int _displayCount = _pageSize;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.stats),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.brandPrimary,
          unselectedLabelColor: context.themeColors.onSurfaceTertiary,
          indicatorColor: AppColors.brandPrimary,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: AppTheme.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: AppTheme.titleMedium,
          tabs: const [
            Tab(text: AppStrings.statsTabOverview),
            Tab(text: AppStrings.statsTabTrend),
            Tab(text: AppStrings.statsTabHistory),
          ],
        ),
      ),
      body: Consumer3<PeriodProvider, SettingsProvider, AiAssistantProvider>(
        builder: (context, periodProvider, settingsProvider, aiProvider,
            child) {
          final cycleData = periodProvider.cycleData;

          if (cycleData == null || cycleData.totalCycles == 0) {
            return _buildEmptyState(context);
          }

          // _displayCount 越界防护在使用处 clamp（_buildHistoryList），
          // 避免在 build 期间修改状态

          return TabBarView(
            controller: _tabController,
            children: [
              // ─── Tab 1: 概览 ───
              _buildOverviewTab(context, cycleData, settingsProvider,
                  periodProvider, aiProvider),
              // ─── Tab 2: 趋势 ───
              _buildTrendTab(context, cycleData, periodProvider),
              // ─── Tab 3: 历史 ───
              _buildHistoryTab(context, cycleData),
            ],
          );
        },
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  //  Tab 1: 概览
  // ═════════════════════════════════════════════════════════════════

  Widget _buildOverviewTab(
    BuildContext context,
    CycleData cycleData,
    SettingsProvider settingsProvider,
    PeriodProvider periodProvider,
    AiAssistantProvider aiProvider,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spacingLg,
        AppDimens.spacingLg,
        AppDimens.spacingLg,
        100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildOverviewCard(context, cycleData),
          const SizedBox(height: AppDimens.spacingLg),
          _buildAlgorithmSelector(context, settingsProvider, periodProvider),
          const SizedBox(height: AppDimens.spacingLg),
          _buildPredictionCard(context, cycleData),
          // 健康评分趋势卡（1.34.0）：≥2 条报告历史时由卡片自身渲染，
          // 不足时 shrink 不占位
          const SizedBox(height: AppDimens.spacingLg),
          HealthScoreTrendChart(history: aiProvider.reportHistory),
          const SizedBox(height: AppDimens.spacingLg),
          _buildAIAssistantCard(context, cycleData),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  //  AI助手入口卡片
  // ═════════════════════════════════════════════════════════════════

  Widget _buildAIAssistantCard(BuildContext context, CycleData cycleData) {
    final hasData = cycleData.totalCycles > 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AIAssistantScreen(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(AppDimens.spacingLg),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              AppColors.aiCardStart,
              AppColors.aiCardEnd,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
              child: const Icon(
                Icons.psychology_rounded,
                color: AppColors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: AppDimens.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.aiAssistantCardTitle,
                    style: AppTheme.titleMedium.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasData
                        ? AppStrings.aiAssistantCardSubtitle
                        : AppStrings.aiAssistantCardNeedsData,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppColors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.white.withValues(alpha: 0.7),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  //  Tab 2: 趋势
  // ═════════════════════════════════════════════════════════════════

  Widget _buildTrendTab(
    BuildContext context,
    CycleData cycleData,
    PeriodProvider periodProvider,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spacingLg,
        AppDimens.spacingLg,
        AppDimens.spacingLg,
        100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CycleChart(periods: cycleData.recentPeriods),
          const SizedBox(height: AppDimens.spacingLg),
          PeriodLengthChart(periods: cycleData.recentPeriods),
          const SizedBox(height: AppDimens.spacingLg),
          YearHeatmap(
            records: periodProvider.records,
            flowMap: periodProvider.dailyFlowMap,
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  //  Tab 3: 历史
  // ═════════════════════════════════════════════════════════════════

  Widget _buildHistoryTab(BuildContext context, CycleData cycleData) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spacingLg,
        AppDimens.spacingLg,
        AppDimens.spacingLg,
        100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHistoryList(context, cycleData),
        ],
      ),
    );
  }

  // ─── Empty state ────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            ),
            child: const Icon(
              Icons.bar_chart,
              size: 40,
              color: AppColors.brandPrimary,
            ),
          ),
          const SizedBox(height: AppDimens.spacingXl),
          Text(
            AppStrings.noStatsData,
            style: AppTheme.headingSmall.copyWith(
              color: context.themeColors.onSurface,
            ),
          ),
          const SizedBox(height: AppDimens.spacingSm),
          Text(
            AppStrings.recordToViewStatsData,
            style: AppTheme.bodyMedium.copyWith(
              color: context.themeColors.onSurfaceTertiary,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Overview card ──────────────────────────────────────────────

  Widget _buildOverviewCard(BuildContext context, CycleData cycleData) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spacingXl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brandPrimary, AppColors.brandLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Column(
        children: [
          Text(
            AppStrings.cycleOverview,
            style: AppTheme.headingMedium.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: AppDimens.spacingXl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // E1 收敛：直接复用 common_widgets.StatCircle（与旧的
              // 私有 _buildStatCircle 逐行等价：76px 圆 + 白字 + 20% 底）。
              StatCircle(
                value: cycleData.averageCycleLength.toStringAsFixed(1),
                label: AppStrings.avgCycleLabel,
                unit: AppStrings.days,
              ),
              StatCircle(
                value: cycleData.averagePeriodLength.toStringAsFixed(1),
                label: AppStrings.avgPeriodLabel,
                unit: AppStrings.days,
              ),
              StatCircle(
                value: '${cycleData.totalCycles}',
                label: AppStrings.recordCycles,
                unit: AppStrings.nDaysUnit,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Algorithm selector ─────────────────────────────────────────

  Widget _buildAlgorithmSelector(
    BuildContext context,
    SettingsProvider settingsProvider,
    PeriodProvider periodProvider,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.predictionAlgorithm,
              style: AppTheme.titleLarge.copyWith(
                color: context.themeColors.onSurface,
              ),
            ),
            const SizedBox(height: AppDimens.spacingMd),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildAlgorithmOption(
                      context,
                      'simple',
                      AppStrings.simpleAverage,
                      AppStrings.basedOnAllHistory,
                      settingsProvider,
                      periodProvider,
                    ),
                  ),
                  const SizedBox(width: AppDimens.spacingMd),
                  Expanded(
                    child: _buildAlgorithmOption(
                      context,
                      'adaptive',
                      AppStrings.weightedAverage,
                      AppStrings.weightedMoreAccurate,
                      settingsProvider,
                      periodProvider,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.spacingSm),
            Text(
              AppStrings.weightedDescription,
              style: AppTheme.bodySmall.copyWith(
                color: context.themeColors.onSurfaceTertiary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlgorithmOption(
    BuildContext context,
    String value,
    String title,
    String description,
    SettingsProvider settingsProvider,
    PeriodProvider periodProvider,
  ) {
    final isSelected = settingsProvider.algorithm == value;

    return InkWell(
      onTap: () async {
        await settingsProvider.setAlgorithm(value);
        await periodProvider.setAlgorithm(value);
      },
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppDimens.spacingMd),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColors.brandPrimary : context.themeColors.divider,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          color: isSelected ? AppColors.brandSoft : context.themeColors.surfaceCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: isSelected
                      ? AppColors.brandPrimary
                      : context.themeColors.onSurfaceTertiary,
                  size: 20,
                ),
                const SizedBox(width: AppDimens.spacingSm),
                Expanded(
                  child: Text(
                    title,
                    style: AppTheme.titleMedium.copyWith(
                      color: isSelected
                          ? AppColors.brandDeep
                          : context.themeColors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spacingSm),
            Text(
              description,
              style: AppTheme.bodySmall.copyWith(
                color: context.themeColors.onSurfaceSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Prediction card ────────────────────────────────────────────

  Widget _buildPredictionCard(BuildContext context, CycleData cycleData) {
    final predictedDate = cycleData.predictedNextPeriod;
    final daysUntil = cycleData.daysUntilPredicted;
    final windowStart = cycleData.predictionWindowStart;
    final windowEnd = cycleData.predictionWindowEnd;
    final mode = cycleData.predictionMode;

    final modeLabel = switch (mode) {
      PredictionMode.baseline => AppStrings.predictionModeBaseline,
      PredictionMode.wmaRegular => AppStrings.predictionModeWmaRegular,
      PredictionMode.wmaVolatile => AppStrings.predictionModeWmaVolatile,
      PredictionMode.simple => AppStrings.predictionModeSimple,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  AppStrings.predictedNextPeriod,
                  style: AppTheme.titleLarge.copyWith(
                    color: context.themeColors.onSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spacingSm,
                    vertical: AppDimens.spacingXs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandSoft,
                    borderRadius:
                        BorderRadius.circular(AppDimens.radiusFull),
                  ),
                  child: Text(
                    modeLabel,
                    style: AppTheme.labelMedium.copyWith(
                      color: AppColors.brandDeep,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spacingMd),
            if (predictedDate != null && daysUntil != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('yyyy年MM月dd日').format(predictedDate),
                        style: AppTheme.headingSmall.copyWith(
                          color: AppColors.brandPrimary,
                        ),
                      ),
                      const SizedBox(height: AppDimens.spacingXs),
                      if (windowStart != null && windowEnd != null)
                        Text(
                          '${AppStrings.predictionWindowPrefix}${DateFormat('MM月dd日').format(windowStart)} ~ ${DateFormat('MM月dd日').format(windowEnd)}',
                          style: AppTheme.bodySmall.copyWith(
                            color: context.themeColors.onSurfaceSecondary,
                          ),
                        ),
                      const SizedBox(height: AppDimens.spacingXs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.spacingSm,
                          vertical: AppDimens.spacingXs,
                        ),
                        decoration: BoxDecoration(
                          color: (daysUntil >= 0
                                  ? AppColors.success
                                  : AppColors.error)
                              .withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusFull),
                        ),
                        child: Text(
                          daysUntil > 0
                              ? AppStrings.daysLeft
                                  .replaceAll('{}', '$daysUntil')
                              : daysUntil == 0
                                  ? AppStrings.today_
                                  : AppStrings.daysPassed
                                      .replaceAll('{}', '${-daysUntil}'),
                          style: AppTheme.labelMedium.copyWith(
                            color: daysUntil >= 0
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(AppDimens.spacingMd),
                    decoration: BoxDecoration(
                      color: AppColors.brandSoft,
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusSm),
                    ),
                    child: const Icon(
                      Icons.calendar_today,
                      color: AppColors.brandPrimary,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                AppStrings.needMoreDataToPredict,
                style: AppTheme.bodyMedium.copyWith(
                  color: context.themeColors.onSurfaceTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── History list ────────────────────────────────────────────────

  Widget _buildHistoryList(BuildContext context, CycleData cycleData) {
    final periods = cycleData.recentPeriods;
    // 数据量变化（导入/删除）时 clamp，防止越界取数
    final displayPeriods =
        periods.take(_displayCount.clamp(0, periods.length)).toList();
    final hasMore = _displayCount < periods.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  AppStrings.historyRecords,
                  style: AppTheme.titleLarge.copyWith(
                    color: context.themeColors.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  // C2 口径统一：统计页历史按「周期」计数（仅已完成），
                  // 与记录页「共 N 条记录」（含进行中）区分开。
                  AppStrings.cyclesCount.replaceAll('{}', '${periods.length}'),
                  style: AppTheme.bodySmall.copyWith(
                    color: context.themeColors.onSurfaceTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spacingMd),
            if (periods.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimens.spacingXl),
                child: Column(
                  children: [
                    Icon(
                      Icons.history,
                      size: 36,
                      color: context.themeColors.onSurfaceTertiary,
                    ),
                    const SizedBox(height: AppDimens.spacingSm),
                    Text(
                      AppStrings.noRecords,
                      style: AppTheme.bodyMedium.copyWith(
                        color: context.themeColors.onSurfaceTertiary,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              Column(
                children: [
                  for (int i = 0; i < displayPeriods.length; i++)
                    _buildPeriodItem(context, displayPeriods[i], i),
                ],
              ),
              if (hasMore || _displayCount > _pageSize)
                const SizedBox(height: AppDimens.spacingSm),
              if (hasMore)
                _buildViewMoreButton(context, periods.length)
              else if (_displayCount > _pageSize)
                _buildCollapseButton(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildViewMoreButton(BuildContext context, int totalCount) {
    final remaining = totalCount - _displayCount;
    final nextBatch = remaining < _pageSize ? remaining : _pageSize;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          setState(() {
            _displayCount += nextBatch;
          });
        },
        icon: const Icon(Icons.expand_more, size: 20),
        label: Text(
          '${AppStrings.viewMore} $nextBatch ${AppStrings.days}',
          style: AppTheme.buttonLabel.copyWith(
            color: AppColors.brandPrimary,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: AppColors.brandPrimary.withValues(alpha: 0.3),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          ),
          padding: const EdgeInsets.symmetric(
            vertical: AppDimens.spacingMd,
          ),
        ),
      ),
    );
  }

  Widget _buildCollapseButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          setState(() {
            _displayCount = _pageSize;
          });
        },
        icon: const Icon(Icons.expand_less, size: 20),
        label: Text(
          AppStrings.collapse,
          style: AppTheme.buttonLabel.copyWith(
            color: AppColors.brandPrimary,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: AppColors.brandPrimary.withValues(alpha: 0.3),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          ),
          padding: const EdgeInsets.symmetric(
            vertical: AppDimens.spacingMd,
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodItem(
    BuildContext context,
    PeriodSummary period,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.spacingSm),
      padding: const EdgeInsets.all(AppDimens.spacingMd),
      decoration: BoxDecoration(
        color: index % 2 == 0
            ? AppColors.brandSoft.withValues(alpha: 0.3)
            : AppColors.transparent,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('yyyy年MM月dd日').format(period.startDate),
                style: AppTheme.titleMedium.copyWith(
                  color: context.themeColors.onSurface,
                ),
              ),
              if (period.endDate != null)
                Text(
                  '${AppStrings.to} ${DateFormat('yyyy年MM月dd日').format(period.endDate!)}',
                  style: AppTheme.bodySmall.copyWith(
                    color: context.themeColors.onSurfaceSecondary,
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${period.periodDays} 天',
                style: AppTheme.titleMedium.copyWith(
                  color: AppColors.brandPrimary,
                ),
              ),
              if (period.cycleLength != null)
                Text(
                  AppStrings.cycleLengthN
                      .replaceAll('{}', '${period.cycleLength}'),
                  style: AppTheme.bodySmall.copyWith(
                    color: context.themeColors.onSurfaceSecondary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
