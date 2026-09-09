import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ai_assistant_provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_theme.dart';

/// 「历史聊天」底部弹层（D2 自 ai_assistant_screen 拆出）。
///
/// 展示全部会话（updatedAt 降序，最新在前），点击回看完整消息并可续聊。
Future<void> showAiChatHistorySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return Consumer<AiAssistantProvider>(
        builder: (context, aiProvider, _) {
          final themeColors = context.themeColors;
          final sessions = aiProvider.sessions;
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            decoration: BoxDecoration(
              color: themeColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppDimens.radius2xl),
                topRight: Radius.circular(AppDimens.radius2xl),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: AppDimens.spacingSm),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: themeColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppDimens.spacingLg),
                    child: Text(
                      AppStrings.aiChatHistoryTitle,
                      style: AppTheme.headingSmall.copyWith(
                        color: themeColors.onSurface,
                      ),
                    ),
                  ),
                  if (sessions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppDimens.spacing3xl),
                      child: Text(
                        AppStrings.aiChatHistoryEmpty,
                        style: AppTheme.bodyMedium.copyWith(
                          color: themeColors.onSurfaceTertiary,
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(
                          AppDimens.spacingLg,
                          0,
                          AppDimens.spacingLg,
                          AppDimens.spacingLg,
                        ),
                        itemCount: sessions.length,
                        itemBuilder: (context, index) {
                          final session = sessions[index];
                          final isActive =
                              session.id == aiProvider.activeSession?.id;
                          return AiSessionTile(
                            session: session,
                            isActive: isActive,
                            themeColors: themeColors,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

/// 历史会话列表项。
class AiSessionTile extends StatelessWidget {
  final ChatSession session;
  final bool isActive;
  final AppThemeColors themeColors;

  const AiSessionTile({
    super.key,
    required this.session,
    required this.isActive,
    required this.themeColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.spacingSm),
      decoration: BoxDecoration(
        color: isActive ? AppColors.brandSoft : themeColors.surfaceTile,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(
          color: isActive
              ? AppColors.brandPrimary.withValues(alpha: 0.4)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          ),
          leading: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.brandSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 20,
              color: AppColors.brandPrimary,
            ),
          ),
          title: Text(
            session.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.bodyMedium.copyWith(
              color: themeColors.onSurface,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          subtitle: Text(
            '${formatAiSessionTime(session.updatedAt)} · '
            '${AppStrings.aiChatMessageCount(session.messages.length)}',
            style: AppTheme.bodySmall.copyWith(
              fontSize: AppTheme.bodySmall.fontSize,
              color: themeColors.onSurfaceTertiary,
            ),
          ),
          trailing: isActive
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spacingSm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                  ),
                  child: Text(
                    AppStrings.aiChatCurrentTag,
                    style: AppTheme.labelMedium.copyWith(
                      fontSize: AppTheme.overline.fontSize,
                      color: AppColors.brandPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : null,
          onTap: () {
            context.read<AiAssistantProvider>().openSession(session.id);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}

/// 会话时间的紧凑展示：今天显示时刻，昨天显示"昨天"，更早显示日期。
String formatAiSessionTime(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  if (day == today) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
  if (day == today.subtract(const Duration(days: 1))) return '昨天';
  return '${dt.month}月${dt.day}日';
}
