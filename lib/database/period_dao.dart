import 'database_helper.dart';
import '../models/period_record.dart';

class PeriodDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

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

  Future<List<PeriodRecord>> getByDateRange(DateTime start, DateTime end) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'period_records',
      where: 'start_date >= ? AND start_date <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'start_date DESC',
    );
    return maps.map((map) => PeriodRecord.fromMap(map)).toList();
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
}
