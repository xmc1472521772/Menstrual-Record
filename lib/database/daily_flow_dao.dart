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
}
