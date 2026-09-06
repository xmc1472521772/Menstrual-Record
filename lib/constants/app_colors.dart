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

  const AppThemeColors._({
    required this.surface,
    required this.surfaceCard,
    required this.surfaceTile,
    required this.onSurface,
    required this.onSurfaceSecondary,
    required this.onSurfaceTertiary,
    required this.divider,
    required this.background,
  });

  static const light = AppThemeColors._(
    surface: Color(0xFFFBF9F5),
    surfaceCard: Color(0xFFFFFFFF),
    surfaceTile: Color(0xFFF1EDE4),
    onSurface: Color(0xFF2A2622),
    onSurfaceSecondary: Color(0xFF6E665E),
    onSurfaceTertiary: Color(0xFFA39A90),
    divider: Color(0xFFE8E2D8),
    background: Color(0xFFF7F4EE),
  );

  static const dark = AppThemeColors._(
    surface: Color(0xFF1C1917),
    surfaceCard: Color(0xFF262220),
    surfaceTile: Color(0xFF2F2A27),
    onSurface: Color(0xFFEDE7DE),
    onSurfaceSecondary: Color(0xFFB4A99E),
    onSurfaceTertiary: Color(0xFF827A72),
    divider: Color(0xFF342F2B),
    background: Color(0xFF141211),
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
    );
  }
}

/// Convenience extension for accessing [AppThemeColors] from [BuildContext].
extension AppThemeColorsX on BuildContext {
  AppThemeColors get themeColors =>
      Theme.of(this).extension<AppThemeColors>()!;
}
