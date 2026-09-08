import 'package:flutter_test/flutter_test.dart';
import 'package:yimaflutter/utils/date_utils.dart';

void main() {
  group('AppDateUtils', () {
    group('isSameDay', () {
      test('returns true for same day', () {
        final date1 = DateTime(2026, 7, 1, 10, 30);
        final date2 = DateTime(2026, 7, 1, 15, 45);
        expect(AppDateUtils.isSameDay(date1, date2), isTrue);
      });

      test('returns false for different days', () {
        final date1 = DateTime(2026, 7, 1);
        final date2 = DateTime(2026, 7, 2);
        expect(AppDateUtils.isSameDay(date1, date2), isFalse);
      });

      test('returns false for different months', () {
        final date1 = DateTime(2026, 6, 30);
        final date2 = DateTime(2026, 7, 1);
        expect(AppDateUtils.isSameDay(date1, date2), isFalse);
      });
    });

    group('isInRange', () {
      test('returns true for date in range', () {
        final date = DateTime(2026, 7, 5);
        final start = DateTime(2026, 7, 1);
        final end = DateTime(2026, 7, 10);
        expect(AppDateUtils.isInRange(date, start, end), isTrue);
      });

      test('returns true for start date', () {
        final date = DateTime(2026, 7, 1);
        final start = DateTime(2026, 7, 1);
        final end = DateTime(2026, 7, 10);
        expect(AppDateUtils.isInRange(date, start, end), isTrue);
      });

      test('returns true for end date', () {
        final date = DateTime(2026, 7, 10);
        final start = DateTime(2026, 7, 1);
        final end = DateTime(2026, 7, 10);
        expect(AppDateUtils.isInRange(date, start, end), isTrue);
      });

      test('returns false for date before range', () {
        final date = DateTime(2026, 6, 30);
        final start = DateTime(2026, 7, 1);
        final end = DateTime(2026, 7, 10);
        expect(AppDateUtils.isInRange(date, start, end), isFalse);
      });

      test('returns false for date after range', () {
        final date = DateTime(2026, 7, 11);
        final start = DateTime(2026, 7, 1);
        final end = DateTime(2026, 7, 10);
        expect(AppDateUtils.isInRange(date, start, end), isFalse);
      });

      test('handles null end date', () {
        final date = DateTime(2026, 7, 5);
        final start = DateTime(2026, 7, 1);
        expect(AppDateUtils.isInRange(date, start, null), isTrue);
      });
    });

    group('getDaysInRange', () {
      test('returns correct days for range', () {
        final start = DateTime(2026, 7, 1);
        final end = DateTime(2026, 7, 5);
        final days = AppDateUtils.getDaysInRange(start, end);

        expect(days.length, 5);
        expect(days[0], DateTime(2026, 7, 1));
        expect(days[4], DateTime(2026, 7, 5));
      });

      test('handles single day range', () {
        final date = DateTime(2026, 7, 1);
        final days = AppDateUtils.getDaysInRange(date, date);

        expect(days.length, 1);
        expect(days[0], DateTime(2026, 7, 1));
      });
    });

    group('daysBetween', () {
      test('returns positive days when a is after b', () {
        final date1 = DateTime(2026, 7, 5); // a (later)
        final date2 = DateTime(2026, 7, 1); // b (earlier)
        expect(AppDateUtils.daysBetween(date1, date2), 4);
      });

      test('returns negative days when a is before b', () {
        final date1 = DateTime(2026, 7, 1); // a (earlier)
        final date2 = DateTime(2026, 7, 5); // b (later)
        expect(AppDateUtils.daysBetween(date1, date2), -4);
      });

      test('returns 0 for same date', () {
        final date = DateTime(2026, 7, 1);
        expect(AppDateUtils.daysBetween(date, date), 0);
      });
    });

    group('formatDate', () {
      test('formats date correctly', () {
        final date = DateTime(2026, 7, 1);
        expect(AppDateUtils.formatDate(date), '2026-07-01');
      });

      test('pads single digit month and day', () {
        final date = DateTime(2026, 1, 5);
        expect(AppDateUtils.formatDate(date), '2026-01-05');
      });
    });

    group('today', () {
      test('returns today without time', () {
        final today = AppDateUtils.today();
        final now = DateTime.now();

        expect(today.year, now.year);
        expect(today.month, now.month);
        expect(today.day, now.day);
        expect(today.hour, 0);
        expect(today.minute, 0);
        expect(today.second, 0);
      });
    });
  });

  group('needsReschedule', () {
    test('从未排期且有预测 → 需要排期', () {
      expect(needsReschedule(null, DateTime(2026, 9, 20)), isTrue);
    });

    test('预测消失 → 不需要排期', () {
      expect(needsReschedule(DateTime(2026, 9, 20), null), isFalse);
      expect(needsReschedule(null, null), isFalse);
    });

    test('预测未变化（同年月日，忽略时分秒）→ 跳过', () {
      final scheduled = DateTime(2026, 9, 20, 9, 30);
      final predicted = DateTime(2026, 9, 20, 0, 0);
      expect(needsReschedule(scheduled, predicted), isFalse);
    });

    test('预测日期变化（年/月/日任一）→ 需要排期', () {
      expect(
        needsReschedule(DateTime(2026, 9, 20), DateTime(2026, 9, 21)),
        isTrue,
      );
      expect(
        needsReschedule(DateTime(2026, 9, 20), DateTime(2026, 10, 20)),
        isTrue,
      );
      expect(
        needsReschedule(DateTime(2026, 12, 20), DateTime(2027, 12, 20)),
        isTrue,
      );
    });
  });
}