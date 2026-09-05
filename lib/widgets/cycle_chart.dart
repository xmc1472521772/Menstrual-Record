import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';
import '../models/cycle_data.dart';

/// 周期折线图：用 [CustomPaint] 手绘，无需第三方依赖。
///
/// 展示每条记录的周期天数（本次经期起始日到上次经期起始日的天数），
/// 让用户直观看到周期的波动趋势。
///
/// 支持时间范围筛选（近三个月 / 六个月 / 一年 / 全部）。
/// 图表始终填满可用宽度，通过智能标签间隔避免文字堆叠，
/// 保证用户一览全局起伏变化。
class CycleChart extends StatefulWidget {
  final List<PeriodSummary> periods;

  const CycleChart({super.key, required this.periods});

  @override
  State<CycleChart> createState() => _CycleChartState();
}

/// 时间范围枚举。
enum _TimeRange {
  threeMonths('近三月'),
  sixMonths('近六月'),
  oneYear('近一年'),
  all('全部');

  final String label;
  const _TimeRange(this.label);
}

class _CycleChartState extends State<CycleChart> {
  _TimeRange _selectedRange = _TimeRange.all;

  List<PeriodSummary> get _filteredData {
    // 只取有 cycleLength 的记录（第一条记录没有上一个周期可比较）
    final withCycle = widget.periods.where((p) => p.cycleLength != null).toList();

    // recentPeriods 是倒序的（最近在前），reversed 后正序（最早在前）
    final ascending = withCycle.reversed.toList();

    if (_selectedRange == _TimeRange.all) {
      return ascending;
    }

    final now = DateTime.now();
    final cutoff = switch (_selectedRange) {
      _TimeRange.threeMonths => DateTime(now.year, now.month - 3, now.day),
      _TimeRange.sixMonths => DateTime(now.year, now.month - 6, now.day),
      _TimeRange.oneYear => DateTime(now.year - 1, now.month, now.day),
      _TimeRange.all => DateTime(2000),
    };

    // 按经期开始日期筛选：只保留 cutoff 之后的记录。
    // PredictionService 在构建 recentPeriods 时已计算好 cycleLength，
    // 直接按 startDate 过滤即可。
    final filtered = <PeriodSummary>[];
    for (final p in ascending) {
      if (!p.startDate.isBefore(cutoff)) {
        filtered.add(p);
      }
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final data = _filteredData;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                const Icon(
                  Icons.show_chart,
                  size: 20,
                  color: AppColors.brandPrimary,
                ),
                const SizedBox(width: AppDimens.spacingSm),
                Text(
                  '周期趋势',
                  style: AppTheme.titleLarge.copyWith(
                    color: context.themeColors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spacingSm),
            Text(
              '各次经期周期天数变化',
              style: AppTheme.bodySmall.copyWith(
                color: context.themeColors.onSurfaceTertiary,
              ),
            ),
            // 时间范围筛选
            const SizedBox(height: AppDimens.spacingMd),
            _buildRangeChips(),
            const SizedBox(height: AppDimens.spacingLg),
            if (data.isEmpty)
              _buildEmptyChart(context)
            else ...[
              _buildChartArea(context, data),
              const SizedBox(height: AppDimens.spacingSm),
              _buildLegend(context, data),
            ],
          ],
        ),
      ),
    );
  }

  // ─── 时间范围筛选条 ─────────────────────────────────────────
  Widget _buildRangeChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _TimeRange.values.map((range) {
          final selected = range == _selectedRange;
          return Padding(
            padding: EdgeInsets.only(
              right: range == _TimeRange.values.last
                  ? 0
                  : AppDimens.spacingSm,
            ),
            child: FilterChip(
              label: Text(range.label),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _selectedRange = range;
                });
              },
              selectedColor: AppColors.brandPrimary,
              backgroundColor: context.themeColors.surfaceTile,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected
                    ? AppColors.white
                    : context.themeColors.onSurfaceSecondary,
              ),
              side: BorderSide(
                color: selected
                    ? AppColors.brandPrimary
                    : context.themeColors.divider,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusFull),
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spacingXs,
                vertical: 2,
              ),
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── 空数据状态 ─────────────────────────────────────────────
  Widget _buildEmptyChart(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 120,
      child: Center(
        child: Text(
          '当前时间范围内暂无周期数据',
          style: AppTheme.bodySmall.copyWith(
            color: context.themeColors.onSurfaceTertiary,
          ),
        ),
      ),
    );
  }

  // ─── 图表区域 ──────────────────────────────────────────────
  /// 图表始终填满可用宽度，不使用水平滚动。
  /// 数据点多时通过 [_CycleLineChartPainter] 内部的智能标签间隔
  /// 自动跳过部分标签，避免文字堆叠，同时保证全局一览。
  Widget _buildChartArea(BuildContext context, List<PeriodSummary> data) {
    return SizedBox(
      width: double.infinity,
      height: 180,
      child: CustomPaint(
        painter: _CycleLineChartPainter(
          data: data,
          lineColor: AppColors.brandPrimary,
          dotColor: AppColors.brandPrimary,
          fillGradient: AppColors.brandPrimary,
          axisColor: context.themeColors.divider,
          textColor: context.themeColors.onSurfaceTertiary,
          avgLineColor: AppColors.brandPrimary.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  // ─── 图例 ─────────────────────────────────────────────────
  Widget _buildLegend(BuildContext context, List<PeriodSummary> data) {
    final values = data.map((p) => p.cycleLength!).toList();
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final avg = (values.reduce((a, b) => a + b) / values.length).round();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _legendItem(context, '最短', '$minVal 天', AppColors.brandPrimary),
        _legendItem(context, '最长', '$maxVal 天', AppColors.brandLight),
        _legendItem(context, '平均', '$avg 天', AppColors.success),
      ],
    );
  }

  Widget _legendItem(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label $value',
          style: AppTheme.bodySmall.copyWith(
            color: context.themeColors.onSurfaceSecondary,
          ),
        ),
      ],
    );
  }
}

