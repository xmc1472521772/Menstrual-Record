import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Abstract interface for providing a database connection.
/// Allows mocking in tests.
abstract class DatabaseProvider {
  Future<Database> get database;

  /// 强制刷新数据库连接。
  /// 默认空实现，只有 [DatabaseHelper] 真正需要刷新。
  Future<void> refreshConnection() async {}
}

class DatabaseHelper implements DatabaseProvider {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static Completer<Database>? _initCompleter;
  static bool _isClosing = false;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  /// Current database version. Increment when schema changes.
  static const int _dbVersion = 4;

  @override
  Future<Database> get database async {
    if (_database != null) return _database!;
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<Database>();
    try {
      _database = await _initDatabase();
      _initCompleter!.complete(_database!);
      return _database!;
    } catch (e, st) {
      final completer = _initCompleter;
      _initCompleter = null;
      if (completer != null && !completer.isCompleted) {
        completer.completeError(e, st);
        // 若无并发等待者，ignore 兜底防止 unhandled exception
        completer.future.ignore();
      }
      rethrow;
    }
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
    if (oldVersion < 2) {
      // Add index on start_date for faster range queries (getByDateRange)
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_period_start_date ON period_records (start_date)');
    }
    if (oldVersion < 3) {
      // Add flow_level column for menstrual flow intensity (1=light, 2=normal, 3=heavy)
      await db.execute(
          'ALTER TABLE period_records ADD COLUMN flow_level INTEGER');
    }
    if (oldVersion < 4) {
      // Create daily_flows table for per-day menstrual flow tracking
      await db.execute('''
        CREATE TABLE IF NOT EXISTS daily_flows (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL UNIQUE,
          flow_level INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }
  }

  /// 仅供测试：对人工构造的低版本库重放迁移步骤（P1-4/T9）。
  ///
  /// 绕过 openDatabase 的 user_version 管理，让迁移测试可以直接
  /// 验证 [_onUpgrade] 每一步的 DDL 与数据兼容性。
  @visibleForTesting
  Future<void> debugUpgrade(Database db, int oldVersion, int newVersion) {
    return _onUpgrade(db, oldVersion, newVersion);
  }

  Future<void> _createTables(Database db) async {
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

    // Index on start_date for faster range queries
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_period_start_date ON period_records (start_date)');

    // Daily flow table for per-day menstrual flow tracking
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_flows (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL UNIQUE,
        flow_level INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _seedSettings(Database db) async {
    await db.insert('settings', {'key': 'avg_cycle_length', 'value': '28'});
    await db.insert('settings', {'key': 'avg_period_length', 'value': '5'});
    await db.insert('settings', {'key': 'reminder_days', 'value': '2'});
    await db.insert('settings', {'key': 'reminder_hour', 'value': '9'});
    await db.insert(
        'settings', {'key': 'prediction_algorithm', 'value': 'adaptive'});
    await db.insert(
        'settings', {'key': 'merge_threshold', 'value': '2'});
  }

  Future<void> close() async {
    if (_isClosing) return;
    _isClosing = true;
    try {
      // 先置空再关闭：关闭期间新来的 database getter 会走重建路径，
      // 而不是拿到一个正在关闭的连接
      final db = _database;
      _database = null;
      _initCompleter = null;
      if (db != null) {
        try {
          await db.close();
        } catch (_) {
          // 关闭失败（如原生端并发已关闭）不应阻塞重建
        }
      }
    } finally {
      _isClosing = false;
    }
  }

  /// 强制刷新数据库连接。
  ///
  /// 当原生端（小组件）通过另一个 SQLiteDatabase 连接直接修改了数据库时，
  /// Flutter 端的 sqflite 连接可能读到缓存的旧数据。
  /// 调用此方法关闭并重新打开连接，确保后续读取能获取最新数据。
  @override
  Future<void> refreshConnection() async {
    if (_isClosing) return;
    _isClosing = true;
    try {
      // 先置空再关闭：关闭期间新来的 database getter 会走重建路径，
      // 而不是拿到一个正在关闭的连接
      final db = _database;
      _database = null;
      _initCompleter = null;
      if (db != null) {
        try {
          await db.close();
        } catch (_) {
          // 关闭失败（如原生端并发已关闭）不应阻塞重建
        }
      }
    } finally {
      _isClosing = false;
    }
    // 重新初始化连接（通过 database getter 触发）
    await database;
  }
}
