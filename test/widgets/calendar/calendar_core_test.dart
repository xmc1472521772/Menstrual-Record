import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:yimaflutter/constants/app_colors.dart';
import 'package:yimaflutter/constants/app_theme.dart';
import 'package:yimaflutter/widgets/calendar/calendar_core.dart';

void main() {
  group('calendar_core：月份几何计算（D1 共享核心）', () {
    test('daysInMonth：平年/闰年/30天月', () {
      expect(daysInMonth(DateTime(2026, 2, 1)), 28); // 平年
      expect(daysInMonth(DateTime(2024, 2, 1)), 29); // 闰年
      expect(daysInMonth(DateTime(2026, 9, 1)), 30);
      expect(daysInMonth(DateTime(2026, 8, 1)), 31);
    });

    test('leadingBlankDays：周一开头（周一=0），与旧首页/多选日历数学一致', () {
      // 2021-02-01 是周一 → 无前置空格
      expect(leadingBlankDays(DateTime(2021, 2, 1)), 0);
      // 2026-09-01 是周二 → 1 个前置空格
      expect(leadingBlankDays(DateTime(2026, 9, 1)), 1);
      // 2026-02-01 是周日 → 6 个前置空格
      expect(leadingBlankDays(DateTime(2026, 2, 1)), 6);
    });

    test('monthRowCount：4/5/6 行三种形态', () {
      // 2021-02：周一开头 + 28 天 → 恰好 4 行
      expect(monthRowCount(DateTime(2021, 2, 1)), 4);
      // 2026-02：周日开头 + 28 天 → 5 行
      expect(monthRowCount(DateTime(2026, 2, 1)), 5);
      // 2026-08：周六开头 + 31 天 → 6 行
      expect(monthRowCount(DateTime(2026, 8, 1)), 6);
    });

    group('buildMonthCells：固定 6 行 42 格（首页日历布局）', () {
      // 2026-09：周二开头（前置 1 格）、30 天
      final cells = buildMonthCells(DateTime(2026, 9, 1));

      test('长度恒为 42（6 行 × 7 列）', () {
        expect(cells.length, 42);
      });

      test('首格为上月末尾日期', () {
        expect(cells[0].year, 2026);
        expect(cells[0].month, 8);
        expect(cells[0].day, 31);
      });

      test('前置偏移后紧跟当月 1 号', () {
        expect(cells[1].month, 9);
        expect(cells[1].day, 1);
      });

      test('当月最后一天位置正确', () {
        expect(cells[30].month, 9);
        expect(cells[30].day, 30);
      });

      test('尾段为下月开头日期', () {
        expect(cells[31].month, 10);
        expect(cells[31].day, 1);
        expect(cells[41].month, 10);
        expect(cells[41].day, 11);
      });

      test('当月格子数等于月天数', () {
        final inMonth = cells
            .where((d) => d.year == 2026 && d.month == 9)
            .length;
        expect(inMonth, 30);
      });
    });
  });

  group('calendar_core：日历格子五态渲染断言（E3）', () {
    // 格子五态 = 经期 / 预测 / 排卵 / 易孕 / 安全（+普通），
    // 颜色解析入口是 AppColors.dayTypeColor（日详情弹窗与图例共用）。
    test('dayTypeColor 五态 + 未知态映射正确', () {
      expect(AppColors.dayTypeColor('period'), AppColors.periodDay);
      expect(AppColors.dayTypeColor('predicted'), AppColors.predictedDay);
      expect(AppColors.dayTypeColor('ovulation'), AppColors.ovulationDay);
      expect(AppColors.dayTypeColor('fertile'), AppColors.fertileBg);
      expect(AppColors.dayTypeColor('safe'), AppColors.safeDay);
      // 未知类型回退透明（普通日不额外着色）
      expect(AppColors.dayTypeColor('normal'), AppColors.transparent);
    });
  });

  group('CalendarWeekdayHeader 组件', () {
    testWidgets('渲染周一至周日 7 个标签', (tester) async {
      // 默认样式依赖 AppThemeColors 扩展 → 需挂 AppTheme 主题
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: CalendarWeekdayHeader()),
        ),
      );
      for (final label in CalendarWeekdayHeader.labels) {
        expect(find.text(label), findsOneWidget);
      }
      expect(CalendarWeekdayHeader.labels.length, 7);
      expect(CalendarWeekdayHeader.labels.first, '一');
      expect(CalendarWeekdayHeader.labels.last, '日');
    });
  });
}
