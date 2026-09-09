import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../constants/app_theme.dart';
import '../providers/ai_assistant_provider.dart';
import 'trend_chart_shared.dart';

/// 健康评分趋势卡（1.34.0）。
///
/// 展示历次 AI 健康报告的评分折线：顶部最新评分大数字 + 较上次的
/// 变化（升高为绿 / 降低为红），下方渐变填充平滑折线，底部首尾日期。
/// 与 [CycleChart] 同一视觉语言，但无时间筛选与点击交互——
/// 整卡可点击跳转 AI 助手页。
///
/// 历史不足 [minEntries] 条时不渲染（SizedBox.shrink）。
class HealthScoreTrendChart extends StatelessWidget {
  /// 报告评分历史（按时间升序）。
  final List<ReportHistoryEntry> history;

  /// 显示所需的最少数据条数。
  static const int minEntries = 2;

  const HealthScoreTrendChart({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.length < minEntries) return const SizedBox.shrink();

    final scores = history.map((e) => e.score).toList();
    final latest = scores.last;
    final prev = scores[scores.length - 2];
    final diff = latest - prev;

    final avg = (scores.reduce((a, b) => a + b) / scores.length).round();

    // 评分升高是好事 → 绿色；降低 → 红色（与周期趋势图的语义相反，
    // 那里周期变长偏红）。
    final diffColor =
        diff >= 0 ? AppColors.success : AppColors.error;

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
                  Icons.monitor_heart_outlined,
                  size: 20,
                  color: AppColors.brandPrimary,
                ),
                const SizedBox(width: AppDimens.spacingSm),
                Text(
                  AppStrings.aiScoreTrend,
                  style: AppTheme.titleLarge.copyWith(
                    color: context.themeColors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spacingLg),

            // ─── 顶部数值摘要 ───
            Row(
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
                  '分',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.themeColors.onSurfaceSecondary,
                  ),
                ),
                const SizedBox(width: AppDimens.spacingMd),
                Icon(
                  diff >= 0
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 16,
                  color: diffColor,
                ),
                Text(
                  '${diff >= 0 ? '+' : ''}$diff',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: diffColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spacingSm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.themeColors.surfaceTile,
                    borderRadius:
                        BorderRadius.circular(AppDimens.radiusFull),
                  ),
                  child: Text(
                    '平均 $avg 分',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.themeColors.onSurfaceSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spacingLg),

            // ─── 折线图 ───
            SizedBox(
              width: double.infinity,
              height: 120,
              child: CustomPaint(
                painter: _ScoreLinePainter(
                  scores: scores,
                  lineColor: AppColors.brandPrimary,
                  textColor: context.themeColors.onSurfaceTertiary,
                  upColor: AppColors.success,
                  downColor: AppColors.error,
                ),
              ),
            ),

            // ─── 首尾日期 ───
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatChartDate(history.first.generatedAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: context.themeColors.onSurfaceTertiary,
                    ),
                  ),
                  Text(
                    formatChartDate(history.last.generatedAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: context.themeColors.onSurfaceTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 评分折线 Painter：平滑贝塞尔 + 渐变填充 + 首尾/极值标签 + 最新点高亮。
class _ScoreLinePainter extends CustomPainter {
  final List<int> scores;
  final Color lineColor;
  final Color textColor;
  final Color upColor;
  final Color downColor;

  _ScoreLinePainter({
    required this.scores,
    required this.lineColor,
    required this.textColor,
    required this.upColor,
    required this.downColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.length < 2) return;

    final minVal = scores.reduce(math.min);
    final maxVal = scores.reduce(math.max);

    // 纵轴范围：上下各留 15% 余量（与周期趋势图一致的动态范围策略）
    final yRange = (maxVal - minVal).toDouble();
    final yPad = yRange == 0 ? 2.0 : yRange * 0.15;
    final yMin = minVal - yPad;
    final ySpan = maxVal + yPad - yMin;

    const leftPad = 4.0;
    const rightPad = 4.0;
    const topPad = 14.0;
    const bottomPad = 6.0;
    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;

    final n = scores.length;
    final points = <Offset>[];
    for (int i = 0; i < n; i++) {
      final x = leftPad + chartW * i / (n - 1);
      final y = topPad + chartH * (1 - (scores[i] - yMin) / ySpan);
      points.add(Offset(x, y));
    }

    // ─── 填充区域 ───
    final fillPath = Path()
      ..moveTo(points.first.dx, topPad + chartH)
      ..lineTo(points.first.dx, points.first.dy);
    for (int i = 1; i < n; i++) {
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
          lineColor.withValues(alpha: 0.22),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(leftPad, topPad, chartW, chartH));
    canvas.drawPath(fillPath, fillPaint);

    // ─── 折线 ───
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < n; i++) {
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

    // ─── 数据点 ───
    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    final dotBgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    for (int i = 0; i < n; i++) {
      canvas.drawCircle(points[i], 4, dotBgPaint);
      canvas.drawCircle(points[i], 2.5, dotPaint);
    }

    // ─── 极值标签（仅 2 点时首尾即极值，避免标签重叠，跳过首点标签）───
    final minIdx = scores.indexOf(minVal);
    final maxIdx = scores.indexOf(maxVal);
    if (minIdx != 0) {
      _drawCenteredText(canvas, '$minVal',
          Offset(points[minIdx].dx, points[minIdx].dy + 16), downColor, 10,
          bold: true);
    }
    if (maxIdx != 0 && maxIdx != n - 1) {
      _drawCenteredText(canvas, '$maxVal',
          Offset(points[maxIdx].dx, points[maxIdx].dy - 14), upColor, 10,
          bold: true);
    }

    // ─── 最新点高亮：光晕 + 大圆 + 分数标签 ───
    final last = points.last;
    final glowPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(last, 12, glowPaint);
    canvas.drawCircle(last, 6, dotBgPaint);
    canvas.drawCircle(last, 4, dotPaint);
    _drawCenteredText(
      canvas,
      '${scores.last}',
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
          fontFamily: AppTheme.fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
        canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _ScoreLinePainter oldDelegate) {
    return oldDelegate.scores.length != scores.length ||
        oldDelegate.scores.last != scores.last ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.textColor != textColor ||
        oldDelegate.upColor != upColor ||
        oldDelegate.downColor != downColor;
  }
}
