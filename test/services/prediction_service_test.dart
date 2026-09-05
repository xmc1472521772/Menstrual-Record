import 'package:flutter_test/flutter_test.dart';
import 'package:yimaflutter/services/prediction_service.dart';
import 'package:yimaflutter/models/cycle_data.dart';
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
        expect(result.predictionMode, PredictionMode.baseline);
      });

      test('returns correct data for single record (cold start)', () {
        final records = [
          PeriodRecord(
            startDate: '2026-01-01',
            endDate: '2026-01-05',
            periodLength: 5,
          ),
        ];

        final result = PredictionService.calculateCycleData(records);

        expect(result.totalCycles, 0);
        expect(result.averagePeriodLength, 5.0);
        expect(result.lastPeriodStart, DateTime(2026, 1, 1));
        expect(result.predictionMode, PredictionMode.baseline);
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
        expect(result.predictionMode, PredictionMode.simple);
      });
    });

    group('adaptive algorithm', () {
      test('uses baseline mode for cold start (N < 3)', () {
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
          algorithm: 'adaptive',
        );

        expect(result.predictionMode, PredictionMode.baseline);
        // Cold start: average of [28] clamped to 21~35 → 28
        expect(result.averageCycleLength, 28.0);
      });

      test('uses WMA-regular for regular cycles (low STD)', () {
        // 5 records with very regular 28-day cycles
        final records = [
          PeriodRecord(startDate: '2025-10-01', endDate: '2025-10-05', periodLength: 5),
          PeriodRecord(startDate: '2025-10-29', endDate: '2025-11-02', periodLength: 5),
          PeriodRecord(startDate: '2025-11-26', endDate: '2025-11-30', periodLength: 5),
          PeriodRecord(startDate: '2025-12-24', endDate: '2025-12-28', periodLength: 5),
          PeriodRecord(startDate: '2026-01-21', endDate: '2026-01-25', periodLength: 5),
        ];

        final result = PredictionService.calculateCycleData(
          records,
          algorithm: 'adaptive',
        );

        expect(result.predictionMode, PredictionMode.wmaRegular);
        expect(result.averageCycleLength, closeTo(28.0, 1.0));
        // Regular → narrow window (±1 day)
        expect(result.predictionWindowDays, 2);
      });

      test('uses WMA-volatile for irregular cycles (high STD)', () {
        // Records with highly variable cycle lengths: 35, 16, 40, 24
        final records = [
          PeriodRecord(startDate: '2025-06-03', endDate: '2025-06-10', periodLength: 8),
          PeriodRecord(startDate: '2025-07-05', endDate: '2025-07-12', periodLength: 8),
          PeriodRecord(startDate: '2025-08-09', endDate: '2025-08-16', periodLength: 8),
          PeriodRecord(startDate: '2025-09-23', endDate: '2025-09-30', periodLength: 8),
          PeriodRecord(startDate: '2025-11-02', endDate: '2025-11-09', periodLength: 8),
        ];

        final result = PredictionService.calculateCycleData(
          records,
          algorithm: 'adaptive',
        );

        // Cycles: [32, 35, 16, 29, 40] → STD > 5 → volatile
        expect(result.predictionMode, PredictionMode.wmaVolatile);
        // Volatile → wide window (±3 days)
        expect(result.predictionWindowDays, 6);
      });

      test('detects trend shift and switches to volatile mode', () {
        // User was regular (~28 days) then suddenly shifted to ~17 days
        // Cycles: 28, 28, 28, 28, 17, 17
        final records = [
          PeriodRecord(startDate: '2025-06-03', endDate: '2025-06-10', periodLength: 8),
          PeriodRecord(startDate: '2025-07-01', endDate: '2025-07-08', periodLength: 8),
          PeriodRecord(startDate: '2025-07-29', endDate: '2025-08-05', periodLength: 8),
          PeriodRecord(startDate: '2025-08-26', endDate: '2025-09-02', periodLength: 8),
          PeriodRecord(startDate: '2025-09-12', endDate: '2025-09-19', periodLength: 8),
          PeriodRecord(startDate: '2025-09-29', endDate: '2025-10-06', periodLength: 8),
        ];

        final result = PredictionService.calculateCycleData(
          records,
          algorithm: 'adaptive',
        );

        // Recent 2 avg = 17, historical avg = 28 → diff = 11 > 7 → trend shift
        expect(result.predictionMode, PredictionMode.wmaVolatile);
      });

      test('weighted algorithm name maps to adaptive path', () {
        // Backward compatibility: 'weighted' should behave like 'adaptive'
        final records = [
          PeriodRecord(startDate: '2025-10-01', endDate: '2025-10-05', periodLength: 5),
          PeriodRecord(startDate: '2025-10-29', endDate: '2025-11-02', periodLength: 5),
          PeriodRecord(startDate: '2025-11-26', endDate: '2025-11-30', periodLength: 5),
          PeriodRecord(startDate: '2025-12-24', endDate: '2025-12-28', periodLength: 5),
          PeriodRecord(startDate: '2026-01-21', endDate: '2026-01-25', periodLength: 5),
        ];

        final resultWeighted = PredictionService.calculateCycleData(
          records,
          algorithm: 'weighted',
        );
        final resultAdaptive = PredictionService.calculateCycleData(
          records,
          algorithm: 'adaptive',
        );

        expect(resultWeighted.averageCycleLength,
            resultAdaptive.averageCycleLength);
        expect(resultWeighted.predictionMode, resultAdaptive.predictionMode);
      });

      test('clamps cycle length to physiological range (21-45)', () {
        // Extremely short cycles that would produce very low average
        final records = [
          PeriodRecord(startDate: '2025-10-01', endDate: '2025-10-02', periodLength: 2),
          PeriodRecord(startDate: '2025-10-05', endDate: '2025-10-06', periodLength: 2),
          PeriodRecord(startDate: '2025-10-09', endDate: '2025-10-10', periodLength: 2),
          PeriodRecord(startDate: '2025-10-13', endDate: '2025-10-14', periodLength: 2),
        ];

        final result = PredictionService.calculateCycleData(
          records,
          algorithm: 'adaptive',
        );

        expect(result.averageCycleLength, greaterThanOrEqualTo(21.0));
        expect(result.averageCycleLength, lessThanOrEqualTo(45.0));
      });

      test('real user data: 24 cycles with trend shift → volatile mode', () {
        // Simulating the user's actual data (25 records → 24 cycle lengths)
        // Last 6: [38, 40, 33, 17, 17, 23] → recent2 avg=20, historical avg~31
        // → trend shift detected
        final records = [
          PeriodRecord(startDate: '2024-09-05', endDate: '2024-09-12', periodLength: 8),
          PeriodRecord(startDate: '2024-09-29', endDate: '2024-10-07', periodLength: 9),
          PeriodRecord(startDate: '2024-10-28', endDate: '2024-11-04', periodLength: 8),
          PeriodRecord(startDate: '2024-11-30', endDate: '2024-12-07', periodLength: 8),
          PeriodRecord(startDate: '2025-01-02', endDate: '2025-01-09', periodLength: 8),
          PeriodRecord(startDate: '2025-02-07', endDate: '2025-02-14', periodLength: 8),
          PeriodRecord(startDate: '2025-03-14', endDate: '2025-03-21', periodLength: 8),
          PeriodRecord(startDate: '2025-04-08', endDate: '2025-04-15', periodLength: 8),
          PeriodRecord(startDate: '2025-05-06', endDate: '2025-05-13', periodLength: 8),
          PeriodRecord(startDate: '2025-06-03', endDate: '2025-06-10', periodLength: 8),
          PeriodRecord(startDate: '2025-07-05', endDate: '2025-07-12', periodLength: 8),
          PeriodRecord(startDate: '2025-08-09', endDate: '2025-08-16', periodLength: 8),
          PeriodRecord(startDate: '2025-08-25', endDate: '2025-09-01', periodLength: 8),
          PeriodRecord(startDate: '2025-09-23', endDate: '2025-09-30', periodLength: 8),
          PeriodRecord(startDate: '2025-11-02', endDate: '2025-11-09', periodLength: 8),
          PeriodRecord(startDate: '2025-11-26', endDate: '2025-12-03', periodLength: 8),
          PeriodRecord(startDate: '2025-12-25', endDate: '2026-01-01', periodLength: 8),
          PeriodRecord(startDate: '2026-01-30', endDate: '2026-02-07', periodLength: 9),
          PeriodRecord(startDate: '2026-03-16', endDate: '2026-03-25', periodLength: 10),
          PeriodRecord(startDate: '2026-04-23', endDate: '2026-04-30', periodLength: 8),
          PeriodRecord(startDate: '2026-06-02', endDate: '2026-06-11', periodLength: 10),
          PeriodRecord(startDate: '2026-07-05', endDate: '2026-07-14', periodLength: 9),
          PeriodRecord(startDate: '2026-07-22', endDate: '2026-08-01', periodLength: 10),
          PeriodRecord(startDate: '2026-08-08', endDate: '2026-08-14', periodLength: 7),
          PeriodRecord(startDate: '2026-08-31', endDate: null, periodLength: null),
        ];

        final result = PredictionService.calculateCycleData(
          records,
          algorithm: 'adaptive',
        );

        // Recent 2 avg = (17+23)/2 = 20, historical avg ≈ 31.8 → trend shift
        expect(result.predictionMode, PredictionMode.wmaVolatile);
        // Should NOT be 29.9 (the old buggy value)
        expect(result.averageCycleLength, lessThan(29.0));
      });
    });
  });
}