class _CycleLineChartPainter extends CustomPainter {
  final List<PeriodSummary> data;
  final Color lineColor;
  final Color dotColor;
  final Color fillGradient;
  final Color axisColor;
  final Color textColor;
  final Color avgLineColor;

  _CycleLineChartPainter({
    required this.data,
    required this.lineColor,
    required this.dotColor,
    required this.fillGradient,
    required this.axisColor,
    required this.textColor,
    required this.avgLineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final values = data.map((p) => p.cycleLength!).toList();
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final avgVal = values.reduce((a, b) => a + b) / values.length;

    // 纵轴范围：在 min/max 基础上留出余量，避免折线贴边
    final yMin = (minVal - 2).clamp(15, minVal.toDouble()).toDouble();
    final yMax = (maxVal + 2).clamp(maxVal.toDouble(), 60.0).toDouble();
    final yRange = yMax - yMin;

    // 画布边距：左侧固定 36px 给 Y 轴标签，右侧 12px 留白
    const leftPad = 36.0;
    const rightPad = 12.0;
    const topPad = 16.0;
    const bottomPad = 28.0;

    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;

    // ─── 横向网格线（3 条）───
    final gridPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= 3; i++) {
      final y = topPad + chartH * (i / 3);
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(size.width - rightPad, y),
        gridPaint,
      );

      // Y 轴标签：右对齐到 leftPad - 4 的位置
      final val = (yMax - yRange * (i / 3)).round();
      final yLabel = '$val';
      final tp = TextPainter(
        text: TextSpan(
          text: yLabel,
          style: TextStyle(
            color: textColor,
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 4, y - tp.height / 2));
    }

    // ─── Y 轴线 ───
    final axisPaint = Paint()
        ..color = axisColor
        ..strokeWidth = 1;
    canvas.drawLine(
      const Offset(leftPad, topPad),
      Offset(leftPad, topPad + chartH),
      axisPaint,
    );

    // ─── 平均值虚线 ───
    final avgY = topPad + chartH * (1 - (avgVal - yMin) / yRange);
    final dashPaint = Paint()
      ..color = avgLineColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const dashWidth = 4.0;
    const dashGap = 3.0;
    double startX = leftPad;
    while (startX < size.width - rightPad) {
      final endX = startX + dashWidth;
      canvas.drawLine(
        Offset(startX, avgY),
        Offset(endX.clamp(leftPad, size.width - rightPad), avgY),
        dashPaint,
      );
      startX += dashWidth + dashGap;
    }

    // ─── 计算所有数据点坐标 ───
    final points = <Offset>[];
    final n = data.length;
    for (int i = 0; i < n; i++) {
      final x = leftPad + (n == 1 ? chartW / 2 : chartW * i / (n - 1));
      final y = topPad + chartH * (1 - (values[i] - yMin) / yRange);
      points.add(Offset(x, y));
    }

    // ─── 填充区域 ───
    if (points.length >= 2) {
      final fillPath = Path()
        ..moveTo(points.first.dx, topPad + chartH)
        ..lineTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        final prev = points[i - 1];
        final curr = points[i];
        final midX = (prev.dx + curr.dx) / 2;
        fillPath.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
      }
      fillPath.lineTo(points.last.dx, topPad + chartH);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            fillGradient.withValues(alpha: 0.25),
            fillGradient.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(
          leftPad,
          topPad,
          chartW,
          chartH,
        ));
      canvas.drawPath(fillPath, fillPaint);
    }

    // ─── 折线 ───
    if (points.length >= 2) {
      final linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        final prev = points[i - 1];
        final curr = points[i];
        final midX = (prev.dx + curr.dx) / 2;
        linePath.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
      }
      final linePaint = Paint()
        ..color = lineColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(linePath, linePaint);
    }

    // ─── 数据点 + 数值标签 ───
    // 智能间隔：数据点多时只显示首、尾、极值和等间隔标签，避免堆叠。
    final valueLabelStep = _computeLabelStep(n, chartW, 28.0);
    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;
    final dotBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // 首尾和极值索引
    final minIdx = values.indexOf(minVal);
    final maxIdx = values.indexOf(maxVal);
    final importantIdxs = <int>{0, n - 1, minIdx, maxIdx};

    for (int i = 0; i < points.length; i++) {
      // 白底圆
      canvas.drawCircle(points[i], 5, dotBorderPaint);
      // 实心圆
      canvas.drawCircle(points[i], 3.5, dotPaint);

      // 数值标签：等间隔 + 首尾极值
      if (i % valueLabelStep == 0 || importantIdxs.contains(i)) {
        _drawCenteredText(
          canvas,
          '${values[i]}',
          Offset(points[i].dx, points[i].dy - 14),
          lineColor,
          10,
          bold: true,
        );
      }
    }

    // ─── X 轴标签（日期）──智能间隔 + 居中对齐 ───
    final dateLabelStep = _computeLabelStep(n, chartW, 40.0);
    for (int i = 0; i < n; i++) {
      if (i % dateLabelStep == 0 || i == n - 1) {
        final x = leftPad + (n == 1 ? chartW / 2 : chartW * i / (n - 1));
        final label = _formatDate(data[i].startDate);
        _drawCenteredText(
          canvas,
          label,
          Offset(x, topPad + chartH + 12),
          textColor,
          9,
        );
      }
    }
  }

  /// 计算标签显示间隔。
  ///
  /// 每个标签需要 [minSpacing] 像素的最小水平间距才不重叠。
  /// 当数据点间距小于此值时，跳过部分标签。
  /// 最小 step 为 1（每个都显示），数据多时自动增大。
  int _computeLabelStep(int n, double chartW, double minSpacing) {
    if (n <= 1) return 1;
    final pointSpacing = chartW / (n - 1);
    if (pointSpacing >= minSpacing) return 1;
    final step = (minSpacing / pointSpacing).ceil();
    return step.clamp(1, n);
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }

  /// 以 [center] 为中心绘制文字（水平 + 垂直居中）。
  void _drawCenteredText(
    Canvas canvas,
    String text,
    Offset center,
    Color color,
    double fontSize, {
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _CycleLineChartPainter oldDelegate) {
    return oldDelegate.data.length != data.length ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.axisColor != axisColor;
  }
}
