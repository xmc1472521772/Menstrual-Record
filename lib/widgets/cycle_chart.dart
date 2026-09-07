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
///
/// 点击任意数据点可显示该节点的日期 + 周期天数气泡。
class CycleChart extends StatefulWidget {
  final List<PeriodSummary> periods;

  const CycleChart({super.key, required this.periods});

  @override
  State<CycleChart> createState() => _CycleChartState();
}

enum _TimeRange {
  threeMonths('3月'),
  sixMonths('6月'),
  oneYear('1年'),
  all('全部');

  final String label;
  const _TimeRange(this.label);
}

class _CycleChartState extends State<CycleChart> {
  _TimeRange _selectedRange = _TimeRange.all;

  /// 当前选中的数据点索引（点击切换）。null = 无选中。
  int? _selectedIdx;

  /// 画布边距（必须与 Painter 中保持一致）。
  static const _leftPad = 4.0;
  static const _rightPad = 4.0;
  static const _topPad = 14.0;
  static const _bottomPad = 6.0;

  List<PeriodSummary> get _filteredData {
    final withCycle =
        widget.periods.where((p) => p.cycleLength != null).toList();
    final ascending = withCycle.reversed.toList();

    if (_selectedRange == _TimeRange.all) return ascending;

    final now = DateTime.now();
    // 使用月初作为截断点，避免 now.day 超出目标月天数导致的边界偏移
    // （如 5月31日减3个月 = 2月31日 → 3月3日）。
    final cutoff = switch (_selectedRange) {
      _TimeRange.threeMonths => DateTime(now.year, now.month - 3, 1),
      _TimeRange.sixMonths => DateTime(now.year, now.month - 6, 1),
      _TimeRange.oneYear => DateTime(now.year - 1, now.month, 1),
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
            // ─── 标题行 + 筛选条（水平对齐，节省纵向空间）───
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
                const SizedBox(width: AppDimens.spacingSm),
                _buildRangeChips(),
              ],
            ),
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
          child: Text(
            '平均 $avg 天',
            style: TextStyle(
              fontSize: 12,
              color: context.themeColors.onSurfaceSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ─── 筛选条 ───────────────────────────────────────────────
  Widget _buildRangeChips() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _TimeRange.values.map((range) {
        final selected = range == _selectedRange;
        final isLast = range == _TimeRange.values.last;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedRange = range;
              _selectedIdx = null;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 3,
            ),
            margin: EdgeInsets.only(
              right: isLast ? 0 : 4,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.brandPrimary
                  : context.themeColors.surfaceTile,
              borderRadius: BorderRadius.circular(AppDimens.radiusFull),
              border: selected
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
                color: selected
                    ? AppColors.white
                    : context.themeColors.onSurfaceSecondary,
              ),
            ),
          ),
        );
      }).toList(),
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

  // ─── 折线图区域（带点击交互）──────────────────────────────
  Widget _buildChart(BuildContext context, List<PeriodSummary> data) {
    final values = data.map((p) => p.cycleLength!).toList();
    final minVal = values.reduce(math.min);
    final maxVal = values.reduce(math.max);

    // 气泡背景色：80% 不透明的白色（暗色模式用黑色）
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tooltipBg = (isDark ? Colors.black : Colors.white)
        .withValues(alpha: 0.8);

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final chartWidth = constraints.maxWidth;
            // 预计算数据点的像素坐标（与 Painter 中的逻辑完全一致）
            const chartH = 140.0 - _topPad - _bottomPad;
            final chartW = chartWidth - _leftPad - _rightPad;
            final yRange = (maxVal - minVal).toDouble();
            final yPad = yRange == 0 ? 2.0 : yRange * 0.15;
            final yMin = minVal - yPad;
            final ySpan = maxVal + yPad - yMin;
            final n = data.length;
            final positions = <Offset>[];
            for (int i = 0; i < n; i++) {
              final x = _leftPad + (n == 1 ? chartW / 2 : chartW * i / (n - 1));
              final y = _topPad + chartH * (1 - (values[i] - yMin) / ySpan);
              positions.add(Offset(x, y));
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                _handleTap(details.localPosition, positions, n);
              },
              child: SizedBox(
                width: chartWidth,
                height: 140,
                child: CustomPaint(
                  painter: _FundChartPainter(
                    data: data,
                    lineColor: AppColors.brandPrimary,
                    fillGradient: AppColors.brandPrimary,
                    axisColor: context.themeColors.divider,
                    textColor: context.themeColors.onSurfaceTertiary,
                    avgLineColor:
                        AppColors.brandPrimary.withValues(alpha: 0.25),
                    highlightColor: AppColors.brandPrimary,
                    selectedIdx: _selectedIdx,
                    tooltipBg: tooltipBg,
                    tooltipBorder: AppColors.brandPrimary,
                    tooltipTextColor: context.themeColors.onSurface,
                    tooltipSubColor: context.themeColors.onSurfaceSecondary,
                    pointPositions: positions,
                  ),
                ),
              ),
            );
          },
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

  // ─── 点击命中测试 ──────────────────────────────────────────
  void _handleTap(Offset tapPos, List<Offset> positions, int n) {
    if (positions.isEmpty) return;
    // 找到离点击位置最近的数据点
    int nearest = 0;
    double minDist = double.infinity;
    for (int i = 0; i < positions.length; i++) {
      final d = (positions[i] - tapPos).distance;
      if (d < minDist) {
        minDist = d;
        nearest = i;
      }
    }
    // 命中半径 24px
    if (minDist <= 24) {
      setState(() {
        _selectedIdx = (_selectedIdx == nearest) ? null : nearest;
      });
    } else {
      setState(() => _selectedIdx = null);
    }
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
/// - 选中点显示气泡 tooltip（日期 + 周期天数）
class _FundChartPainter extends CustomPainter {
  final List<PeriodSummary> data;
  final Color lineColor;
  final Color fillGradient;
  final Color axisColor;
  final Color textColor;
  final Color avgLineColor;
  final Color highlightColor;

  /// 当前选中的数据点索引。
  final int? selectedIdx;

  /// 气泡背景色。
  final Color tooltipBg;
  /// 气泡边框色。
  final Color tooltipBorder;
  /// 气泡主文字颜色。
  final Color tooltipTextColor;
  /// 气泡副文字颜色。
  final Color tooltipSubColor;

  /// 预计算的数据点像素坐标（由外部 LayoutBuilder 计算）。
  final List<Offset> pointPositions;
  _FundChartPainter({
    required this.data,
    required this.lineColor,
    required this.fillGradient,
    required this.axisColor,
    required this.textColor,
    required this.avgLineColor,
    required this.highlightColor,
    this.selectedIdx,
    required this.tooltipBg,
    required this.tooltipBorder,
    required this.tooltipTextColor,
    required this.tooltipSubColor,
    required this.pointPositions,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final values = data.map((p) => p.cycleLength!).toList();
    final minVal = values.reduce(math.min);
    final maxVal = values.reduce(math.max);
    final avgVal = values.reduce((a, b) => a + b) / values.length;

    // 纵轴范围：上下各留 15% 余量
    final yRange = (maxVal - minVal).toDouble();
    final yPad = yRange == 0 ? 2.0 : yRange * 0.15;
    final yMin = minVal - yPad;
    final ySpan = maxVal + yPad - yMin;

    // 画布边距
    const leftPad = 4.0;
    const rightPad = 4.0;
    const topPad = 14.0;
    const bottomPad = 6.0;

    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;

    // ─── 计算数据点坐标 ───
    final n = data.length;
    // 直接使用外部预计算的坐标，确保与命中测试一致
    final points = pointPositions.isNotEmpty && pointPositions.length == n
        ? pointPositions
        : _computePoints(n, values, yMin, ySpan, chartW, chartH, leftPad, topPad);

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

    // ─── 选中点的竖直指示线 ───
    if (selectedIdx != null && selectedIdx! < n) {
      final sp = points[selectedIdx!];
      final indicatorPaint = Paint()
        ..color = lineColor.withValues(alpha: 0.2)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(sp.dx, topPad),
        Offset(sp.dx, topPad + chartH),
        indicatorPaint,
      );
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
    final selectedGlowPaint = Paint()
      ..color = highlightColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < n; i++) {
      // 选中的点先画光晕
      if (i == selectedIdx) {
        canvas.drawCircle(points[i], 10, selectedGlowPaint);
      }
      // 普通点：小白底 + 实心圆
      canvas.drawCircle(points[i], 4, whitePaint);
      canvas.drawCircle(points[i], 2.5, dotPaint);
    }

    // 极值点数值标签（如果与选中点重合则跳过，避免与气泡重叠）
    if (minIdx != selectedIdx) {
      _drawCenteredText(
        canvas,
        '$minVal',
        Offset(points[minIdx].dx, points[minIdx].dy + 16),
        AppColors.success,
        10,
        bold: true,
      );
    }
    if (maxIdx != selectedIdx) {
      _drawCenteredText(
        canvas,
        '$maxVal',
        Offset(points[maxIdx].dx, points[maxIdx].dy - 14),
        AppColors.error,
        10,
        bold: true,
      );
    }

    // ─── 最新点高亮：光晕 + 大圆 ───
    final lastIdx = n - 1;
    final last = points.last;
    if (lastIdx != selectedIdx) {
      final glowPaint = Paint()
        ..color = highlightColor.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(last, 12, glowPaint);
      canvas.drawCircle(last, 6, whitePaint);
      canvas.drawCircle(last, 4, dotPaint);

      _drawCenteredText(
        canvas,
        '${values.last}',
        Offset(last.dx, last.dy - 16),
        lineColor,
        11,
        bold: true,
      );
    } else {
      // 选中最新点时也保持高亮大圆
      canvas.drawCircle(last, 6, whitePaint);
      canvas.drawCircle(last, 4, dotPaint);
    }

    // ─── 选中点气泡 tooltip ───
    if (selectedIdx != null && selectedIdx! < n) {
      _drawTooltip(
        canvas,
        size,
        points[selectedIdx!],
        data[selectedIdx!],
        values[selectedIdx!],
      );
    }
  }

  /// 绘制气泡 tooltip：显示日期 + 周期天数。
  void _drawTooltip(
    Canvas canvas,
    Size canvasSize,
    Offset point,
    PeriodSummary period,
    int cycleDays,
  ) {
    final dateStr =
        '${period.startDate.year}.${period.startDate.month.toString().padLeft(2, '0')}.${period.startDate.day.toString().padLeft(2, '0')}';
    final cycleStr = '$cycleDays 天';

    // 测量文字
    final dateTp = TextPainter(
      text: TextSpan(
        text: dateStr,
        style: TextStyle(
          color: tooltipSubColor,
          fontSize: 10,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final cycleTp = TextPainter(
      text: TextSpan(
        text: cycleStr,
        style: TextStyle(
          color: tooltipTextColor,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // 气泡尺寸
    const padH = 10.0;
    const padV = 8.0;
    const gap = 2.0;
    final bubbleW = math.max(dateTp.width, cycleTp.width) + padH * 2;
    final bubbleH = dateTp.height + cycleTp.height + padV * 2 + gap;

    // 气泡位置：优先在数据点上方，空间不够时放下方
    const arrowH = 6.0;
    double bx = point.dx - bubbleW / 2;
    double by = point.dy - bubbleH - arrowH - 8;

    // 水平边界：不超出画布
    bx = bx.clamp(2.0, canvasSize.width - bubbleW - 2);

    // 垂直边界：上方不够则放下方
    final above = by >= 2;
    if (!above) {
      by = point.dy + arrowH + 8;
    }

    // 气泡背景 + 边框
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bx, by, bubbleW, bubbleH),
      const Radius.circular(8),
    );
    final bgPaint = Paint()
      ..color = tooltipBg
      ..style = PaintingStyle.fill;
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    // 阴影
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bx + 1, by + 2, bubbleW, bubbleH),
        const Radius.circular(8),
      ),
      shadowPaint,
    );
    // 背景
    canvas.drawRRect(rrect, bgPaint);
    // 边框
    final borderPaint = Paint()
      ..color = tooltipBorder
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(rrect, borderPaint);

    // 小三角箭头
    final arrowPaint = Paint()
      ..color = tooltipBg
      ..style = PaintingStyle.fill;
    final borderArrowPaint = Paint()
      ..color = tooltipBorder
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // 箭头 x 对齐数据点 x（但限制在气泡范围内）
    final arrowX = point.dx.clamp(bx + 8, bx + bubbleW - 8);
    if (above) {
      // 向下三角
      final triPath = Path()
        ..moveTo(arrowX - 4, by + bubbleH)
        ..lineTo(arrowX + 4, by + bubbleH)
        ..lineTo(arrowX, by + bubbleH + arrowH)
        ..close();
      canvas.drawPath(triPath, arrowPaint);
      canvas.drawPath(triPath, borderArrowPaint);
    } else {
      // 向上三角
      final triPath = Path()
        ..moveTo(arrowX - 4, by)
        ..lineTo(arrowX + 4, by)
        ..lineTo(arrowX, by - arrowH)
        ..close();
      canvas.drawPath(triPath, arrowPaint);
      canvas.drawPath(triPath, borderArrowPaint);
    }

    // 文字
    final textCenter = bx + bubbleW / 2;
    final dateY = above ? by + padV : by + padV;
    final cycleY = dateY + dateTp.height + gap;

    dateTp.paint(canvas, Offset(textCenter - dateTp.width / 2, dateY));
    cycleTp.paint(canvas, Offset(textCenter - cycleTp.width / 2, cycleY));
  }

  List<Offset> _computePoints(
    int n,
    List<int> values,
    double yMin,
    double ySpan,
    double chartW,
    double chartH,
    double leftPad,
    double topPad,
  ) {
    final points = <Offset>[];
    for (int i = 0; i < n; i++) {
      final x = leftPad + (n == 1 ? chartW / 2 : chartW * i / (n - 1));
      final y = topPad + chartH * (1 - (values[i] - yMin) / ySpan);
      points.add(Offset(x, y));
    }
    return points;
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
    // 所有颜色和状态属性都参与比较，确保主题切换（暗色模式）时重绘。
    return oldDelegate.data.length != data.length ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillGradient != fillGradient ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.textColor != textColor ||
        oldDelegate.avgLineColor != avgLineColor ||
        oldDelegate.highlightColor != highlightColor ||
        oldDelegate.selectedIdx != selectedIdx ||
        oldDelegate.tooltipBg != tooltipBg ||
        oldDelegate.tooltipBorder != tooltipBorder ||
        oldDelegate.tooltipTextColor != tooltipTextColor ||
        oldDelegate.tooltipSubColor != tooltipSubColor ||
        oldDelegate.pointPositions != pointPositions;
  }
}
