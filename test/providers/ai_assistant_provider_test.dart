import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:yimaflutter/providers/ai_assistant_provider.dart';
import 'package:yimaflutter/database/settings_dao.dart';
import 'package:yimaflutter/database/database_helper.dart';
import 'package:yimaflutter/services/ai_health_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AiAssistantProvider provider;
  late _TestDatabaseProvider dbHelper;
  late SettingsDao settingsDao;

  setUp(() async {
    // Create an in-memory database for each test
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );

    dbHelper = _TestDatabaseProvider(db);
    settingsDao = SettingsDao(dbHelper: dbHelper);
    provider = AiAssistantProvider(settingsDao: settingsDao);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  HealthReport makeReport(int score, DateTime at) => HealthReport(
        generatedAt: at,
        currentOverview: '概览',
        cycleStats: [],
        cycleTrendSummary: '',
        symptomTrends: [],
        comparisonTrends: [],
        attentions: [],
        nextCycleSuggestions: [],
        medicalReminders: [],
        conclusion: '总结',
        healthScore: score,
      );

  group('AiAssistantProvider - report history', () {
    test('cacheReport 按时间升序追加评分历史条目', () {
      final at1 = DateTime(2026, 8, 1, 10, 30);
      final at2 = DateTime(2026, 9, 1, 10, 30);

      provider.cacheReport(makeReport(80, at1),
          modelId: 'glm-4-flash', dataVersion: 1);
      provider.cacheReport(makeReport(85, at2),
          modelId: 'ling-3.0-flash-sante:free', dataVersion: 2);

      final history = provider.reportHistory;
      expect(history, hasLength(2));
      expect(history.first.score, 80);
      expect(history.first.generatedAt, at1);
      expect(history.first.modelId, 'glm-4-flash');
      expect(history.last.score, 85);
      expect(history.last.modelId, 'ling-3.0-flash-sante:free');
    });

    test('报告历史持久化往返（写入 → 重新加载恢复）', () async {
      provider.cacheReport(makeReport(80, DateTime(2026, 8, 1)),
          modelId: 'glm-4-flash', dataVersion: 1);
      provider.cacheReport(makeReport(88, DateTime(2026, 9, 1)),
          modelId: 'glm-4-flash', dataVersion: 2);

      // 持久化是 fire-and-forget，冲刷事件队列等待落库完成
      await pumpEventQueue();

      final restored = AiAssistantProvider(settingsDao: settingsDao);
      await restored.ensureLoaded();

      expect(restored.reportHistory, hasLength(2));
      expect(restored.reportHistory.first.score, 80);
      expect(restored.reportHistory.last.score, 88);
      expect(
        restored.reportHistory.last.generatedAt,
        DateTime(2026, 9, 1),
      );
    });

    test('历史条目达到上限 30 条后丢弃最旧条目', () {
      // 写入 35 条，分数 1..35
      for (int i = 1; i <= 35; i++) {
        provider.cacheReport(makeReport(i, DateTime(2026, 1, 1).add(Duration(days: i))),
            modelId: 'glm-4-flash', dataVersion: i);
      }

      final history = provider.reportHistory;
      expect(history, hasLength(AiAssistantProvider.maxPersistedReportHistory));
      // 最旧的 5 条（分数 1~5）被丢弃
      expect(history.first.score, 6);
      expect(history.last.score, 35);
    });

    test('clearCachedReport 只清当前报告缓存，不清历史', () {
      provider.cacheReport(makeReport(80, DateTime(2026, 8, 1)),
          modelId: 'glm-4-flash', dataVersion: 1);

      provider.clearCachedReport();

      expect(provider.cachedReport, isNull);
      expect(provider.reportHistory, hasLength(1));
      expect(provider.reportHistory.first.score, 80);
    });

    test('reportHistory 返回不可变视图', () {
      provider.cacheReport(makeReport(80, DateTime(2026, 8, 1)),
          modelId: 'glm-4-flash', dataVersion: 1);

      expect(
        () => provider.reportHistory.add(
          ReportHistoryEntry(
            generatedAt: DateTime(2026, 9, 1),
            score: 90,
            modelId: 'glm-4-flash',
          ),
        ),
        throwsUnsupportedError,
      );
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
