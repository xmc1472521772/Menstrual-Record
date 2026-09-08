import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import '../models/period_record.dart';

class PeriodDao {
  final DatabaseProvider _dbHelper;

  /// Allows injecting a [DatabaseProvider] for testing; defaults to the singleton.
  PeriodDao({DatabaseProvider? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  Future<int> insert(PeriodRecord record) async {
    try {
      final db = await _dbHelper.database;
      return await db.insert('period_records', record.toMap());
    } catch (e) {
      throw Exception('Failed to insert period record: $e');
    }
  }

  Future<int> update(PeriodRecord record) async {
    try {
      final db = await _dbHelper.database;
      return await db.update(
        'period_records',
        record.toMap(),
        where: 'id = ?',
        whereArgs: [record.id],
      );
    } catch (e) {
      throw Exception('Failed to update period record: $e');
    }
  }

  Future<int> delete(int id) async {
    try {
      final db = await _dbHelper.database;
      return await db.delete(
        'period_records',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw Exception('Failed to delete period record: $e');
    }
  }

  Future<PeriodRecord?> getById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'period_records',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return PeriodRecord.fromMap(maps.first);
  }

  Future<List<PeriodRecord>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'period_records',
      orderBy: 'start_date DESC',
    );
    return maps.map((map) => PeriodRecord.fromMap(map)).toList();
  }

  /// Queries records whose start_date falls within [start, end].
  ///
  /// Dates are stored as 'yyyy-MM-dd' strings (no time component), so we
  /// format the query parameters the same way to ensure correct string
  /// comparison.
  Future<List<PeriodRecord>> getByDateRange(DateTime start, DateTime end) async {
    final db = await _dbHelper.database;
    final startStr = _formatDate(start);
    final endStr = _formatDate(end);
    final maps = await db.query(
      'period_records',
      where: 'start_date >= ? AND start_date <= ?',
      whereArgs: [startStr, endStr],
      orderBy: 'start_date DESC',
    );
    return maps.map((map) => PeriodRecord.fromMap(map)).toList();
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}'
        '-${date.month.toString().padLeft(2, '0')}'
        '-${date.day.toString().padLeft(2, '0')}';
  }

  Future<PeriodRecord?> getLatest() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'period_records',
      orderBy: 'start_date DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return PeriodRecord.fromMap(maps.first);
  }

  Future<int> deleteAll() async {
    final db = await _dbHelper.database;
    return await db.delete('period_records');
  }

  Future<void> insertAll(List<PeriodRecord> records) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final record in records) {
      batch.insert('period_records', record.toMap());
    }
    await batch.commit(noResult: true);
  }

  /// Atomically replaces all records with [records] in a single transaction.
  ///
  /// If insertion fails, the original data is preserved.
  /// 传入 [txn] 时在调用方的外层事务内执行（用于跨表原子导入），否则自建事务。
  Future<void> replaceAll(List<PeriodRecord> records, {Transaction? txn}) async {
    Future<void> body(DatabaseExecutor executor) async {
      await executor.delete('period_records');
      for (final record in records) {
        await executor.insert('period_records', record.toMap());
      }
    }

    if (txn != null) return body(txn);
    final db = await _dbHelper.database;
    await db.transaction(body);
  }
}
