import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';
import '../models/period_record.dart';
import '../utils/date_utils.dart';

/// 年度热力图 — GitHub 风格的日历活动图。
///
/// 以周一为列起始，每列代表一周，每个格子代表一天。
/// 经期日用品牌色填充，颜色深浅表示经量等级：
/// - 无经量记录的经期日：中等深浅
/// - 有经量记录的经期日：根据等级（0=无, 1=少, 2=中, 3=多）显示不同深浅
/// - 透明：非经期日
///
/// 月份标签显示在每列首行的上方，月份切换处标注月份缩写。
class YearHeatmap extends StatefulWidget {
  /// 所有经期记录（按时间正序排列）。
  final List<PeriodRecord> records;

  /// 每日经量映射：`dayKey -> flowLevel`（0=无, 1=少, 2=中, 3=多）。
  final Map<int, int> flowMap;

  /// 选中日期的回调（点击格子时触发）。
  final void Function(DateTime date)? onDateSelected;

  const YearHeatmap({
    super.key,
    required this.records,
    this.flowMap = const {},
    this.onDateSelected,
  });

  @override
  State<YearHeatmap> createState() => _YearHeatmapState();
}

class _YearHeatmapState extends State<YearHeatmap> {
  /// 当前显示的年份。
  late int _year;

