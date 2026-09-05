import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class SettingsDao {
  final DatabaseProvider _dbHelper;

  /// Allows injecting a [DatabaseProvider] for testing; defaults to the singleton.
  SettingsDao({DatabaseProvider? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  Future<String?> getValue(String key) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isEmpty) return null;
    return maps.first['value'] as String;
  }

  Future<void> setValue(String key, String value) async {
    final db = await _dbHelper.database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, String>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query('settings');
    final result = <String, String>{};
    for (final map in maps) {
      result[map['key'] as String] = map['value'] as String;
    }
    return result;
  }

  Future<int> getCycleLength() async {
    final value = await getValue('avg_cycle_length');
    return int.tryParse(value ?? '28') ?? 28;
  }

  Future<int> getPeriodLength() async {
    final value = await getValue('avg_period_length');
    return int.tryParse(value ?? '5') ?? 5;
  }

  Future<int> getReminderDays() async {
    final value = await getValue('reminder_days');
    return int.tryParse(value ?? '2') ?? 2;
  }

  Future<int> getReminderHour() async {
    final value = await getValue('reminder_hour');
    return int.tryParse(value ?? '9') ?? 9;
  }

  Future<String> getPredictionAlgorithm() async {
    final value = await getValue('prediction_algorithm');
    // 兼容旧版：'weighted' 统一映射为 'adaptive'
    if (value == 'weighted') return 'adaptive';
    return value ?? 'adaptive';
  }

  /// 合并阈值（天数）。两次经期结束与开始间隔 <= 此值时触发合并逻辑。
  /// 默认 2 天。
  Future<int> getMergeThreshold() async {
    final value = await getValue('merge_threshold');
    return int.tryParse(value ?? '2') ?? 2;
  }
}
