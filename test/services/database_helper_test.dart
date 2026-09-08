import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:yimaflutter/database/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  /// 手工构造 v1 结构：无索引、无 flow_level 列、无 daily_flows 表，
  /// 对应 DatabaseHelper._dbVersion == 1 时代的真实 schema。
  Future<void> createV1Schema() async {
    await db.execute('''
      CREATE TABLE period_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_date TEXT NOT NULL,
        end_date TEXT,
        cycle_length INTEGER,
        period_length INTEGER,
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
  }

  setUp(() async {
    db = await openDatabase(inMemoryDatabasePath);
    await createV1Schema();
  });

  tearDown(() async {
    await db.close();
  });

  group('DatabaseHelper.debugUpgrade 迁移测试', () {
    test('1→4 补齐索引、flow_level 列与 daily_flows 表，旧数据保留', () async {
      // 迁移前写入一行 v1 时代的记录（无 flow_level 列）
      await db.insert('period_records', {
        'start_date': '2026-08-01',
        'end_date': '2026-08-05',
        'cycle_length': 28,
        'period_length': 5,
        'created_at': 1754000000000,
      });

      await DatabaseHelper().debugUpgrade(db, 1, 4);

      // 索引已创建
      final indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' "
        "AND name='idx_period_start_date'",
      );
      expect(indexes, isNotEmpty);

      // flow_level 列已添加
      final columns = await db.rawQuery('PRAGMA table_info(period_records)');
      expect(columns.map((c) => c['name']), contains('flow_level'));

      // daily_flows 表已创建
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name='daily_flows'",
      );
      expect(tables, isNotEmpty);

      // 迁移不丢数据
      final rows = await db.query('period_records');
      expect(rows, hasLength(1));
      expect(rows.first['start_date'], '2026-08-01');
    });

    test('2→4 执行 v3/v4 迁移：补 flow_level 列与 daily_flows 表', () async {
      // v2 结构：已有索引（v1→v2 迁移的产物），
      // 尚无 flow_level 列（v3）与 daily_flows 表（v4）
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_period_start_date '
        'ON period_records (start_date)',
      );

      await DatabaseHelper().debugUpgrade(db, 2, 4);

      // flow_level 已添加且仅一列
      final columns = await db.rawQuery('PRAGMA table_info(period_records)');
      expect(
        columns.map((c) => c['name']).where((n) => n == 'flow_level'),
        hasLength(1),
      );

      // daily_flows 已创建
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name='daily_flows'",
      );
      expect(tables, isNotEmpty);

      // 迁移中重复 CREATE INDEX 因 IF NOT EXISTS 幂等不报错
      final indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' "
        "AND name='idx_period_start_date'",
      );
      expect(indexes, hasLength(1));
    });

    test('4→4 版本相同时不执行任何迁移动作', () async {
      await DatabaseHelper().debugUpgrade(db, 4, 4);

      // v1 起点的库未被改动：daily_flows 不应存在
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name='daily_flows'",
      );
      expect(tables, isEmpty);
    });
  });
}
