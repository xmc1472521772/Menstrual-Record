import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../models/period_record.dart';
import '../providers/period_provider.dart';
import '../providers/settings_provider.dart';
import '../models/cycle_data.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../constants/app_theme.dart';
import '../utils/date_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// 缓存今日日期，只在 initState 时初始化，避免每次 build 都调用 DateTime.now()。
  late DateTime _today;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();

  /// ─── 日历翻页参数（可调）─────────────────────────────────────
  /// PageView 使用的基础页索引，对应 _baseMonth 的偏移量。
  /// 用一个较大的中间值，允许向前后翻页多个月。
  static const int _kInitialPage = 5000;

  /// PageView 控制器。
  late final PageController _pageController =
      PageController(initialPage: _kInitialPage);

  /// 基准月份（_kInitialPage 对应的月份），翻页索引以此为原点。
  final DateTime _baseMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);

  /// 当前 PageView 页码（用于标题更新）。
  int _currentPage = _kInitialPage;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _focusedDay = _today;
    _selectedDay = _today;
    _pageController.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    final page = _pageController.page?.round() ?? _kInitialPage;
    if (page != _currentPage) {
      _currentPage = page;
      final newMonth = DateTime(
        _baseMonth.year,
        _baseMonth.month + (page - _kInitialPage),
        1,
      );
      if (!_isSameMonth(newMonth, _focusedDay)) {
        setState(() {
          _focusedDay = newMonth;
        });
        _cleanupNotifiers();
      }
    }
  }

  bool _isSameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  /// 跳到指定月份（程序化跳转，如点击按钮或「回到今天」）。
  void _jumpToPage(DateTime month) {
    final delta = (month.year - _baseMonth.year) * 12 +
        (month.month - _baseMonth.month);
    final targetPage = _kInitialPage + delta;
    _pageController.animateToPage(
      targetPage,
      // ▶ 吸附动画时长（可调）：250ms–300ms，Material Design 推荐范围
      duration: const Duration(milliseconds: 280),
      // ▶ 吸附动画曲线（可调）：fastOutSlowIn，Material 推荐曲线
      curve: Curves.fastOutSlowIn,
    );
  }

  void _cleanupNotifiers() {
    final y = _focusedDay.year;
    final m = _focusedDay.month;
    final toRemove = <int>[];
    for (final key in _dayCellNotifiers.keys) {
      final keyY = AppDateUtils.dayKeyToYear(key);
      final keyM = AppDateUtils.dayKeyToMonth(key);
      if (keyY != y || keyM != m) {
        if (_selectedDay != null &&
            keyY == _selectedDay!.year &&
            keyM == _selectedDay!.month) {
          continue;
        }
        toRemove.add(key);
      }
    }
    for (final key in toRemove) {
      _dayCellNotifiers[key]?.dispose();
      _dayCellNotifiers.remove(key);
    }
  }

  /// 日历格子的局部刷新通知器：key 为 `yyyyMMdd`，按需懒创建。
  /// 选中某天时只重建受影响的 1~2 个格子，不再整页 setState。
  final Map<int, ValueNotifier<int>> _dayCellNotifiers =
      <int, ValueNotifier<int>>{};

  /// 选中状态版本号 —— 供「回到今天」按钮这类需要读取 _selectedDay 的部件监听。
  final ValueNotifier<int> _selectionVersion = ValueNotifier<int>(0);

  bool get _isTodaySelected {
    return _selectedDay != null &&
        _selectedDay!.year == _today.year &&
        _selectedDay!.month == _today.month &&
        _selectedDay!.day == _today.day;
  }

  bool get _isCurrentMonth {
    return _focusedDay.year == _today.year && _focusedDay.month == _today.month;
  }

  void _jumpToToday() {
    final previous = _selectedDay;
    _jumpToPage(DateTime(_today.year, _today.month, 1));
    _selectedDay = _today;
    if (previous != null) {
      _dayCellNotifiers[AppDateUtils.dayKey(previous)]?.value++;
    }
    _dayCellNotifiers[AppDateUtils.dayKey(_today)]?.value++;
    _selectionVersion.value++;
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    for (final notifier in _dayCellNotifiers.values) {
      notifier.dispose();
    }
    _dayCellNotifiers.clear();
    _selectionVersion.dispose();
    super.dispose();
  }

  static const List<String> _weekdayLabels = [
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
    '日',
  ];

  /// 普通格子的外边距。
  static const EdgeInsets _kDayCellMargin = EdgeInsets.all(3);

  /// 「今天 / 选中」描边格子的外边距。
  static const EdgeInsets _kDaySelectedMargin = EdgeInsets.all(2);

  static String _weekdayLabel(int weekday) => _weekdayLabels[weekday - 1];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: AppDimens.spacingXl,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(AppStrings.appName),
            const SizedBox(height: 2),
            Text(
              '${_today.month}月${_today.day}日 星期${_weekdayLabel(_today.weekday)}',
              style: AppTheme.bodySmall.copyWith(
                color: AppColors.inkSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              // 跳转到设置页的提醒设置区域
              MainScreen.globalKey.currentState?.jumpToSettings();
            },
            icon: const Icon(Icons.notifications_none_rounded, size: 22),
            color: AppColors.ink,
            tooltip: AppStrings.notificationTitle,
          ),
          const SizedBox(width: AppDimens.spacingSm),
        ],
      ),
      floatingActionButton: ValueListenableBuilder<int>(
        valueListenable: _selectionVersion,
        builder: (context, _, __) {
          final showFab =
              !_isCurrentMonth || (_selectedDay != null && !_isTodaySelected);
          if (!showFab) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 80),
            child: FloatingActionButton.small(
              onPressed: _jumpToToday,
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: AppColors.white,
              elevation: AppDimens.elevationLow,
              child: const Text(
                AppStrings.todayButton,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          );
        },
      ),
      body: Selector<PeriodProvider, int>(
        selector: (_, provider) => provider.dataVersion,
        builder: (context, _, __) {
          final provider = context.read<PeriodProvider>();
          final cycleData = provider.cycleData;

          // 错误提示横幅
          if (provider.lastError != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.spacingXl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 48, color: AppColors.error),
                    const SizedBox(height: AppDimens.spacingMd),
                    Text(
                      provider.lastError!,
                      textAlign: TextAlign.center,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: AppDimens.spacingLg),
                    ElevatedButton(
                      onPressed: () => provider.loadRecords(),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spacingXl,
              AppDimens.spacingSm,
              AppDimens.spacingXl,
              100,
            ),
            child: Column(
              children: [
                // 状态卡内容在数据不变时是静态的：RepaintBoundary 让它滚动时只
                // 整体平移、不逐帧重录（同时与下方日历的重绘相互隔离）。阴影等
                // 昂贵绘制已在 _buildStatusHero 内扁平化处理，见其注释。
                RepaintBoundary(child: _buildStatusHero(cycleData, provider)),
                const SizedBox(height: AppDimens.spacingLg),
                _buildQuickActions(provider),
                const SizedBox(height: AppDimens.spacingLg),
                // 日历与上方可独立重绘，互不影响；数据变化（添加经期）时
                // 只重绘本图层内的格子，不会波及上方状态卡片的重绘。
                RepaintBoundary(child: _buildCalendar(provider)),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Status hero ──────────────────────────────────────────────────
  Widget _buildStatusHero(CycleData? cycleData, PeriodProvider provider) {
    if (cycleData == null) {
      return _buildEmptyHero();
    }

    final daysUntil = cycleData.daysUntilPredicted;
    final currentDay = cycleData.currentCycleDay;
    final hasOngoing = provider.hasOngoingPeriod;

    final String caption;
    final String headline;
    final IconData icon;

    if (hasOngoing) {
      caption = AppStrings.periodOngoing;
      headline = '${AppStrings.currentDay} $currentDay ${AppStrings.days}';
      icon = Icons.favorite_rounded;
    } else if (daysUntil == null) {
      caption = AppStrings.recordToStartPredict;
      headline = AppStrings.noData;
      icon = Icons.info_outline_rounded;
    } else if (daysUntil > 0) {
      caption = AppStrings.daysUntilPeriod;
      headline = '$daysUntil ${AppStrings.days}';
      icon = Icons.calendar_today_rounded;
    } else if (daysUntil == 0) {
      caption = AppStrings.predictedNextPeriod;
      headline = AppStrings.predictedToday;
      icon = Icons.notifications_active_rounded;
    } else {
      caption = AppStrings.overdue;
      headline = '${-daysUntil} ${AppStrings.days}';
      icon = Icons.warning_amber_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimens.spacingXl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brandPrimary, AppColors.brandLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        // 性能说明：这里刻意不放 boxShadow。此前用 blur 28 的大投影制造悬浮感，
        // 但该卡片常驻在上下可滚动的首屏中——RepaintBoundary 只能避免重录，
        // 滚动时图层的每一帧仍会重放一次高斯模糊栅格化（这是「添加经期后，
        // 状态卡变为渐变版，滑动开始掉帧」的直接根因）。去掉后状态卡依靠渐变
        // 本身与画布底色形成层次，与整套 A1 扁平卡片语言保持一致，且渲染成本
        // 从「每帧 blur」降为「每帧一个线性渐变填充」。
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
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
                    Icon(icon, color: AppColors.white, size: 14),
                    const SizedBox(width: AppDimens.spacingXs),
                    Text(
                      caption,
                      style: AppTheme.labelMedium.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spacingMd),
          Text(
            headline,
            style: AppTheme.headingLarge.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: AppDimens.spacingXl),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spacingLg,
              vertical: AppDimens.spacingMd,
            ),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildHeroStat(
                    AppStrings.averageCycle,
                    '${cycleData.averageCycleLength.toStringAsFixed(1)} ${AppStrings.days}',
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: AppColors.white.withValues(alpha: 0.22),
                ),
                Expanded(
                  child: _buildHeroStat(
                    AppStrings.averagePeriod,
                    '${cycleData.averagePeriodLength.toStringAsFixed(1)} ${AppStrings.days}',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: AppColors.white.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: AppDimens.spacingXs - 2),
        Text(
          value,
          style: AppTheme.titleLarge.copyWith(color: AppColors.white),
        ),
      ],
    );
  }

  Widget _buildEmptyHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spacingXl,
        vertical: AppDimens.spacing3xl,
      ),
      decoration: BoxDecoration(
        color: AppColors.brandSurface,
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.calendar_month_rounded,
            color: AppColors.brandPrimary,
            size: 40,
          ),
          SizedBox(height: AppDimens.spacingMd),
          Text(
            AppStrings.startRecordingPrompt,
            style: AppTheme.titleLarge,
          ),
          SizedBox(height: AppDimens.spacingXs),
          Text(
            AppStrings.recordToViewStats,
            style: AppTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  // ─── Quick actions ────────────────────────────────────────────────

  /// 处理「开始经期」按钮点击，带自动合并逻辑。
  Future<void> _handleStartPeriod(
    BuildContext context,
    PeriodProvider provider,
  ) async {
    final settings = context.read<SettingsProvider>();
    final threshold = settings.mergeThreshold;

    final outcome = await provider.startPeriodWithMerge(
      DateTime.now(),
      mergeThreshold: threshold,
    );

    if (!mounted) return;

    switch (outcome.result) {
      case PeriodStartResult.created:
        // 直接新建成功，无需额外操作
        break;
      case PeriodStartResult.mergedSilently:
        // 同天静默合并：显示 SnackBar 提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(AppStrings.mergeSilentDone),
              duration: const Duration(seconds: 2),
              backgroundColor: AppColors.brandPrimary,
            ),
          );
        }
        break;
      case PeriodStartResult.needsConfirmation:
        // 间隔在阈值内：弹窗让用户选择
        if (mounted && outcome.mergeInfo != null) {
          await _showMergeConfirmationDialog(
            context,
            provider,
            outcome.mergeInfo!,
          );
        }
        break;
    }
  }

  /// 弹窗：让用户选择「续接上一段」还是「开启新经期」。
  Future<void> _showMergeConfirmationDialog(
    BuildContext context,
    PeriodProvider provider,
    PeriodMergeInfo info,
  ) async {
    final gapDays = info.gapDays;
    final bodyText = AppStrings.mergePromptBody.replaceAll('{}', gapDays.toString());

    final choice = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.mergePromptTitle),
        content: Text(bodyText),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(AppStrings.mergeAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(AppStrings.newPeriodAction),
          ),
        ],
      ),
    );

    // choice == true → 续接上一段；choice == false → 新经期；null → 取消
    if (choice == true) {
      await provider.mergeWithLastPeriod(info.newStartDate);
    } else if (choice == false) {
      await provider.startNewPeriod(info.newStartDate);
    }
  }

  Widget _buildQuickActions(PeriodProvider provider) {
    final hasOngoing = provider.hasOngoingPeriod;

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: hasOngoing
                  ? null
                  : () async {
                      await _handleStartPeriod(context, provider);
                    },
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text(AppStrings.startPeriod),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: AppColors.white,
                disabledBackgroundColor: AppColors.tile,
                disabledForegroundColor: AppColors.inkTertiary,
                elevation: AppDimens.elevationNone,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                textStyle: AppTheme.buttonLabel,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppDimens.spacingMd),
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: hasOngoing
                  ? () async {
                      await provider.endPeriod(DateTime.now());
                    }
                  : null,
              icon: const Icon(Icons.stop_rounded, size: 18),
              label: const Text(AppStrings.endPeriod),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brandPrimary,
                disabledForegroundColor: AppColors.inkTertiary,
                side: BorderSide(
                  color: hasOngoing
                      ? AppColors.brandPrimary
                      : AppColors.hairline,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                textStyle: AppTheme.buttonLabel,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Calendar ─────────────────────────────────────────────────────

  /// 将 PageView 索引转换为对应的月份 DateTime。
  DateTime _monthFromPage(int page) {
    final delta = page - _kInitialPage;
    return DateTime(
      _baseMonth.year,
      _baseMonth.month + delta,
      1,
    );
  }

  Widget _buildCalendar(PeriodProvider provider) {
    final border = BorderRadius.circular(AppDimens.radiusLg);

    return Container(
      decoration: BoxDecoration(
        color: context.themeColors.surfaceCard,
        borderRadius: border,
        border: Border.all(color: AppColors.hairline),
      ),
      child: ClipRRect(
        borderRadius: border,
        child: Column(
          children: [
            // ── 月份标题栏 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spacingSm,
                AppDimens.spacingSm,
                AppDimens.spacingSm,
                0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => _jumpToPage(DateTime(
                      _focusedDay.year,
                      _focusedDay.month - 1,
                      1,
                    )),
                    icon: const Icon(Icons.chevron_left_rounded),
                    color: AppColors.inkSecondary,
                    iconSize: 26,
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                    child: Text(
                      '${_focusedDay.year}年${_focusedDay.month}月',
                      key: ValueKey(
                          '${_focusedDay.year}-${_focusedDay.month}'),
                      style: AppTheme.titleLarge.copyWith(
                        color: context.themeColors.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _jumpToPage(DateTime(
                      _focusedDay.year,
                      _focusedDay.month + 1,
                      1,
                    )),
                    icon: const Icon(Icons.chevron_right_rounded),
                    color: AppColors.inkSecondary,
                    iconSize: 26,
                  ),
                ],
              ),
            ),
            // ── 星期标题行 ──
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spacingMd,
              ),
              child: Row(
                children: _weekdayLabels
                    .map(
                      (day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: AppTheme.bodySmall.copyWith(
                              color: AppColors.inkTertiary,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: AppDimens.spacingSm),
            // ── PageView 日历网格（安卓原生翻页） ──
            //
            // 核心特性：
            // 1. 1:1 触摸跟手滑动（PageView 默认行为）
            // 2. 翻页阈值（可调）：PageView 默认约 1/3 视口宽度
            //    可通过 [PageView.builder] 的 [pageSnapping] 控制（默认 true）
            // 3. 吸附动画时长：由系统 physics 控制，通常 250ms–300ms
            // 4. 物理特性：[ClampingScrollPhysics] ——
            //    禁用 iOS 回弹，使用安卓原生夹紧效果
            // 5. 边缘拉伸效果（可调）：由 [_StretchScrollBehavior] 提供
            //    Android 12+ Stretch overscroll 效果
            //
            // ▶ 滑动吸附阈值：由 PageView 的 viewportFraction 和
            //    physics 中的 tolerance 共同决定，默认 ~30% 视口宽度
            // ▶ 动画时长：PageView 翻页由 ClampingScrollPhysics 创建的
            //    BallisticSimulation 决定，Material 默认 250ms 左右
            // ▶ 边缘拉伸强度：在 [_StretchScrollBehavior] 中通过
            //    OverscrollStretch 规则控制
            LayoutBuilder(
              builder: (context, constraints) {
                // 根据实际可用宽度动态计算6行格子总高度：
                // 每格宽度 = (屏宽 - 2*spacingMd) / 7，高度 = 宽度 (1:1)，
                // 总高度 = 6 × 单格高度。
                final cellWidth =
                    (constraints.maxWidth - AppDimens.spacingMd * 2) / 7;
                final gridHeight = cellWidth * 6;
                return SizedBox(
                  height: gridHeight,
                  child: ScrollConfiguration(
                    behavior: _StretchScrollBehavior(),
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const ClampingScrollPhysics(
                        // ▶ 边缘拉伸/发光强度（可调）：
                        //    ClampingScrollPhysics 默认使用 GlowOverscrollIndicator
                        //    （Android 12+ 会自动升级为 Stretch overscroll）
                      ),
                      pageSnapping: true, // 吸附到整数页
                      itemBuilder: (context, page) {
                        final month = _monthFromPage(page);
                        return _buildCalendarGridForMonth(provider, month);
                      },
                    ),
                  ),
                );
              },
            ),
            const Divider(height: 1),
            const SizedBox(height: AppDimens.spacingMd),
            _buildLegend(),
            const SizedBox(height: AppDimens.spacingMd),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGridForMonth(
      PeriodProvider provider, DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    final weekday = firstDay.weekday;
    final daysInMonth = lastDay.day;
    final prevMonthDays = weekday - 1;

    final now = _today;
    final todayStart = DateTime(now.year, now.month, now.day);

    // 固定 6 行（42 格）：不同月份天数不同会导致行数在 4~6 之间变化，
    // 固定为 6 行可消除月份间日历高度差异，避免与下方预测信息间隙忽大忽小。
    final rows = 6;

    // 主题相关的三个文字色在整个网格构建中只查询一次，再传给 42 个格子，
    // 避免每格重复做 Theme/ThemeExtension 查找（一次网格构建少 80+ 次）。
    final themeColors = context.themeColors;
    final palette = _DayCellPalette(
      onSurface: themeColors.onSurface,
      onSurfaceSecondary: themeColors.onSurfaceSecondary,
      onSurfaceTertiary: themeColors.onSurfaceTertiary,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spacingMd),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List<Widget>.generate(rows, (row) {
          return Expanded(
            child: Row(
              children: List<Widget>.generate(7, (col) {
                final index = row * 7 + col;
                final dayOffset = index - prevMonthDays;

                // ── 非本月日期：用上下月日期填充并置灰 ──
                if (dayOffset < 0) {
                  // 上个月末尾日期
                  final prevDay = DateTime(
                    month.year,
                    month.month,
                    dayOffset + 1, // dayOffset 为负，DateTime 会自动回退到上月
                  );
                  return Expanded(
                    child: _buildOtherMonthCell(prevDay, palette),
                  );
                }
                if (dayOffset >= daysInMonth) {
                  // 下个月开头日期
                  final nextDay = DateTime(
                    month.year,
                    month.month,
                    dayOffset + 1, // 超出本月天数，DateTime 会自动前进到下月
                  );
                  return Expanded(
                    child: _buildOtherMonthCell(nextDay, palette),
                  );
                }

                // ── 本月日期 ──
                final day =
                    DateTime(month.year, month.month, dayOffset + 1);
                final dayType = provider.getDayType(day);
                final isToday = _isSameDay(now, day);

                return Expanded(
                  child: ValueListenableBuilder<int>(
                    // 只在选中日期变化时重建格子，而不是整个页面
                    valueListenable: _cellNotifierFor(AppDateUtils.dayKey(day)),
                    builder: (context, _, __) {
                      final isSelected = _isSameDay(_selectedDay, day);
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _selectDay(day),
                        onLongPress: () => _showDayDetail(context, day, dayType, provider),
                        child: _buildDayCell(
                          day,
                          dayType,
                          isSelected,
                          isToday,
                          todayStart,
                          palette,
                        ),
                      );
                    },
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  /// 构建非本月日期格子（上月末尾 / 下月开头），置灰显示。
  Widget _buildOtherMonthCell(DateTime day, _DayCellPalette palette) {
    return Container(
      margin: _kDayCellMargin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: palette.onSurfaceTertiary.withValues(alpha: 0.4),
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  ValueNotifier<int> _cellNotifierFor(int key) =>
      _dayCellNotifiers.putIfAbsent(key, () => ValueNotifier<int>(0));

  void _selectDay(DateTime day) {
    final previous = _selectedDay;
    _selectedDay = day;
    // 只刷新旧选中项和新选中项这两个格子
    if (previous != null) {
      _dayCellNotifiers[AppDateUtils.dayKey(previous)]?.value++;
    }
    _dayCellNotifiers[AppDateUtils.dayKey(day)]?.value++;
  }

  /// 长按日历日期显示详情弹窗。
  void _showDayDetail(
      BuildContext context, DateTime day, String dayType, PeriodProvider provider) {
    final cycleData = provider.cycleData;

    // 日类型中文标签
    const typeLabels = {
      'period': '经期',
      'predicted': '预测经期',
      'ovulation': '排卵日',
      'fertile': '易孕期',
      'safe': '安全期',
      'normal': '普通日',
    };
    final typeLabel = typeLabels[dayType] ?? '普通日';
    final typeColor = AppColors.dayTypeColor(dayType);

    // 计算距下次经期天数
    String? daysToNext;
    if (cycleData != null && cycleData.predictedNextPeriod != null) {
      final diff = cycleData.predictedNextPeriod!.difference(day).inDays;
      if (diff > 0) {
        daysToNext = '距下次经期还有 $diff 天';
      } else if (diff == 0) {
        daysToNext = '今天预测经期开始';
      }
    }

    // 查找该日期所属的经期记录
    PeriodRecord? matchedRecord;
    for (final r in provider.records) {
      if (!r.isOngoing && r.endDateTime != null) {
        if (!day.isBefore(r.startDateTime) && !day.isAfter(r.endDateTime!)) {
          matchedRecord = r;
          break;
        }
      } else if (r.isOngoing) {
        if (!day.isBefore(r.startDateTime) &&
            !day.isAfter(DateTime.now())) {
          matchedRecord = r;
          break;
        }
      }
    }

    final themeColors = context.themeColors;
    final secondaryColor = themeColors.onSurfaceSecondary;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '${day.year}年${day.month}月${day.day}日',
          style: AppTheme.titleMedium.copyWith(color: themeColors.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: typeColor,
                    shape: BoxShape.circle,
                    border: typeColor == AppColors.transparent
                        ? Border.all(color: themeColors.divider, width: 1)
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Text(typeLabel,
                    style: AppTheme.bodyMedium
                        .copyWith(color: themeColors.onSurface)),
              ],
            ),
            if (daysToNext != null) ...[
              const SizedBox(height: 12),
              Text(daysToNext,
                  style:
                      AppTheme.bodySmall.copyWith(color: secondaryColor)),
            ],
            if (matchedRecord != null) ...[
              const SizedBox(height: 12),
              Text(
                '经期记录：${matchedRecord.startDateTime.month}/${matchedRecord.startDateTime.day} - ${matchedRecord.isOngoing ? '进行中' : '${matchedRecord.endDateTime!.month}/${matchedRecord.endDateTime!.day}'}',
                style:
                    AppTheme.bodySmall.copyWith(color: secondaryColor),
              ),
              const SizedBox(height: 4),
              Text(
                '持续 ${matchedRecord.periodDays} 天',
                style:
                    AppTheme.bodySmall.copyWith(color: secondaryColor),
              ),
              if (matchedRecord.mood != null ||
                  matchedRecord.symptoms != null) ...[
                const SizedBox(height: 8),
                if (matchedRecord.mood != null)
                  Text('心情：${matchedRecord.mood}',
                      style: TextStyle(
                          fontSize: 16, color: themeColors.onSurface)),
                if (matchedRecord.symptoms != null)
                  Text('症状：${matchedRecord.symptoms}',
                      style: AppTheme.bodySmall
                          .copyWith(color: secondaryColor)),
              ],
              if (matchedRecord.notes != null &&
                  matchedRecord.notes!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('备注：${matchedRecord.notes}',
                    style: AppTheme.bodySmall
                        .copyWith(color: secondaryColor)),
              ],
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppStrings.confirm),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildDayCell(
    DateTime day,
    String dayType,
    bool isSelected,
    bool isToday,
    DateTime todayStart,
    _DayCellPalette palette,
  ) {
    final isPast = DateTime(day.year, day.month, day.day).isBefore(todayStart);

    Color? fill;
    Color? ring;
    Color textColor;
    FontWeight fontWeight = FontWeight.w500;

    switch (dayType) {
      case 'period':
        fill = AppColors.brandPrimary;
        textColor = AppColors.white;
        fontWeight = FontWeight.w600;
        break;
      case 'predicted':
        ring = AppColors.brandPrimary;
        textColor = AppColors.brandPrimary;
        break;
      case 'ovulation':
        fill = AppColors.ovulationDay;
        textColor = AppColors.ink;
        break;
      case 'fertile':
        fill = AppColors.fertileBg;
        textColor = AppColors.fertileDay;
        break;
      case 'safe':
        fill = AppColors.safeDay.withValues(alpha: 0.55);
        textColor = palette.onSurfaceSecondary;
        break;
      default:
        textColor = isToday
            ? AppColors.brandPrimary
            : (isPast ? palette.onSurface : palette.onSurfaceTertiary);
        fontWeight = isToday ? FontWeight.w700 : FontWeight.w400;
    }

    final cell = Container(
      margin: _kDayCellMargin,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: ring != null ? Border.all(color: ring, width: 1.2) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: textColor,
          fontSize: 13,
          fontWeight: fontWeight,
        ),
      ),
    );

    if (isToday || isSelected) {
      return Container(
        margin: _kDaySelectedMargin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          border: Border.all(
            color: AppColors.brandPrimary,
            width: isSelected ? 2 : 1.4,
          ),
        ),
        child: cell,
      );
    }

    return cell;
  }

  // ─── Legend ───────────────────────────────────────────────────────
  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spacingMd),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem(color: AppColors.brandPrimary, label: AppStrings.legendPeriod),
          _buildLegendItem(
            color: AppColors.transparent,
            ring: AppColors.brandPrimary,
            label: AppStrings.legendPredicted,
          ),
          _buildLegendItem(color: AppColors.ovulationDay, label: AppStrings.legendOvulation),
          _buildLegendItem(color: AppColors.fertileBg, label: AppStrings.legendFertile),
          _buildLegendItem(color: AppColors.safeDay, label: AppStrings.legendSafe),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    Color? ring,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spacingXs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              border: ring != null ? Border.all(color: ring, width: 1.2) : null,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppDimens.spacingXs),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(
              color: AppColors.inkSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// 单次网格构建解析出的主题色快照。
///
/// 42 个日历格子共用同一份，避免每个格子构建时各自执行
/// `Theme.of(context).extension<AppThemeColors>()` 查找。
class _DayCellPalette {
  const _DayCellPalette({
    required this.onSurface,
    required this.onSurfaceSecondary,
    required this.onSurfaceTertiary,
  });

  final Color onSurface;
  final Color onSurfaceSecondary;
  final Color onSurfaceTertiary;
}

/// 安卓原生风格的 ScrollBehavior —— 用于日历 PageView。
///
/// 关键特性：
/// 1. 强制使用 [ClampingScrollPhysics]（安卓原生夹紧物理，非 iOS 回弹）
/// 2. 使用 [StretchOverscrollIndicator] 提供 Android 12+ 的拉伸过滚动效果
///    （在低于 Android 12 的设备上，框架会自动回退为传统的 Glow 微光反馈）
///
/// ▶ 边缘拉伸强度（可调）：
///    拉伸幅度由 [StretchOverscrollIndicator] 内部的 overscroll 偏移量决定，
///    越大的拖拽距离产生越明显的拉伸，松手后以 [Curves.fastOutSlowIn] 回弹。
///    如需调整强度，可在此 behavior 中覆写 [buildOverscrollIndicator]
///    并返回自定义的 indicator。
class _StretchScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    // Android 12+ 使用 Stretch overscroll；低版本自动回退为 Glow。
    return StretchingOverscrollIndicator(
      // ▶ 拉伸方向：水平（日历左右翻页）
      axisDirection: AxisDirection.right,
      child: child,
    );
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // 强制使用 ClampingScrollPhysics，禁用 iOS 的 BouncingScrollPhysics。
    return const ClampingScrollPhysics();
  }
}
