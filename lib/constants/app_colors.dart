import 'package:flutter/material.dart';

class AppColors {
  // ─── Brand Palette ───────────────────────────────────────────────
  static const Color primaryPink = Color(0xFFE91E63);
  static const Color lightPink = Color(0xFFFCE4EC);
  static const Color mediumPink = Color(0xFFF48FB1);
  static const Color darkPink = Color(0xFFC2185B);
  static const Color accentPink = Color(0xFFEC407A);

  // ─── Semantic Colors (Light Mode) ────────────────────────────────
  static const Color surface = Color(0xFFFAFAFA);
  static const Color surfaceCard = Colors.white;
  static const Color onSurface = Color(0xFF1A1A1A);
  static const Color onSurfaceSecondary = Color(0xFF666666);
  static const Color onSurfaceTertiary = Color(0xFF999999);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color background = Color(0xFFF5F5F5);

  // ─── Semantic Colors (Dark Mode) ─────────────────────────────────
  static const Color darkSurface = Color(0xFF121212);
  static const Color darkSurfaceCard = Color(0xFF1E1E1E);
  static const Color darkOnSurface = Color(0xFFE0E0E0);
  static const Color darkOnSurfaceSecondary = Color(0xFFAAAAAA);
  static const Color darkOnSurfaceTertiary = Color(0xFF777777);
  static const Color darkDivider = Color(0xFF2A2A2A);
  static const Color darkBackground = Color(0xFF0A0A0A);

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
