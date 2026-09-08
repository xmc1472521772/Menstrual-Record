import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:yimaflutter/constants/app_theme.dart';
import 'package:yimaflutter/database/database_helper.dart';
import 'package:yimaflutter/database/period_dao.dart';
import 'package:yimaflutter/database/daily_flow_dao.dart';
import 'package:yimaflutter/database/settings_dao.dart';
import 'package:yimaflutter/providers/period_provider.dart';
import 'package:yimaflutter/providers/settings_provider.dart';
import 'package:yimaflutter/screens/home_screen.dart';

/// 首页（日历）在「无记录 / 有经期记录」两种形态下都能正常构建与滚动，
/// 覆盖状态卡渐变版、日历格子填充、快速操作等关键渲染路径的回归保护。
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late PeriodProvider provider;
  late SettingsProvider settingsProvider;
  late _TestDatabaseProvider dbHelper;

  Future<void> buildHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PeriodProvider>.value(value: provider),
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

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
      },
    );

    // 防止通知插件抛 MissingPluginException
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async => null,
    );

    dbHelper = _TestDatabaseProvider(db);
    settingsProvider = SettingsProvider(
      settingsDao: SettingsDao(dbHelper: dbHelper),
    );
    await settingsProvider.ensureLoaded();
    provider = PeriodProvider(
      periodDao: PeriodDao(dbHelper: dbHelper),
      flowDao: DailyFlowDao(dbHelper: dbHelper),
      settingsDao: SettingsDao(dbHelper: dbHelper),
      scheduleReminders: false,
      autoEndExpiredPeriods: false,
    );
    await provider.loadRecords();
  });

  tearDown(() async {
    await dbHelper.close();
  });

  testWidgets('无记录时正常渲染：状态卡 + 日历 + 快速操作', (tester) async {
    await buildHome(tester);

    expect(find.text('月事记'), findsOneWidget);
    // 开始 / 结束经期两个快捷按钮
    expect(find.text('开始经期'), findsOneWidget);
    expect(find.text('结束经期'), findsOneWidget);
    // 日历标题存在（当前年月）
    final now = DateTime.now();
    expect(
      find.text('${now.year}年${now.month}月'),
      findsOneWidget,
    );
    // 图例
    expect(find.text('经期中'), findsOneWidget);
  });

  testWidgets('存在经期记录时：状态卡切换为渐变版，上下滚动流畅无异常',
      (tester) async {
    await buildHome(tester);

    // 通过快捷操作新增一条进行中的经期记录（DB 写入为真实异步，需 runAsync）
    await tester.runAsync(() async {
      await tester.tap(find.text('开始经期'));
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pumpAndSettle();

    expect(provider.records, hasLength(1));
    expect(provider.hasOngoingPeriod, isTrue);
    // 状态卡从空态切换到「经期进行中」文案
    expect(find.text('经期进行中'), findsWidgets);

    // 日历「今天」格子应有经期填充（白色字/加粗的数字仍渲染为 Text）
    final now = DateTime.now();
    expect(find.text('${now.day}'), findsWidgets);

    // 反复上下滚动整页，验证含记录的渐变状态卡渲染路径下无异常/卡死
    for (var i = 0; i < 3; i++) {
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -160),
      );
      await tester.pump();
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, 160),
      );
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
    expect(find.text('经期进行中'), findsWidgets);
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