  /// 经期日索引：`yyyyMMdd -> flowLevel`，用于 O(1) 判断某天是否为经期及其经量。
  /// flowLevel: 1=偏少, 2=正常, 3=偏多, 0=未设置（默认中等）
  late Map<int, int> _periodDays;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
    _rebuildIndex();
  }

  @override
  void didUpdateWidget(covariant YearHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.records != widget.records) {
      _rebuildIndex();
    }
  }

  void _rebuildIndex() {
    _periodDays = {};
    final now = DateTime.now();
    for (final r in widget.records) {
      final start = r.startDateTime;
      final end = r.endDateTime ?? now;
      var d = DateTime(start.year, start.month, start.day);
      while (!d.isAfter(end)) {
        if (d.year == _year) {
          // 优先使用每日经量记录中的等级，否则用 0（无记录）
          final key = AppDateUtils.dayKey(d);
          _periodDays[key] = widget.flowMap[key] ?? 0;
        }
        d = d.add(const Duration(days: 1));
      }
    }
  }

  void _changeYear(int delta) {
    setState(() {
      _year += delta;
      _rebuildIndex();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── 标题行 ───
            Row(
              children: [
                const Icon(
                  Icons.calendar_view_month_rounded,
                  size: 20,
                  color: AppColors.brandPrimary,
                ),
                const SizedBox(width: AppDimens.spacingSm),
                Text(
                  '年度热力图',
                  style: AppTheme.titleLarge.copyWith(
                    color: context.themeColors.onSurface,
                  ),
                ),
                const Spacer(),
                // 年份切换
                _buildYearSelector(),
              ],
            ),
            const SizedBox(height: AppDimens.spacingMd),
            // ─── 统计摘要 ───
            _buildSummary(),
            const SizedBox(height: AppDimens.spacingLg),
            // ─── 热力图 ───
            _buildHeatmapGrid(context),
            const SizedBox(height: AppDimens.spacingSm),
            // ─── 图例 ───
            _buildLegend(context),
          ],
        ),
      ),
    );
  }

  Widget _buildYearSelector() {
    final now = DateTime.now().year;
    final canGoNext = _year < now;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _year > 2020 ? () => _changeYear(-1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
          iconSize: 20,
          color: AppColors.inkSecondary,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        Text(
          '$_year',
          style: AppTheme.titleMedium.copyWith(
            color: context.themeColors.onSurface,
          ),
        ),
        IconButton(
          onPressed: canGoNext ? () => _changeYear(1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
          iconSize: 20,
          color: AppColors.inkSecondary,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    // 统计今年经期天数
    final periodDayCount = _periodDays.length;
    // 统计经期次数
    int periodCount = 0;
    for (final r in widget.records) {
      final start = r.startDateTime;
      final end = r.endDateTime ?? DateTime.now();
      // 经期与今年有重叠
      if ((start.year == _year) ||
          (end.year == _year) ||
          (start.year < _year && end.year > _year)) {
        periodCount++;
      }
    }
    return Row(
      children: [
        _summaryChip('$_year年', '$periodCount 次', '经期'),
        const SizedBox(width: AppDimens.spacingMd),
        _summaryChip('$_year年', '$periodDayCount 天', '经期日'),
      ],
    );
  }

  Widget _summaryChip(String prefix, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spacingMd,
        vertical: AppDimens.spacingXs + 2,
      ),
      decoration: BoxDecoration(
        color: context.themeColors.surfaceTile,
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTheme.titleMedium.copyWith(
              color: AppColors.brandPrimary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(
              color: context.themeColors.onSurfaceSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapGrid(BuildContext context) {
    // 计算该年第一天是星期几（周一=1）
    final jan1 = DateTime(_year, 1, 1);
    // DateTime.weekday: 周一=1, 周日=7
    final firstWeekday = jan1.weekday;
    // 从1月1日之前的周一开始，补齐前置空格
    final startDate = jan1.subtract(Duration(days: firstWeekday - 1));

    // 计算该年最后一天
    final dec31 = DateTime(_year, 12, 31);
    final lastWeekday = dec31.weekday;
    // 补齐到周日
    final endDate = dec31.add(Duration(days: 7 - lastWeekday));

    // 总天数
    final totalDays = endDate.difference(startDate).inDays + 1;
    // 总周数
    final totalWeeks = (totalDays / 7).ceil();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 月份标签：每列对应一周，如果该周包含某月第一天则标注月份
    final monthLabels = <int, String>{};
    for (int week = 0; week < totalWeeks; week++) {
      final weekStart = startDate.add(Duration(days: week * 7));
      // 检查这周是否包含某月的1号
      for (int day = 0; day < 7; day++) {
        final d = weekStart.add(Duration(days: day));
        if (d.day == 1) {
          monthLabels[week] = '${d.month}月';
          break;
        }
      }
    }

    // 星期标签
    const weekdayLabels = ['一', '三', '五'];

    final themeColors = context.themeColors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        // 左侧 weekday 标签宽度
        const labelWidth = 16.0;
        final gridWidth = availableWidth - labelWidth;
        final cellSize = gridWidth / totalWeeks;
        final cellHeight = cellSize.clamp(6.0, 14.0);
        final gridHeight = cellHeight * 7;

        return Column(
          children: [
            // 月份标签行
            SizedBox(
              height: 14,
              child: Padding(
                padding: const EdgeInsets.only(left: labelWidth),
                child: Row(
                  children: [
                    for (int week = 0; week < totalWeeks; week++)
                      SizedBox(
                        width: cellSize,
                        child: Text(
                          monthLabels[week] ?? '',
                          style: TextStyle(
                            fontSize: 9,
                            color: themeColors.onSurfaceTertiary,
                          ),
                          overflow: TextOverflow.clip,
                          maxLines: 1,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 2),
            // 热力图主体
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 星期标签
                SizedBox(
                  width: labelWidth,
                  height: gridHeight,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: weekdayLabels
                        .map((label) => Text(
                              label,
                              style: TextStyle(
                                fontSize: 9,
                                color: themeColors.onSurfaceTertiary,
                              ),
                            ))
                        .toList(),
                  ),
                ),
                // 格子网格
                SizedBox(
                  width: gridWidth,
                  height: gridHeight,
                  child: Row(
                    children: [
                      for (int week = 0; week < totalWeeks; week++)
                        Expanded(
                          child: Column(
                            children: [
                              for (int day = 0; day < 7; day++)
                                _buildCell(
                                  startDate.add(Duration(days: week * 7 + day)),
                                  cellHeight,
                                  themeColors,
                                  today,
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildCell(
    DateTime date,
    double cellHeight,
    AppThemeColors themeColors,
    DateTime today,
  ) {
    final isThisYear = date.year == _year;
    final flowLevel = _periodDays[AppDateUtils.dayKey(date)];
    final isPeriodDay = flowLevel != null;
    final isFuture = date.isAfter(today);

    Color? cellColor;
    if (isPeriodDay) {
      // 根据经量等级显示不同颜色（使用独立色相，避免仅透明度差异难以辨认）
      // flowLevel: 0=无（未记录）, 1=少, 2=中, 3=多
      switch (flowLevel) {
        case 0:
          cellColor = AppColors.flowNone;
          break;
        case 1:
          cellColor = AppColors.flowLight;
          break;
        case 2:
          cellColor = AppColors.flowNormal;
          break;
        case 3:
          cellColor = AppColors.flowHeavy;
          break;
        default:
          cellColor = AppColors.flowNone;
      }
    } else if (!isThisYear) {
      cellColor = Colors.transparent;
    } else {
      cellColor = themeColors.surfaceTile.withValues(alpha: isFuture ? 0.3 : 0.5);
    }

    final cellWidget = GestureDetector(
      onTap: isThisYear
          ? () => widget.onDateSelected?.call(date)
          : null,
      child: Container(
        height: cellHeight,
        margin: const EdgeInsets.all(0.5),
        decoration: BoxDecoration(
          color: cellColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );

    return cellWidget;
  }

  Widget _buildLegend(BuildContext context) {
    final themeColors = context.themeColors;
    // 4 个经量等级色块，使用不同色相/明度区分
    final legendColors = [
      AppColors.flowNone,   // 无（未记录）
      AppColors.flowLight,  // 少
      AppColors.flowNormal, // 中
      AppColors.flowHeavy,  // 多
    ];
    final legendLabels = ['无', '少', '中', '多'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (int i = 0; i < legendColors.length; i++) ...[
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: legendColors[i],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 2),
          Text(
            legendLabels[i],
            style: TextStyle(
              fontSize: 9,
              color: themeColors.onSurfaceTertiary,
            ),
          ),
          if (i < legendColors.length - 1)
            const SizedBox(width: 8),
        ],
      ],
    );
  }
}
