import 'package:flutter/material.dart';

// ─── Brand Palette (theme-independent) ──────────────────────────
class AppColors {
  AppColors._();

  static const Color primaryPink = Color(0xFFE91E63);
  static const Color lightPink = Color(0xFFFCE4EC);
  static const Color mediumPink = Color(0xFFF48FB1);
  static const Color darkPink = Color(0xFFC2185B);
  static const Color accentPink = Color(0xFFEC407A);

  // ─── Functional Colors ───────────────────────────────────────────
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);
  static const Color warning = Color(0xFFFF8F00);
  static const Color info = Color(0xFF1976D2);

  // ─── Calendar Day Type Colors ────────────────────────────────────
  static const Color periodDay = Color(0xFFE91E63);
  static const Color predictedDay = Color(0xFFF48FB1);
  static const Color ovulationDay = Color(0xFFFFCA28);
  static const Color fertileDay = Color(0xFFFF9800);
  static const Color safeDay = Color(0xFFBDBDBD);
  static const Color todayHighlight = Color(0xFFFCE4EC);

  // ─── Commonly Used ───────────────────────────────────────────────
  static const Color white = Colors.white;
  static final Color white90 = Colors.white.withValues(alpha: 0.9);
  static const Color black87 = Colors.black87;
  static const Color black54 = Colors.black54;
  static const Color black38 = Colors.black38;
  static const Color grey = Colors.grey;
  static const Color transparent = Colors.transparent;

  // ─── Calendar Helpers ────────────────────────────────────────────
  static Color getPeriodColor(DateTime date) => periodDay;

  static Color getPredictedColor(DateTime date) {
    return predictedDay.withValues(alpha: 0.6);
  }

  static Color getOvulationColor(DateTime date) => ovulationDay;

  static Color getFertileColor(DateTime date) => fertileDay;

  static Color getSafeColor(DateTime date) {
    return safeDay.withValues(alpha: 0.4);
  }
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
  final Color onSurface;
  final Color onSurfaceSecondary;
  final Color onSurfaceTertiary;
  final Color divider;
  final Color background;

  const AppThemeColors._({
    required this.surface,
    required this.surfaceCard,
    required this.onSurface,
    required this.onSurfaceSecondary,
    required this.onSurfaceTertiary,
    required this.divider,
    required this.background,
  });

  static const light = AppThemeColors._(
    surface: Color(0xFFFAFAFA),
    surfaceCard: Colors.white,
    onSurface: Color(0xFF1A1A1A),
    onSurfaceSecondary: Color(0xFF666666),
    onSurfaceTertiary: Color(0xFF999999),
    divider: Color(0xFFE0E0E0),
    background: Color(0xFFF5F5F5),
  );

  static const dark = AppThemeColors._(
    surface: Color(0xFF121212),
    surfaceCard: Color(0xFF1E1E1E),
    onSurface: Color(0xFFE0E0E0),
    onSurfaceSecondary: Color(0xFFAAAAAA),
    onSurfaceTertiary: Color(0xFF777777),
    divider: Color(0xFF2A2A2A),
    background: Color(0xFF0A0A0A),
  );

  @override
  AppThemeColors copyWith({
    Color? surface,
    Color? surfaceCard,
    Color? onSurface,
    Color? onSurfaceSecondary,
    Color? onSurfaceTertiary,
    Color? divider,
    Color? background,
  }) {
    return AppThemeColors._(
      surface: surface ?? this.surface,
      surfaceCard: surfaceCard ?? this.surfaceCard,
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
