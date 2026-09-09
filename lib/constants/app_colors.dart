import 'package:flutter/material.dart';

// ─── Brand Palette (theme-independent) ──────────────────────────
//
// Design language: "成熟温暖" — a warm, muted Nordic direction built on
// terracotta instead of the previous saturated pink.
class AppColors {
  AppColors._();

  // ─── Brand (terracotta) ──────────────────────────────────────────
  static const Color brandPrimary = Color(0xFFB4564F);
  static const Color brandLight = Color(0xFFC97B6F);
  static const Color brandDeep = Color(0xFF8E3F3A);
  static const Color brandSoft = Color(0xFFF3E7E3);
  static const Color brandSurface = Color(0xFFEFE4E0);

  // ─── Neutrals ────────────────────────────────────────────────────
  static const Color canvas = Color(0xFFF7F4EE);
  static const Color card = Color(0xFFFFFFFF);
  static const Color tile = Color(0xFFF1EDE4);
  static const Color hairline = Color(0xFFE8E2D8);
  static const Color ink = Color(0xFF2A2622);
  static const Color inkSecondary = Color(0xFF6E665E);
  static const Color inkTertiary = Color(0xFFA39A90);

  // ─── Functional Colors ───────────────────────────────────────────
  static const Color error = Color(0xFFB4463F);
  static const Color success = Color(0xFF55684F);
  static const Color warning = Color(0xFFD9A441);
  static const Color info = Color(0xFF6E665E);

  // ─── Calendar Day Type Colors ────────────────────────────────────
  static const Color periodDay = Color(0xFFB4564F);
  static const Color predictedDay = Color(0xFFB4564F);
  static const Color ovulationDay = Color(0xFFD9A441);
  static const Color fertileDay = Color(0xFF55684F);
  static const Color fertileBg = Color(0xFFE6EFE7);
  static const Color safeDay = Color(0xFFE2DDD2);
  static const Color todayHighlight = Color(0xFFEFE4E0);

  // ─── Flow Level Colors (热力图经量等级) ───────────────────────────
  // 使用不同色相/明度区分四档经量，避免单纯透明度差异难以辨认。
  static const Color flowNone = Color(0xFFE8D5D2);   // 无（未记录）：浅灰粉
  static const Color flowLight = Color(0xFFF0B4A8);  // 少：浅暖粉
  static const Color flowNormal = Color(0xFFD97065); // 中：中暖红
  static const Color flowHeavy = Color(0xFF8E3F3A);  // 多：深酒红

  // ─── AI 功能卡（统计页 AI 助手入口渐变，A3 收敛进色板）────────────
  // 深浅主题共用暖紫渐变：与陶土红形成功能区分色。
  // P0-3：整组加深一档 —— 原 #6B5B95→#8B7AB8 的末端白字仅 3.77:1，
  // 加深后两端分别为 7.50:1 / 5.91:1，均达 AA 正文标准。
  static const Color aiCardStart = Color(0xFF5B4C82);
  static const Color aiCardEnd = Color(0xFF6B5B95);

  // ─── 渐变卡（首页状态卡 / 统计概览卡）─────────────────────────────
  // P0-1：渐变方向由「中→浅」改为「深→中」。
  // 原 brandPrimary→brandLight 的末端白字仅 3.21:1，且叠加半透明白后
  // 低至 2.34:1；改深→中后两端为 7.19:1 / 4.79:1，全段达标。
  // ⚠️ 铁律：本渐变上的文字一律 100% 白，禁止 white.withValues(alpha<1)，
  // 层级用字号/字重/分隔线表达（#B4564F 上 95% 白恰好 4.50，余量不足）。
  static const Color heroGradientStart = Color(0xFF8E3F3A); // brandDeep
  static const Color heroGradientEnd = Color(0xFFB4564F); // brandPrimary

  // ─── Commonly Used ───────────────────────────────────────────────
  static const Color white = Colors.white;
  static final Color white90 = Colors.white.withValues(alpha: 0.9);
  static const Color black87 = Colors.black87;
  static const Color black54 = Colors.black54;
  static const Color black38 = Colors.black38;
  static const Color grey = Color(0xFFA39A90);
  static const Color transparent = Colors.transparent;

