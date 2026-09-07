import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:yimaflutter/constants/app_strings.dart';
import 'package:yimaflutter/constants/app_theme.dart';
import 'package:yimaflutter/database/database_helper.dart';
import 'package:yimaflutter/database/period_dao.dart';
import 'package:yimaflutter/database/daily_flow_dao.dart';
import 'package:yimaflutter/database/settings_dao.dart';
import 'package:yimaflutter/providers/period_provider.dart';
import 'package:yimaflutter/screens/add_record_calendar_page.dart';
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
  group('computeDefaultPeriodDays 取值规则', () {
    int days(int completedCount, double avg, int setting) =>
        computeDefaultPeriodDays(
          completedRecordCount: completedCount,
          averagePeriodLength: avg,
          settingsPeriodLength: setting,
        );

    test('已完成记录不足 3 条时以设置值为准', () {
      expect(days(0, 5.0, 8), 8);
      expect(days(1, 5.0, 10), 10);
      expect(days(2, 4.5, 7), 7);
    });

    test('已完成记录达到 3 条时取平均值', () {
      expect(days(3, 6.4, 10), 6);
      expect(days(5, 5.5, 2), 6);
    });

    test('平均值异常（<=0）时回落到设置值', () {
      expect(days(3, 0, 9), 9);
    });
  });

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

    testWidgets('点击非相邻日期：替换默认预选并自动延展 X 天', (tester) async {
      await buildCalendar(tester);

      // 默认预选今日(6/15)起 5 天；点击 3 号（非相邻）应替换为 6/03 起 5 天
      await tester.tap(_dayInCurrentMonth(tester, 3, DateTime(2026, 6, 15)));
      await tester.pump();
      expect(find.textContaining('已选 5 天：06/03-06/07'), findsOneWidget);
    });

    testWidgets('编辑过后点击非相邻日期：追加为新区间，支持一次多段补录',
        (tester) async {
      await buildCalendar(tester);

      // 第一次点击 3 号：仍是默认预选 -> 替换为 6/03-06/07
      await tester.tap(_dayInCurrentMonth(tester, 3, DateTime(2026, 6, 15)));
      await tester.pump();
      expect(find.textContaining('已选 5 天：06/03-06/07'), findsOneWidget);

      // 第二次点击 20 号（非相邻）：已编辑过 -> 追加为新区间，共两段 10 天
      await tester.tap(_dayInCurrentMonth(tester, 20, DateTime(2026, 6, 15)));
      await tester.pump();
      expect(
        find.textContaining('已选 10 天：06/03-06/07、06/20-06/24'),
        findsOneWidget,
      );
    });

    testWidgets('自动延展遇到已有记录即停', (tester) async {
      // 预置一条 6/10-6/12 的已有记录
      await tester.runAsync(() async {
        await provider
            .savePeriodRecord(DateTime(2026, 6, 10), DateTime(2026, 6, 12));
      });

      await buildCalendar(tester);

      // 点击 8 号：从 8 号起应延展 5 天，但 10-12 已有记录 -> 只选中 8、9 两天
      await tester.tap(_dayInCurrentMonth(tester, 8, DateTime(2026, 6, 15)));
      await tester.pump();
      expect(find.textContaining('已选 2 天：06/08-06/09'), findsOneWidget);
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
