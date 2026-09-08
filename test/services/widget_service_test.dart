import 'package:flutter_test/flutter_test.dart';

import 'package:yimaflutter/models/cycle_data.dart';
import 'package:yimaflutter/models/period_record.dart';
import 'package:yimaflutter/services/widget_service.dart';

void main() {
  group('WidgetService.buildWidgetJsonForTest 三态契约', () {
    final service = WidgetService.instance;
    final today = DateTime(2026, 9, 8);

    test('态1 经期进行中：hasOngoing=true 且 periodDay 按起始日递增', () {
      final json = service.buildWidgetJsonForTest(
        records: [
          // 已结束的旧记录在前，进行中的记录在后（顺序不应影响结果）
          PeriodRecord(
            startDate: '2026-08-01',
            endDate: '2026-08-05',
            createdAt: 0,
          ),
          PeriodRecord(startDate: '2026-09-06', createdAt: 0),
        ],
        cycleData: null,
        today: today,
        userCycleLength: 28,
        userPeriodLength: 5,
        todayFlow: 2,
      );

      expect(json['hasOngoing'], isTrue);
      // 9/6 开始，9/8 是第 3 天
      expect(json['periodDay'], 3);
      expect(json['lastStart'], '2026-09-06');
      expect(json['lastEnd'], '');
      // 今日经量透传给小组件
      expect(json['todayFlow'], 2);
    });

    test('态2 上次经期已结束：取最近一条已结束记录而非列表顺序', () {
      final json = service.buildWidgetJsonForTest(
        records: [
          PeriodRecord(
            startDate: '2026-07-01',
            endDate: '2026-07-05',
            createdAt: 0,
          ),
          PeriodRecord(
            startDate: '2026-08-01',
            endDate: '2026-08-05',
            createdAt: 0,
          ),
        ],
        cycleData: null,
        today: today,
        userCycleLength: 28,
        userPeriodLength: 5,
      );

      expect(json['hasOngoing'], isFalse);
      expect(json['periodDay'], 0);
      expect(json['lastStart'], '2026-08-01');
      expect(json['lastEnd'], '2026-08-05');
    });

    test('态3 空数据：占位默认值且无预测', () {
      final json = service.buildWidgetJsonForTest(
        records: const [],
        cycleData: null,
        today: today,
        userCycleLength: 28,
        userPeriodLength: 5,
      );

      expect(json['hasOngoing'], isFalse);
      // -1 表示「无预测」，小组件端据此隐藏倒计时
      expect(json['daysUntil'], -1);
      expect(json['predictedDate'], '');
      expect(json['lastStart'], '');
      expect(json['lastEnd'], '');
      expect(json['averageCycle'], 0);
      expect(json['averagePeriod'], 0);
      expect(json['cycleCount'], 0);
    });

    test('cycleData 提供预测：daysUntil 下限钳制为 0，日期格式为 M月d日', () {
      final json = service.buildWidgetJsonForTest(
        records: const [],
        cycleData: CycleData(
          averageCycleLength: 28.4,
          averagePeriodLength: 5.2,
          totalCycles: 6,
          predictedNextPeriod: DateTime(2026, 9, 3), // 早于 today 5 天
          recentPeriods: const [],
        ),
        today: today,
        userCycleLength: 28,
        userPeriodLength: 5,
      );

      // 预测日已过时钳到 0，不允许负数
      expect(json['daysUntil'], 0);
      expect(json['predictedDate'], '9月3日');
      // 统计信息取整透传
      expect(json['averageCycle'], 28);
      expect(json['averagePeriod'], 5);
      expect(json['cycleCount'], 6);
    });

    test('预测日在未来：daysUntil 为剩余天数', () {
      final json = service.buildWidgetJsonForTest(
        records: const [],
        cycleData: CycleData(
          averageCycleLength: 28,
          averagePeriodLength: 5,
          totalCycles: 3,
          predictedNextPeriod: DateTime(2026, 9, 13),
          recentPeriods: const [],
        ),
        today: today,
        userCycleLength: 28,
        userPeriodLength: 5,
      );

      expect(json['daysUntil'], 5);
    });
  });
}
