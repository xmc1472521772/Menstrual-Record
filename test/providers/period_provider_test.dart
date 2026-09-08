import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:yimaflutter/providers/period_provider.dart';
import 'package:yimaflutter/providers/settings_provider.dart';
import 'package:yimaflutter/database/period_dao.dart';
import 'package:yimaflutter/database/daily_flow_dao.dart';
import 'package:yimaflutter/database/settings_dao.dart';
import 'package:yimaflutter/database/database_helper.dart';
import 'package:yimaflutter/models/period_record.dart';
import 'package:yimaflutter/services/prediction_service.dart';

void main() {
  // Initialize sqflite for testing
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late PeriodProvider provider;
  late SettingsProvider settingsProvider;
  late _TestDatabaseProvider dbHelper;
  late PeriodDao periodDao;
  late DailyFlowDao dailyFlowDao;
  late SettingsDao settingsDao;

  setUp(() async {
    // Create an in-memory database for each test
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE period_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            start_date TEXT NOT NULL,
            end_date TEXT,
            cycle_length INTEGER,
            period_length INTEGER,
            flow_level INTEGER,
            mood TEXT,
            notes TEXT,
            symptoms TEXT,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE daily_flows (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL UNIQUE,
            flow_level INTEGER NOT NULL DEFAULT 0
          )
        ''');
        // Seed default settings
        await db.insert('settings', {'key': 'avg_cycle_length', 'value': '28'});
        await db.insert('settings', {'key': 'avg_period_length', 'value': '5'});
        await db.insert('settings', {'key': 'reminder_days', 'value': '2'});
        await db.insert('settings', {'key': 'reminder_hour', 'value': '9'});
        await db.insert(
            'settings', {'key': 'prediction_algorithm', 'value': 'simple'});
        await db.insert(
            'settings', {'key': 'merge_threshold', 'value': '2'});
      },
    );

    // Mock the local notifications channel to prevent MissingPluginException
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async => null,
    );

    // Create a test DatabaseProvider that returns our in-memory DB
    dbHelper = _TestDatabaseProvider(db);
    periodDao = PeriodDao(dbHelper: dbHelper);
    dailyFlowDao = DailyFlowDao(dbHelper: dbHelper);
    settingsDao = SettingsDao(dbHelper: dbHelper);

    provider = PeriodProvider(
      periodDao: periodDao,
      flowDao: dailyFlowDao,
      settingsDao: settingsDao,
      // overwrite 导入的事务直接在 dbProvider 上开，必须与 DAO 同库，
      // 否则事务会写到 DatabaseHelper 单例指向的另一个数据库
      dbProvider: dbHelper,
      scheduleReminders: false,
      autoEndExpiredPeriods: false,
    );
    settingsProvider = SettingsProvider(settingsDao: settingsDao);

    await provider.loadRecords();
    await settingsProvider.loadSettings();
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('PeriodProvider - Initial State', () {
    test('starts with empty records', () {
      expect(provider.records, isEmpty);
    });

    test('starts with zero totalCycles', () {
      expect(provider.cycleData, isNotNull);
      expect(provider.cycleData!.totalCycles, 0);
    });

    test('isLoading is false after loadRecords', () {
      expect(provider.isLoading, isFalse);
    });
  });

  group('PeriodProvider - startPeriod', () {
    test('successfully starts a period', () async {
      final result = await provider.startPeriod(DateTime(2025, 1, 10));
      expect(result, isTrue);
      expect(provider.records, hasLength(1));
      expect(provider.records.first.isOngoing, isTrue);
      expect(provider.records.first.startDate, '2025-01-10');
    });

    test('prevents starting a second period while one is ongoing', () async {
      await provider.startPeriod(DateTime(2025, 1, 10));
      final result = await provider.startPeriod(DateTime(2025, 1, 12));
      expect(result, isFalse);
      expect(provider.records, hasLength(1));
    });

    test('prevents starting a period that conflicts with existing record',
        () async {
      await provider.startPeriod(DateTime(2025, 1, 10));
      await provider.endPeriod(DateTime(2025, 1, 14));

      // Try to start a period within the existing record's range
      final result = await provider.startPeriod(DateTime(2025, 1, 12));
      expect(result, isFalse);
      expect(provider.records, hasLength(1));
    });

    test('allows starting a period after a previous one ended', () async {
      await provider.startPeriod(DateTime(2025, 1, 10));
      await provider.endPeriod(DateTime(2025, 1, 14));

      final result = await provider.startPeriod(DateTime(2025, 2, 10));
      expect(result, isTrue);
      expect(provider.records, hasLength(2));
    });
  });

  group('PeriodProvider - endPeriod', () {
    test('successfully ends an ongoing period', () async {
      await provider.startPeriod(DateTime(2025, 1, 10));
      final result = await provider.endPeriod(DateTime(2025, 1, 14));

      expect(result, isTrue);
      expect(provider.records.first.isOngoing, isFalse);
      expect(provider.records.first.endDate, '2025-01-14');
      expect(provider.records.first.periodLength, 5);
    });

    test('fails to end when no period is ongoing', () async {
      final result = await provider.endPeriod(DateTime(2025, 1, 14));
      expect(result, isFalse);
    });
  });

  group('PeriodProvider - isPeriodDay', () {
    test('returns true for dates within a completed period', () async {
      await provider.startPeriod(DateTime(2025, 1, 10));
      await provider.endPeriod(DateTime(2025, 1, 14));

      expect(provider.isPeriodDay(DateTime(2025, 1, 10)), isTrue);
      expect(provider.isPeriodDay(DateTime(2025, 1, 12)), isTrue);
      expect(provider.isPeriodDay(DateTime(2025, 1, 14)), isTrue);
    });

    test('returns false for dates outside a period', () async {
      await provider.startPeriod(DateTime(2025, 1, 10));
      await provider.endPeriod(DateTime(2025, 1, 14));

      // Dates before the period
      expect(provider.isPeriodDay(DateTime(2025, 1, 9)), isFalse);
      // Dates after the period but within today (auto-end might affect)
      // Use a date well outside the range
      expect(provider.isPeriodDay(DateTime(2024, 6, 1)), isFalse);
    });
  });

  group('PeriodProvider - isDateInAnyRecord', () {
    test('returns true for dates in any record', () async {
      await provider.startPeriod(DateTime(2025, 1, 10));
      await provider.endPeriod(DateTime(2025, 1, 14));

      expect(provider.isDateInAnyRecord(DateTime(2025, 1, 11)), isTrue);
      expect(provider.isDateInAnyRecord(DateTime(2024, 6, 1)), isFalse);
    });
  });

  group('PeriodProvider - setAlgorithm', () {
    test('updates algorithm and recalculates cycle data', () async {
      await provider.startPeriod(DateTime(2025, 1, 10));
      await provider.endPeriod(DateTime(2025, 1, 14));
      await provider.startPeriod(DateTime(2025, 2, 7));
      await provider.endPeriod(DateTime(2025, 2, 11));

      final simpleData = provider.cycleData!;
      await provider.setAlgorithm('weighted');
      final weightedData = provider.cycleData!;

      // Both algorithms should produce cycle data
      expect(simpleData, isNotNull);
      expect(weightedData, isNotNull);
      expect(simpleData.totalCycles, weightedData.totalCycles);
    });
  });

  group('PeriodProvider - exportData / importData', () {
    test('exports and imports data correctly (append mode)', () async {
      await provider.startPeriod(DateTime(2025, 1, 10));
      await provider.endPeriod(DateTime(2025, 1, 14));

      final exported = await provider.exportData();
      expect(exported, isNotEmpty);

      // Clear and re-import
      await provider.deleteRecord(provider.records.first.id!);
      expect(provider.records, isEmpty);

      final result = await provider.importData(exported, overwrite: false);
      expect(result, isTrue);
      expect(provider.records, hasLength(1));
      expect(provider.records.first.startDate, '2025-01-10');
      expect(provider.records.first.endDate, '2025-01-14');
    });

    test('import overwrite mode replaces all data', () async {
      await provider.startPeriod(DateTime(2025, 1, 10));
      await provider.endPeriod(DateTime(2025, 1, 14));

      final exported = await provider.exportData();

      // Add another record
      await provider.startPeriod(DateTime(2025, 2, 10));
      await provider.endPeriod(DateTime(2025, 2, 14));
      expect(provider.records, hasLength(2));

      // Overwrite with exported data (1 record)
      final result = await provider.importData(exported, overwrite: true);
      expect(result, isTrue);
      expect(provider.records, hasLength(1));
      expect(provider.records.first.startDate, '2025-01-10');
    });

    test('import handles null fields correctly', () async {
      const json =
          '[{"startDate":"2025-01-10","endDate":null,"cycleLength":null,"periodLength":null,"mood":null,"notes":null,"symptoms":null,"createdAt":1736467200000}]';

      final result = await provider.importData(json, overwrite: false);
      expect(result, isTrue);
      expect(provider.records, hasLength(1));
      expect(provider.records.first.startDate, '2025-01-10');
      expect(provider.records.first.endDate, isNull);
      expect(provider.records.first.mood, isNull);
      expect(provider.records.first.notes, isNull);
    });

    test('import handles empty string as null for nullable fields', () {
      final record = PeriodRecord.fromJson({
        'startDate': '2025-01-10',
        'endDate': null,
        'cycleLength': null,
        'periodLength': null,
        'mood': '',
        'notes': '',
        'symptoms': '',
        'createdAt': 1736467200000,
      });

      expect(record.mood, isNull);
      expect(record.notes, isNull);
      expect(record.symptoms, isNull);
    });
  });

  group('PeriodProvider - PeriodRecord.copyWith', () {
    test('copies with new values', () {
      final record = PeriodRecord(
        startDate: '2025-01-10',
        endDate: '2025-01-14',
      );

      final copy = record.copyWith(endDate: '2025-01-15');
      expect(copy.endDate, '2025-01-15');
      expect(copy.startDate, '2025-01-10');
    });

    test('clears nullable fields when clear flag is set', () {
      final record = PeriodRecord(
        startDate: '2025-01-10',
        endDate: '2025-01-14',
        mood: 'happy',
        notes: 'some notes',
      );

      final copy = record.copyWith(clearEndDate: true, clearMood: true);
      expect(copy.endDate, isNull);
      expect(copy.mood, isNull);
      expect(copy.notes, 'some notes');
    });
  });

  group('PeriodProvider - getDayType', () {
    test('returns period for dates in a record', () async {
      await provider.startPeriod(DateTime(2025, 1, 10));
      await provider.endPeriod(DateTime(2025, 1, 14));

      expect(provider.getDayType(DateTime(2025, 1, 10)), 'period');
      expect(provider.getDayType(DateTime(2025, 1, 12)), 'period');
      expect(provider.getDayType(DateTime(2025, 1, 14)), 'period');
    });

    test('returns normal for dates outside any period', () async {
      await provider.startPeriod(DateTime(2025, 1, 10));
      await provider.endPeriod(DateTime(2025, 1, 14));

      // Date far from any period
      final dayType = provider.getDayType(DateTime(2025, 6, 1));
      expect(dayType, anyOf('normal', 'safe'));
    });
  });

  group('PredictionService - calculateCycleData', () {
    test('returns defaults for empty records', () {
      final data = PredictionService.calculateCycleData([], algorithm: 'simple');
      expect(data.totalCycles, 0);
      expect(data.averageCycleLength, greaterThanOrEqualTo(0));
      expect(data.averagePeriodLength, greaterThanOrEqualTo(0));
    });

    test('calculates average cycle length correctly', () {
      final records = [
        PeriodRecord(startDate: '2025-01-01', endDate: '2025-01-05'),
        PeriodRecord(startDate: '2025-01-29', endDate: '2025-02-02'),
        PeriodRecord(startDate: '2025-02-26', endDate: '2025-03-02'),
      ];

      final data = PredictionService.calculateCycleData(records,
          algorithm: 'simple');
      // 3 records → 2 cycles (gaps between consecutive records)
      expect(data.totalCycles, 2);
      expect(data.averageCycleLength, closeTo(28.0, 0.5));
    });

    test('calculates weighted average correctly', () {
      final records = [
        PeriodRecord(startDate: '2025-01-01', endDate: '2025-01-05'),
        PeriodRecord(startDate: '2025-01-29', endDate: '2025-02-02'),
        PeriodRecord(startDate: '2025-02-26', endDate: '2025-03-02'),
        PeriodRecord(startDate: '2025-03-26', endDate: '2025-03-30'),
      ];

      final simpleData = PredictionService.calculateCycleData(records,
          algorithm: 'simple');
      final weightedData = PredictionService.calculateCycleData(records,
          algorithm: 'weighted');

      // 4 records → 3 cycles (gaps between consecutive records)
      expect(simpleData.totalCycles, 3);
      expect(weightedData.totalCycles, 3);
      expect(weightedData.averageCycleLength, greaterThan(0));
    });

    test('predicts next period correctly when last period is ongoing', () {
      // Two completed periods + one ongoing period
      final records = [
        PeriodRecord(startDate: '2025-01-01', endDate: '2025-01-05'),
        PeriodRecord(startDate: '2025-01-29', endDate: '2025-02-02'),
        PeriodRecord(startDate: '2025-02-26'), // ongoing, no endDate
      ];

      final data = PredictionService.calculateCycleData(records,
          algorithm: 'simple');

      // avgCycle = (28 + 28) / 2 = 28
      // predictedNext should be based on the LAST record (ongoing) start date:
      // 2025-02-26 + 28 days = 2025-03-26
      // NOT based on the previous record (which would give 2025-01-29 + 28 = 2025-02-26,
      // i.e. the current period itself)
      expect(data.predictedNextPeriod, isNotNull);
      expect(data.predictedNextPeriod!.year, 2025);
      expect(data.predictedNextPeriod!.month, 3);
      expect(data.predictedNextPeriod!.day, 26);
    });

    test('predicts next period for single ongoing period using default cycle', () {
      // Single ongoing period, no history
      final records = [
        PeriodRecord(startDate: '2025-01-01'), // ongoing
      ];

      final data = PredictionService.calculateCycleData(records,
          algorithm: 'simple');

      // No cycle history → avgCycle = defaultCycleLength = 28
      // predictedNext = 2025-01-01 + 28 days = 2025-01-29
      expect(data.predictedNextPeriod, isNotNull);
      expect(data.predictedNextPeriod!.year, 2025);
      expect(data.predictedNextPeriod!.month, 1);
      expect(data.predictedNextPeriod!.day, 29);
    });
  });

  // ─── Period Merge Tests ─────────────────────────────────────────────
  group('PeriodProvider - startPeriodWithMerge', () {
    test('scene A: same day (gap=0) → silent merge', () async {
      // 08-31 开始，09-05 结束
      await provider.startPeriod(DateTime(2026, 8, 31));
      await provider.endPeriod(DateTime(2026, 9, 5));
      expect(provider.records, hasLength(1));
      expect(provider.records.first.isOngoing, isFalse);

      // 同天再开 → 静默合并
      final outcome = await provider.startPeriodWithMerge(
        DateTime(2026, 9, 5),
        mergeThreshold: 2,
      );

      expect(outcome.result, PeriodStartResult.mergedSilently);
      expect(provider.records, hasLength(1)); // 没有新增记录
      expect(provider.records.first.isOngoing, isTrue); // 恢复为进行中
      expect(provider.records.first.startDate, '2026-08-31');
      expect(provider.records.first.endDate, isNull); // endDate 被清空
    });

    test('scene A: start day equals end day (gap=0) → silent merge', () async {
      // 09-01 开始，09-03 结束
      await provider.startPeriod(DateTime(2026, 9, 1));
      await provider.endPeriod(DateTime(2026, 9, 3));

      // 09-03 同天再开
      final outcome = await provider.startPeriodWithMerge(
        DateTime(2026, 9, 3),
        mergeThreshold: 2,
      );

      expect(outcome.result, PeriodStartResult.mergedSilently);
      expect(provider.records, hasLength(1));
      expect(provider.records.first.isOngoing, isTrue);
    });

    test('scene B: gap=1 → needs confirmation', () async {
      // 09-01 开始，09-03 结束
      await provider.startPeriod(DateTime(2026, 9, 1));
      await provider.endPeriod(DateTime(2026, 9, 3));

      // 09-04 再开（间隔 1 天）
      final outcome = await provider.startPeriodWithMerge(
        DateTime(2026, 9, 4),
        mergeThreshold: 2,
      );

      expect(outcome.result, PeriodStartResult.needsConfirmation);
      expect(outcome.mergeInfo, isNotNull);
      expect(outcome.mergeInfo!.gapDays, 1);
    });

    test('scene B: gap=2 (equals threshold) → needs confirmation', () async {
      // 09-01 开始，09-03 结束
      await provider.startPeriod(DateTime(2026, 9, 1));
      await provider.endPeriod(DateTime(2026, 9, 3));

      // 09-05 再开（间隔 2 天 = 阈值）
      final outcome = await provider.startPeriodWithMerge(
        DateTime(2026, 9, 5),
        mergeThreshold: 2,
      );

      expect(outcome.result, PeriodStartResult.needsConfirmation);
      expect(outcome.mergeInfo, isNotNull);
      expect(outcome.mergeInfo!.gapDays, 2);
    });

    test('scene C: gap > threshold → created (new period)', () async {
      // 09-01 开始，09-03 结束
      await provider.startPeriod(DateTime(2026, 9, 1));
      await provider.endPeriod(DateTime(2026, 9, 3));

      // 09-10 再开（间隔 7 天 > 阈值 2）
      final outcome = await provider.startPeriodWithMerge(
        DateTime(2026, 9, 10),
        mergeThreshold: 2,
      );

      expect(outcome.result, PeriodStartResult.created);
      expect(provider.records, hasLength(2));
    });

    test('no history → created', () async {
      final outcome = await provider.startPeriodWithMerge(
        DateTime(2026, 9, 1),
        mergeThreshold: 2,
      );

      expect(outcome.result, PeriodStartResult.created);
      expect(provider.records, hasLength(1));
    });

    test('user chooses merge → mergeWithLastPeriod', () async {
      // 09-01 开始，09-03 结束
      await provider.startPeriod(DateTime(2026, 9, 1));
      await provider.endPeriod(DateTime(2026, 9, 3));

      // 用户选择续接
      final ok = await provider.mergeWithLastPeriod();
      expect(ok, isTrue);
      expect(provider.records, hasLength(1));
      expect(provider.records.first.isOngoing, isTrue);
      expect(provider.records.first.endDate, isNull);
    });

    test('user chooses new period → startNewPeriod', () async {
      // 09-01 开始，09-03 结束
      await provider.startPeriod(DateTime(2026, 9, 1));
      await provider.endPeriod(DateTime(2026, 9, 3));

      // 用户选择新开
      final ok = await provider.startNewPeriod(DateTime(2026, 9, 4));
      expect(ok, isTrue);
      expect(provider.records, hasLength(2));
      expect(provider.records.first.isOngoing, isTrue);
    });

    test('exact user scenario: 08-31 start, 09-05 end, 09-05 restart → merge',
        () async {
      // 用户场景：8月31日开始，9月5日结束，9月5日又开启
      await provider.startPeriod(DateTime(2026, 8, 31));
      await provider.endPeriod(DateTime(2026, 9, 5));

      expect(provider.records, hasLength(1));
      expect(provider.records.first.isOngoing, isFalse);
      expect(provider.records.first.startDate, '2026-08-31');
      expect(provider.records.first.endDate, '2026-09-05');

      // 9月5日同天再开 → 应该静默合并
      final outcome = await provider.startPeriodWithMerge(
        DateTime(2026, 9, 5),
        mergeThreshold: 2,
      );

      expect(outcome.result, PeriodStartResult.mergedSilently);
      expect(provider.records, hasLength(1)); // 仍然只有一条记录
      expect(provider.records.first.isOngoing, isTrue); // 恢复为进行中
      expect(provider.records.first.startDate, '2026-08-31'); // 开始日期不变
      expect(provider.records.first.endDate, isNull); // endDate 被清空
    });
  });

  group('PeriodProvider - savePeriodRecord 写入前校验（添加记录数据防线）', () {
    test('与已有记录重叠时拒绝保存', () async {
      await provider.startPeriod(DateTime(2025, 1, 10));
      await provider.endPeriod(DateTime(2025, 1, 14));

      final result = await provider
          .savePeriodRecord(DateTime(2025, 1, 12), DateTime(2025, 1, 16));
      expect(result, isFalse);
      expect(provider.records, hasLength(1));
    });

    test('与已有记录共享边界日（同一天）时拒绝保存', () async {
      await provider.startPeriod(DateTime(2025, 1, 10));
      await provider.endPeriod(DateTime(2025, 1, 14));

      // 1/14 已被上一条记录占用（与编辑对话框口径一致：两段记录不共享任何一天）
      final result = await provider
          .savePeriodRecord(DateTime(2025, 1, 14), DateTime(2025, 1, 16));
      expect(result, isFalse);
      expect(provider.records, hasLength(1));
    });

    test('紧邻上一条记录的次日开始时允许保存', () async {
      await provider.startPeriod(DateTime(2025, 1, 10));
      await provider.endPeriod(DateTime(2025, 1, 14));

      final result = await provider
          .savePeriodRecord(DateTime(2025, 1, 15), DateTime(2025, 1, 18));
      expect(result, isTrue);
      expect(provider.records, hasLength(2));
    });

    test('未来日期拒绝保存', () async {
      final result = await provider
          .savePeriodRecord(DateTime(2100, 1, 1), DateTime(2100, 1, 3));
      expect(result, isFalse);
      expect(provider.records, isEmpty);
    });

    test('结束日期早于开始日期拒绝保存', () async {
      final result = await provider
          .savePeriodRecord(DateTime(2025, 1, 20), DateTime(2025, 1, 18));
      expect(result, isFalse);
      expect(provider.records, isEmpty);
    });

    test('与进行中的经期重叠拒绝，之前的历史区间允许', () async {
      await provider.startPeriod(DateTime(2025, 1, 10)); // ongoing

      // 进行中记录占用 [1/10, 今天]，1/12-1/15 落在其中 → 拒绝
      final conflict = await provider
          .savePeriodRecord(DateTime(2025, 1, 12), DateTime(2025, 1, 15));
      expect(conflict, isFalse);

      // ongoing 之前的历史补录不重叠 → 允许
      final backfill = await provider
          .savePeriodRecord(DateTime(2024, 12, 20), DateTime(2024, 12, 25));
      expect(backfill, isTrue);
      expect(provider.records, hasLength(2));
    });
  });
}

/// A test-only DatabaseProvider that wraps an in-memory database.
class _TestDatabaseProvider implements DatabaseProvider {
  final Database _db;

  _TestDatabaseProvider(this._db);

  @override
  Future<Database> get database => Future.value(_db);

  @override
  Future<void> refreshConnection() async {}

  Future<void> close() async {
    await _db.close();
  }
}
