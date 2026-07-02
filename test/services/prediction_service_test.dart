import 'package:flutter_test/flutter_test.dart';
import 'package:yimaflutter/services/prediction_service.dart';
import 'package:yimaflutter/models/period_record.dart';

void main() {
  group('PredictionService', () {
    group('calculateCycleData', () {
      test('returns default values for empty records', () {
        final result = PredictionService.calculateCycleData([]);

        expect(result.averageCycleLength, 28.0);
        expect(result.averagePeriodLength, 5.0);
        expect(result.totalCycles, 0);
        expect(result.recentPeriods, isEmpty);
        expect(result.predictedNextPeriod, isNull);
      });

      test('returns correct data for single record', () {
        final records = [
          PeriodRecord(
            startDate: '2026-01-01',
            endDate: '2026-01-05',
            periodLength: 5,
          ),
        ];

        final result = PredictionService.calculateCycleData(records);

        // totalCycles is the count of cycle lengths, which is 0 for a single record
        expect(result.totalCycles, 0);
        expect(result.averagePeriodLength, 5.0);
        expect(result.lastPeriodStart, DateTime(2026, 1, 1));
      });

      test('calculates correct averages for multiple records', () {
        final records = [
          PeriodRecord(
            startDate: '2026-01-01',
            endDate: '2026-01-05',
            periodLength: 5,
          ),
          PeriodRecord(
            startDate: '2026-01-29',
            endDate: '2026-02-02',
            periodLength: 5,
          ),
          PeriodRecord(
            startDate: '2026-02-26',
            endDate: '2026-03-01',
            periodLength: 4,
          ),
        ];

        final result = PredictionService.calculateCycleData(records);

        // totalCycles is the count of cycle lengths (2 for 3 records)
        expect(result.totalCycles, 2);
        expect(result.averagePeriodLength, closeTo(4.67, 0.1));
        expect(result.averageCycleLength, closeTo(28.0, 0.1));
      });
    });

    group('simple algorithm', () {
      test('predicts next period correctly', () {
        final records = [
          PeriodRecord(
            startDate: '2026-01-01',
            endDate: '2026-01-05',
            periodLength: 5,
          ),
          PeriodRecord(
            startDate: '2026-01-29',
            endDate: '2026-02-02',
            periodLength: 5,
          ),
        ];

        final result = PredictionService.calculateCycleData(
          records,
          algorithm: 'simple',
        );

        expect(result.predictedNextPeriod, DateTime(2026, 2, 26));
      });
    });

    group('weighted algorithm', () {
      test('gives higher weight to recent records', () {
        final records = [
          PeriodRecord(
            startDate: '2025-10-01',
            endDate: '2025-10-05',
            periodLength: 5,
          ),
          PeriodRecord(
            startDate: '2025-10-29',
            endDate: '2025-11-02',
            periodLength: 5,
          ),
          PeriodRecord(
            startDate: '2025-11-26',
            endDate: '2025-11-30',
            periodLength: 5,
          ),
          PeriodRecord(
            startDate: '2025-12-24',
            endDate: '2025-12-28',
            periodLength: 5,
          ),
          PeriodRecord(
            startDate: '2026-01-21',
            endDate: '2026-01-25',
            periodLength: 5,
          ),
        ];

        final result = PredictionService.calculateCycleData(
          records,
          algorithm: 'weighted',
        );

        // Weighted average should be closer to recent cycle lengths
        expect(result.averageCycleLength, closeTo(28.0, 0.1));
      });
    });
  });
}