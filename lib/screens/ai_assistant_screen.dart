import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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
  // ─── 报告相关状态 ───
  HealthReport? _report;
  bool _isAnalyzing = false;
  String? _error;
  int _analyzingStep = 0;
  int _lastReportDataVersion = 0;

  // ─── 问答相关状态 ───
  final List<ChatMessage> _chatHistory = [];
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
      _generateReport();
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

    // 检查API Key是否配置
    if (!AIHealthService.isConfigured) {
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
      );

      if (mounted) {
        setState(() {
          _report = report;
          _isAnalyzing = false;
          _lastReportDataVersion = provider.dataVersion;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _error = '$e';
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
    return _lastReportDataVersion != provider.dataVersion &&
        _lastReportDataVersion != 0;
  }

  // ─── 问答功能（流式）────────────────────────────────────────

  Future<void> _sendChatMessage(String text) async {
    if (text.trim().isEmpty || _isChatLoading) return;

    final provider = context.read<PeriodProvider>();
    final settings = context.read<SettingsProvider>();

    if (provider.records.isEmpty || provider.cycleData == null) {
      return;
    }

    final userMessage = ChatMessage(
      role: 'user',
      content: text.trim(),
      timestamp: DateTime.now(),
    );

    // 立即添加用户消息和空的AI回答消息
    setState(() {
      _chatHistory.add(userMessage);
      _chatHistory.add(ChatMessage(
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
        // 传不含最后空回答的历史
        chatHistory: _chatHistory.sublist(0, _chatHistory.length - 1),
      );

      await for (final chunk in stream) {
        if (!mounted) break;
        _streamingBuffer.write(chunk);
        // 实时更新最后一条AI消息
        setState(() {
          final lastIndex = _chatHistory.length - 1;
          _chatHistory[lastIndex] = ChatMessage(
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
        setState(() {
          // 如果有部分内容已经收到，保留它并添加错误标记
          if (_streamingBuffer.isNotEmpty) {
            final lastIndex = _chatHistory.length - 1;
            _chatHistory[lastIndex] = ChatMessage(
              role: 'assistant',
              content: '${_streamingBuffer.toString()}\n\n⚠️ $e',
              timestamp: DateTime.now(),
            );
          } else {
            // 没收到任何内容，替换为错误提示
            final lastIndex = _chatHistory.length - 1;
            _chatHistory[lastIndex] = ChatMessage(
              role: 'assistant',
              content: '回答失败：$e',
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
          if (_currentTab == 0 && _report != null && !_isAnalyzing)
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
    if (_isAnalyzing) {
      return _buildAnalyzingState(context);
    }
    if (_error != null) {
      return _buildErrorState(context);
    }
    if (_report == null) {
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
  //  Full report (移除基本信息卡片，改为摘要行)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildReport(BuildContext context) {
    final report = _report!;
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

          // ─── 摘要行（替代原"基本信息"卡片）───
          _buildSummaryRow(context, report, themeColors),
          const SizedBox(height: AppDimens.spacingLg),

          // ─── 报告摘要 ───
          _buildSummaryCard(context, report, themeColors),
          const SizedBox(height: AppDimens.spacingLg),

          // ─── 周期评估 ───
          _buildCycleAssessmentCard(context, report, themeColors),
          const SizedBox(height: AppDimens.spacingLg),

          // ─── 症因排查 ───
          _buildCauseAnalysisCard(context, report, themeColors),
          const SizedBox(height: AppDimens.spacingLg),

          // ─── 行动建议 ───
          _buildActionSuggestionsCard(context, report, themeColors),
          const SizedBox(height: AppDimens.spacingLg),

          // ─── 就医预警 ───
          _buildRedFlagsCard(context, report, themeColors),
          const SizedBox(height: AppDimens.spacingLg),

          // ─── 健康建议 ───
          ..._buildAdviceCards(context, report, themeColors),

          // ─── 免责声明 ───
          const SizedBox(height: AppDimens.spacingLg),
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

  // ─── 摘要行（替代原"基本信息"卡片）──────────────────────────────

  Widget _buildSummaryRow(
    BuildContext context,
    HealthReport report,
    var themeColors,
  ) {
    final info = report.basicInfo;
    final records = info['totalRecords'] ?? '-';
    final lastDate = info['lastPeriodDate'] ?? '-';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spacingXs),
      child: Text(
        '基于 $records · 上次经期 $lastDate',
        style: AppTheme.bodySmall.copyWith(
          color: themeColors.onSurfaceTertiary,
        ),
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

  // ─── 报告摘要 ──────────────────────────────────────────────────

  Widget _buildSummaryCard(
    BuildContext context,
    HealthReport report,
    var themeColors,
  ) {
    return _ReportCard(
      title: AppStrings.aiReportSummary,
      icon: Icons.summarize_rounded,
      themeColors: themeColors,
      child: Text(
        report.summary,
        style: AppTheme.bodyMedium.copyWith(
          color: themeColors.onSurfaceSecondary,
          height: 1.6,
        ),
      ),
    );
  }

  // ─── 周期评估 ──────────────────────────────────────────────────

  Widget _buildCycleAssessmentCard(
    BuildContext context,
    HealthReport report,
    var themeColors,
  ) {
    final assessment = report.cycleAssessment;
    final bool isNormal = assessment.isNormal;
    final Color statusColor =
        isNormal ? AppColors.success : AppColors.warning;
    final String statusLabel = isNormal
        ? AppStrings.aiOnTrack
        : (assessment.deviationDays > 0
            ? AppStrings.aiDaysLate
            : AppStrings.aiDaysEarly);

    return _ReportCard(
      title: AppStrings.aiCycleAssessment,
      icon: Icons.analytics_outlined,
      themeColors: themeColors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spacingMd,
                  vertical: AppDimens.spacingXs + 2,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isNormal
                          ? Icons.check_circle_rounded
                          : Icons.warning_amber_rounded,
                      color: statusColor,
                      size: 14,
                    ),
                    const SizedBox(width: AppDimens.spacingXs),
                    Text(
                      assessment.deviationDays == 0
                          ? statusLabel
                          : '$statusLabel ${assessment.deviationDays.abs()} 天',
                      style:
                          AppTheme.labelMedium.copyWith(color: statusColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spacingMd),
          Text(
            assessment.explanation,
            style: AppTheme.bodyMedium.copyWith(
              color: themeColors.onSurfaceSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppDimens.spacingMd),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spacingMd,
              vertical: AppDimens.spacingSm,
            ),
            decoration: BoxDecoration(
              color: themeColors.surfaceTile,
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 14, color: themeColors.onSurfaceTertiary),
                const SizedBox(width: AppDimens.spacingXs),
                Expanded(
                  child: Text(
                    assessment.normalRange,
                    style: AppTheme.bodySmall.copyWith(
                      color: themeColors.onSurfaceTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 症因排查 ──────────────────────────────────────────────────

  Widget _buildCauseAnalysisCard(
    BuildContext context,
    HealthReport report,
    var themeColors,
  ) {
    return _ReportCard(
      title: AppStrings.aiCauseAnalysis,
      icon: Icons.search_rounded,
      themeColors: themeColors,
      child: Column(
        children: report.causeFactors.asMap().entries.map((entry) {
          final idx = entry.key;
          final factor = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: idx < report.causeFactors.length - 1
                  ? AppDimens.spacingMd
                  : 0,
            ),
            child: _buildFactorItem(factor, themeColors, idx + 1),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFactorItem(CauseFactor factor, var themeColors, int index) {
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
                factor.factor,
                style: AppTheme.titleMedium.copyWith(
                  color: themeColors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppDimens.spacingXs),
              Text(
                factor.explanation,
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

  // ─── 行动建议 ──────────────────────────────────────────────────

  Widget _buildActionSuggestionsCard(
    BuildContext context,
    HealthReport report,
    var themeColors,
  ) {
    return _ReportCard(
      title: AppStrings.aiActionSuggestions,
      icon: Icons.tips_and_updates_outlined,
      themeColors: themeColors,
      child: Column(
        children: report.actionSuggestions.asMap().entries.map((entry) {
          final idx = entry.key;
          final suggestion = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: idx < report.actionSuggestions.length - 1
                  ? AppDimens.spacingMd
                  : 0,
            ),
            child: _buildSuggestionItem(suggestion, themeColors),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSuggestionItem(ActionSuggestion suggestion, var themeColors) {
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
              const Icon(Icons.visibility_outlined,
                  size: 14, color: AppColors.brandPrimary),
              const SizedBox(width: AppDimens.spacingXs),
              Text(
                AppStrings.aiObservation,
                style: AppTheme.labelMedium.copyWith(
                  color: AppColors.brandPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spacingXs),
          Text(
            suggestion.observation,
            style: AppTheme.bodySmall.copyWith(
              color: themeColors.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppDimens.spacingSm),
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  size: 14, color: AppColors.success),
              const SizedBox(width: AppDimens.spacingXs),
              Text(
                AppStrings.aiSuggestion,
                style: AppTheme.labelMedium.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spacingXs),
          Text(
            suggestion.suggestion,
            style: AppTheme.bodySmall.copyWith(
              color: themeColors.onSurfaceSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 就医预警（个性化 userMatched 高亮）──────────────────────────

  Widget _buildRedFlagsCard(
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
                AppStrings.aiRedFlags,
                style: AppTheme.titleLarge.copyWith(
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spacingSm),
          Text(
            '出现以下「红旗症状」时必须立即就医：',
            style: AppTheme.bodySmall.copyWith(
              color: themeColors.onSurfaceSecondary,
            ),
          ),
          const SizedBox(height: AppDimens.spacingMd),
          Column(
            children: report.redFlags.asMap().entries.map((entry) {
              final idx = entry.key;
              final flag = entry.value;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: idx < report.redFlags.length - 1
                      ? AppDimens.spacingSm
                      : 0,
                ),
                child: _buildRedFlagItem(flag, themeColors),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRedFlagItem(RedFlagSymptom flag, var themeColors) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spacingSm),
      margin: const EdgeInsets.only(bottom: AppDimens.spacingSm),
      decoration: BoxDecoration(
        color: flag.userMatched
            ? AppColors.error.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: flag.userMatched
            ? Border.all(color: AppColors.error.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            flag.userMatched ? Icons.priority_high_rounded : Icons.flag_rounded,
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
                    Text(
                      flag.symptom,
                      style: AppTheme.titleMedium.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (flag.userMatched) ...[
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
                          '⚠️ 已符合',
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
                  flag.description,
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

  // ─── 健康建议卡片 ──────────────────────────────────────────────

  List<Widget> _buildAdviceCards(
    BuildContext context,
    HealthReport report,
    var themeColors,
  ) {
    return report.advices.map((advice) {
      final (bgColor, iconColor) = _adviceColors(advice.type);
      return Padding(
        padding: const EdgeInsets.only(bottom: AppDimens.spacingLg),
        child: Container(
          padding: const EdgeInsets.all(AppDimens.spacingLg),
          decoration: BoxDecoration(
            color: themeColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(
              color: iconColor.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                ),
                child: Icon(advice.icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: AppDimens.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      advice.title,
                      style: AppTheme.titleMedium.copyWith(
                        color: iconColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppDimens.spacingXs),
                    Text(
                      advice.content,
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
        ),
      );
    }).toList();
  }

  (Color, Color) _adviceColors(AdviceType type) {
    return switch (type) {
      AdviceType.info =>
        (AppColors.success.withValues(alpha: 0.1), AppColors.success),
      AdviceType.caution =>
        (AppColors.warning.withValues(alpha: 0.1), AppColors.warning),
      AdviceType.warning =>
        (AppColors.error.withValues(alpha: 0.1), AppColors.error),
    };
  }

  // ─── 免责声明 ──────────────────────────────────────────────────

  Widget _buildDisclaimer(BuildContext context, var themeColors) {
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
              AppStrings.aiDisclaimer,
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
    // 判断是否为初始空状态（没有任何消息）
    final isEmpty = _chatHistory.isEmpty;

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
                  itemCount: _chatHistory.length,
                  itemBuilder: (context, index) {
                    final msg = _chatHistory[index];
                    // 最后一条AI消息正在流式输出时显示打字光标
                    final isStreaming = _isChatLoading &&
                        index == _chatHistory.length - 1 &&
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
            0,
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
                    child: Text(
                      displayContent,
                      style: AppTheme.bodyMedium.copyWith(
                        color: isUser ? AppColors.white : themeColors.onSurface,
                        height: 1.5,
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