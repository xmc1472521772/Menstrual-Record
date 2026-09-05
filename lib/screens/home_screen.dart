import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../providers/period_provider.dart';
import '../models/cycle_data.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../constants/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();

  // ─── 三个月数据（拖拽前预算好，拖拽中只读） ──────────────────────
  late DateTime _prevMonth;
  late DateTime _currentMonth;
  late DateTime _nextMonth;

  // ─── 偏移通知器（避免整页 setState） ────────────────────────────
  /// 拖拽/动画产生的水平偏移（px）。
  /// 正值=向右拖→上月，负值=向左拖→下月。
  final ValueNotifier<double> _offsetNotifier = ValueNotifier<double>(0);

  /// 标题透明度通知器（0=当前月完全显示，1=目标月完全显示）。
  /// 仅用于标题栏交叉淡化。
  final ValueNotifier<double> _titleProgressNotifier =
      ValueNotifier<double>(0);

  // ─── 动画控制器 ──────────────────────────────────────────────────
  late final AnimationController _animController;
  Animation<double>? _animAnimation;

  // ─── 状态标志 ────────────────────────────────────────────────────
  /// 是否处于 settle 动画（翻月或回弹）中。
  bool _isSettling = false;

  /// 手势开始时是否已有 settle 动画在进行（用于中断续接）。
  bool _wasSettlingOnDragStart = false;

  // ─── 常量 ────────────────────────────────────────────────────────
  /// 翻月的拖拽距离阈值（屏幕宽度的比例）。
  static const double _kSwipeThresholdRatio = 0.25;

  /// 翻米的最低横向滑动速度（px/s）。
  static const double _kSwipeVelocityThreshold = 500;

  /// 标题栏动画的最大位移（px）。
  static const double _kTitleShift = 20;

  /// 日历格子的局部刷新通知器：key 为 `yyyyMMdd`，按需懒创建。
  final Map<int, ValueNotifier<int>> _dayCellNotifiers =
      <int, ValueNotifier<int>>{};

  /// 选中状态版本号 —— 供「回到今天」按钮这类需要读取 _selectedDay 的部件监听。
  final ValueNotifier<int> _selectionVersion = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _recomputeThreeMonths();
  }

  /// 根据 _focusedDay 重新计算三个月数据。
  void _recomputeThreeMonths() {
    _currentMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    _prevMonth = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
    _nextMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
  }

  bool get _isTodaySelected {
    final now = DateTime.now();
    return _selectedDay != null &&
        _selectedDay!.year == now.year &&
        _selectedDay!.month == now.month &&
        _selectedDay!.day == now.day;
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _focusedDay.year == now.year && _focusedDay.month == now.month;
  }

  void _jumpToToday() {
    final now = DateTime.now();
    final previous = _selectedDay;
    _animController.stop();
    _isSettling = false;
    _offsetNotifier.value = 0;
    _titleProgressNotifier.value = 0;
    setState(() {
      _focusedDay = DateTime(now.year, now.month, 1);
    });
    _recomputeThreeMonths();
    _selectedDay = now;
    if (previous != null) {
      _dayCellNotifiers[_dayKey(previous)]?.value++;
    }
    _dayCellNotifiers[_dayKey(now)]?.value++;
    _selectionVersion.value++;
  }

  @override
  void dispose() {
    _animController.dispose();
    _offsetNotifier.dispose();
    _titleProgressNotifier.dispose();
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
    final now = DateTime.now();

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
              '${now.month}月${now.day}日 星期${_weekdayLabel(now.weekday)}',
              style: AppTheme.bodySmall.copyWith(
                color: AppColors.inkSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
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
                '今',
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

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spacingXl,
              AppDimens.spacingSm,
              AppDimens.spacingXl,
              100,
            ),
            child: Column(
              children: [
                RepaintBoundary(child: _buildStatusHero(cycleData, provider)),
                const SizedBox(height: AppDimens.spacingLg),
                _buildQuickActions(provider),
                const SizedBox(height: AppDimens.spacingLg),
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
      caption = '记录经期以开始预测';
      headline = '暂无数据';
      icon = Icons.info_outline_rounded;
    } else if (daysUntil > 0) {
      caption = AppStrings.daysUntilPeriod;
      headline = '$daysUntil ${AppStrings.days}';
      icon = Icons.calendar_today_rounded;
    } else if (daysUntil == 0) {
      caption = AppStrings.predictedNextPeriod;
      headline = '预计今天';
      icon = Icons.notifications_active_rounded;
    } else {
      caption = '已逾期';
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
                    '${cycleData.averageCycleLength.round()} ${AppStrings.days}',
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
                    '${cycleData.averagePeriodLength.round()} ${AppStrings.days}',
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
            '开始记录您的经期',
            style: AppTheme.titleLarge,
          ),
          SizedBox(height: AppDimens.spacingXs),
          Text(
            '记录后可查看周期预测与统计',
            style: AppTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  // ─── Quick actions ────────────────────────────────────────────────
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
                      await provider.startPeriod(DateTime.now());
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

  // ─── Calendar: 手势 + 三月并存 ────────────────────────────────────

  /// 手指拖拽开始。
  void _onDragStart(DragStartDetails details) {
    // 如果 settle 动画进行中，立即停止并从当前位置续接手势。
    _wasSettlingOnDragStart = _isSettling;
    _animController.stop();
    _isSettling = false;
    // 月份数据在拖拽期间保持不变。
  }

  /// 手指拖拽过程中 1:1 跟随（不使用 Curve）。
  void _onDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    // 限制偏移范围在 [-screenWidth, +screenWidth] 之间，防止过度拖拽。
    final screenWidth = MediaQuery.of(context).size.width;
    final newOffset = (_offsetNotifier.value + delta).clamp(
      -screenWidth,
      screenWidth,
    );
    _offsetNotifier.value = newOffset;
    // 更新标题进度。
    _titleProgressNotifier.value =
        (_offsetNotifier.value / screenWidth).clamp(-1.0, 1.0);
  }

  /// 手指抬起后判定翻月或回弹。
  void _onDragEnd(DragEndDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final offset = _offsetNotifier.value;
    final velocity = details.primaryVelocity ?? 0;
    final threshold = screenWidth * _kSwipeThresholdRatio;

    // 判断方向：offset<0 → 左拖→下月(+1)；offset>0 → 右拖→上月(-1)
    final direction = offset < 0 ? 1 : -1;
    final absOffset = offset.abs();

    // 双阈值：距离或速度任一满足即可翻月。
    final distanceMet = absOffset >= threshold;
    final velocityMet =
        (velocity.abs() >= _kSwipeVelocityThreshold) &&
        ((direction == 1 && velocity < 0) ||
            (direction == -1 && velocity > 0));

    if (distanceMet || velocityMet) {
      _settleToMonth(direction);
    } else {
      _settleBack();
    }
  }

  /// 回弹动画：偏移从当前值回到 0。
  void _settleBack() {
    final startOffset = _offsetNotifier.value;
    if (startOffset == 0) return;

    _isSettling = true;
    _animController.value = 0;
    _animAnimation = Tween<double>(begin: startOffset, end: 0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutQuart,
      ),
    )..addListener(() {
      final v = _animAnimation!.value;
      _offsetNotifier.value = v;
      final screenWidth = MediaQuery.of(context).size.width;
      _titleProgressNotifier.value = (v / screenWidth).clamp(-1.0, 1.0);
    });

    _animController.forward(from: 0).then((_) {
      _isSettling = false;
    });
  }

  /// 翻月动画：偏移从当前值平移到完整页宽，然后切换月份并重置。
  void _settleToMonth(int delta) {
    final screenWidth = MediaQuery.of(context).size.width;
    // 目标偏移：delta>0(下月) → -screenWidth；delta<0(上月) → +screenWidth
    final targetOffset = delta > 0 ? -screenWidth : screenWidth;
    final startOffset = _offsetNotifier.value;

    _isSettling = true;
    _animController.value = 0;
    _animAnimation = Tween<double>(
      begin: startOffset,
      end: targetOffset,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutQuart,
      ),
    )..addListener(() {
      final v = _animAnimation!.value;
      _offsetNotifier.value = v;
      _titleProgressNotifier.value = (v / screenWidth).clamp(-1.0, 1.0);
    });

    _animController.forward(from: 0).then((_) {
      // 动画完成：切换月份数据，重置偏移到 0。
      // 用户看不到重置——因为月份已变，网格内容直接替换。
      _doChangeMonth(delta);
      _offsetNotifier.value = 0;
      _titleProgressNotifier.value = 0;
      _isSettling = false;
    });
  }

  /// 按钮点击切换月份（带平移动画）。
  void _changeMonth(int delta) {
    if (_isSettling) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final targetOffset = delta > 0 ? -screenWidth : screenWidth;

    _isSettling = true;
    _animController.value = 0;
    _animAnimation = Tween<double>(
      begin: 0,
      end: targetOffset,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutQuart,
      ),
    )..addListener(() {
      final v = _animAnimation!.value;
      _offsetNotifier.value = v;
      _titleProgressNotifier.value = (v / screenWidth).clamp(-1.0, 1.0);
    });

    _animController.forward(from: 0).then((_) {
      // 切换月份，重置偏移到 0。
      _doChangeMonth(delta);
      _offsetNotifier.value = 0;
      _titleProgressNotifier.value = 0;
      _isSettling = false;
    });
  }

  /// 实际执行月份切换 + notifier 清理 + 三月数据更新。
  void _doChangeMonth(int delta) {
    setState(() {
      _focusedDay = DateTime(
        _focusedDay.year,
        _focusedDay.month + delta,
        1,
      );
    });
    _recomputeThreeMonths();
    // 清理非当前月和选中日的 notifier，防止来回滑动多个月后无界增长。
    final y = _focusedDay.year;
    final m = _focusedDay.month;
    final toRemove = <int>[];
    for (final key in _dayCellNotifiers.keys) {
      final keyY = key ~/ 10000;
      final keyM = (key % 10000) ~/ 100;
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

  Widget _buildCalendar(PeriodProvider provider) {
    final border = BorderRadius.circular(AppDimens.radiusLg);
    final themeColors = context.themeColors;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      decoration: BoxDecoration(
        color: themeColors.surfaceCard,
        borderRadius: border,
        border: Border.all(color: AppColors.hairline),
      ),
      child: ClipRRect(
        borderRadius: border,
        child: RawGestureDetector(
          // 自定义手势识别器：水平拖拽只响应明显的横向滑动，
          // 垂直手势交给外层 ScrollView，避免误触月份切换。
          gestures: <Type, GestureRecognizerFactory>{
            HorizontalDragGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                    HorizontalDragGestureRecognizer>(
              () => HorizontalDragGestureRecognizer(
                supportDeviceOrientation: true,
              ),
              (HorizontalDragGestureRecognizer instance) {
                instance.onStart = _onDragStart;
                instance.onUpdate = _onDragUpdate;
                instance.onEnd = _onDragEnd;
              },
            ),
          },
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              // ─── 标题栏（跟随 drag progress 交叉淡化） ───
              _buildCalendarHeader(themeColors, screenWidth),
              // ─── 星期标签 ───
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
              // ─── 三月并存的网格 ───
              ClipRect(
                child: ValueListenableBuilder<double>(
                  valueListenable: _offsetNotifier,
                  builder: (context, offset, _) {
                    return SizedBox(
                      width: screenWidth,
                      child: Stack(
                        children: [
                          // 上月：默认在 -screenWidth
                          Positioned(
                            left: -screenWidth + offset,
                            top: 0,
                            child: SizedBox(
                              width: screenWidth,
                              child: _buildMonthGrid(provider, _prevMonth),
                            ),
                          ),
                          // 当前月：默认在 0
                          Positioned(
                            left: offset,
                            top: 0,
                            child: SizedBox(
                              width: screenWidth,
                              child: _buildMonthGrid(provider, _currentMonth),
                            ),
                          ),
                          // 下月：默认在 +screenWidth
                          Positioned(
                            left: screenWidth + offset,
                            top: 0,
                            child: SizedBox(
                              width: screenWidth,
                              child: _buildMonthGrid(provider, _nextMonth),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: AppDimens.spacingMd),
              _buildLegend(),
              const SizedBox(height: AppDimens.spacingMd),
            ],
          ),
        ),
      ),
    );
  }

  /// 标题栏：当前月标题和目标月标题交叉淡化，
  /// 水平位移 0~20px，opacity 1→0 / 0→1，进度跟随 drag offset。
  Widget _buildCalendarHeader(AppThemeColors themeColors, double screenWidth) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spacingSm,
        AppDimens.spacingSm,
        AppDimens.spacingSm,
        0,
      ),
      child: SizedBox(
        height: 32,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 左箭头
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => _changeMonth(-1),
                icon: const Icon(Icons.chevron_left_rounded),
                color: AppColors.inkSecondary,
                iconSize: 26,
                padding: EdgeInsets.zero,
              ),
            ),
            // 右箭头
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () => _changeMonth(1),
                icon: const Icon(Icons.chevron_right_rounded),
                color: AppColors.inkSecondary,
                iconSize: 26,
                padding: EdgeInsets.zero,
              ),
            ),
            // 标题区域：根据拖拽进度交叉淡化
            ValueListenableBuilder<double>(
              valueListenable: _offsetNotifier,
              builder: (context, offset, _) {
                final progress =
                    (offset / screenWidth).clamp(-1.0, 1.0).abs();
                // 当前月标题透明度：1 → 0
                final currentOpacity = (1.0 - progress).clamp(0.0, 1.0);
                // 目标月标题透明度：0 → 1
                final targetOpacity = progress.clamp(0.0, 1.0);

                // 当前月标题位移方向：右拖时(offset>0)向右移，左拖时向左移
                final currentShift =
                    offset.sign * progress * _kTitleShift;
                // 目标月标题位移方向：从拖拽方向的反侧进入
                final targetShift =
                    -offset.sign * (1.0 - progress) * _kTitleShift;

                // 目标月 DateTime
                final targetMonth =
                    offset >= 0 ? _prevMonth : _nextMonth;

                return Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 当前月标题
                      Opacity(
                        opacity: currentOpacity,
                        child: Transform.translate(
                          offset: Offset(currentShift, 0),
                          child: Text(
                            '${_currentMonth.year}年${_currentMonth.month}月',
                            style: AppTheme.titleLarge.copyWith(
                              color: themeColors.onSurface,
                            ),
                          ),
                        ),
                      ),
                      // 目标月标题
                      Opacity(
                        opacity: targetOpacity,
                        child: Transform.translate(
                          offset: Offset(targetShift, 0),
                          child: Text(
                            '${targetMonth.year}年${targetMonth.month}月',
                            style: AppTheme.titleLarge.copyWith(
                              color: themeColors.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── 日历网格构建（参数化月份） ───────────────────────────────────

  /// 构建指定月份的日历网格。
  /// 传入 [month] 而非直接读 _focusedDay，使三个月可独立渲染。
  Widget _buildMonthGrid(PeriodProvider provider, DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    final weekday = firstDay.weekday;
    final daysInMonth = lastDay.day;
    final prevMonthDays = weekday - 1;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    // 固定 6 行（42 格），确保三个月份网格高度一致，避免 Stack 高度跳变。
    const rows = 6;

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
          return Row(
            children: List<Widget>.generate(7, (col) {
              final index = row * 7 + col;
              final dayOffset = index - prevMonthDays;
              if (dayOffset < 0 || dayOffset >= daysInMonth) {
                return const Expanded(child: SizedBox.shrink());
              }

              final day =
                  DateTime(month.year, month.month, dayOffset + 1);
              final dayType = provider.getDayType(day);
              final isToday = _isSameDay(now, day);

              return Expanded(
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: ValueListenableBuilder<int>(
                    valueListenable: _cellNotifierFor(_dayKey(day)),
                    builder: (context, _, __) {
                      final isSelected = _isSameDay(_selectedDay, day);
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _selectDay(day),
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
                ),
              );
            }),
          );
        }),
      ),
    );
  }

  /// Integer day key: year * 10000 + month * 100 + day.
  static int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  ValueNotifier<int> _cellNotifierFor(int key) =>
      _dayCellNotifiers.putIfAbsent(key, () => ValueNotifier<int>(0));

  void _selectDay(DateTime day) {
    final previous = _selectedDay;
    _selectedDay = day;
    if (previous != null) {
      _dayCellNotifiers[_dayKey(previous)]?.value++;
    }
    _dayCellNotifiers[_dayKey(day)]?.value++;
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
          _buildLegendItem(color: AppColors.brandPrimary, label: '经期中'),
          _buildLegendItem(
            color: AppColors.transparent,
            ring: AppColors.brandPrimary,
            label: '预测',
          ),
          _buildLegendItem(color: AppColors.ovulationDay, label: '排卵期'),
          _buildLegendItem(color: AppColors.fertileBg, label: '易孕期'),
          _buildLegendItem(color: AppColors.safeDay, label: '安全期'),
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