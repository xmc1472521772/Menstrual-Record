import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/ai_health_service.dart';
import '../providers/period_provider.dart';
import '../providers/settings_provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../constants/app_theme.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen>
    with SingleTickerProviderStateMixin {
  // ─── 报告相关状态（仅UI层状态，报告本身缓存在PeriodProvider）───
  bool _isAnalyzing = false;
  String? _error;
  int _analyzingStep = 0;

  // ─── 问答相关状态（聊天历史缓存在PeriodProvider）───
  final TextEditingController _chatController = TextEditingController();
  bool _isChatLoading = false;
  final ScrollController _chatScrollController = ScrollController();
  // 流式回答的实时拼接buffer
  final StringBuffer _streamingBuffer = StringBuffer();

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
      // 只有第一次（没有缓存报告）才自动生成
      if (provider.cachedReport == null &&
          provider.records.isNotEmpty &&
          provider.cycleData != null) {
        _generateReport();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _generateReport() async {
    final provider = context.read<PeriodProvider>();
    final settings = context.read<SettingsProvider>();

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
        provider.cacheReport(report, modelId: modelId);
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
    return provider.isReportDataStale;
  }

  bool get _modelChangedSinceReport {
    final provider = context.read<PeriodProvider>();
    final settings = context.read<SettingsProvider>();
    return provider.cachedReport != null &&
        provider.reportModelId != settings.reportModel;
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

    final chatHistory = provider.chatHistory;
    final userMessage = ChatMessage(
      role: 'user',
      content: text.trim(),
      timestamp: DateTime.now(),
    );

    // 立即添加用户消息和空的AI回答消息
    setState(() {
      chatHistory.add(userMessage);
      chatHistory.add(ChatMessage(
        role: 'assistant',
        content: '',
        timestamp: DateTime.now(),
      ));
      _isChatLoading = true;
      _streamingBuffer.clear();
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
        chatHistory: chatHistory.sublist(0, chatHistory.length - 1),
      );

      await for (final chunk in stream) {
        if (!mounted) break;
        _streamingBuffer.write(chunk);
        // 实时更新最后一条AI消息
        setState(() {
          final lastIndex = chatHistory.length - 1;
          chatHistory[lastIndex] = ChatMessage(
            role: 'assistant',
            content: _streamingBuffer.toString(),
            timestamp: DateTime.now(),
          );
        });
        _scrollChatToBottom();
      }

      if (mounted) {
        setState(() {
          _isChatLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = '$e'.replaceFirst('Exception: ', '');
        setState(() {
          // 如果有部分内容已经收到，保留它并添加错误标记
          if (_streamingBuffer.isNotEmpty) {
            final lastIndex = chatHistory.length - 1;
            chatHistory[lastIndex] = ChatMessage(
              role: 'assistant',
              content: '${_streamingBuffer.toString()}\n\n⚠️ $errorMsg',
              timestamp: DateTime.now(),
            );
          } else {
            // 没收到任何内容，替换为错误提示
            final lastIndex = chatHistory.length - 1;
            chatHistory[lastIndex] = ChatMessage(
              role: 'assistant',
              content: '回答失败：$errorMsg',
              timestamp: DateTime.now(),
            );
          }
          _isChatLoading = false;
        });
      }
    }
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
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
          _buildModelSelector(),
          if (_currentTab == 0 && context.read<PeriodProvider>().cachedReport != null && !_isAnalyzing)
            IconButton(
              onPressed: _generateReport,
              icon: const Icon(Icons.refresh_rounded, size: 22),
              color: AppColors.ink,
              tooltip: AppStrings.aiRegenerateReport,
            ),
          const SizedBox(width: AppDimens.spacingSm),
        ],
      ),
      body: Consumer2<PeriodProvider, SettingsProvider>(
        builder: (context, provider, settings, _) {
          if (provider.records.isEmpty || provider.cycleData == null) {
            return _buildEmptyState(context);
          }

          return Column(
            children: [
              _buildTabBar(context),
              Expanded(
                child: _currentTab == 0
                    ? _buildReportTab(context)
                    : _buildChatTab(context),
              ),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Model Selector（根据当前 Tab 显示报告或问答的模型选择）
  // ═══════════════════════════════════════════════════════════════

  Widget _buildModelSelector() {
    final isReportTab = _currentTab == 0;

    return PopupMenuButton<String>(
      onSelected: (modelId) {
        final settings = context.read<SettingsProvider>();
        if (isReportTab) {
          settings.setReportModel(modelId);
          // 切换报告模型时不清除已有报告，而是显示提示
          setState(() {
            _error = null;
          });
        } else {
          settings.setChatModel(modelId);
        }
      },
      itemBuilder: (context) {
        final settings = context.read<SettingsProvider>();
        final currentModel = isReportTab
            ? settings.reportModel
            : settings.chatModel;
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
                      : AppColors.inkTertiary,
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
                final modelId = isReportTab
                    ? settings.reportModel
                    : settings.chatModel;
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
        duration: const Duration(milliseconds: 200),
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
              color: selected ? AppColors.white : AppColors.inkTertiary,
            ),
            const SizedBox(width: AppDimens.spacingXs),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? AppColors.white : AppColors.inkTertiary,
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
    final provider = context.read<PeriodProvider>();
    if (_isAnalyzing) {
      return _buildAnalyzingState(context);
    }
    if (_error != null) {
      return _buildErrorState(context);
    }
    if (provider.cachedReport == null) {
      return _buildGenerateButton(context);
    }
    return _buildReport(context);
  }

  // ═══════════════════════════════════════════════════════════════
  //  Empty state
  // ═══════════════════════════════════════════════════════════════

  Widget _buildEmptyState(BuildContext context) {
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
                Icons.psychology_outlined,
                size: 44,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(height: AppDimens.spacingXl),
            Text(
              AppStrings.aiNoDataTitle,
              style: AppTheme.headingSmall.copyWith(
                color: context.themeColors.onSurface,
              ),
            ),
            const SizedBox(height: AppDimens.spacingSm),
            Text(
              AppStrings.aiNoDataSubtitle,
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(
                color: context.themeColors.onSurfaceTertiary,
              ),
            ),
          ],
        ),
      ),
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
              '分析失败',
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
  //  Full report — 7 部分结构
  // ═══════════════════════════════════════════════════════════════

  Widget _buildReport(BuildContext context) {
    final report = context.read<PeriodProvider>().cachedReport!;
    final themeColors = context.themeColors;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spacingLg,
        AppDimens.spacingSm,
        AppDimens.spacingLg,
        100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── 健康评分头部 ───
          _buildScoreHeader(context, report),
          const SizedBox(height: AppDimens.spacingSm),

          // ─── 数据更新提示 ───
          if (_dataUpdatedSinceReport) _buildDataUpdatedHint(themeColors),

          // ─── 模型已切换提示 ───
          if (_modelChangedSinceReport) _buildModelChangedHint(themeColors),

          const SizedBox(height: AppDimens.spacingLg),

          // ─── 1. 本周期概览 ───
          if (report.currentOverview.isNotEmpty)
            _buildCurrentOverviewCard(context, report, themeColors),
          if (report.currentOverview.isNotEmpty)
            const SizedBox(height: AppDimens.spacingLg),

          // ─── 2. 周期趋势 ───
          if (report.cycleStats.isNotEmpty || report.cycleTrendSummary.isNotEmpty)
            _buildCycleTrendCard(context, report, themeColors),
          if (report.cycleStats.isNotEmpty || report.cycleTrendSummary.isNotEmpty)
            const SizedBox(height: AppDimens.spacingLg),

          // ─── 3. 症状趋势 ───
          if (report.symptomTrends.isNotEmpty)
            _buildSymptomTrendCard(context, report, themeColors),
          if (report.symptomTrends.isNotEmpty)
            const SizedBox(height: AppDimens.spacingLg),

          // ─── 4. 与过去相比 ───
          if (report.comparisonTrends.isNotEmpty)
            _buildComparisonCard(context, report, themeColors),
          if (report.comparisonTrends.isNotEmpty)
            const SizedBox(height: AppDimens.spacingLg),

          // ─── 5. 值得关注的地方 ───
          if (report.attentions.isNotEmpty)
            _buildAttentionsCard(context, report, themeColors),
          if (report.attentions.isNotEmpty)
            const SizedBox(height: AppDimens.spacingLg),

          // ─── 6. 下一周期建议 ───
          if (report.nextCycleSuggestions.isNotEmpty)
            _buildNextCycleSuggestionsCard(context, report, themeColors),
          if (report.nextCycleSuggestions.isNotEmpty)
            const SizedBox(height: AppDimens.spacingLg),

          // ─── 7. 就医提醒 ───
          if (report.medicalReminders.isNotEmpty)
            _buildMedicalRemindersCard(context, report, themeColors),
          if (report.medicalReminders.isNotEmpty)
            const SizedBox(height: AppDimens.spacingLg),

          // ─── 总结 ───
          if (report.conclusion.isNotEmpty)
            _buildConclusionCard(context, report, themeColors),
          if (report.conclusion.isNotEmpty)
            const SizedBox(height: AppDimens.spacingLg),

          // ─── 免责声明 ───
          _buildDisclaimer(context, themeColors),
        ],
      ),
    );
  }

  // ─── 数据更新提示 ──────────────────────────────────────────────

  Widget _buildDataUpdatedHint(var themeColors) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.spacingSm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spacingMd,
        vertical: AppDimens.spacingSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.update_rounded, size: 14, color: AppColors.warning),
          const SizedBox(width: AppDimens.spacingXs),
          Expanded(
            child: Text(
              AppStrings.aiDataUpdatedHint,
              style: AppTheme.bodySmall.copyWith(color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 模型已切换提示 ──────────────────────────────────────────────

  Widget _buildModelChangedHint(var themeColors) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.spacingSm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spacingMd,
        vertical: AppDimens.spacingSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.brandPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: Border.all(
          color: AppColors.brandPrimary.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.swap_horiz_rounded, size: 14, color: AppColors.brandPrimary),
          const SizedBox(width: AppDimens.spacingXs),
          Expanded(
            child: Text(
              AppStrings.aiModelChangedHint,
              style: AppTheme.bodySmall.copyWith(color: AppColors.brandPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 健康评分头部 ──────────────────────────────────────────────

  Widget _buildScoreHeader(BuildContext context, HealthReport report) {
    final score = report.healthScore;
    final scoreColor = _scoreColor(score);
    final scoreLabel = _scoreLabel(score);

    return Container(
      padding: const EdgeInsets.all(AppDimens.spacingXl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scoreColor, scoreColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spacingMd,
                  vertical: AppDimens.spacingXs + 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.insights_rounded,
                        color: AppColors.white, size: 14),
                    const SizedBox(width: AppDimens.spacingXs),
                    Text(
                      AppStrings.aiHealthReport,
                      style:
                          AppTheme.labelMedium.copyWith(color: AppColors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spacingLg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$score',
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: AppDimens.spacingXs),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '/ 100',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppColors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.spacingMd),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  scoreLabel,
                  style: AppTheme.titleLarge.copyWith(color: AppColors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spacingSm),
          Text(
            '${AppStrings.aiReportTime}：${DateFormat('yyyy-MM-dd HH:mm').format(report.generatedAt)}',
            style: AppTheme.bodySmall.copyWith(
              color: AppColors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 85) return AppColors.success;
    if (score >= 70) return AppColors.brandPrimary;
    if (score >= 50) return AppColors.warning;
    return AppColors.error;
  }

  String _scoreLabel(int score) {
    if (score >= 85) return '健康';
    if (score >= 70) return '良好';
    if (score >= 50) return '需关注';
    return '需就医';
  }

  // ─── 1. 本周期概览 ─────────────────────────────────────────────

  Widget _buildCurrentOverviewCard(
    BuildContext context,
    HealthReport report,
    var themeColors,
  ) {
    return _ReportCard(
      title: AppStrings.aiSectionCurrentOverview,
      icon: Icons.today_rounded,
      themeColors: themeColors,
      child: Text(
        report.currentOverview,
        style: AppTheme.bodyMedium.copyWith(
          color: themeColors.onSurfaceSecondary,
          height: 1.6,
        ),
      ),
    );
  }

  // ─── 2. 周期趋势 ───────────────────────────────────────────────

  Widget _buildCycleTrendCard(
    BuildContext context,
    HealthReport report,
    var themeColors,
  ) {
    return _ReportCard(
      title: AppStrings.aiSectionCycleTrend,
      icon: Icons.trending_up_rounded,
      themeColors: themeColors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (report.cycleStats.isNotEmpty) ...[
            Wrap(
              spacing: AppDimens.spacingSm,
              runSpacing: AppDimens.spacingSm,
              children: report.cycleStats.map((stat) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spacingMd,
                    vertical: AppDimens.spacingSm,
                  ),
                  decoration: BoxDecoration(
                    color: themeColors.surfaceTile,
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        stat.label,
                        style: AppTheme.bodySmall.copyWith(
                          color: themeColors.onSurfaceTertiary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stat.value,
                        style: AppTheme.titleMedium.copyWith(
                          color: themeColors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            if (report.cycleTrendSummary.isNotEmpty)
              const SizedBox(height: AppDimens.spacingMd),
          ],
          if (report.cycleTrendSummary.isNotEmpty)
            Text(
              report.cycleTrendSummary,
              style: AppTheme.bodyMedium.copyWith(
                color: themeColors.onSurfaceSecondary,
                height: 1.6,
              ),
            ),
        ],
      ),
    );
  }

  // ─── 3. 症状趋势 ───────────────────────────────────────────────

  Widget _buildSymptomTrendCard(
    BuildContext context,
    HealthReport report,
    var themeColors,
  ) {
    return _ReportCard(
      title: AppStrings.aiSectionSymptomTrend,
      icon: Icons.healing_rounded,
      themeColors: themeColors,
      child: Column(
        children: report.symptomTrends.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: idx < report.symptomTrends.length - 1
                  ? AppDimens.spacingMd
                  : 0,
            ),
            child: _buildTrendItem(item, themeColors),
          );
        }).toList(),
      ),
    );
  }

  // ─── 4. 与过去相比 ─────────────────────────────────────────────

  Widget _buildComparisonCard(
    BuildContext context,
    HealthReport report,
    var themeColors,
  ) {
    return _ReportCard(
      title: AppStrings.aiSectionComparison,
      icon: Icons.compare_arrows_rounded,
      themeColors: themeColors,
      child: Column(
        children: report.comparisonTrends.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: idx < report.comparisonTrends.length - 1
                  ? AppDimens.spacingMd
                  : 0,
            ),
            child: _buildTrendItem(item, themeColors),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTrendItem(TrendItem item, var themeColors) {
    final statusColor = _trendStatusColor(item.status);
    return Container(
      padding: const EdgeInsets.all(AppDimens.spacingMd),
      decoration: BoxDecoration(
        color: themeColors.surfaceTile.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: AppTheme.titleMedium.copyWith(
                    color: themeColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.spacingSm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spacingSm,
                  vertical: AppDimens.spacingXs,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                ),
                child: Text(
                  item.status,
                  style: AppTheme.labelMedium.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spacingXs),
          Text(
            item.detail,
            style: AppTheme.bodySmall.copyWith(
              color: themeColors.onSurfaceSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Color _trendStatusColor(String status) {
    if (status.contains('增加') || status.contains('变长') || status.contains('减少') || status.contains('变短')) {
      return AppColors.warning;
    }
    if (status.contains('稳定') || status.contains('无明显变化')) {
      return AppColors.success;
    }
    return AppColors.brandPrimary;
  }

  // ─── 5. 值得关注的地方 ─────────────────────────────────────────

  Widget _buildAttentionsCard(
    BuildContext context,
    HealthReport report,
    var themeColors,
  ) {
    return _ReportCard(
      title: AppStrings.aiSectionAttentions,
      icon: Icons.visibility_outlined,
      themeColors: themeColors,
      child: Column(
        children: report.attentions.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: idx < report.attentions.length - 1
                  ? AppDimens.spacingMd
                  : 0,
            ),
            child: _buildAttentionItem(item, themeColors),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAttentionItem(AttentionItem item, var themeColors) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active_outlined,
                  size: 16, color: AppColors.warning),
              const SizedBox(width: AppDimens.spacingXs),
              Expanded(
                child: Text(
                  item.title,
                  style: AppTheme.titleMedium.copyWith(
                    color: themeColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spacingXs),
          Text(
            item.detail,
            style: AppTheme.bodySmall.copyWith(
              color: themeColors.onSurfaceSecondary,
              height: 1.5,
            ),
          ),
          if (item.evidence.isNotEmpty) ...[
            const SizedBox(height: AppDimens.spacingXs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spacingSm,
                vertical: AppDimens.spacingXs,
              ),
              decoration: BoxDecoration(
                color: themeColors.surfaceTile,
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.fact_check_outlined,
                      size: 12, color: themeColors.onSurfaceTertiary),
                  const SizedBox(width: AppDimens.spacingXs),
                  Expanded(
                    child: Text(
                      '${AppStrings.aiEvidence}：${item.evidence}',
                      style: AppTheme.bodySmall.copyWith(
                        color: themeColors.onSurfaceTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── 6. 下一周期建议 ───────────────────────────────────────────

  Widget _buildNextCycleSuggestionsCard(
    BuildContext context,
    HealthReport report,
    var themeColors,
  ) {
    return _ReportCard(
      title: AppStrings.aiSectionNextCycleSuggestions,
      icon: Icons.tips_and_updates_outlined,
      themeColors: themeColors,
      child: Column(
        children: report.nextCycleSuggestions.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: idx < report.nextCycleSuggestions.length - 1
                  ? AppDimens.spacingMd
                  : 0,
            ),
            child: _buildSuggestionItem(item, themeColors, idx + 1),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSuggestionItem(
      NextCycleSuggestion item, var themeColors, int index) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.brandPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimens.radiusFull),
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: AppTheme.labelMedium.copyWith(
              color: AppColors.brandPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AppDimens.spacingMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: AppTheme.titleMedium.copyWith(
                  color: themeColors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppDimens.spacingXs),
              Text(
                item.detail,
                style: AppTheme.bodySmall.copyWith(
                  color: themeColors.onSurfaceSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── 7. 就医提醒 ───────────────────────────────────────────────

  Widget _buildMedicalRemindersCard(
    BuildContext context,
    HealthReport report,
    var themeColors,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_hospital_rounded,
                  color: AppColors.error, size: 20),
              const SizedBox(width: AppDimens.spacingSm),
              Text(
                AppStrings.aiSectionMedicalReminders,
                style: AppTheme.titleLarge.copyWith(
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spacingMd),
          Column(
            children: report.medicalReminders.asMap().entries.map((entry) {
              final idx = entry.key;
              final reminder = entry.value;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: idx < report.medicalReminders.length - 1
                      ? AppDimens.spacingSm
                      : 0,
                ),
                child: _buildMedicalReminderItem(reminder, themeColors),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalReminderItem(
      MedicalReminder reminder, var themeColors) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spacingSm),
      margin: const EdgeInsets.only(bottom: AppDimens.spacingSm),
      decoration: BoxDecoration(
        color: reminder.userMatched
            ? AppColors.error.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: reminder.userMatched
            ? Border.all(color: AppColors.error.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            reminder.userMatched
                ? Icons.priority_high_rounded
                : Icons.flag_rounded,
            size: 14,
            color: AppColors.error.withValues(alpha: 0.7),
          ),
          const SizedBox(width: AppDimens.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        reminder.condition,
                        style: AppTheme.titleMedium.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (reminder.userMatched) ...[
                      const SizedBox(width: AppDimens.spacingXs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusFull),
                        ),
                        child: const Text(
                          '⚠️ ${AppStrings.aiYouMatched}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  reminder.detail,
                  style: AppTheme.bodySmall.copyWith(
                    color: themeColors.onSurfaceSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 总结 ──────────────────────────────────────────────────────

  Widget _buildConclusionCard(
    BuildContext context,
    HealthReport report,
    var themeColors,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spacingLg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.brandPrimary.withValues(alpha: 0.06),
            AppColors.brandPrimary.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(
          color: AppColors.brandPrimary.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.summarize_rounded,
                  color: AppColors.brandPrimary, size: 20),
              const SizedBox(width: AppDimens.spacingSm),
              Text(
                AppStrings.aiSectionConclusion,
                style: AppTheme.titleLarge.copyWith(
                  color: AppColors.brandPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spacingMd),
          Text(
            report.conclusion,
            style: AppTheme.bodyMedium.copyWith(
              color: themeColors.onSurface,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 免责声明 ──────────────────────────────────────────────────

  Widget _buildDisclaimer(BuildContext context, var themeColors) {
    final provider = context.read<PeriodProvider>();
    final disclaimerText = AIHealthService.disclaimerFor(provider.reportModelId);
    return Container(
      padding: const EdgeInsets.all(AppDimens.spacingMd),
      decoration: BoxDecoration(
        color: themeColors.surfaceTile.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 16, color: themeColors.onSurfaceTertiary),
          const SizedBox(width: AppDimens.spacingSm),
          Expanded(
            child: Text(
              disclaimerText,
              style: AppTheme.bodySmall.copyWith(
                color: themeColors.onSurfaceTertiary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Chat Tab (经期问答)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildChatTab(BuildContext context) {
    final themeColors = context.themeColors;
    final provider = context.read<PeriodProvider>();
    final chatHistory = provider.chatHistory;
    // 判断是否为初始空状态（没有任何消息）
    final isEmpty = chatHistory.isEmpty;

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
                  itemCount: chatHistory.length,
                  itemBuilder: (context, index) {
                    final msg = chatHistory[index];
                    // 最后一条AI消息正在流式输出时显示打字光标
                    final isStreaming = _isChatLoading &&
                        index == chatHistory.length - 1 &&
                        msg.role == 'assistant';
                    return _buildChatBubble(msg, themeColors,
                        isStreaming: isStreaming);
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
              fontSize: 11,
              color: themeColors.onSurfaceTertiary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatEmptyState(var themeColors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacing3xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: BorderRadius.circular(AppDimens.radius2xl),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 32,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(height: AppDimens.spacingLg),
            Text(
              AppStrings.aiChatTitle,
              style: AppTheme.titleLarge.copyWith(
                color: themeColors.onSurface,
              ),
            ),
            const SizedBox(height: AppDimens.spacingXs),
            Text(
              '基于您的经期数据进行智能问答',
              style: AppTheme.bodySmall.copyWith(
                color: themeColors.onSurfaceTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickQuestion(String text, var themeColors) {
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
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage msg, var themeColors,
      {bool isStreaming = false}) {
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
          color: isUser
              ? AppColors.brandPrimary
              : themeColors.surfaceCard,
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
                  Text(
                    AppStrings.aiChatThinking,
                    style: AppTheme.bodySmall.copyWith(
                      color: themeColors.onSurfaceTertiary,
                    ),
                  ),
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
                    _StreamingCursor(themeColors: themeColors),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildChatInput(var themeColors) {
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
            disabledColor: AppColors.inkTertiary,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Reusable report card widget
// ═══════════════════════════════════════════════════════════════════

class _ReportCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final dynamic themeColors;

  const _ReportCard({
    required this.title,
    required this.icon,
    required this.child,
    required this.themeColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spacingLg),
      decoration: BoxDecoration(
        color: themeColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: themeColors.divider.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.brandPrimary),
              const SizedBox(width: AppDimens.spacingSm),
              Text(
                title,
                style: AppTheme.titleLarge.copyWith(
                  color: themeColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spacingMd),
          child,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Streaming cursor (闪烁光标，流式输出时使用)
// ═══════════════════════════════════════════════════════════════════

class _StreamingCursor extends StatefulWidget {
  final dynamic themeColors;

  const _StreamingCursor({required this.themeColors});

  @override
  State<_StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<_StreamingCursor>
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