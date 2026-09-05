import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';
import '../models/cycle_data.dart';

/// 周期趋势图（基金风格）。
///
/// 顶部展示最新周期天数的大数字 + 较上次的涨跌（绿色↑ / 红色↓），
/// 下方是渐变填充的平滑折线，数据点末端高亮最新值，
/// 底部 X 轴只标首尾两个日期，极简不堆叠。
class CycleChart extends StatefulWidget {
  final List<PeriodSummary> periods;

  const CycleChart({super.key, required this.periods});

  @override
  State<CycleChart> createState() => _CycleChartState();
}

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
    final withCycle =
        widget.periods.where((p) => p.cycleLength != null).toList();
    final ascending = withCycle.reversed.toList();

    if (_selectedRange == _TimeRange.all) return ascending;

    final now = DateTime.now();
    final cutoff = switch (_selectedRange) {
      _TimeRange.threeMonths => DateTime(now.year, now.month - 3, now.day),
      _TimeRange.sixMonths => DateTime(now.year, now.month - 6, now.day),
      _TimeRange.oneYear => DateTime(now.year - 1, now.month, now.day),
      _TimeRange.all => DateTime(2000),
    };

    return ascending.where((p) => !p.startDate.isBefore(cutoff)).toList();
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
            // ─── 标题行 ───
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
            const SizedBox(height: AppDimens.spacingMd),

            // ─── 筛选条 ───
            _buildRangeChips(),
            const SizedBox(height: AppDimens.spacingLg),

            if (data.isEmpty)
              _buildEmptyChart(context)
            else ...[
              // ─── 顶部数值摘要 ───
              _buildHeader(context, data),
              const SizedBox(height: AppDimens.spacingLg),
              // ─── 折线图 ───
              _buildChart(context, data),
              const SizedBox(height: AppDimens.spacingSm),
              // ─── 图例 ───
              _buildLegend(context, data),
            ],
          ],
        ),
      ),
    );
  }

  // ─── 顶部数值摘要（基金风格）──────────────────────────────
  Widget _buildHeader(BuildContext context, List<PeriodSummary> data) {
    final values = data.map((p) => p.cycleLength!).toList();
    final latest = values.last;
    final avg = (values.reduce((a, b) => a + b) / values.length).round();

    // 计算较上次的涨跌
    int? diff;
    bool isUp = false;
    if (values.length >= 2) {
      final prev = values[values.length - 2];
      diff = latest - prev;
      isUp = diff >= 0;
    }

    // 涨跌颜色：基金风格中红涨绿跌，但此项目用红=品牌色系，
    // 这里以"偏离平均值"来着色：高于平均偏暖色，低于平均偏绿色
    final diffColor = diff == null
        ? context.themeColors.onSurfaceTertiary
        : isUp
            ? AppColors.error
            : AppColors.success;
    final diffIcon = diff == null
        ? null
        : isUp
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        // 最新周期值
        Text(
          '$latest',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: context.themeColors.onSurface,
            height: 1.0,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '天',
          style: TextStyle(
            fontSize: 14,
            color: context.themeColors.onSurfaceSecondary,
          ),
        ),
        const SizedBox(width: AppDimens.spacingMd),
        // 涨跌
        if (diff != null) ...[
          Icon(diffIcon, size: 16, color: diffColor),
          const SizedBox(width: 2),
          Text(
            '${diff >= 0 ? '+' : ''}$diff',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: diffColor,
            ),
          ),
        ],
        const Spacer(),
        // 平均值小标签
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spacingSm,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: context.themeColors.surfaceTile,
            borderRadius: BorderRadius.circular(AppDimens.radiusFull),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '平均 $avg 天',
                style: TextStyle(
                  fontSize: 12,
                  color: context.themeColors.onSurfaceSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── 筛选条 ───────────────────────────────────────────────
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
              onSelected: (_) =>
                  setState(() => _selectedRange = range),
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

  // ─── 空状态 ───────────────────────────────────────────────
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

  // ─── 折线图区域 ────────────────────────────────────────────
  Widget _buildChart(BuildContext context, List<PeriodSummary> data) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 140,
          child: CustomPaint(
            painter: _FundChartPainter(
              data: data,
              lineColor: AppColors.brandPrimary,
              fillGradient: AppColors.brandPrimary,
              axisColor: context.themeColors.divider,
              textColor: context.themeColors.onSurfaceTertiary,
              avgLineColor: AppColors.brandPrimary.withValues(alpha: 0.25),
              highlightColor: AppColors.brandPrimary,
            ),
          ),
        ),
        // 首尾日期
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(data.first.startDate),
                style: TextStyle(
                  fontSize: 11,
                  color: context.themeColors.onSurfaceTertiary,
                ),
              ),
              Text(
                _formatDate(data.last.startDate),
                style: TextStyle(
                  fontSize: 11,
                  color: context.themeColors.onSurfaceTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }

  // ─── 图例 ─────────────────────────────────────────────────
  Widget _buildLegend(BuildContext context, List<PeriodSummary> data) {
    final values = data.map((p) => p.cycleLength!).toList();
    final minVal = values.reduce(math.min);
    final maxVal = values.reduce(math.max);
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

/// 基金风格的折线图 Painter。
///
/// 特点：
/// - 无 Y 轴竖线、无网格线（极简）
/// - 折线平滑（贝塞尔），底部渐变填充
/// - 仅在折线上方为极值点标数值
/// - 最新点用大圆 + 光晕高亮
class _FundChartPainter extends CustomPainter {
  final List<PeriodSummary> data;
  final Color lineColor;
  final Color fillGradient;
  final Color axisColor;
  final Color textColor;
  final Color avgLineColor;
  final Color highlightColor;

  _FundChartPainter({
    required this.data,
    required this.lineColor,
    required this.fillGradient,
    required this.axisColor,
    required this.textColor,
    required this.avgLineColor,
    required this.highlightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final values = data.map((p) => p.cycleLength!).toList();
    final minVal = values.reduce(math.min);
    final maxVal = values.reduce(math.max);
    final avgVal = values.reduce((a, b) => a + b) / values.length;

    // 纵轴范围：上下各留 12% 余量
    final yRange = (maxVal - minVal).toDouble();
    final yPad = yRange == 0 ? 2.0 : yRange * 0.15;
    final yMin = minVal - yPad;
    final yMax = maxVal + yPad;
    final ySpan = yMax - yMin;

    // 画布边距：无 Y 轴标签，左右只留极小边距
    const leftPad = 4.0;
    const rightPad = 4.0;
    const topPad = 14.0;
    const bottomPad = 6.0;

    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;

    // ─── 计算数据点坐标 ───
    final n = data.length;
    final points = <Offset>[];
    for (int i = 0; i < n; i++) {
      final x = leftPad + (n == 1 ? chartW / 2 : chartW * i / (n - 1));
      final y = topPad + chartH * (1 - (values[i] - yMin) / ySpan);
      points.add(Offset(x, y));
    }

    // ─── 平均线（虚线）───
    final avgY = topPad + chartH * (1 - (avgVal - yMin) / ySpan);
    final dashPaint = Paint()
      ..color = avgLineColor
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    const dashW = 3.0;
    const dashGap = 3.0;
    double dx = leftPad;
    while (dx < size.width - rightPad) {
      canvas.drawLine(
        Offset(dx, avgY),
        Offset((dx + dashW).clamp(leftPad, size.width - rightPad), avgY),
        dashPaint,
      );
      dx += dashW + dashGap;
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
            fillGradient.withValues(alpha: 0.22),
            fillGradient.withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromLTWH(leftPad, topPad, chartW, chartH),
        );
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
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(linePath, linePaint);
    }

    // ─── 数据点 ───
    final minIdx = values.indexOf(minVal);
    final maxIdx = values.indexOf(maxVal);
    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (int i = 0; i < n; i++) {
      // 普通点：小白底 + 实心圆
      canvas.drawCircle(points[i], 4, whitePaint);
      canvas.drawCircle(points[i], 2.5, dotPaint);
    }

    // 极值点数值标签
    _drawCenteredText(
      canvas,
      '$minVal',
      Offset(points[minIdx].dx, points[minIdx].dy + 16),
      AppColors.success,
      10,
      bold: true,
    );
    _drawCenteredText(
      canvas,
      '$maxVal',
      Offset(points[maxIdx].dx, points[maxIdx].dy - 14),
      AppColors.error,
      10,
      bold: true,
    );

    // ─── 最新点高亮：光晕 + 大圆 ───
    final last = points.last;
    final glowPaint = Paint()
      ..color = highlightColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(last, 12, glowPaint);
    canvas.drawCircle(last, 6, whitePaint);
    canvas.drawCircle(last, 4, dotPaint);

    // 最新值数值标签
    _drawCenteredText(
      canvas,
      '${values.last}',
      Offset(last.dx, last.dy - 16),
      lineColor,
      11,
      bold: true,
    );
  }

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
  bool shouldRepaint(covariant _FundChartPainter oldDelegate) {
    return oldDelegate.data.length != data.length ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.axisColor != axisColor;
  }
}
