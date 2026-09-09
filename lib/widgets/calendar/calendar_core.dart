import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_theme.dart';

/// 双日历共享核心（D1 抽核）。
///
/// 项目内存在两套日历 UI：首页单选日历（PageView + 固定 6 行网格）与
/// 多选补录日历（滚动月份列表 + 区间多选）。此前月份数学（周首偏移、
/// 月天数、行数）与星期标题行在两处各写一遍，视觉规则改动需双处同步。
/// 本文件抽出两页**完全等价**的共享部分：
/// - [leadingBlankDays] / [daysInMonth] / [monthRowCount]：月份几何计算；
/// - [buildMonthCells]：固定 6 行（42 格）的月份格子序列（首页用）；
/// - [CalendarWeekdayHeader]：周一开头的星期标题行（样式可参数化，
///   两页各自传入原有样式参数，视觉零变化）。
///
/// 选择策略（单选/区间多选）与格子渲染仍由各页面持有——两者交互语义
/// 差异过大，强行统一反而引入耦合；待未来出现第三处日历场景再评估
/// 渲染协议下沉。

/// [month] 当月 1 号前需要填充的空格数（周一开头，周一=0 … 周日=6）。
int leadingBlankDays(DateTime month) {
  final firstDay = DateTime(month.year, month.month, 1);
  return firstDay.weekday - 1;
}

/// [month] 当月的天数。
int daysInMonth(DateTime month) {
  return DateTime(month.year, month.month + 1, 0).day;
}

/// [month] 在周一开头的网格中占用的行数（4~6 行）。
int monthRowCount(DateTime month) {
  final totalCells = leadingBlankDays(month) + daysInMonth(month);
  return (totalCells + 6) ~/ 7;
}

/// 生成固定 6 行（42 格）的月份格子序列（首页日历布局）。
///
/// 顺序为行优先（row-major）：index = row * 7 + col。非本月位置用
/// 上月末尾 / 下月开头的真实日期填充（首页将其置灰渲染）。
/// 固定 6 行可消除月份间日历高度差异，避免与下方内容间隙忽大忽小。
List<DateTime> buildMonthCells(DateTime month) {
  final leading = leadingBlankDays(month);
  // DateTime 的日字段溢出/下溢自动规范化到相邻月份
  return List<DateTime>.generate(
    42,
    (i) => DateTime(month.year, month.month, i - leading + 1),
  );
}

/// 星期标题行（周一 → 周日）。
///
/// 样式参数化：首页用 bodySmall(12px)，多选日历用 14px + 卡片底色，
/// 视觉与各自旧实现完全一致；结构（Expanded+Center+Text×7）单点维护。
class CalendarWeekdayHeader extends StatelessWidget {
  /// 每个标签的样式；为 null 时使用 [AppTheme.bodySmall]。
  final TextStyle? textStyle;

  /// 行内边距。首页为水平 spacingMd；多选日历另加垂直 spacingSm。
  final EdgeInsetsGeometry padding;

  /// 行背景色；null 表示透明（首页）。
  final Color? backgroundColor;

  const CalendarWeekdayHeader({
    super.key,
    this.textStyle,
    this.padding = const EdgeInsets.symmetric(horizontal: AppDimens.spacingMd),
    this.backgroundColor,
  });

  static const List<String> labels = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final style = textStyle ??
        AppTheme.bodySmall.copyWith(
          color: context.themeColors.onSurfaceTertiary,
        );
    return Container(
      padding: padding,
      color: backgroundColor,
      child: Row(
        children: [
          for (final label in labels)
            Expanded(
              child: Center(child: Text(label, style: style)),
            ),
        ],
      ),
    );
  }
}
