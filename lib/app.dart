import 'dart:ui';
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

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    RecordScreen(),
    StatsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
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
/// - 选中项的指示器是一个圆角滑块，切换时左右滑动（AnimatedAlign）
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
        bottom: AppDimens.spacingMd,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
        // 高斯模糊背景
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: (isDark ? Colors.black : Colors.white)
                  .withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(AppDimens.radiusFull),
              border: Border.all(
                color: themeColors.divider.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemW = constraints.maxWidth / n;
                return Stack(
                  children: [
                    // ─── 滑块指示器 ───
                    AnimatedAlign(
                      alignment: Alignment(
                        -1 + 2 * currentIndex / (n - 1),
                        0,
                      ),
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      child: FractionalTranslation(
                        translation: const Offset(-0.5, 0),
                        child: Container(
                          width: itemW * 0.72,
                          height: 44,
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.brandPrimary,
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusFull),
                          ),
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
                              isDark: isDark,
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
  final bool isDark;

  const _NavItemView({
    required this.item,
    required this.selected,
    required this.isDark,
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
