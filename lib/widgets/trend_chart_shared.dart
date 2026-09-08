import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Formats a DateTime as `yyyy.MM.dd`.
String formatChartDate(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

/// 趋势图时间范围筛选项（周期趋势图 / 经期天数趋势图共用）。
enum ChartTimeRange {
  threeMonths('3月'),
  sixMonths('6月'),
  oneYear('1年'),
  all('全部');

  final String label;
  const ChartTimeRange(this.label);
}

/// 返回 [range] 对应的日期截断点。
/// 使用月初作为截断点，避免 now.day 超出目标月天数导致的边界偏移
/// （如 5月31日减3个月 = 2月31日 → 3月3日）。
DateTime chartCutoffFor(ChartTimeRange range) {
  final now = DateTime.now();
  return switch (range) {
    ChartTimeRange.threeMonths => DateTime(now.year, now.month - 3, 1),
    ChartTimeRange.sixMonths => DateTime(now.year, now.month - 6, 1),
    ChartTimeRange.oneYear => DateTime(now.year - 1, now.month, 1),
    ChartTimeRange.all => DateTime(2000),
  };
}

/// 筛选条 chips（周期趋势图 / 经期天数趋势图共用）。
class ChartRangeChips extends StatelessWidget {
  final ChartTimeRange selected;
  final ValueChanged<ChartTimeRange> onChanged;

  const ChartRangeChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: ChartTimeRange.values.map((range) {
        final isSelected = range == selected;
        final isLast = range == ChartTimeRange.values.last;
        return GestureDetector(
          onTap: () => onChanged(range),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 3,
            ),
            margin: EdgeInsets.only(
              right: isLast ? 0 : 4,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.brandPrimary
                  : context.themeColors.surfaceTile,
              borderRadius: BorderRadius.circular(AppDimens.radiusFull),
              border: isSelected
                  ? null
                  : Border.all(
                      color: context.themeColors.divider,
                      width: 0.5,
                    ),
            ),
            child: Text(
              range.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? AppColors.white
                    : context.themeColors.onSurfaceSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
