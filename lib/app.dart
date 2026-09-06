import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/period_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'screens/record_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'constants/app_colors.dart';
import 'constants/app_strings.dart';
import 'constants/app_theme.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
  return MultiProvider(
    // lazy: false —— 在应用启动（splash 期间）就创建并开始加载，避免用户
    // 直达"记录"等页面时设置/记录数据尚未加载完成的竞态。
    providers: [
      ChangeNotifierProvider(
          lazy: false, create: (_) => PeriodProvider()..loadRecords()),
      ChangeNotifierProvider(
          lazy: false, create: (_) => SettingsProvider()..ensureLoaded()),
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
        home: const SplashScreen(),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  /// 全局 key，供外部（如首页通知按钮）跳转到指定 tab。
  static final GlobalKey<MainScreenState> globalKey =
      GlobalKey<MainScreenState>();

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    RecordScreen(),
    StatsScreen(),
    SettingsScreen(),
  ];

  /// 跳转到设置页（tab index = 3），供首页通知按钮等外部入口调用。
  void jumpToSettings() {
    setState(() => _currentIndex = 3);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // extendBody 让 body 延伸到 bottomNavigationBar 下方，
      // 这样 BackdropFilter 才能模糊到底下页面的内容。
      extendBody: true,
      // 使用 IndexedStack 保持所有 tab 的 State，
      // 切换 tab 时不会销毁前一个 tab 的页面（如日历的滚动位置、选中日期等）。
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _GlassNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == _currentIndex) return;
          setState(() => _currentIndex = index);
        },
      ),
    );
  }
}

/// 玻璃态底部导航栏。
///
/// 特点：
/// - 高斯模糊背景（透过可见底下的内容）
/// - 选中项的指示器是一个圆角滑块，切换时左右滑动（AnimatedPositioned）
/// - 图标 + 文字双行布局
class _GlassNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _GlassNavBar({required this.currentIndex, required this.onTap});

  static const _items = <_NavItem>[
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: AppStrings.home,
    ),
    _NavItem(
      icon: Icons.edit_outlined,
      activeIcon: Icons.edit_rounded,
      label: AppStrings.record,
    ),
    _NavItem(
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart_rounded,
      label: AppStrings.stats,
    ),
    _NavItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: AppStrings.settings,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final n = _items.length;
    final themeColors = context.themeColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(
        left: AppDimens.spacingXl,
        right: AppDimens.spacingXl,
        bottom: AppDimens.spacingSm,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
        child: Container(
          // 性能说明：此前使用 BackdropFilter 做高斯模糊，但 IndexedStack
          // 会同时保活所有 4 个 tab 页面，BackdropFilter 每帧都要对整个屏幕
          // 内容做高斯模糊栅格化。首页（PageView 翻页）和记录页（滚动列表）
          // 的内容在交互时每帧都在变化，导致模糊成本暴增、帧率骤降。
          // 统计页和设置页内容静态，GPU 可复用模糊结果故不卡顿。
          // 替换为半透明纯色背景，彻底消除每帧模糊开销。
          height: 64,
          decoration: BoxDecoration(
            color: (isDark ? Colors.black : Colors.white)
                .withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(AppDimens.radiusFull),
            border: Border.all(
              color: themeColors.divider.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemW = constraints.maxWidth / n;
              // 滑块宽度：单格的 72%
              final sliderW = itemW * 0.72;
              // 滑块 left = 当前格的起始 + (单格 - 滑块) / 2 居中
              final sliderLeft =
                  currentIndex * itemW + (itemW - sliderW) / 2;

              return Stack(
                children: [
                  // ─── 滑块指示器（AnimatedPositioned 精确定位）───
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    left: sliderLeft,
                    top: 10,
                    width: sliderW,
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimary,
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusFull),
                      ),
                    ),
                  ),
                  // ─── 导航项 ───
                  Row(
                    children: List.generate(n, (i) {
                      final item = _items[i];
                      final selected = i == currentIndex;
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onTap(i),
                          child: _NavItemView(
                            item: item,
                            selected: selected,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _NavItemView extends StatelessWidget {
  final _NavItem item;
  final bool selected;

  const _NavItemView({
    required this.item,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = AppColors.white;
    final inactiveColor = context.themeColors.onSurfaceTertiary;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: selected
          ? Column(
              key: const ValueKey('active'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.activeIcon, size: 22, color: activeColor),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: activeColor,
                  ),
                ),
              ],
            )
          : Column(
              key: const ValueKey('inactive'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.icon, size: 22, color: inactiveColor),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: inactiveColor,
                  ),
                ),
              ],
            ),
    );
  }
}
