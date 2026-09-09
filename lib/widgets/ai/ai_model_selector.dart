import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/ai_health_service.dart';
import '../../providers/settings_provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_theme.dart';

/// AI 模型选择器（D2 自 ai_assistant_screen 拆出）。
///
/// AppBar 内的胶囊按钮 + 弹出菜单：根据 [isReportTab] 展示报告模型或
/// 问答模型。模型落库由 [onSelected] 回调（屏幕层）处理——它还需要
/// 联动清空错误提示等屏幕状态。
class AiModelSelector extends StatelessWidget {
  final bool isReportTab;
  final ValueChanged<String> onSelected;

  const AiModelSelector({
    super.key,
    required this.isReportTab,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (context) {
        final settings = context.read<SettingsProvider>();
        final currentModel =
            isReportTab ? settings.reportModel : settings.chatModel;
        return AIHealthService.availableModels.map((model) {
          return PopupMenuItem<String>(
            value: model.id,
            child: Row(
              children: [
                Icon(
                  model.id == currentModel
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: model.id == currentModel
                      ? AppColors.brandPrimary
                      : context.themeColors.onSurfaceTertiary,
                ),
                const SizedBox(width: AppDimens.spacingSm),
                Text(
                  model.displayName,
                  style: AppTheme.bodyMedium.copyWith(
                    color: model.id == currentModel
                        ? AppColors.brandPrimary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: model.id == currentModel
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spacingSm,
          vertical: AppDimens.spacingXs,
        ),
        decoration: BoxDecoration(
          color: AppColors.brandSoft,
          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              size: 14,
              color: AppColors.brandPrimary,
            ),
            const SizedBox(width: 4),
            Consumer<SettingsProvider>(
              builder: (context, settings, _) {
                final modelId =
                    isReportTab ? settings.reportModel : settings.chatModel;
                final config = AIHealthService.configFor(modelId);
                return Text(
                  config.displayName,
                  style: AppTheme.labelMedium.copyWith(
                    color: AppColors.brandPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              },
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.arrow_drop_down_rounded,
              size: 16,
              color: AppColors.brandPrimary,
            ),
          ],
        ),
      ),
    );
  }
}
