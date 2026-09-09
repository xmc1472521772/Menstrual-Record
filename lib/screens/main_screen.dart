import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../constants/app_theme.dart';
import '../constants/app_motion.dart';
import 'home_screen.dart';
import 'record_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';

/// 主界面壳层：IndexedStack 4 tab + 玻璃态底部导航栏。
///
/// 从 app.dart 迁出（E5）：app.dart 回归「根装配」单一职责
/// （Provider + MaterialApp + 生命周期 + 字体缩放钳制），
/// 导航壳 UI 独立成本文件演进。
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  /// 跳转到设置页（tab index = 3）。
  ///
  /// D4 解耦：不再暴露全局 GlobalKey 供首页跨页调用，改由
  /// [HomeScreen.onOpenSettings] 回调注入（见 build 中的构造）。
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
        children: [
          // 首页通过回调跳转设置页（通知按钮），不依赖全局 Key
          HomeScreen(onOpenSettings: jumpToSettings),
          const RecordScreen(),
          const StatsScreen(),
          const SettingsScreen(),
        ],
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
/// - 半透明纯色背景（性能说明：此前使用 BackdropFilter 做高斯模糊，但
///   IndexedStack 会同时保活所有 4 个 tab 页面，BackdropFilter 每帧都要
///   对整个屏幕内容做高斯模糊栅格化，交互时帧率骤降，故替换为纯色）
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
          height: AppDimens.navBarHeight,
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
                    duration: AppMotion.slow,
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
                        // 无障碍：底部导航项为纯图标+文字的自绘点击区，
                        // 显式声明语义标签与按钮特征（P2-6）。
                        child: Semantics(
                          label: item.label,
                          button: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onTap(i),
                            child: _NavItemView(
                              item: item,
                              selected: selected,
                            ),
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
      duration: AppMotion.base,
      child: selected
          ? Column(
              key: const ValueKey('active'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.activeIcon, size: 22, color: activeColor),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: AppTheme.caption.fontSize,
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
                    fontSize: AppTheme.caption.fontSize,
                    fontWeight: FontWeight.w500,
                    color: inactiveColor,
                  ),
                ),
              ],
            ),
    );
  }
}
