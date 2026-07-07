import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Abstract interface for providing a database connection.
/// Allows mocking in tests.
abstract class DatabaseProvider {
  Future<Database> get database;
}

class DatabaseHelper implements DatabaseProvider {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  /// Current database version. Increment when schema changes.
  static const int _dbVersion = 1;

  @override
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
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
    await _seedSettings(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Incrementally apply migrations as new versions are introduced.
    //
    // Example for future migrations:
    //   if (oldVersion < 2) {
    //     await db.execute('ALTER TABLE period_records ADD COLUMN flow TEXT');
    //   }
    //   if (oldVersion < 3) {
    //     await db.execute('ALTER TABLE period_records ADD COLUMN tag TEXT');
    //   }
  }

  Future<void> _createTables(Database db) async {
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

  Future<void> _seedSettings(Database db) async {
    await db.insert('settings', {'key': 'avg_cycle_length', 'value': '28'});
    await db.insert('settings', {'key': 'avg_period_length', 'value': '5'});
    await db.insert('settings', {'key': 'reminder_days', 'value': '2'});
    await db.insert('settings', {'key': 'reminder_hour', 'value': '9'});
    await db.insert(
        'settings', {'key': 'prediction_algorithm', 'value': 'simple'});
  }

  Future<void> close() async {
    final db = await database;
    db.close();
    _database = null;
  }
}
