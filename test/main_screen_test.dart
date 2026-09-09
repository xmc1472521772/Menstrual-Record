import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:yimaflutter/providers/period_provider.dart';
import 'package:yimaflutter/providers/settings_provider.dart';
import 'package:yimaflutter/providers/ai_assistant_provider.dart';
import 'package:yimaflutter/screens/main_screen.dart';
import 'package:yimaflutter/constants/app_strings.dart';
import 'package:yimaflutter/constants/app_theme.dart';

/// E3：主界面壳层（main_screen.dart）基础 widget 测试。
/// 覆盖：4 tab 同时保活（IndexedStack）、tab 切换、首页通知按钮
/// 经回调跳转设置页（D4 解耦后的导航路径）。
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Mock the local notifications channel to prevent MissingPluginException
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async => null,
    );
  });

  Future<void> pumpMainScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PeriodProvider>(create: (_) => PeriodProvider()),
          ChangeNotifierProvider<SettingsProvider>(create: (_) => SettingsProvider()),
          ChangeNotifierProvider<AiAssistantProvider>(
              create: (_) => AiAssistantProvider()),
        ],
        // 挂 AppTheme：页面通过 context.themeColors 读取 ThemeExtension
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MainScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('IndexedStack 保活：四个 tab 的内容同时挂在树上',
      (tester) async {
    await pumpMainScreen(tester);

    // IndexedStack 的非选中子树在元素树中保活（状态不丢），但默认 finder
    // 会跳过未上屏内容 → 用 skipOffstage: false 验证"同时挂在树上"。
    // 首页 AppBar 标题（当前选中 tab）
    expect(find.text(AppStrings.appName), findsOneWidget);
    // 记录页（保活在树上，未上屏）
    expect(find.text(AppStrings.addPeriodRecord, skipOffstage: false),
        findsOneWidget);
    // 统计页 Tab 标签
    expect(find.text(AppStrings.statsTabOverview, skipOffstage: false),
        findsOneWidget);
    // 设置页分区标题
    expect(find.text(AppStrings.cycleParams, skipOffstage: false),
        findsOneWidget);
  });

  testWidgets('底部导航切换：点击「统计」后统计内容可见且首页仍在树上',
      (tester) async {
    await pumpMainScreen(tester);

    await tester.tap(find.text(AppStrings.stats));
    await tester.pumpAndSettle();

    // 统计页当前上屏
    expect(find.text(AppStrings.statsTabOverview), findsOneWidget);
    // 首页 AppBar 依旧保活（未上屏但在树上 → skipOffstage: false）
    expect(find.text(AppStrings.appName, skipOffstage: false),
        findsOneWidget);
  });

  testWidgets('D4：首页通知按钮经注入回调跳转到设置页', (tester) async {
    await pumpMainScreen(tester);

    // 首页 AppBar 的通知按钮（tooltip = 打开提醒设置）
    await tester.tap(find.byTooltip(AppStrings.notificationTooltip));
    await tester.pumpAndSettle();

    // 设置页置顶（当前 tab），其周期参数区块正常渲染
    expect(find.text(AppStrings.cycleParams), findsOneWidget);
    // 「设置」出现两处：AppBar 标题 + 底部导航项（选中态白字）
    expect(find.text(AppStrings.settings), findsNWidgets(2));
  });
}
