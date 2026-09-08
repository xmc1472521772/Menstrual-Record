import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import '../models/daily_flow.dart';

class DailyFlowDao {
  final DatabaseProvider _dbHelper;

  /// Allows injecting a [DatabaseProvider] for testing; defaults to the singleton.
  DailyFlowDao({DatabaseProvider? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  /// 插入或更新某天的经量记录（upsert）。
  Future<void> upsert(DailyFlow flow) async {
    final db = await _dbHelper.database;
    await db.insert(
      'daily_flows',
      flow.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 删除某天的经量记录。
  Future<void> delete(String date) async {
    final db = await _dbHelper.database;
    await db.delete(
      'daily_flows',
      where: 'date = ?',
      whereArgs: [date],
    );
  }

  /// 获取所有经量记录，按日期正序排列。
  Future<List<DailyFlow>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'daily_flows',
      orderBy: 'date ASC',
    );
    return maps.map((map) => DailyFlow.fromMap(map)).toList();
  }

  /// 获取指定日期的经量记录。
  Future<DailyFlow?> getByDate(String date) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'daily_flows',
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return DailyFlow.fromMap(maps.first);
  }

  /// 获取指定年份的所有经量记录。
  Future<List<DailyFlow>> getByYear(int year) async {
    final db = await _dbHelper.database;
    final startStr = '$year-01-01';
    final endStr = '$year-12-31';
    final maps = await db.query(
      'daily_flows',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startStr, endStr],
      orderBy: 'date ASC',
    );
    return maps.map((map) => DailyFlow.fromMap(map)).toList();
  }

  /// 删除所有经量记录。
  Future<int> deleteAll() async {
    final db = await _dbHelper.database;
    return await db.delete('daily_flows');
  }

  /// 原子替换：先删全部再批量插入。
  /// 用于导入覆盖模式。
  /// 传入 [txn] 时在调用方的外层事务内执行（用于跨表原子导入），否则自建事务。
  Future<void> replaceAll(List<DailyFlow> flows, {Transaction? txn}) async {
    Future<void> body(DatabaseExecutor executor) async {
      await executor.delete('daily_flows');
      for (final f in flows) {
        await executor.insert(
          'daily_flows',
          f.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }

    if (txn != null) return body(txn);
    final db = await _dbHelper.database;
    await db.transaction(body);
  }

  /// 批量插入（追加模式，遇到重复日期则替换）。
  Future<void> insertAll(List<DailyFlow> flows) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      for (final f in flows) {
        await txn.insert(
          'daily_flows',
          f.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}
