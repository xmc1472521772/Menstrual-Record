import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:yimaflutter/constants/app_strings.dart';
import 'package:yimaflutter/constants/app_theme.dart';
import 'package:yimaflutter/database/database_helper.dart';
import 'package:yimaflutter/database/period_dao.dart';
import 'package:yimaflutter/database/settings_dao.dart';
import 'package:yimaflutter/providers/period_provider.dart';
import 'package:yimaflutter/screens/record_screen.dart';

/// 日历打开后会自动滚动到当前月，整棵树里会出现多个 "15"。
/// 这里把查找范围限定到 [today] 所在月份（其 KeyedSubtree 的 ValueKey），
/// 避免误选中屏幕外其它月份的格子。
Finder _dayInCurrentMonth(WidgetTester tester, int day, DateTime today) {
  final monthKey = ValueKey<String>('${today.year}-${today.month}');
  return find.descendant(
    of: find.byKey(monthKey),
    matching: find.text('$day'),
  );
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late PeriodProvider provider;
  late _TestDatabaseProvider dbHelper;

  Future<void> buildCalendar(WidgetTester tester) async {
    // 给足高度，保证当前月能完整渲染
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: AddRecordCalendarPage(
          provider: provider,
          defaultDays: 5,
          today: DateTime(2026, 6, 15),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
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
    provider = PeriodProvider(
      periodDao: PeriodDao(dbHelper: dbHelper),
      settingsDao: SettingsDao(dbHelper: dbHelper),
      scheduleReminders: false,
      autoEndExpiredPeriods: false,
    );
    await provider.loadRecords();
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('AddRecordCalendarPage 交互', () {
    testWidgets('首屏可正常渲染并默认预选今日区间', (tester) async {
      await buildCalendar(tester);

      expect(find.text('添加经期记录'), findsOneWidget);
      expect(find.text(AppStrings.confirm), findsOneWidget);
      // 打开即预选今日(6/15)起 defaultDays=5 天，底部即时显示已选摘要
      expect(find.textContaining('已选 5 天'), findsOneWidget);
    });

    testWidgets('打开即预选默认区间，点击可增减/取消单日', (tester) async {
      await buildCalendar(tester);

      // 默认已选 5 天
      expect(find.textContaining('已选 5 天'), findsOneWidget);

      final dayCell = _dayInCurrentMonth(tester, 15, DateTime(2026, 6, 15));
      // 点击已选中的 15 号 -> 取消该天，剩 4 天
      await tester.tap(dayCell);
      await tester.pump();
      expect(find.textContaining('已选 4 天'), findsOneWidget);

      // 再次点击 15 号 -> 重新加入，恢复 5 天
      await tester.tap(_dayInCurrentMonth(tester, 15, DateTime(2026, 6, 15)));
      await tester.pump();
      expect(find.textContaining('已选 5 天'), findsOneWidget);
    });

    testWidgets('确定后返回选中区间，且写入数据库', (tester) async {
      final ranges = <(DateTime, DateTime)>[];

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final result =
                    await Navigator.push<List<(DateTime, DateTime)>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddRecordCalendarPage(
                      provider: provider,
                      defaultDays: 3,
                      today: DateTime(2026, 6, 15),
                    ),
                  ),
                );
                if (result != null) ranges.addAll(result);
              },
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // 默认已预选 3 天，直接「确定」即保存（验证一键保存路径）
      await tester.tap(find.text(AppStrings.confirm));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('open'), findsOneWidget);
      expect(ranges, hasLength(1));

      // 页面已关闭；在测试体内显式落库并断言。
      // 注意：sqflite_ffi 的 DB 写入是真实异步操作，testWidgets 的 FakeAsync
      // 时钟不会推进它，直接 await 会挂到用例超时。必须放进 tester.runAsync
      // 的真实事件循环里执行；且 DB 写入后不要再 pump（会持续调度帧导致挂起，
      // 真机无此问题），这里只在 saveMultipleRecords 返回后同步断言 provider 状态。
      final success =
          await tester.runAsync(() => provider.saveMultipleRecords(ranges));
      expect(success, isTrue);
      expect(provider.records, hasLength(1));
      expect(provider.records.first.periodDays, 3);
    });
  });
}

class _TestDatabaseProvider implements DatabaseProvider {
  final Database _db;

  _TestDatabaseProvider(this._db);

  @override
  Future<Database> get database => Future.value(_db);

  Future<void> close() async {
    await _db.close();
  }
}
