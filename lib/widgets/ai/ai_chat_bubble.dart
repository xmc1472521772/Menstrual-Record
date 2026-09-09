import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../services/ai_health_service.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_theme.dart';

/// 聊天气泡（D2 自 ai_assistant_screen 拆出）。
///
/// 用户消息 = 品牌实底白字；AI 消息 = 卡片底 Markdown。
/// [isStreaming] 为 true 时：内容为空显示"正在思考…（含秒数）"指示器，
/// 非空则在末尾追加闪烁光标。
class AiChatBubble extends StatelessWidget {
  final ChatMessage msg;
  final AppThemeColors themeColors;
  final bool isStreaming;

  const AiChatBubble({
    super.key,
    required this.msg,
    required this.themeColors,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    final displayContent = msg.content;

    // 流式输出中且内容为空时显示"正在思考…"指示器
    final showThinking = isStreaming && displayContent.isEmpty;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimens.spacingMd),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spacingMd,
          vertical: AppDimens.spacingSm + 2,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColors.brandPrimary : themeColors.surfaceCard,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppDimens.radiusLg),
            topRight: const Radius.circular(AppDimens.radiusLg),
            bottomLeft: isUser
                ? const Radius.circular(AppDimens.radiusLg)
                : const Radius.circular(2),
            bottomRight: isUser
                ? const Radius.circular(2)
                : const Radius.circular(AppDimens.radiusLg),
          ),
          border: isUser
              ? null
              : Border.all(color: themeColors.divider.withValues(alpha: 0.3)),
        ),
        child: showThinking
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                  const SizedBox(width: AppDimens.spacingSm),
                  AiThinkingIndicator(themeColors: themeColors),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: isUser
                        ? Text(
                            displayContent,
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppColors.white,
                              height: 1.5,
                            ),
                          )
                        : MarkdownBody(
                            data: displayContent,
                            styleSheet: MarkdownStyleSheet(
                              p: AppTheme.bodyMedium.copyWith(
                                color: themeColors.onSurface,
                                height: 1.5,
                              ),
                              strong: AppTheme.bodyMedium.copyWith(
                                color: themeColors.onSurface,
                                fontWeight: FontWeight.w700,
                                height: 1.5,
                              ),
                              em: AppTheme.bodyMedium.copyWith(
                                color: themeColors.onSurface,
                                fontStyle: FontStyle.italic,
                                height: 1.5,
                              ),
                              listBullet: AppTheme.bodyMedium.copyWith(
                                color: themeColors.onSurface,
                                height: 1.5,
                              ),
                            ),
                          ),
                  ),
                  // 流式输出中且内容不为空时，显示闪烁光标
                  if (isStreaming) ...[
                    const SizedBox(width: 2),
                    const AiStreamingCursor(),
                  ],
                ],
              ),
      ),
    );
  }
}

/// 思考指示器（带已等待秒数，弱化慢响应的"卡死感"）。
class AiThinkingIndicator extends StatefulWidget {
  final AppThemeColors themeColors;

  const AiThinkingIndicator({super.key, required this.themeColors});

  @override
  State<AiThinkingIndicator> createState() => _AiThinkingIndicatorState();
}

class _AiThinkingIndicatorState extends State<AiThinkingIndicator> {
  Timer? _timer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _elapsedSeconds < 3
        ? AppStrings.aiChatThinking
        : '${AppStrings.aiChatThinking} ${_elapsedSeconds}s';
    return Text(
      text,
      style: AppTheme.bodySmall.copyWith(
        color: widget.themeColors.onSurfaceTertiary,
      ),
    );
  }
}

/// 闪烁光标（流式输出时使用）。
class AiStreamingCursor extends StatefulWidget {
  const AiStreamingCursor({super.key});

  @override
  State<AiStreamingCursor> createState() => _AiStreamingCursorState();
}

class _AiStreamingCursorState extends State<AiStreamingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, _) {
        return Opacity(
          opacity: _opacity.value,
          child: Container(
            width: 3,
            height: 16,
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: AppColors.brandPrimary,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        );
      },
    );
  }
}
