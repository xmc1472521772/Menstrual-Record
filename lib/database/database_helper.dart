import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'yima_period.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
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

    await db.insert('settings', {'key': 'avg_cycle_length', 'value': '28'});
    await db.insert('settings', {'key': 'avg_period_length', 'value': '5'});
    await db.insert('settings', {'key': 'reminder_days', 'value': '2'});
    await db.insert('settings', {'key': 'reminder_hour', 'value': '9'});
    await db.insert('settings', {'key': 'prediction_algorithm', 'value': 'simple'});
  }

  Future<void> close() async {
    final db = await database;
    db.close();
    _database = null;
  }
}