  /// 根据日类型字符串返回对应颜色，供弹窗等处统一适配日历配色。
  static Color dayTypeColor(String dayType) {
    return switch (dayType) {
      'period' => periodDay,
      'predicted' => predictedDay,
      'ovulation' => ovulationDay,
      'fertile' => fertileBg,
      'safe' => safeDay,
      _ => transparent,
    };
  }

  // ─── Calendar Helpers ────────────────────────────────────────────
  static Color getPeriodColor(DateTime date) => periodDay;

  static Color getPredictedColor(DateTime date) {
    return predictedDay.withValues(alpha: 0.14);
  }

  static Color getOvulationColor(DateTime date) => ovulationDay;

  static Color getFertileColor(DateTime date) => fertileBg;

  static Color getSafeColor(DateTime date) {
    return safeDay.withValues(alpha: 0.4);
  }
}

// ─── Elevation Tokens (theme-independent) ───────────────────────
//
// A three-tier soft shadow system. All shadows share the same warm
// neutral hue so elevation reads as depth, never as a grey halo.
class AppShadows {
  AppShadows._();

  /// Resting surface — cards, list rows.
  static const List<BoxShadow> low = [
    BoxShadow(
      color: Color(0x0F292419),
      offset: Offset(0, 4),
      blurRadius: 16,
      spreadRadius: -4,
    ),
  ];

  /// Raised surface — floating tab bar, sheets.
  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color(0x14292419),
      offset: Offset(0, 8),
      blurRadius: 24,
      spreadRadius: -6,
    ),
  ];

  /// Hero surface — gradient status header.
  static const List<BoxShadow> high = [
    BoxShadow(
      color: Color(0x1FB4564F),
      offset: Offset(0, 10),
      blurRadius: 28,
      spreadRadius: -8,
    ),
  ];
}

// ─── Spacing & Radius Tokens (theme-independent) ────────────────
class AppDimens {
  AppDimens._();

  // ─── Spacing Tokens ──────────────────────────────────────────────
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 12.0;
  static const double spacingLg = 16.0;
  static const double spacingXl = 20.0;
  static const double spacing2xl = 24.0;
  static const double spacing3xl = 32.0;
  static const double spacing4xl = 48.0;

  // ─── Radius Tokens ───────────────────────────────────────────────
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radius2xl = 28.0;
  static const double radiusFull = 999.0;

  // ─── Elevation Tokens ────────────────────────────────────────────
  static const double elevationNone = 0;
  static const double elevationLow = 1;
  static const double elevationMedium = 2;
  static const double elevationHigh = 4;

  // ─── 布局尺寸 Tokens（C3 收敛：互相咬合的魔法数统一归口）──────────
  /// 玻璃底部导航栏高度（main_screen 的 _GlassNavBar 唯一真源；主题不配置 NavigationBar）。
  static const double navBarHeight = 64.0;

  /// 页面滚动内容底部预留空间：需容纳悬浮导航栏（[navBarHeight]）+
  /// SafeArea 边距 + 呼吸空间，避免最后一张卡片被导航栏遮住。
  static const double navBarClearance = 100.0;

  /// 首页/记录页大标题 AppBar 高度（双行标题需要比默认更高的工具栏）。
  static const double appBarHeight = 68.0;

  /// 「回到今天」FAB 相对屏幕底部的抬升量（导航栏高度 + 间隙）。
  static const double fabLift = 80.0;

  // ─── 控件高度三档（P2-5）─────────────────────────────────────
  /// 小号控件（紧凑行内按钮、芯片）。
  static const double controlHeightSm = 36.0;

  /// 中号控件（次操作按钮、标准触摸目标）。
  static const double controlHeightMd = 44.0;

  /// 大号控件（主操作按钮，全站统一）。
  static const double controlHeightLg = 52.0;

