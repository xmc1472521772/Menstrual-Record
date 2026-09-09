import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/period_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/ai_assistant_provider.dart';
import 'screens/splash_screen.dart';
import 'services/widget_service.dart';
import 'constants/app_strings.dart';
import 'constants/app_theme.dart';

/// 应用根装配（E5 职责收敛）：只负责 Provider 装配、MaterialApp 配置、
/// 小组件数据变更回调与全局字体缩放钳制；导航壳 UI 已迁至
/// `screens/main_screen.dart`。
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  /// 直接持有的 Provider 实例。
  ///
  /// 注意：不能在生命周期回调里用 `context.read<PeriodProvider>()` 获取
  /// Provider —— 本 State 的 context 位于 MultiProvider 之上，向上查找
  /// 永远找不到 Provider，会抛 ProviderNotFoundException 并被静默吞掉。
  /// 这曾导致小组件 → App 的全部同步路径（dataChanged 通知、恢复前台
  /// dirty 检查、启动检查）静默失效：小组件改了经量，回到 App 仍显示
  /// 旧值。改为在 initState 中创建实例并以 `.value` 注入 MultiProvider，
  /// 回调直接引用字段即可。
  late final PeriodProvider _periodProvider;
  late final SettingsProvider _settingsProvider;
  late final AiAssistantProvider _aiAssistantProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 在应用启动（splash 期间）就创建并开始加载，避免用户直达"记录"
    // 等页面时设置/记录数据尚未加载完成的竞态。
    _periodProvider = PeriodProvider()..loadRecords();
    _settingsProvider = SettingsProvider()..ensureLoaded();
    // AI 报告/聊天历史缓存（ensureLoaded 从 SQLite 恢复持久化内容）
    _aiAssistantProvider = AiAssistantProvider()..ensureLoaded();

    // 注册小组件数据变更回调
    // 当小组件按钮直接操作数据库后，原生端会发送 dataChanged 通知
    // 覆盖两条路径：
    // 1. App 在前台 → MethodChannel 即时投递 → onDataChanged → loadRecords
    // 2. App 在后台 → MethodChannel 延迟/丢失 → 恢复前台时 checkDataDirty 补救
    WidgetService.instance.onDataChanged = () {
      // 延迟到下一帧，确保 Provider 已创建
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        debugPrint('[MyApp] widget data changed, reloading...');
        // 清除 dirty 标记（数据已在此时重新加载，无需恢复前台时再加载一次）
        WidgetService.instance.clearDataDirty();
        // forceRefresh 确保数据库连接被刷新，读到小组件写入的最新数据
        _periodProvider.loadRecords(forceRefresh: true);
      });
    };

    // App 启动时主动检查小组件是否修改了数据库
    // 覆盖场景：App 进程被杀 → 小组件修改数据库 → 重新打开 App
    // 此时 onNewIntent 不会被调用，但 dirty 标记仍然为 true
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetService.instance.checkDataDirty().then((dirty) {
        if (!mounted || !dirty) return;
        debugPrint('[MyApp] widget data dirty on start, reloading...');
        _periodProvider.loadRecords(forceRefresh: true);
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WidgetService.instance.onDataChanged = null;
    // Provider 实例由本 State 创建（以 .value 注入 MultiProvider，
    // 不会被其自动 dispose），需要在这里手动释放。
    _periodProvider.dispose();
    _settingsProvider.dispose();
    _aiAssistantProvider.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // App 从后台恢复前台时，可能小组件操作修改了数据库，需要刷新
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        debugPrint('[MyApp] App resumed, checking widget data dirty...');
        // 先检查日期是否已跨天
        _periodProvider.checkAndRefreshForNewDay();
        // 主动检查小组件是否修改了数据库（通过 SharedPreferences dirty 标记）
        // 这比仅依赖 MethodChannel 通知更可靠，因为后者在 App 后台时可能被延迟投递
        WidgetService.instance.checkDataDirty().then((dirty) {
          if (!mounted) return;
          if (dirty) {
            debugPrint('[MyApp] Widget data dirty flag set, reloading...');
            _periodProvider.loadRecords(forceRefresh: true);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      // 使用 .value 注入 initState 中创建的实例（而不是 create 工厂），
      // 生命周期回调才能直接引用同一个实例。
      providers: [
        ChangeNotifierProvider<PeriodProvider>.value(value: _periodProvider),
        ChangeNotifierProvider<SettingsProvider>.value(value: _settingsProvider),
        ChangeNotifierProvider<AiAssistantProvider>.value(
            value: _aiAssistantProvider),
      ],
      child: MaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('zh', 'CN'),
          Locale('en', 'US'),
        ],
        locale: const Locale('zh', 'CN'),
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        // 跨机型一致性：在应用根节点钳制系统字体缩放。不同 ROM 默认字体
        // 大小不同（部分机型默认就是 1.1~1.3 倍），不限制时所有页面的
        // 文本会随系统设置放大，与固定尺寸元素（徽标、卡片、导航栏）的
        // 比例失衡导致排版错乱。上限 1.3 兼顾无障碍可读性与布局稳定。
        builder: (context, child) {
          if (child == null) return const SizedBox.shrink();
          return MediaQuery.withClampedTextScaling(
            minScaleFactor: 1.0,
            maxScaleFactor: 1.3,
            child: child,
          );
        },
        home: const SplashScreen(),
      ),
    );
  }
}
