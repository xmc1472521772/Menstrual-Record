import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  /// 全局统一字体族：内置 MiSans 子集（见 pubspec.yaml fonts 声明）。
  /// 所有页面（含 CustomPainter 里 TextPainter 绘制的图表文字）
  /// 都必须引用此常量，保证不同 ROM 上字体度量完全一致。
  static const String fontFamily = 'MiSans';

  // ─── Light Theme ─────────────────────────────────────────────────
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandPrimary,
      brightness: Brightness.light,
      primary: AppColors.brandPrimary,
      secondary: AppColors.brandLight,
      error: AppColors.error,
      surface: AppThemeColors.light.surface,
    );

    /// Radius used by every filled surface in the new language.
    const cardRadius = BorderRadius.all(
      Radius.circular(AppDimens.radiusLg),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: colorScheme,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppThemeColors.light.background,
      extensions: const [AppThemeColors.light],

      // AppBar — flat, sits on the warm canvas rather than a coloured bar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink,
        surfaceTintColor: AppColors.transparent,
        elevation: AppDimens.elevationNone,
        scrolledUnderElevation: AppDimens.elevationNone,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
          letterSpacing: -0.2,
        ),
      ),

      // Card — hairline border instead of a shadow, per the new language
      cardTheme: CardThemeData(
        color: AppThemeColors.light.surfaceCard,
        surfaceTintColor: AppColors.transparent,
        elevation: AppDimens.elevationNone,
        shape: const RoundedRectangleBorder(
          borderRadius: cardRadius,
          side: BorderSide(color: AppColors.hairline, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // ElevatedButton
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandPrimary,
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
          foregroundColor: AppColors.brandPrimary,
          side: const BorderSide(color: AppColors.brandPrimary, width: 1.5),
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
          foregroundColor: AppColors.brandPrimary,
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
            return AppColors.brandPrimary;
          }
          return AppColors.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.brandPrimary.withValues(alpha: 0.3);
          }
          return AppColors.grey.withValues(alpha: 0.2);
        }),
      ),

      // InputDecoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppThemeColors.light.surfaceTile,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          borderSide: const BorderSide(color: AppColors.brandPrimary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spacingLg,
          vertical: AppDimens.spacingMd,
        ),
        hintStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.inkTertiary,
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.hairline,
        thickness: 1,
        space: 1,
      ),

      // Slider — terracotta track, no overlay halo
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.brandPrimary,
        inactiveTrackColor: AppColors.tile,
        thumbColor: AppColors.brandPrimary,
        overlayColor: Color(0x1FB4564F),
        trackHeight: 4,
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.white,
        ),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: AppThemeColors.light.surfaceCard,
        surfaceTintColor: AppColors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radius2xl),
        ),
        elevation: AppDimens.elevationHigh,
      ),

      // PopupMenu
      popupMenuTheme: PopupMenuThemeData(
        color: AppThemeColors.light.surfaceCard,
        surfaceTintColor: AppColors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        elevation: AppDimens.elevationMedium,
      ),
    );
  }

  // ─── Dark Theme ──────────────────────────────────────────────────
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandPrimary,
      brightness: Brightness.dark,
      primary: AppColors.brandLight,
      secondary: AppColors.brandLight,
      error: const Color(0xFFEF5350),
      surface: AppThemeColors.dark.surface,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppThemeColors.dark.background,
      extensions: const [AppThemeColors.dark],

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF141211),
        foregroundColor: Color(0xFFEDE7DE),
        surfaceTintColor: AppColors.transparent,
        elevation: AppDimens.elevationNone,
        scrolledUnderElevation: AppDimens.elevationNone,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFFEDE7DE),
          letterSpacing: -0.2,
        ),
      ),

      // NavigationBar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1C1917),
        surfaceTintColor: AppColors.transparent,
        elevation: AppDimens.elevationNone,
        height: 62,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: AppColors.brandPrimary,
        indicatorShape: const StadiumBorder(),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.white, size: 22);
          }
          return const IconThemeData(color: AppColors.inkTertiary, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.brandLight,
            );
          }
          return const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.inkTertiary,
          );
        }),
      ),

      // Card
      cardTheme: CardThemeData(
        color: const Color(0xFF262220),
        surfaceTintColor: AppColors.transparent,
        elevation: AppDimens.elevationNone,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          side: const BorderSide(color: Color(0xFF342F2B), width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // ElevatedButton
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandPrimary,
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
          foregroundColor: AppColors.brandLight,
          side: const BorderSide(color: AppColors.brandLight, width: 1.5),
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
          foregroundColor: AppColors.brandLight,
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
            return AppColors.brandLight;
          }
          return const Color(0xFF777777);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.brandPrimary.withValues(alpha: 0.3);
          }
          return const Color(0xFF2A2A2A);
        }),
      ),

      // InputDecoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2F2A27),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          borderSide: const BorderSide(color: Color(0xFF342F2B)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          borderSide: const BorderSide(color: Color(0xFF342F2B)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          borderSide: const BorderSide(color: AppColors.brandLight, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spacingLg,
          vertical: AppDimens.spacingMd,
        ),
        // P0-5：深色 hint 不再复用浅色固定值 inkTertiary（#A39A90），
        // 改用深色三级语义色（= AppThemeColors.dark.onSurfaceTertiary）。
        hintStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Color(0xFF948B82),
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: Color(0xFF342F2B),
        thickness: 1,
        space: 1,
      ),

      // Slider
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.brandLight,
        inactiveTrackColor: Color(0xFF2F2A27),
        thumbColor: AppColors.brandLight,
        overlayColor: Color(0x1FB4564F),
        trackHeight: 4,
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF2F2A27),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFFEDE7DE),
        ),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF262220),
        surfaceTintColor: AppColors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radius2xl),
        ),
        elevation: AppDimens.elevationHigh,
      ),

      // PopupMenu
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xFF262220),
        surfaceTintColor: AppColors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
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

  /// 按钮文字专用样式：**不带 height**。
  /// Impeller(Vulkan) 渲染下，按钮文字若使用带 height 的样式（如
  /// titleMedium 的 1.4），字形底部会超出行框被平切（Impeller 已知的
  /// 文本裁剪问题，表现为"保存记录"等按钮文字下半部分消失）。
  static const TextStyle buttonLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
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

  /// 辅助说明（10px）。仅限 placeholder / 计数标注等弱信息。
  static const TextStyle caption = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  /// 上标小字（11px）。标签、导航微标。
  static const TextStyle overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  /// 脚注（13px）。介于 bodySmall 与 bodyMedium 之间的次级正文。
  static const TextStyle footnote = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// 微标（9px）。仅限图表坐标轴 / 热力图月份等极弱辅助标注。
  static const TextStyle micro = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );

  /// 超大展示数字（36px）。图表中心重价值（周期天数 / 经期天数等）。
  static const TextStyle displayXl = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    height: 1.1,
  );

  /// 特大展示数字（56px）。AI 报告首屏健康总分等核心指标。
  static const TextStyle display2xl = TextStyle(
    fontSize: 56,
    fontWeight: FontWeight.w700,
    height: 1.1,
  );
}
