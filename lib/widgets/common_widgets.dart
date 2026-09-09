import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';

/// A reusable card with an optional title and child content.
///
/// Adapts its background color to the current theme automatically.
///
/// A2 表面层级统一：与 [AppTheme] 的 cardTheme 保持同一层级表达 ——
/// surfaceCard 底 + hairline 描边 + radiusLg（16），不再使用旧的
/// black 5% 阴影。浅色下 hairline 等价旧观感，深色下描边随主题切换。
class SectionCard extends StatelessWidget {
  final String? title;

  /// 标题行右侧的附加控件（计数、徽章、操作按钮等）。
  final Widget? titleTrailing;
  final Widget child;

  /// 卡片内边距（默认 spacingLg）。承载 ListTile 等自带内边距的内容时传 0。
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const SectionCard({
    super.key,
    this.title,
    this.titleTrailing,
    required this.child,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(AppDimens.spacingLg),
      decoration: BoxDecoration(
        color: context.themeColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: context.themeColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null || titleTrailing != null) ...[
            Row(
              children: [
                if (title != null)
                  Expanded(
                    child: Text(
                      title!,
                      style: AppTheme.titleLarge.copyWith(
                        color: context.themeColors.onSurface,
                      ),
                    ),
                  ),
                if (titleTrailing != null) titleTrailing!,
              ],
            ),
            const SizedBox(height: AppDimens.spacingMd),
          ],
          child,
        ],
      ),
    );
  }
}

/// A circular stat display used in overview cards.
class StatCircle extends StatelessWidget {
  final String value;
  final String label;
  final String unit;
  final Color? valueColor;
  final Color? labelColor;

  const StatCircle({
    super.key,
    required this.value,
    required this.label,
    required this.unit,
    this.valueColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final vColor = valueColor ?? AppColors.white;
    // P0-2：标签原为 0.9 白（渐变末端 2.91:1），收敛为 100% 白。
    final lColor = labelColor ?? AppColors.white;

    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: vColor.withValues(alpha: 0.2),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: AppTheme.headingLarge.copyWith(color: vColor),
                ),
                Text(
                  unit,
                  // P0-2：单位原为 0.7 白（2.34:1），改 100% 白；
                  // 与数值的层级由 12px 对 24px 的字号承担。
                  style: AppTheme.bodySmall.copyWith(
                    color: vColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimens.spacingSm),
        Text(
          label,
          style: AppTheme.bodyMedium.copyWith(color: lColor),
        ),
      ],
    );
  }
}

/// A reusable empty state widget with an icon, message, and optional subtitle.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subtitle;
  final Color? iconColor;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.subtitle,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            ),
            child: Icon(
              icon,
              size: 40,
              color: iconColor ?? AppColors.brandPrimary,
            ),
          ),
          const SizedBox(height: AppDimens.spacingXl),
          Text(
            message,
            style: AppTheme.headingSmall.copyWith(
              color: context.themeColors.onSurface,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppDimens.spacingSm),
            Text(
              subtitle!,
              // P0-4：副标题承载引导信息，走 secondary（tertiary 在
              // 画布底色上仅 4.26:1，余量不足）。
              style: AppTheme.bodyMedium.copyWith(
                color: context.themeColors.onSurfaceSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 数据加载中的占位骨架（圆角浅色条），避免首屏 / 导入大数据时白屏直跳。
///
/// 仅作占位，不做呼吸动画——加载通常在 app 启动时已完成，骨架主要覆盖
/// 「恢复备份」等触发 [PeriodProvider.loadRecords] 的短暂窗口。
class SkeletonList extends StatelessWidget {
  final int rows;
  const SkeletonList({super.key, this.rows = 3});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        rows,
        (i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppDimens.spacingMd),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: context.themeColors.surfaceTile,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
          ),
        ),
      ),
    );
  }
}

/// A legend item used in the home screen's legend section.
class LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  /// 说明文字，可省略（首页日历图例只有标签）。
  final String? description;

  /// 描边色：用于「预测经期」这类只有环、无填充的图例项。
  final Color? ring;

  /// 色块尺寸（默认 16，首页日历图例用 8）。
  final double size;
  final bool isDashed;

  const LegendItem({
    super.key,
    required this.color,
    required this.label,
    this.description,
    this.ring,
    this.size = 16,
    this.isDashed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spacingXs),
      child: Row(
        mainAxisSize: description == null ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isDashed ? AppColors.transparent : color,
              border: ring != null
                  ? Border.all(color: ring!, width: 1.2)
                  : (isDashed
                      ? Border.all(color: AppColors.brandLight, width: 1.5)
                      : null),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppDimens.spacingXs),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(
              color: context.themeColors.onSurfaceSecondary,
            ),
          ),
          if (description != null) ...[
            const SizedBox(width: AppDimens.spacingSm),
            Expanded(
              child: Text(
                description!,
                style: AppTheme.bodySmall.copyWith(
                  color: context.themeColors.onSurfaceSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
