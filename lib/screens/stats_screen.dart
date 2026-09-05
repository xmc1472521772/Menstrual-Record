import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/cycle_data.dart';
import '../providers/period_provider.dart';
import '../providers/settings_provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../constants/app_theme.dart';
import '../widgets/cycle_chart.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.stats),
      ),
      body: Consumer2<PeriodProvider, SettingsProvider>(
        builder: (context, periodProvider, settingsProvider, child) {
          final cycleData = periodProvider.cycleData;

          if (cycleData == null || cycleData.totalCycles == 0) {
            return _buildEmptyState(context);
          }

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
                CycleChart(periods: cycleData.recentPeriods),
                const SizedBox(height: AppDimens.spacingLg),
                _buildAlgorithmSelector(context, settingsProvider, periodProvider),
                const SizedBox(height: AppDimens.spacingLg),
                _buildPredictionCard(context, cycleData),
                const SizedBox(height: AppDimens.spacingLg),
                _buildHistoryList(context, cycleData),
              ],
            ),
          );
        },
      ),
    );
  }

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
        // 与 home_screen 的状态卡片保持一致：不使用 boxShadow。
        // 滚动时每帧重放高斯模糊栅格化会导致掉帧。
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
              _buildStatCircle(
                '${cycleData.averageCycleLength.round()}',
                AppStrings.avgCycleLabel,
                AppStrings.days,
              ),
              _buildStatCircle(
                '${cycleData.averagePeriodLength.round()}',
                AppStrings.avgPeriodLabel,
                AppStrings.days,
              ),
              _buildStatCircle(
                '${cycleData.totalCycles}',
                AppStrings.recordCycles,
                AppStrings.nDaysUnit,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCircle(String value, String label, String unit) {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.white.withValues(alpha: 0.2),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: AppTheme.headingLarge.copyWith(
                    color: AppColors.white,
                  ),
                ),
                Text(
                  unit,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppColors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimens.spacingSm),
        Text(
          label,
          style: AppTheme.bodyMedium.copyWith(
            color: AppColors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

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
            Row(
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
                    'weighted',
                    AppStrings.weightedAverage,
                    AppStrings.weightedMoreAccurate,
                    settingsProvider,
                    periodProvider,
                  ),
                ),
              ],
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
        // 先持久化设置，成功后再重算预测，保证 DB 与内存一致
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
                  color:
                      isSelected ? AppColors.brandPrimary : AppColors.grey,
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

  Widget _buildPredictionCard(BuildContext context, CycleData cycleData) {
    final predictedDate = cycleData.predictedNextPeriod;
    final daysUntil = cycleData.daysUntilPredicted;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.predictedNextPeriod,
              style: AppTheme.titleLarge.copyWith(
                color: context.themeColors.onSurface,
              ),
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
                              ? '还有 $daysUntil 天'
                              : daysUntil == 0
                                  ? '今天'
                                  : '已过 ${-daysUntil} 天',
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

  Widget _buildHistoryList(BuildContext context, CycleData cycleData) {
    final periods = cycleData.recentPeriods;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.historyRecords,
              style: AppTheme.titleLarge.copyWith(
                color: context.themeColors.onSurface,
              ),
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
            else
              // 不使用 ListView.builder + shrinkWrap（shrinkWrap 会测量全部子项，
              // 失去懒加载优势）。改为 Column + for 循环直接展开，
              // 历史记录通常不超过几十条，成本可忽略。
              Column(
                children: [
                  for (int i = 0; i < periods.length; i++)
                    _buildPeriodItem(context, periods[i], i),
                ],
              ),
          ],
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
                  '至 ${DateFormat('yyyy年MM月dd日').format(period.endDate!)}',
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
                  '周期 ${period.cycleLength} 天',
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
