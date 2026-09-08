import 'package:flutter_test/flutter_test.dart';

import 'package:yimaflutter/constants/app_strings.dart';
import 'package:yimaflutter/models/period_record.dart';
import 'package:yimaflutter/utils/period_validation.dart';

/// [validateNewPeriodRange] / [periodLengthWarning] 的纯函数单测。
/// 覆盖记录页「添加经期记录」的日期校验规则：
/// 不允许未来日期、不允许与已有记录（含进行中的）重叠、异常长度提示。
void main() {
  // 固定「今天」，避免用例依赖真实时钟
  final today = DateTime(2026, 9, 8);

  PeriodRecord record(String start, [String? end]) =>
      PeriodRecord(startDate: start, endDate: end);

  group('validateNewPeriodRange - 基本规则', () {
    test('合法区间且无已有记录时通过', () {
      final error = validateNewPeriodRange(
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 9, 5),
        today: today,
        records: const [],
      );
      expect(error, isNull);
    });

    test('结束日期早于开始日期被拦截', () {
      final error = validateNewPeriodRange(
        start: DateTime(2026, 9, 5),
        end: DateTime(2026, 9, 3),
        today: today,
        records: const [],
      );
      expect(error, AppStrings.endDateCannotBeBeforeStart);
    });

    test('开始日期晚于今天被拦截', () {
      final error = validateNewPeriodRange(
        start: DateTime(2026, 9, 9),
        end: DateTime(2026, 9, 10),
        today: today,
        records: const [],
      );
      expect(error, AppStrings.dateCannotBeFuture);
    });

    test('结束日期晚于今天被拦截', () {
      final error = validateNewPeriodRange(
        start: DateTime(2026, 9, 5),
        end: DateTime(2026, 9, 9),
        today: today,
        records: const [],
      );
      expect(error, AppStrings.dateCannotBeFuture);
    });

    test('开始与结束都等于今天时允许', () {
      final error = validateNewPeriodRange(
        start: today,
        end: today,
        today: today,
        records: const [],
      );
      expect(error, isNull);
    });
  });

  group('validateNewPeriodRange - 与已完成记录的重叠判定', () {
    final existing = [record('2026-08-10', '2026-08-14')];

    test('完全落在已有记录内 → 重叠', () {
      final error = validateNewPeriodRange(
        start: DateTime(2026, 8, 11),
        end: DateTime(2026, 8, 13),
        today: today,
        records: existing,
      );
      expect(error, AppStrings.dateRangeOverlap);
    });

    test('与已有记录尾部重叠 → 重叠', () {
      final error = validateNewPeriodRange(
        start: DateTime(2026, 8, 12),
        end: DateTime(2026, 8, 16),
        today: today,
        records: existing,
      );
      expect(error, AppStrings.dateRangeOverlap);
    });

    test('与已有记录头部重叠 → 重叠', () {
      final error = validateNewPeriodRange(
        start: DateTime(2026, 8, 8),
        end: DateTime(2026, 8, 12),
        today: today,
        records: existing,
      );
      expect(error, AppStrings.dateRangeOverlap);
    });

    test('完全包含已有记录 → 重叠', () {
      final error = validateNewPeriodRange(
        start: DateTime(2026, 8, 8),
        end: DateTime(2026, 8, 16),
        today: today,
        records: existing,
      );
      expect(error, AppStrings.dateRangeOverlap);
    });

    test('共享已有记录的结束日（同一天）→ 重叠', () {
      final error = validateNewPeriodRange(
        start: DateTime(2026, 8, 14),
        end: DateTime(2026, 8, 16),
        today: today,
        records: existing,
      );
      expect(error, AppStrings.dateRangeOverlap);
    });

    test('紧邻已有记录结束日的次日开始 → 通过', () {
      final error = validateNewPeriodRange(
        start: DateTime(2026, 8, 15),
        end: DateTime(2026, 8, 18),
        today: today,
        records: existing,
      );
      expect(error, isNull);
    });

    test('结束日紧邻已有记录开始日的前一天 → 通过', () {
      final error = validateNewPeriodRange(
        start: DateTime(2026, 8, 5),
        end: DateTime(2026, 8, 9),
        today: today,
        records: existing,
      );
      expect(error, isNull);
    });

    test('落在两段已有记录的间隙内 → 通过', () {
      final error = validateNewPeriodRange(
        start: DateTime(2026, 8, 5),
        end: DateTime(2026, 8, 8),
        today: today,
        records: [record('2026-08-01', '2026-08-03'), record('2026-08-10', '2026-08-12')],
      );
      expect(error, isNull);
    });
  });

  group('validateNewPeriodRange - 进行中的经期', () {
    // endDate 为 null 的记录视为进行中，占用 [开始日, 今天]
    final ongoing = [record('2026-09-01')];

    test('落在进行中区间内 → 重叠', () {
      final error = validateNewPeriodRange(
        start: DateTime(2026, 9, 3),
        end: DateTime(2026, 9, 5),
        today: today,
        records: ongoing,
      );
      expect(error, AppStrings.dateRangeOverlap);
    });

    test('区间延伸到今天仍重叠', () {
      final error = validateNewPeriodRange(
        start: DateTime(2026, 9, 7),
        end: today,
        today: today,
        records: ongoing,
      );
      expect(error, AppStrings.dateRangeOverlap);
    });

    test('进行中开始日之前的历史区间 → 通过', () {
      final error = validateNewPeriodRange(
        start: DateTime(2026, 8, 20),
        end: DateTime(2026, 8, 25),
        today: today,
        records: ongoing,
      );
      expect(error, isNull);
    });

    test('跨越进行中开始日 → 重叠', () {
      final error = validateNewPeriodRange(
        start: DateTime(2026, 8, 30),
        end: DateTime(2026, 9, 3),
        today: today,
        records: ongoing,
      );
      expect(error, AppStrings.dateRangeOverlap);
    });
  });

  group('periodLengthWarning', () {
    test('1 天 → 偏短提示', () {
      expect(periodLengthWarning(1), contains('偏短'));
    });

    test('2 天 → 正常', () {
      expect(periodLengthWarning(2), isNull);
    });

    test('10 天 → 正常', () {
      expect(periodLengthWarning(10), isNull);
    });

    test('11 天 → 偏长提示', () {
      expect(periodLengthWarning(11), contains('偏长'));
    });
  });
}
