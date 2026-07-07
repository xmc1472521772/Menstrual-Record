import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  // ─── Light Theme ─────────────────────────────────────────────────
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryPink,
      brightness: Brightness.light,
      primary: AppColors.primaryPink,
      secondary: AppColors.accentPink,
      error: AppColors.error,
      surface: AppThemeColors.light.surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppThemeColors.light.background,
      extensions: const [AppThemeColors.light],

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primaryPink,
        foregroundColor: AppColors.white,
        elevation: AppDimens.elevationNone,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
        ),
      ),

      // NavigationBar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppThemeColors.light.surfaceCard,
        elevation: AppDimens.elevationMedium,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: AppColors.lightPink,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primaryPink, size: 24);
          }
          return const IconThemeData(color: Color(0xFF999999), size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryPink,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Color(0xFF999999),
          );
        }),
      ),

      // Card
      cardTheme: CardThemeData(
        color: AppThemeColors.light.surfaceCard,
        elevation: AppDimens.elevationLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        margin: EdgeInsets.zero,
      ),

      // ElevatedButton
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryPink,
          foregroundColor: AppColors.white,
          elevation: AppDimens.elevationNone,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spacingXl,
            vertical: AppDimens.spacingLg,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryPink,
          side: const BorderSide(color: AppColors.primaryPink, width: 1.5),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spacingXl,
            vertical: AppDimens.spacingLg,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // TextButton
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryPink,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryPink;
          }
          return AppColors.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryPink.withValues(alpha: 0.3);
          }
          return AppColors.grey.withValues(alpha: 0.2);
        }),
      ),

      // InputDecoration
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          borderSide: const BorderSide(color: AppColors.primaryPink, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spacingLg,
          vertical: AppDimens.spacingMd,
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE0E0E0),
        thickness: 1,
        space: 1,
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        ),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        ),
        elevation: AppDimens.elevationHigh,
      ),

      // PopupMenu
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        ),
        elevation: AppDimens.elevationMedium,
      ),
    );
  }

  // ─── Dark Theme ──────────────────────────────────────────────────
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryPink,
      brightness: Brightness.dark,
      primary: AppColors.mediumPink,
      secondary: AppColors.accentPink,
      error: const Color(0xFFEF5350),
      surface: AppThemeColors.dark.surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppThemeColors.dark.background,
      extensions: const [AppThemeColors.dark],

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        foregroundColor: Color(0xFFE0E0E0),
        elevation: AppDimens.elevationNone,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE0E0E0),
        ),
      ),

      // NavigationBar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: AppDimens.elevationNone,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: AppColors.primaryPink.withValues(alpha: 0.2),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.mediumPink, size: 24);
          }
          return const IconThemeData(color: Color(0xFF777777), size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.mediumPink,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Color(0xFF777777),
          );
        }),
      ),

      // Card
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        elevation: AppDimens.elevationNone,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          side: const BorderSide(color: Color(0xFF2A2A2A), width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // ElevatedButton
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryPink,
          foregroundColor: AppColors.white,
          elevation: AppDimens.elevationNone,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spacingXl,
            vertical: AppDimens.spacingLg,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.mediumPink,
          side: const BorderSide(color: AppColors.mediumPink, width: 1.5),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spacingXl,
            vertical: AppDimens.spacingLg,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // TextButton
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.mediumPink,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.mediumPink;
          }
          return const Color(0xFF777777);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryPink.withValues(alpha: 0.3);
          }
          return const Color(0xFF2A2A2A);
        }),
      ),

      // InputDecoration
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          borderSide: const BorderSide(color: AppColors.mediumPink, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spacingLg,
          vertical: AppDimens.spacingMd,
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2A2A2A),
        thickness: 1,
        space: 1,
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1E1E1E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        ),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFFE0E0E0),
        ),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        ),
        elevation: AppDimens.elevationHigh,
      ),

      // PopupMenu
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        ),
        elevation: AppDimens.elevationMedium,
      ),
    );
  }

  // ─── Text Styles ─────────────────────────────────────────────────
  static const TextStyle headingLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const TextStyle statValue = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static const TextStyle statLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );
}
