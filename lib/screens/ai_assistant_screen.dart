import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ai_health_service.dart';
import '../providers/period_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/ai_assistant_provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../constants/app_theme.dart';
import '../constants/app_motion.dart';
import '../widgets/common_widgets.dart';
import '../widgets/ai/ai_chat_bubble.dart';
import '../widgets/ai/ai_model_selector.dart';
import '../widgets/ai/ai_report_view.dart';
import '../widgets/ai/ai_session_sheet.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

/// AI 助手主屏（D2 拆分后回落为「状态编排 + 页面装配」）：
/// - 报告生成/分析动画/错误状态 → 本文件；
/// - 流式回放节奏（缓冲 + 80ms 节流 flush）→ [AiAssistantProvider]（可单测）；
/// - 聊天气泡/报告视图/模型选择器/会话弹层 → widgets/ai/ 下独立组件。
class _AIAssistantScreenState extends State<AIAssistantScreen>
    with SingleTickerProviderStateMixin {
  // ─── 报告相关状态（仅UI层状态，报告本身缓存在AiAssistantProvider）───
  bool _isAnalyzing = false;
  String? _error;
  int _analyzingStep = 0;

  // ─── 问答相关状态（聊天会话缓存在 AiAssistantProvider）───
  final TextEditingController _chatController = TextEditingController();
  bool _isChatLoading = false;
  final ScrollController _chatScrollController = ScrollController();

  // ─── Tab 控制 ───
  int _currentTab = 0;

  // ─── 分析动画 ───
  late final AnimationController _animController;
  late final Animation<double> _anim;

  static const _analyzingSteps = [
    AppStrings.aiAnalyzing1,
    AppStrings.aiAnalyzing2,
    AppStrings.aiAnalyzing3,
  ];

  /// 流式 flush 发生在 Provider 内，屏幕通过监听其 notifyListeners
  /// 在 loading 期间跟随滚动到底（接替旧版 flush 内直接滚动的方式）。
  AiAssistantProvider? _observedAiProvider;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _anim = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PeriodProvider>();
      final aiProvider = context.read<AiAssistantProvider>();
      // 只有第一次（没有缓存报告）才自动生成
      if (aiProvider.cachedReport == null &&
          provider.records.isNotEmpty &&
          provider.cycleData != null) {
        _generateReport();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ai = context.read<AiAssistantProvider>();
    if (!identical(ai, _observedAiProvider)) {
      _observedAiProvider?.removeListener(_onAiProviderChanged);
      _observedAiProvider = ai;
      ai.addListener(_onAiProviderChanged);
    }
  }

  /// 流式输出期间每次 Provider 刷新（flush/updateMessage）后跟随滚动到底。
  void _onAiProviderChanged() {
    if (_isChatLoading) _scrollChatToBottom();
  }

  @override
  void dispose() {
    _observedAiProvider?.removeListener(_onAiProviderChanged);
    _animController.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _generateReport() async {
    final provider = context.read<PeriodProvider>();
    final settings = context.read<SettingsProvider>();
    final aiProvider = context.read<AiAssistantProvider>();

    if (provider.records.isEmpty || provider.cycleData == null) {
      return;
    }

    final modelId = settings.reportModel;

    // 检查API Key是否配置
    if (!AIHealthService.isModelConfigured(modelId)) {
      setState(() {
        _error = AppStrings.aiApiKeyNotConfigured;
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _error = null;
      _analyzingStep = 0;
    });

    // 分步更新动画文字
    _startStepAnimation();

    try {
      final report = await AIHealthService.generateReport(
        records: provider.records,
        cycleData: provider.cycleData!,
        dailyFlowMap: provider.dailyFlowMap,
        userCycleLength: settings.cycleLength,
        userPeriodLength: settings.periodLength,
        modelId: modelId,
      );

      if (report != null) {
        // 无论用户是否已退出页面都缓存报告（service 层操作，不依赖 mounted），
        // 避免已成功生成（已消耗 API 调用）的报告被白白丢弃。
        // dataVersion 以缓存时刻为准：生成期间数据若变化，下次进入时
        // 会显示"数据已更新"提示。
        aiProvider.cacheReport(
          report,
          modelId: modelId,
          dataVersion: provider.dataVersion,
        );
      }

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _error = '$e'.replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _startStepAnimation() async {
    for (int i = 0; i < _analyzingSteps.length && _isAnalyzing; i++) {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted && _isAnalyzing) {
        setState(() => _analyzingStep = i);
      }
    }
  }

  bool get _dataUpdatedSinceReport {
    final provider = context.read<PeriodProvider>();
    final aiProvider = context.read<AiAssistantProvider>();
    return aiProvider.isReportDataStale(provider.dataVersion);
  }

  bool get _modelChangedSinceReport {
    final aiProvider = context.read<AiAssistantProvider>();
    final settings = context.read<SettingsProvider>();
    return aiProvider.cachedReport != null &&
        aiProvider.reportModelId != settings.reportModel;
  }

  // ─── 问答功能（流式）────────────────────────────────────────

  Future<void> _sendChatMessage(String text) async {
    if (text.trim().isEmpty || _isChatLoading) return;

    final provider = context.read<PeriodProvider>();
    final settings = context.read<SettingsProvider>();

    if (provider.records.isEmpty || provider.cycleData == null) {
      return;
    }

    final modelId = settings.chatModel;

    final aiProvider = context.read<AiAssistantProvider>();
    final userMessage = ChatMessage(
      role: 'user',
      content: text.trim(),
      timestamp: DateTime.now(),
    );

    // 通过 provider 落定消息：无活跃会话时自动新建（标题取首条提问）
    aiProvider.appendMessage(userMessage);
    aiProvider.appendMessage(ChatMessage(
      role: 'assistant',
      content: '',
      timestamp: DateTime.now(),
    ));
    // 流式写入绑定本轮会话（Provider 内记录 sessionId），
    // 中途新建/切换会话不影响写入目标
    final session = aiProvider.activeSession!;
    aiProvider.beginChatStream(session);

    setState(() {
      _isChatLoading = true;
    });

    _chatController.clear();
    _scrollChatToBottom();

    try {
      final stream = AIHealthService.askQuestionStream(
        question: text.trim(),
        records: provider.records,
        cycleData: provider.cycleData!,
        dailyFlowMap: provider.dailyFlowMap,
        userCycleLength: settings.cycleLength,
        userPeriodLength: settings.periodLength,
        modelId: modelId,
        // 传不含最后空回答的历史
        chatHistory: session.messages.sublist(0, session.messages.length - 1),
      );

      await for (final chunk in stream) {
        if (!mounted) break;
        // 节流合并发生在 Provider 内：高频 chunk 不再逐个触发整屏重建
        aiProvider.onStreamChunk(session, chunk);
      }

      // 流正常结束：Provider 做最终 flush（节流窗口内累积内容完整落进会话），
      // 与 loading 结束合并为一次状态更新。
      aiProvider.finishChatStream(session);
      if (mounted) {
        setState(() {
          _isChatLoading = false;
        });
        _scrollChatToBottom();
      }
      // 整轮问答完成后持久化（流式过程中不写库）
      aiProvider.persistChatHistory();
    } catch (e) {
      // 异常路径：Provider 取消补刷定时器并写入错误标记（保留已收内容）
      final errorMsg = '$e'.replaceFirst('Exception: ', '');
      aiProvider.abortChatStream(session, errorMsg);
      if (mounted) {
        setState(() {
          _isChatLoading = false;
        });
      }
      // 出错落库同样持久化（错误标记已含在最后一条消息中）
      aiProvider.persistChatHistory();
    }
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: AppMotion.page,
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.aiAssistant),
        actions: [
          // 模型切换按钮（根据当前 Tab 选择报告或问答模型）
          AiModelSelector(
            isReportTab: _currentTab == 0,
            onSelected: (modelId) {
              final settings = context.read<SettingsProvider>();
              if (_currentTab == 0) {
                settings.setReportModel(modelId);
                // 切换报告模型时不清除已有报告，而是显示提示
                setState(() {
                  _error = null;
                });
              } else {
                settings.setChatModel(modelId);
              }
            },
          ),
          if (_currentTab == 0 && context.read<AiAssistantProvider>().cachedReport != null && !_isAnalyzing)
            IconButton(
              onPressed: _generateReport,
              icon: const Icon(Icons.refresh_rounded, size: 22),
              color: context.themeColors.onSurface,
              tooltip: AppStrings.aiRegenerateReport,
            ),
          // 聊天会话管理（仅问答 Tab 显示，1.36.0）
          if (_currentTab == 1) ..._buildChatSessionActions(),
          const SizedBox(width: AppDimens.spacingSm),
        ],
      ),
      body: Consumer3<PeriodProvider, SettingsProvider, AiAssistantProvider>(
        builder: (context, provider, settings, aiProvider, _) {
          if (provider.records.isEmpty || provider.cycleData == null) {
            return _buildEmptyState(context);
          }

          return Column(
            children: [
              _buildTabBar(context),
              Expanded(
                child: _currentTab == 0
                    ? _buildReportTab(context)
                    : _buildChatTab(context, aiProvider),
              ),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Chat session actions（清空 / 新建 / 历史，1.36.0）
  // ═══════════════════════════════════════════════════════════════

  /// 问答 Tab 的 AppBar 动作：清空当前对话（有会话时）+ 新建聊天 + 历史。
  List<Widget> _buildChatSessionActions() {
    return [
      // 清空按钮随会话存在性显隐，用 Consumer 响应会话变化
      Consumer<AiAssistantProvider>(
        builder: (context, aiProvider, _) {
          if (!aiProvider.hasActiveSession) return const SizedBox.shrink();
          return IconButton(
            onPressed: _confirmClearCurrentChat,
            icon: const Icon(Icons.delete_sweep_outlined, size: 22),
            color: context.themeColors.onSurface,
            tooltip: AppStrings.aiChatClearMessages,
          );
        },
      ),
      IconButton(
        onPressed: () => context.read<AiAssistantProvider>().startNewChat(),
        icon: const Icon(Icons.add_comment_outlined, size: 22),
        color: context.themeColors.onSurface,
        tooltip: AppStrings.aiChatNewChat,
      ),
      IconButton(
        onPressed: () => showAiChatHistorySheet(context),
        icon: const Icon(Icons.history_rounded, size: 22),
        color: context.themeColors.onSurface,
        tooltip: AppStrings.aiChatHistory,
      ),
    ];
  }

  /// 「清空消息」二次确认后仅清除当前会话，其他历史会话不受影响。
  Future<void> _confirmClearCurrentChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.aiChatClearConfirmTitle),
        content: const Text(AppStrings.aiChatClearConfirmContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(AppStrings.aiChatCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              AppStrings.aiChatClearConfirmAction,
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    context.read<AiAssistantProvider>().clearActiveSession();
  }

  // ═══════════════════════════════════════════════════════════════
  //  Tab Bar
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTabBar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDimens.spacingLg,
        AppDimens.spacingSm,
        AppDimens.spacingLg,
        AppDimens.spacingSm,
      ),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.themeColors.surfaceTile,
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabItem(0, AppStrings.aiChatTabReport,
                Icons.description_outlined, Icons.description_rounded),
          ),
          Expanded(
            child: _buildTabItem(1, AppStrings.aiChatTabQA,
                Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(
      int index, String label, IconData icon, IconData activeIcon) {
    final selected = _currentTab == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = index),
      child: AnimatedContainer(
        duration: AppMotion.base,
        padding: const EdgeInsets.symmetric(vertical: AppDimens.spacingSm),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? activeIcon : icon,
              size: 16,
              color: selected
                  ? AppColors.white
                  : context.themeColors.onSurfaceTertiary,
            ),
            const SizedBox(width: AppDimens.spacingXs),
            Text(
              label,
              style: TextStyle(
                fontSize: AppTheme.footnote.fontSize,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? AppColors.white
                    : context.themeColors.onSurfaceTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Report Tab
  // ═══════════════════════════════════════════════════════════════

  Widget _buildReportTab(BuildContext context) {
    final aiProvider = context.read<AiAssistantProvider>();
    if (_isAnalyzing) {
      return _buildAnalyzingState(context);
    }
    if (_error != null) {
      return _buildErrorState(context);
    }
    if (aiProvider.cachedReport == null) {
      return _buildGenerateButton(context);
    }
    return AiReportView(
      report: aiProvider.cachedReport!,
      themeColors: context.themeColors,
      showDataUpdatedHint: _dataUpdatedSinceReport,
      showModelChangedHint: _modelChangedSinceReport,
      modelId: aiProvider.reportModelId,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Empty state
  // ═══════════════════════════════════════════════════════════════

  Widget _buildEmptyState(BuildContext context) {
    // P1-2：空状态统一走公共 EmptyState。
    return const EmptyState(
      icon: Icons.psychology_outlined,
      message: AppStrings.aiNoDataTitle,
      subtitle: AppStrings.aiNoDataSubtitle,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Analyzing state (分段式动画)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAnalyzingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 脉动动画图标
          ScaleTransition(
            scale: _anim,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: BorderRadius.circular(AppDimens.radius2xl),
              ),
              child: const Icon(
                Icons.psychology_rounded,
                size: 36,
                color: AppColors.brandPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spacingXl),
          // 分段文字
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              _analyzingSteps[_analyzingStep],
              key: ValueKey(_analyzingStep),
              style: AppTheme.bodyLarge.copyWith(
                color: context.themeColors.onSurfaceSecondary,
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spacingLg),
          // 步骤指示器
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _analyzingSteps.length,
              (i) => Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: i <= _analyzingStep
                      ? AppColors.brandPrimary
                      : AppColors.brandPrimary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Error state
  // ═══════════════════════════════════════════════════════════════

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacing3xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppDimens.radius2xl),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 44,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppDimens.spacingXl),
            Text(
              AppStrings.analysisFailed,
              style: AppTheme.headingSmall.copyWith(
                color: context.themeColors.onSurface,
              ),
            ),
            const SizedBox(height: AppDimens.spacingSm),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(
                color: context.themeColors.onSurfaceTertiary,
              ),
            ),
            const SizedBox(height: AppDimens.spacingXl),
            ElevatedButton.icon(
              onPressed: _generateReport,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text(AppStrings.aiRegenerateReport),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Generate button
  // ═══════════════════════════════════════════════════════════════

  Widget _buildGenerateButton(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacing3xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: BorderRadius.circular(AppDimens.radius2xl),
              ),
              child: const Icon(
                Icons.health_and_safety_outlined,
                size: 44,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(height: AppDimens.spacingXl),
            ElevatedButton.icon(
              onPressed: _generateReport,
              icon: const Icon(Icons.auto_awesome, size: 20),
              label: const Text(AppStrings.aiGenerateReport),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Chat Tab (经期问答)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildChatTab(
    BuildContext context,
    AiAssistantProvider aiProvider,
  ) {
    final themeColors = context.themeColors;
    final activeSession = aiProvider.activeSession;
    final chatMessages = aiProvider.chatMessages;
    // 判断是否为初始空状态（当前会话没有任何消息）
    final isEmpty = chatMessages.isEmpty;

    return Column(
      children: [
        // ─── 消息列表 ───
        Expanded(
          child: isEmpty
              ? _buildChatEmptyState(themeColors)
              : ListView.builder(
                  controller: _chatScrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spacingLg,
                    AppDimens.spacingSm,
                    AppDimens.spacingLg,
                    AppDimens.spacingSm,
                  ),
                  itemCount: chatMessages.length,
                  itemBuilder: (context, index) {
                    final msg = chatMessages[index];
                    // 最后一条AI消息正在流式输出时显示打字光标
                    // （仅限消息所属会话即当前流式目标会话）
                    final isStreaming = _isChatLoading &&
                        activeSession != null &&
                        activeSession.id == aiProvider.streamingSessionId &&
                        index == chatMessages.length - 1 &&
                        msg.role == 'assistant';
                    return AiChatBubble(
                      msg: msg,
                      themeColors: themeColors,
                      isStreaming: isStreaming,
                    );
                  },
                ),
        ),
        // ─── 快捷问题 ───
        if (isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spacingLg,
              vertical: AppDimens.spacingSm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildQuickQuestion(
                    AppStrings.aiChatQuickQ1, themeColors),
                ),
                const SizedBox(width: AppDimens.spacingSm),
                Expanded(
                  child: _buildQuickQuestion(
                    AppStrings.aiChatQuickQ2, themeColors),
                ),
                const SizedBox(width: AppDimens.spacingSm),
                Expanded(
                  child: _buildQuickQuestion(
                    AppStrings.aiChatQuickQ3, themeColors),
                ),
              ],
            ),
          ),
        // ─── 输入框 ───
        _buildChatInput(themeColors),
        // ─── 免责声明 ───
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spacingLg,
            AppDimens.spacingSm,
            AppDimens.spacingLg,
            AppDimens.spacingSm,
          ),
          child: Text(
            AppStrings.aiChatDisclaimer,
            style: AppTheme.bodySmall.copyWith(
              fontSize: AppTheme.overline.fontSize,
              color: themeColors.onSurfaceTertiary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatEmptyState(AppThemeColors themeColors) {
    // P1-2：空状态统一走公共 EmptyState（内部按主题取色，themeColors 仅保留签名兼容）。
    return const EmptyState(
      icon: Icons.chat_bubble_outline_rounded,
      message: AppStrings.aiChatTitle,
      subtitle: AppStrings.aiChatEmptySubtitle,
    );
  }

  Widget _buildQuickQuestion(String text, AppThemeColors themeColors) {
    return GestureDetector(
      onTap: () => _sendChatMessage(text),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spacingSm,
          vertical: AppDimens.spacingSm,
        ),
        decoration: BoxDecoration(
          color: themeColors.surfaceTile,
          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
          border: Border.all(
            color: AppColors.brandPrimary.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTheme.bodySmall.copyWith(
            color: AppColors.brandPrimary,
            fontSize: AppTheme.bodySmall.fontSize,
          ),
        ),
      ),
    );
  }

  Widget _buildChatInput(AppThemeColors themeColors) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDimens.spacingLg,
        0,
        AppDimens.spacingLg,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spacingMd,
        vertical: AppDimens.spacingXs,
      ),
      decoration: BoxDecoration(
        color: themeColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
        border: Border.all(color: themeColors.divider.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              style: AppTheme.bodyMedium.copyWith(
                color: themeColors.onSurface,
              ),
              decoration: InputDecoration(
                hintText: AppStrings.aiChatHint,
                hintStyle: AppTheme.bodyMedium.copyWith(
                  color: themeColors.onSurfaceTertiary,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spacingXs,
                  vertical: AppDimens.spacingSm,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (text) => _sendChatMessage(text),
            ),
          ),
          const SizedBox(width: AppDimens.spacingXs),
          IconButton(
            onPressed: _isChatLoading
                ? null
                : () => _sendChatMessage(_chatController.text),
            icon: const Icon(Icons.send_rounded, size: 20),
            color: AppColors.brandPrimary,
            disabledColor: themeColors.onSurfaceTertiary,
          ),
        ],
      ),
    );
  }
}
