import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:yimaflutter/providers/period_provider.dart';
import 'package:yimaflutter/database/period_dao.dart';
import 'package:yimaflutter/database/daily_flow_dao.dart';
import 'package:yimaflutter/database/settings_dao.dart';
import 'package:yimaflutter/database/database_helper.dart';

/// 导入/导出功能测试（T9）。
///
/// 覆盖 PeriodProvider.exportData / importData 的核心契约：
/// 新旧两种 JSON 格式、追加模式的重叠过滤、覆盖模式的整体替换、
/// 以及非法输入的容错。
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late PeriodProvider provider;
  late _TestDatabaseProvider dbHelper;
  late PeriodDao periodDao;
  late DailyFlowDao dailyFlowDao;
  late SettingsDao settingsDao;

  setUp(() async {
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

    // 屏蔽通知插件通道，防止调度提醒时抛 MissingPluginException
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async => null,
    );
    // 屏蔽小组件通道
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.yima.yimaflutter/widget'),
      (call) async => null,
    );

    dbHelper = _TestDatabaseProvider(db);
    periodDao = PeriodDao(dbHelper: dbHelper);
    dailyFlowDao = DailyFlowDao(dbHelper: dbHelper);
    settingsDao = SettingsDao(dbHelper: dbHelper);

    provider = PeriodProvider(
      periodDao: periodDao,
      flowDao: dailyFlowDao,
      settingsDao: settingsDao,
      // overwrite 导入的事务直接在 dbProvider 上开，必须与 DAO 同库
      dbProvider: dbHelper,
      scheduleReminders: false,
      autoEndExpiredPeriods: false,
    );

    await provider.loadRecords();
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('exportData / importData roundtrip（覆盖模式）', () {
    test('导出的 JSON 重新导入后记录一致，含每日经量', () async {
      // 准备数据：一条已结束 + 一条进行中 + 一条每日经量
      await provider.startPeriod(DateTime(2026, 9, 1));
      await provider.endPeriod(DateTime(2026, 9, 5));
      await provider.startPeriod(DateTime(2026, 10, 1));
      await provider.setDailyFlow(DateTime(2026, 9, 2), 2);
      expect(provider.records, hasLength(2));

      final exported = await provider.exportData();
      final decoded = jsonDecode(exported) as Map<String, dynamic>;
      expect(decoded, containsPair('periods', isA<List>()));
      expect(decoded, containsPair('dailyFlows', isA<List>()));
      expect(decoded['dailyFlows'], hasLength(1));

      // 覆盖模式导入（数据先清空再写入，仍应还原出同样的记录集）
      final ok = await provider.importData(exported, overwrite: true);
      expect(ok, isTrue);

      final starts = provider.records.map((r) => r.startDate).toSet();
      expect(starts, {'2026-09-01', '2026-10-01'});
      final sepRecord = provider.records
          .firstWhere((r) => r.startDate == '2026-09-01');
      expect(sepRecord.endDate, '2026-09-05');
    });
  });

  group('importData 旧版格式与追加模式', () {
    test('旧版纯数组格式（无 periods/dailyFlows 包装）可导入', () async {
      final legacyJson = jsonEncode([
        {
          'startDate': '2026-07-01',
          'endDate': '2026-07-05',
          'createdAt': 1000,
        },
      ]);

      final ok = await provider.importData(legacyJson);
      expect(ok, isTrue);
      expect(provider.records, hasLength(1));
      expect(provider.records.first.startDate, '2026-07-01');
    });

    test('追加模式跳过与现有记录重叠的区间，只导入不重叠的', () async {
      // 库中已有 8/1 - 8/5
      await provider.startPeriod(DateTime(2026, 8, 1));
      await provider.endPeriod(DateTime(2026, 8, 5));

      final importJson = jsonEncode({
        'periods': [
          // 与 8/1-8/5 重叠（8/3 落在其中）→ 应被跳过
          {
            'startDate': '2026-08-03',
            'endDate': '2026-08-07',
            'createdAt': 2000,
          },
          // 与现有记录不重叠 → 应被导入
          {
            'startDate': '2026-06-01',
            'endDate': '2026-06-05',
            'createdAt': 3000,
          },
        ],
        'dailyFlows': <Map<String, dynamic>>[],
      });

      final ok = await provider.importData(importJson);
      expect(ok, isTrue);
      expect(provider.records, hasLength(2));
      final starts = provider.records.map((r) => r.startDate).toSet();
      expect(starts, {'2026-08-01', '2026-06-01'});
    });
  });

  group('importData 容错', () {
    test('非法 JSON 字符串返回 false 且不改变现有数据', () async {
      await provider.startPeriod(DateTime(2026, 8, 1));
      await provider.endPeriod(DateTime(2026, 8, 5));

      expect(await provider.importData('not-json{'), isFalse);
      expect(await provider.importData('"scalar-only"'), isFalse);
      expect(provider.records, hasLength(1));
    });

    test('超出 10MB 限制的 JSON 返回 false', () async {
      final tooLarge = '0' * (10 * 1024 * 1024 + 1);
      expect(await provider.importData(tooLarge), isFalse);
    });
  });
}

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
