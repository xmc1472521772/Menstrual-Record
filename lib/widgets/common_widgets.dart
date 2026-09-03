import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';

/// A reusable card with an optional title and child content.
///
/// Adapts its background color to the current theme automatically.
class SectionCard extends StatelessWidget {
  final String? title;
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const SectionCard({
    super.key,
    this.title,
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
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: AppTheme.titleLarge.copyWith(
                color: context.themeColors.onSurface,
              ),
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
    final lColor = labelColor ?? AppColors.white.withValues(alpha: 0.9);

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
                  style: AppTheme.bodySmall.copyWith(
                    color: vColor.withValues(alpha: 0.7),
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
              style: AppTheme.bodyMedium.copyWith(
                color: context.themeColors.onSurfaceTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A legend item used in the home screen's legend section.
class LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String description;
  final bool isDashed;

  const LegendItem({
    super.key,
    required this.color,
    required this.label,
    required this.description,
    this.isDashed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spacingXs),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: isDashed ? AppColors.transparent : color,
              border: isDashed
                  ? Border.all(color: AppColors.brandLight, width: 1.5)
                  : null,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppDimens.spacingMd),
          Text(
            label,
            style: AppTheme.labelLarge.copyWith(
              color: context.themeColors.onSurface,
            ),
          ),
          const SizedBox(width: AppDimens.spacingSm),
          Expanded(
            child: Text(
              description,
              style: AppTheme.bodySmall.copyWith(
                color: context.themeColors.onSurfaceSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
