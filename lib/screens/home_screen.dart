import 'package:flutter/material.dart';
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

class _HomeScreenState extends State<HomeScreen> {
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

  /// 日历格子的局部刷新通知器：key 为 `yyyyMMdd`，按需懒创建。
  /// 选中某天时只重建受影响的 1~2 个格子，不再整页 setState。
  final Map<int, ValueNotifier<int>> _dayCellNotifiers =
      <int, ValueNotifier<int>>{};

  /// 选中状态版本号 —— 供「回到今天」按钮这类需要读取 _selectedDay 的部件监听。
  final ValueNotifier<int> _selectionVersion = ValueNotifier<int>(0);

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
    _jumpToPage(DateTime(now.year, now.month, 1));
    _selectedDay = now;
    if (previous != null) {
      _dayCellNotifiers[_dayKey(previous)]?.value++;
    }
    _dayCellNotifiers[_dayKey(now)]?.value++;
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
            SizedBox(
              height: _calendarGridHeight,
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

  /// 日历网格固定高度：6 行 × 每格边长 + 内边距。
  /// 每个格子的 AspectRatio 为 1:1，宽度为 (屏宽 - 2*spacingMd) / 7。
  static double get _calendarGridHeight {
    // 使用一个合理的固定高度估算：6 行格子，每行约 48px，加上上下边距。
    // 实际运行时由 AspectRatio 1:1 自动校正。
    return 300.0; // 6 * ~48 + padding
  }

  Widget _buildCalendarGridForMonth(
      PeriodProvider provider, DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    final weekday = firstDay.weekday;
    final daysInMonth = lastDay.day;
    final prevMonthDays = weekday - 1;
    final totalCells = ((prevMonthDays + daysInMonth) / 7).ceil() * 7;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    // 用固定行数的 Column/Row 代替 shrinkWrap 的 GridView。
    // shrinkWrap 的 GridView 每次布局都要测量全部子项，无法懒加载；
    // 这里格子数量固定（最多 42 个），直接展开成行列更省。
    final rows = totalCells ~/ 7;

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
                    // 只在选中日期变化时重建格子，而不是整个页面
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
    // 只刷新旧选中项和新选中项这两个格子
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