  /// 最小触摸目标（Material 建议 ≥ 44dp，P2-2）。
  static const double minTouchTarget = 44.0;
}

/// Theme-dependent semantic colors registered as a [ThemeExtension].
///
/// Retrieve via `Theme.of(context).extension<AppThemeColors>()!`
/// or the convenience extension `context.themeColors`.
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color surface;
  final Color surfaceCard;
  final Color surfaceTile;
  final Color onSurface;
  final Color onSurfaceSecondary;
  final Color onSurfaceTertiary;
  final Color divider;
  final Color background;

  /// 危险/破坏性操作语义色（删除、清空等）。
  ///
  /// P0-6：原先全项目硬编码 `AppColors.error`（#B4463F），该值在深色卡片
  /// 上仅 2.92:1 不可读。深色下改用提亮一档的 #E8908C（6.61:1）。
  final Color destructive;

  const AppThemeColors._({
    required this.surface,
    required this.surfaceCard,
    required this.surfaceTile,
    required this.onSurface,
    required this.onSurfaceSecondary,
    required this.onSurfaceTertiary,
    required this.divider,
    required this.background,
    required this.destructive,
  });

  /// P0-4：onSurfaceTertiary 由 #A39A90 改为 #7A7269（白卡 2.77 → 4.73:1）。
  /// ⚠️ 语义边界：本档仅限 placeholder / disabled / 弱化图标；
  /// 承载信息的次级说明一律用 [onSurfaceSecondary]（白卡 5.64 / tile 4.78）。
  static const light = AppThemeColors._(
    surface: Color(0xFFFBF9F5),
    surfaceCard: Color(0xFFFFFFFF),
    surfaceTile: Color(0xFFF1EDE4),
    onSurface: Color(0xFF2A2622),
    onSurfaceSecondary: Color(0xFF6E665E),
    onSurfaceTertiary: Color(0xFF7A7269),
    divider: Color(0xFFE8E2D8),
    background: Color(0xFFF7F4EE),
    destructive: Color(0xFFB4463F),
  );

  /// P0-4：深色三级文本 #827A72 在深色卡上仅 3.74:1，改为 #948B82（4.71:1）。
  static const dark = AppThemeColors._(
    surface: Color(0xFF1C1917),
    surfaceCard: Color(0xFF262220),
    surfaceTile: Color(0xFF2F2A27),
    onSurface: Color(0xFFEDE7DE),
    onSurfaceSecondary: Color(0xFFB4A99E),
    onSurfaceTertiary: Color(0xFF948B82),
    divider: Color(0xFF342F2B),
    background: Color(0xFF141211),
    destructive: Color(0xFFE8908C),
  );

  @override
  AppThemeColors copyWith({
    Color? surface,
    Color? surfaceCard,
    Color? surfaceTile,
    Color? onSurface,
    Color? onSurfaceSecondary,
    Color? onSurfaceTertiary,
    Color? divider,
    Color? background,
    Color? destructive,
  }) {
    return AppThemeColors._(
      surface: surface ?? this.surface,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceTile: surfaceTile ?? this.surfaceTile,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceSecondary: onSurfaceSecondary ?? this.onSurfaceSecondary,
      onSurfaceTertiary: onSurfaceTertiary ?? this.onSurfaceTertiary,
      divider: divider ?? this.divider,
      background: background ?? this.background,
      destructive: destructive ?? this.destructive,
    );
  }

  @override
  AppThemeColors lerp(AppThemeColors? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors._(
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      surfaceTile: Color.lerp(surfaceTile, other.surfaceTile, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceSecondary:
          Color.lerp(onSurfaceSecondary, other.onSurfaceSecondary, t)!,
      onSurfaceTertiary:
          Color.lerp(onSurfaceTertiary, other.onSurfaceTertiary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      background: Color.lerp(background, other.background, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
    );
  }
}

/// Convenience extension for accessing [AppThemeColors] from [BuildContext].
extension AppThemeColorsX on BuildContext {
  AppThemeColors get themeColors =>
      Theme.of(this).extension<AppThemeColors>()!;
}
