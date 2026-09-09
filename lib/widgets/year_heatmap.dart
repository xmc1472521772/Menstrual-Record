import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';
import '../models/period_record.dart';
import '../utils/date_utils.dart';

/// 年度热力图 — GitHub 风格的日历活动图。
///
/// 横向滚动布局：每列代表一周，每个格子代表一天。
/// 经期日用品牌色填充，颜色深浅表示经量等级：
/// - 无经量记录的经期日：浅灰粉
/// - 有经量记录的经期日：根据等级（0=无, 1=少, 2=中, 3=多）显示不同颜色
/// - 灰色：非经期日
///
/// 月份标签固定在顶部，月份分界处有竖线。
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

  /// 经期日索引：`yyyyMMdd -> flowLevel`。
  late Map<int, int> _periodDays;

  /// 格子尺寸（px）。
  static const double _cellSize = 13.0;
  static const double _cellGap = 2.0;
  static const double _cellStep = _cellSize + _cellGap;

  /// 左侧星期标签宽度。
  static const double _labelWidth = 20.0;

  /// 月份标签高度。
  static const double _monthLabelHeight = 18.0;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
    _rebuildIndex();
  }

  @override
  void didUpdateWidget(covariant YearHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 无条件重建索引：上游每次传入新 List 实例时身份比较恰好工作，
    // 但若复用同一实例（内容已变）会显示陈旧数据。重建成本低，安全优先。
    _rebuildIndex();
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
                _buildYearSelector(),
              ],
            ),
            const SizedBox(height: AppDimens.spacingMd),
            // ─── 统计摘要 ───
            _buildSummary(),
            const SizedBox(height: AppDimens.spacingLg),
            // ─── 热力图 ───
            _buildHeatmap(context),
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
          // P0-5：改用主题语义色（原 inkSecondary 在深色卡上仅 2.80:1）。
          color: context.themeColors.onSurfaceSecondary,
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
          // P0-5：改用主题语义色（原 inkSecondary 在深色卡上仅 2.80:1）。
          color: context.themeColors.onSurfaceSecondary,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    final periodDayCount = _periodDays.length;
    int periodCount = 0;
    for (final r in widget.records) {
      final start = r.startDateTime;
      final end = r.endDateTime ?? DateTime.now();
      if ((start.year == _year) ||
          (end.year == _year) ||
          (start.year < _year && end.year > _year)) {
        periodCount++;
      }
    }
    return Row(
      children: [
        _summaryChip('$periodCount', '次经期'),
        const SizedBox(width: AppDimens.spacingMd),
        _summaryChip('$periodDayCount', '天经期日'),
      ],
    );
  }

  Widget _summaryChip(String value, String label) {
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

  /// ─── 核心构建：横向滚动热力图 ───

  /// 计算该年的起始日期（1月1日所在周的周一）和总周数。
  ({DateTime startDate, int totalWeeks}) _computeYearLayout() {
    final jan1 = DateTime(_year, 1, 1);
    final firstWeekday = jan1.weekday; // 周一=1, 周日=7
    final startDate = jan1.subtract(Duration(days: firstWeekday - 1));

    final dec31 = DateTime(_year, 12, 31);
    final lastWeekday = dec31.weekday;
    final endDate = dec31.add(Duration(days: 7 - lastWeekday));

    final totalDays = endDate.difference(startDate).inDays + 1;
    final totalWeeks = (totalDays / 7).ceil();

    return (startDate: startDate, totalWeeks: totalWeeks);
  }

  /// 计算月份标签：返回每周对应的月份（如果该周包含某月1号则标记）。
  /// 同时返回每月1号所在的 week 索引，用于画月份分隔线。
  ({Map<int, int> weekMonths, List<int> monthStartWeeks}) _computeMonthLabels(
      DateTime startDate, int totalWeeks) {
    final weekMonths = <int, int>{};
    final monthStartWeeks = <int>[];

    for (int week = 0; week < totalWeeks; week++) {
      final weekStart = startDate.add(Duration(days: week * 7));
      for (int day = 0; day < 7; day++) {
        final d = weekStart.add(Duration(days: day));
        if (d.day == 1 && d.year == _year) {
          weekMonths[week] = d.month;
          // 月份分隔线画在标签所在周的左侧
          if (week > 0) monthStartWeeks.add(week);
          break;
        }
      }
    }
    return (weekMonths: weekMonths, monthStartWeeks: monthStartWeeks);
  }

  Widget _buildHeatmap(BuildContext context) {
    final layout = _computeYearLayout();
    final startDate = layout.startDate;
    final totalWeeks = layout.totalWeeks;
    final labelData = _computeMonthLabels(startDate, totalWeeks);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final themeColors = context.themeColors;
    final gridWidth = totalWeeks * _cellStep;
    const gridHeight = 7 * _cellStep;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: _labelWidth + gridWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 月份标签行 ──
            SizedBox(
              height: _monthLabelHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(width: _labelWidth),
                  SizedBox(
                    width: gridWidth,
                    child: Stack(
                      children: [
                        // 月份文字
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _MonthLabelPainter(
                              weekMonths: labelData.weekMonths,
                              monthStartWeeks: labelData.monthStartWeeks,
                              cellStep: _cellStep,
                              textColor: themeColors.onSurfaceTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            // ── 热力图主体 ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左侧星期标签（固定不滚动）
                SizedBox(
                  width: _labelWidth,
                  height: gridHeight,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildWeekdayLabel('一', themeColors.onSurfaceTertiary),
                      const SizedBox(),
                      _buildWeekdayLabel('三', themeColors.onSurfaceTertiary),
                      const SizedBox(),
                      _buildWeekdayLabel('五', themeColors.onSurfaceTertiary),
                      const SizedBox(),
                      _buildWeekdayLabel('日', themeColors.onSurfaceTertiary),
                    ],
                  ),
                ),
                // 格子网格
                SizedBox(
                  width: gridWidth,
                  height: gridHeight,
                  child: Stack(
                    children: [
                      // 月份分隔线
                      CustomPaint(
                        painter: _MonthDividerPainter(
                          monthStartWeeks: labelData.monthStartWeeks,
                          cellStep: _cellStep,
                          gridHeight: gridHeight,
                          dividerColor: themeColors.divider,
                        ),
                        size: Size(gridWidth, gridHeight),
                      ),
                      // 格子
                      Row(
                        children: [
                          for (int week = 0; week < totalWeeks; week++)
                            SizedBox(
                              width: _cellStep,
                              child: Column(
                                children: [
                                  for (int day = 0; day < 7; day++)
                                    _buildCell(
                                      startDate.add(
                                          Duration(days: week * 7 + day)),
                                      themeColors,
                                      today,
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekdayLabel(String label, Color color) {
    return Text(
      label,
      style: TextStyle(
        fontSize: AppTheme.micro.fontSize,
        color: color,
      ),
    );
  }

  Widget _buildCell(
    DateTime date,
    AppThemeColors themeColors,
    DateTime today,
  ) {
    final isThisYear = date.year == _year;
    final flowLevel = _periodDays[AppDateUtils.dayKey(date)];
    final isPeriodDay = flowLevel != null;
    final isFuture = date.isAfter(today);

    Color cellColor;
    if (isPeriodDay) {
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
      // 非本年日期（补齐格子）：完全透明
      cellColor = Colors.transparent;
    } else {
      // 非经期日：灰色底
      cellColor = themeColors.surfaceTile.withValues(alpha: isFuture ? 0.25 : 0.5);
    }

    return GestureDetector(
      onTap: isThisYear && isPeriodDay
          ? () => _showCellInfo(date, flowLevel, themeColors)
          : null,
      child: Tooltip(
        message: isThisYear && isPeriodDay
            ? '${date.month}月${date.day}日 ${_flowLabel(flowLevel)}'
            : (isThisYear ? '${date.month}月${date.day}日' : ''),
        waitDuration: const Duration(milliseconds: 300),
        preferBelow: false,
        child: Container(
          width: _cellSize,
          height: _cellSize,
          margin: const EdgeInsets.all(_cellGap / 2),
          decoration: BoxDecoration(
            color: cellColor,
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
      ),
    );
  }

  /// 经量等级对应的中文标签。
  String _flowLabel(int flowLevel) {
    switch (flowLevel) {
      case 0:
        return '经量未记录';
      case 1:
        return '经量少';
      case 2:
        return '经量中';
      case 3:
        return '经量多';
      default:
        return '经量未记录';
    }
  }

  /// 点击经期日格子时显示日期+经量信息卡片。
  void _showCellInfo(DateTime date, int flowLevel, AppThemeColors themeColors) {
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final weekday = weekdays[date.weekday - 1];
    final flowLabel = _flowLabel(flowLevel);

    // 经量对应颜色
    Color flowColor;
    switch (flowLevel) {
      case 0:
        flowColor = AppColors.flowNone;
        break;
      case 1:
        flowColor = AppColors.flowLight;
        break;
      case 2:
        flowColor = AppColors.flowNormal;
        break;
      case 3:
        flowColor = AppColors.flowHeavy;
        break;
      default:
        flowColor = AppColors.flowNone;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: themeColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 日期标题
              Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: flowColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: AppDimens.spacingSm),
                  Text(
                    '${date.year}年${date.month}月${date.day}日',
                    style: AppTheme.titleMedium.copyWith(
                      color: themeColors.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.spacingXs),
              Text(
                weekday,
                style: AppTheme.bodySmall.copyWith(
                  color: themeColors.onSurfaceTertiary,
                ),
              ),
              const SizedBox(height: AppDimens.spacingMd),
              // 经量信息
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spacingMd,
                  vertical: AppDimens.spacingSm + 2,
                ),
                decoration: BoxDecoration(
                  color: themeColors.surfaceTile,
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: flowColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: AppDimens.spacingSm),
                    Text(
                      flowLabel,
                      style: AppTheme.bodyMedium.copyWith(
                        color: themeColors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.spacingLg),
              // 关闭按钮
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('关闭'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    final themeColors = context.themeColors;
    final legendColors = [
      AppColors.flowNone,
      AppColors.flowLight,
      AppColors.flowNormal,
      AppColors.flowHeavy,
    ];
    final legendLabels = ['无', '少', '中', '多'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '经量：',
          style: TextStyle(
            fontSize: AppTheme.caption.fontSize,
            color: themeColors.onSurfaceTertiary,
          ),
        ),
        for (int i = 0; i < legendColors.length; i++) ...[
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: legendColors[i],
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          const SizedBox(width: 3),
          Text(
            legendLabels[i],
            style: TextStyle(
              fontSize: AppTheme.caption.fontSize,
              color: themeColors.onSurfaceTertiary,
            ),
          ),
          if (i < legendColors.length - 1)
            const SizedBox(width: 10),
        ],
      ],
    );
  }
}

/// 月份标签绘制器：在每月第一周位置绘制 "X月" 文本。
class _MonthLabelPainter extends CustomPainter {
  final Map<int, int> weekMonths;
  final List<int> monthStartWeeks;
  final double cellStep;
  final Color textColor;

  _MonthLabelPainter({
    required this.weekMonths,
    required this.monthStartWeeks,
    required this.cellStep,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );

    weekMonths.forEach((week, month) {
      final x = week * cellStep;
      final label = '$month月';
      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          fontSize: AppTheme.caption.fontSize,
          color: textColor,
          fontFamily: AppTheme.fontFamily,
        ),
      );
      textPainter.layout();
      // 文字左对齐到月份起始位置
      textPainter.paint(canvas, Offset(x, size.height / 2 - textPainter.height / 2));
    });
  }

  @override
  bool shouldRepaint(covariant _MonthLabelPainter oldDelegate) {
    return oldDelegate.weekMonths != weekMonths ||
        oldDelegate.cellStep != cellStep;
  }
}

/// 月份分隔线绘制器：在每月边界处画竖线。
class _MonthDividerPainter extends CustomPainter {
  final List<int> monthStartWeeks;
  final double cellStep;
  final double gridHeight;
  final Color dividerColor;

  _MonthDividerPainter({
    required this.monthStartWeeks,
    required this.cellStep,
    required this.gridHeight,
    required this.dividerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dividerColor.withValues(alpha: 0.3)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (final week in monthStartWeeks) {
      final x = week * cellStep - cellStep / 4;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, gridHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MonthDividerPainter oldDelegate) {
    return oldDelegate.monthStartWeeks != monthStartWeeks;
  }
}
