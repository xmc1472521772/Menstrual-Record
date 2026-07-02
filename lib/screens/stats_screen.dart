import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/period_provider.dart';
import '../providers/settings_provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../constants/app_theme.dart';

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
            return _buildEmptyState();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppColors.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildOverviewCard(cycleData),
                const SizedBox(height: AppColors.spacingLg),
                _buildAlgorithmSelector(settingsProvider, periodProvider),
                const SizedBox(height: AppColors.spacingLg),
                _buildPredictionCard(cycleData),
                const SizedBox(height: AppColors.spacingLg),
                _buildHistoryList(cycleData),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.lightPink,
              borderRadius: BorderRadius.circular(AppColors.radiusLg),
            ),
            child: const Icon(
              Icons.bar_chart,
              size: 40,
              color: AppColors.primaryPink,
            ),
          ),
          const SizedBox(height: AppColors.spacingXl),
          Text(
            '暂无统计数据',
            style: AppTheme.headingSmall.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: AppColors.spacingSm),
          Text(
            '记录经期后即可查看统计',
            style: AppTheme.bodyMedium.copyWith(
              color: AppColors.onSurfaceTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(cycleData) {
    return Container(
      padding: const EdgeInsets.all(AppColors.spacingXl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryPink, AppColors.accentPink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPink.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '周期概览',
            style: AppTheme.headingMedium.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: AppColors.spacingXl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCircle(
                '${cycleData.averageCycleLength.round()}',
                '平均周期',
                '天',
              ),
              _buildStatCircle(
                '${cycleData.averagePeriodLength.round()}',
                '平均经期',
                '天',
              ),
              _buildStatCircle(
                '${cycleData.totalCycles}',
                '记录周期',
                '个',
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
        const SizedBox(height: AppColors.spacingSm),
        Text(
          label,
          style: AppTheme.bodyMedium.copyWith(
            color: AppColors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildAlgorithmSelector(SettingsProvider settingsProvider, PeriodProvider periodProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppColors.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.predictionAlgorithm,
              style: AppTheme.titleLarge.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: AppColors.spacingMd),
            Row(
              children: [
                Expanded(
                  child: _buildAlgorithmOption(
                    'simple',
                    AppStrings.simpleAverage,
                    '基于所有历史数据的平均值',
                    settingsProvider,
                    periodProvider,
                  ),
                ),
                const SizedBox(width: AppColors.spacingMd),
                Expanded(
                  child: _buildAlgorithmOption(
                    'weighted',
                    AppStrings.weightedAverage,
                    '近期周期数据权重更高，更准确',
                    settingsProvider,
                    periodProvider,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppColors.spacingSm),
            Text(
              '加权移动平均法：基于最近 4 个周期的数据，越近的周期权重越高（40%/30%/20%/10%），不足 4 个周期时按实际数量加权计算。',
              style: AppTheme.bodySmall.copyWith(
                color: AppColors.onSurfaceTertiary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlgorithmOption(
    String value,
    String title,
    String description,
    SettingsProvider settingsProvider,
    PeriodProvider periodProvider,
  ) {
    final isSelected = settingsProvider.algorithm == value;

    return InkWell(
      onTap: () {
        settingsProvider.setAlgorithm(value);
        periodProvider.setAlgorithm(value);
      },
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppColors.spacingMd),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColors.primaryPink : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          color: isSelected ? AppColors.lightPink : AppColors.surfaceCard,
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
                      isSelected ? AppColors.primaryPink : AppColors.grey,
                  size: 20,
                ),
                const SizedBox(width: AppColors.spacingSm),
                Expanded(
                  child: Text(
                    title,
                    style: AppTheme.titleMedium.copyWith(
                      color: isSelected
                          ? AppColors.darkPink
                          : AppColors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppColors.spacingSm),
            Text(
              description,
              style: AppTheme.bodySmall.copyWith(
                color: AppColors.onSurfaceSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionCard(cycleData) {
    final predictedDate = cycleData.predictedNextPeriod;
    final daysUntil = cycleData.daysUntilPredicted;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppColors.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.predictedNextPeriod,
              style: AppTheme.titleLarge.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: AppColors.spacingMd),
            if (predictedDate != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('yyyy年MM月dd日').format(predictedDate),
                        style: AppTheme.headingSmall.copyWith(
                          color: AppColors.primaryPink,
                        ),
                      ),
                      const SizedBox(height: AppColors.spacingXs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppColors.spacingSm,
                          vertical: AppColors.spacingXs,
                        ),
                        decoration: BoxDecoration(
                          color: (daysUntil > 0
                                  ? AppColors.success
                                  : AppColors.error)
                              .withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(AppColors.radiusFull),
                        ),
                        child: Text(
                          daysUntil > 0
                              ? '还有 $daysUntil 天'
                              : daysUntil == 0
                                  ? '今天'
                                  : '已过 ${-daysUntil} 天',
                          style: AppTheme.labelMedium.copyWith(
                            color: daysUntil > 0
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(AppColors.spacingMd),
                    decoration: BoxDecoration(
                      color: AppColors.lightPink,
                      borderRadius:
                          BorderRadius.circular(AppColors.radiusSm),
                    ),
                    child: const Icon(
                      Icons.calendar_today,
                      color: AppColors.primaryPink,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                '需要更多数据来预测',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppColors.onSurfaceTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(cycleData) {
    final periods = cycleData.recentPeriods;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppColors.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.historyRecords,
              style: AppTheme.titleLarge.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: AppColors.spacingMd),
            if (periods.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppColors.spacingXl),
                child: Column(
                  children: [
                    const Icon(
                      Icons.history,
                      size: 36,
                      color: AppColors.onSurfaceTertiary,
                    ),
                    const SizedBox(height: AppColors.spacingSm),
                    Text(
                      AppStrings.noRecords,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppColors.onSurfaceTertiary,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: periods.length,
                itemBuilder: (context, index) {
                  final period = periods[index];
                  return _buildPeriodItem(period, index);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodItem(period, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppColors.spacingSm),
      padding: const EdgeInsets.all(AppColors.spacingMd),
      decoration: BoxDecoration(
        color: index % 2 == 0
            ? AppColors.lightPink.withValues(alpha: 0.3)
            : AppColors.transparent,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
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
                  color: AppColors.onSurface,
                ),
              ),
              if (period.endDate != null)
                Text(
                  '至 ${DateFormat('yyyy年MM月dd日').format(period.endDate!)}',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppColors.onSurfaceSecondary,
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
                  color: AppColors.primaryPink,
                ),
              ),
              if (period.cycleLength != null)
                Text(
                  '周期 ${period.cycleLength} 天',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppColors.onSurfaceSecondary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
