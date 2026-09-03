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
  int _slideDirection = 1;

  bool get _isTodaySelected {
    final now = DateTime.now();
    return _selectedDay != null &&
        _selectedDay!.year == now.year &&
        _selectedDay!.month == now.month &&
        _selectedDay!.day == now.day;
  }

  void _jumpToToday() {
    final now = DateTime.now();
    setState(() {
      _selectedDay = now;
      _focusedDay = DateTime(now.year, now.month, 1);
    });
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

  static String _weekdayLabel(int weekday) => _weekdayLabels[weekday - 1];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth =
        _focusedDay.year == now.year && _focusedDay.month == now.month;
    final showJumpToToday =
        !isCurrentMonth || (_selectedDay != null && !_isTodaySelected);

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
      floatingActionButton: showJumpToToday
          ? FloatingActionButton.small(
              onPressed: _jumpToToday,
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: AppColors.white,
              elevation: AppDimens.elevationNone,
              child: const Text(
                '今',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            )
          : null,
      body: Consumer<PeriodProvider>(
        builder: (context, provider, child) {
          final cycleData = provider.cycleData;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spacingXl,
              AppDimens.spacingSm,
              AppDimens.spacingXl,
              AppDimens.spacing2xl,
            ),
            child: Column(
              children: [
                _buildStatusHero(cycleData),
                const SizedBox(height: AppDimens.spacingLg),
                _buildQuickActions(provider),
                const SizedBox(height: AppDimens.spacingLg),
                _buildCalendar(provider),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Status hero ──────────────────────────────────────────────────
  Widget _buildStatusHero(CycleData? cycleData) {
    if (cycleData == null) {
      return _buildEmptyHero();
    }

    final daysUntil = cycleData.daysUntilPredicted;
    final currentDay = cycleData.currentCycleDay;
    final provider = context.read<PeriodProvider>();
    final hasOngoing = provider.records.any((r) => r.isOngoing);

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
        boxShadow: AppShadows.high,
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
    final hasOngoing = provider.records.any((r) => r.isOngoing);

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
                textStyle: AppTheme.titleMedium,
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
                textStyle: AppTheme.titleMedium,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Calendar ─────────────────────────────────────────────────────
  void _onSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    if (velocity > 300) {
      _changeMonth(-1);
    } else if (velocity < -300) {
      _changeMonth(1);
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _focusedDay = DateTime(
        _focusedDay.year,
        _focusedDay.month + delta,
        1,
      );
      _slideDirection = delta;
    });
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
        child: GestureDetector(
          onHorizontalDragEnd: _onSwipe,
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
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
                      onPressed: () => _changeMonth(-1),
                      icon: const Icon(Icons.chevron_left_rounded),
                      color: AppColors.inkSecondary,
                      iconSize: 26,
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, animation) {
                        final inOffset = Offset(_slideDirection.toDouble(), 0);
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: inOffset,
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          )),
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
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
                      onPressed: () => _changeMonth(1),
                      icon: const Icon(Icons.chevron_right_rounded),
                      color: AppColors.inkSecondary,
                      iconSize: 26,
                    ),
                  ],
                ),
              ),
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
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  final inOffset = Offset(_slideDirection * 0.3, 0);
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: inOffset,
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  key: ValueKey(
                      'grid-${_focusedDay.year}-${_focusedDay.month}'),
                  child: _buildCalendarGrid(provider),
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

  Widget _buildCalendarGrid(PeriodProvider provider) {
    final firstDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final lastDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);

    final weekday = firstDay.weekday;
    final daysInMonth = lastDay.day;
    final prevMonthDays = weekday - 1;
    final totalCells = ((prevMonthDays + daysInMonth) / 7).ceil() * 7;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spacingMd),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 1.0,
        ),
        itemCount: totalCells,
        itemBuilder: (context, index) {
          final dayOffset = index - prevMonthDays;
          if (dayOffset < 0 || dayOffset >= daysInMonth) {
            return const SizedBox.shrink();
          }

          final day =
              DateTime(_focusedDay.year, _focusedDay.month, dayOffset + 1);
          final dayType = provider.getDayType(day);
          final isSelected = _isSameDay(_selectedDay, day);
          final isToday = _isSameDay(now, day);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                _selectedDay = day;
              });
            },
            child: _buildDayCell(day, dayType, isSelected, isToday, todayStart),
          );
        },
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
        textColor = context.themeColors.onSurfaceSecondary;
        break;
      default:
        textColor = isToday
            ? AppColors.brandPrimary
            : (isPast
                ? context.themeColors.onSurface
                : context.themeColors.onSurfaceTertiary);
        fontWeight = isToday ? FontWeight.w700 : FontWeight.w400;
    }

    final cell = Container(
      margin: const EdgeInsets.all(3),
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
        margin: const EdgeInsets.all(2),
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
