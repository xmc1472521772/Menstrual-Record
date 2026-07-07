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

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth =
        _focusedDay.year == now.year && _focusedDay.month == now.month;
    final showJumpToToday = !isCurrentMonth ||
        (_selectedDay != null && !_isTodaySelected);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
      ),
      floatingActionButton: showJumpToToday
          ? FloatingActionButton.small(
              onPressed: _jumpToToday,
              backgroundColor: AppColors.info,
              foregroundColor: AppColors.white,
              child: const Text(
                '今',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            )
          : null,
      body: Consumer<PeriodProvider>(
        builder: (context, provider, child) {
          final cycleData = provider.cycleData;

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildStatusCard(cycleData),
                const SizedBox(height: AppDimens.spacingLg),
                _buildCalendar(provider),
                const SizedBox(height: AppDimens.spacingSm),
                _buildLegend(),
                const SizedBox(height: AppDimens.spacingLg),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: Consumer<PeriodProvider>(
        builder: (context, provider, child) => _buildQuickActions(provider),
      ),
    );
  }

  Widget _buildStatusCard(CycleData? cycleData) {
    if (cycleData == null) {
      return _buildEmptyCard();
    }

    final daysUntil = cycleData.daysUntilPredicted;
    final currentDay = cycleData.currentCycleDay;
    final provider = context.read<PeriodProvider>();
    final hasOngoing = provider.records.any((r) => r.isOngoing);

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDimens.spacingLg,
        AppDimens.spacingLg,
        AppDimens.spacingLg,
        0,
      ),
      padding: const EdgeInsets.all(AppDimens.spacingXl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryPink, AppColors.accentPink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPink.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          if (hasOngoing) ...[
            const Icon(
              Icons.favorite,
              color: AppColors.white,
              size: 28,
            ),
            const SizedBox(height: AppDimens.spacingSm),
            Text(
              AppStrings.periodOngoing,
              style: AppTheme.bodyMedium.copyWith(
                color: AppColors.white.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: AppDimens.spacingXs),
            Text(
              '${AppStrings.currentDay} $currentDay ${AppStrings.days}',
              style: AppTheme.headingLarge.copyWith(color: AppColors.white),
            ),
          ] else if (daysUntil != null && daysUntil > 0) ...[
            const Icon(
              Icons.calendar_today,
              color: AppColors.white,
              size: 28,
            ),
            const SizedBox(height: AppDimens.spacingSm),
            Text(
              AppStrings.daysUntilPeriod,
              style: AppTheme.bodyMedium.copyWith(
                color: AppColors.white.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: AppDimens.spacingXs),
            Text(
              '$daysUntil ${AppStrings.days}',
              style: AppTheme.statValue.copyWith(color: AppColors.white),
            ),
          ] else if (daysUntil == 0) ...[
            const Icon(
              Icons.notifications_active,
              color: AppColors.white,
              size: 28,
            ),
            const SizedBox(height: AppDimens.spacingSm),
            Text(
              '预计今天来临',
              style: AppTheme.headingLarge.copyWith(color: AppColors.white),
            ),
          ] else if (daysUntil != null && daysUntil < 0) ...[
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.white,
              size: 28,
            ),
            const SizedBox(height: AppDimens.spacingSm),
            Text(
              '已逾期',
              style: AppTheme.bodyMedium.copyWith(
                color: AppColors.white.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: AppDimens.spacingXs),
            Text(
              '${-daysUntil} ${AppStrings.days}',
              style: AppTheme.statValue.copyWith(color: AppColors.white),
            ),
          ] else ...[
            const Icon(
              Icons.info_outline,
              color: AppColors.white,
              size: 28,
            ),
            const SizedBox(height: AppDimens.spacingSm),
            Text(
              '记录经期以开始预测',
              style: AppTheme.bodyLarge.copyWith(
                color: AppColors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
          const SizedBox(height: AppDimens.spacingXl),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spacingLg,
              vertical: AppDimens.spacingMd,
            ),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  AppStrings.averageCycle,
                  '${cycleData.averageCycleLength.round()} ${AppStrings.days}',
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: AppColors.white.withValues(alpha: 0.2),
                ),
                _buildStatItem(
                  AppStrings.averagePeriod,
                  '${cycleData.averagePeriodLength.round()} ${AppStrings.days}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDimens.spacingLg,
        AppDimens.spacingLg,
        AppDimens.spacingLg,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spacingXl,
        vertical: AppDimens.spacing3xl,
      ),
      decoration: BoxDecoration(
        color: AppColors.lightPink,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(
              Icons.calendar_month,
              color: AppColors.primaryPink,
              size: 48,
            ),
            SizedBox(height: AppDimens.spacingMd),
            Text(
              '开始记录您的经期',
              style: AppTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: AppColors.white.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: AppDimens.spacingXs),
        Text(
          value,
          style: AppTheme.titleLarge.copyWith(color: AppColors.white),
        ),
      ],
    );
  }

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

  int _slideDirection = 1;

  Widget _buildCalendar(PeriodProvider provider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimens.spacingLg),
      decoration: BoxDecoration(
        color: context.themeColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: GestureDetector(
        onHorizontalDragEnd: _onSwipe,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spacingSm,
                vertical: AppDimens.spacingSm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => _changeMonth(-1),
                    icon: const Icon(
                      Icons.chevron_left,
                      color: AppColors.primaryPink,
                    ),
                    iconSize: 28,
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
                    icon: const Icon(
                      Icons.chevron_right,
                      color: AppColors.primaryPink,
                    ),
                    iconSize: 28,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spacingLg,
              ),
              child: Row(
                children: ['一', '二', '三', '四', '五', '六', '日']
                    .map((day) => Expanded(
                          child: Center(
                            child: Text(
                              day,
                              style: AppTheme.labelMedium.copyWith(
                                color: context.themeColors.onSurfaceTertiary,
                              ),
                            ),
                          ),
                        ))
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
            const SizedBox(height: AppDimens.spacingSm),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(PeriodProvider provider) {
    final firstDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final lastDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);

    int weekday = firstDay.weekday;
    final daysInMonth = lastDay.day;
    final prevMonthDays = weekday - 1;
    final totalCells = ((prevMonthDays + daysInMonth + 6) ~/ 7) * 7;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spacingLg),
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

          final day = DateTime(_focusedDay.year, _focusedDay.month, dayOffset + 1);
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
    Widget dayWidget;

    if (isSelected && !(isToday && dayType != 'normal')) {
      dayWidget = Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.info, width: 2.0),
          boxShadow: [
            BoxShadow(
              color: AppColors.info.withValues(alpha: 0.3),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            color: AppColors.info,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${day.day}',
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    } else {
      switch (dayType) {
        case 'period':
          dayWidget = Container(
            margin: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: AppColors.primaryPink,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: isToday ? AppColors.info : AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
          break;
        case 'predicted':
          dayWidget = Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.mediumPink, width: 1.5),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: isToday ? AppColors.info : AppColors.mediumPink,
                ),
              ),
            ),
          );
          break;
        case 'ovulation':
          dayWidget = Container(
            margin: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: AppColors.ovulationDay,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: isToday ? AppColors.info : AppColors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
          break;
        case 'fertile':
          dayWidget = Container(
            margin: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: AppColors.fertileDay,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: isToday ? AppColors.info : AppColors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
          break;
        case 'safe':
          dayWidget = Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.safeDay.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: isToday ? AppColors.info : context.themeColors.onSurfaceSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          );
          break;
        default:
          final dayDate = DateTime(day.year, day.month, day.day);
          final isPast = dayDate.isBefore(todayStart);
          dayWidget = Center(
            child: Text(
              '${day.day}',
              style: TextStyle(
                color: isToday
                    ? AppColors.info
                    : (isPast
                        ? context.themeColors.onSurface
                        : context.themeColors.onSurfaceTertiary),
                fontWeight: isToday ? FontWeight.bold : null,
              ),
            ),
          );
      }
    }

    if (isToday && isSelected && dayType != 'normal') {
      return Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.info, width: 1.5),
        ),
        child: dayWidget,
      );
    }

    return dayWidget;
  }

  Widget _buildLegend() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimens.spacingLg),
      padding: const EdgeInsets.all(AppDimens.spacingLg),
      decoration: BoxDecoration(
        color: context.themeColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '颜色说明',
            style: AppTheme.titleLarge.copyWith(color: context.themeColors.onSurface),
          ),
          const SizedBox(height: AppDimens.spacingMd),
          _buildLegendItem(
            color: AppColors.primaryPink,
            label: '经期中',
            description: '实际记录的经期',
          ),
          _buildLegendItem(
            color: AppColors.transparent,
            label: '预测经期',
            description: '预测的下次经期',
            isDashed: true,
          ),
          _buildLegendItem(
            color: AppColors.ovulationDay,
            label: '排卵期',
            description: '排卵期当天',
          ),
          _buildLegendItem(
            color: AppColors.fertileDay,
            label: '易孕期',
            description: '排卵期前5天至后4天',
          ),
          _buildLegendItem(
            color: AppColors.safeDay,
            label: '安全期',
            description: '相对安全的日子',
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required String description,
    bool isDashed = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spacingXs),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: isDashed ? AppColors.transparent : color,
              border: isDashed
                  ? Border.all(
                      color: AppColors.mediumPink,
                      width: 1.5,
                    )
                  : null,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppDimens.spacingMd),
          Text(
            label,
            style: AppTheme.labelLarge.copyWith(color: context.themeColors.onSurface),
          ),
          const SizedBox(width: AppDimens.spacingSm),
          Expanded(
            child: Text(
              description,
              style: AppTheme.bodySmall.copyWith(
                color: context.themeColors.onSurfaceSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(PeriodProvider provider) {
    final hasOngoing = provider.records.any((r) => r.isOngoing);

    return Container(
      padding: const EdgeInsets.all(AppDimens.spacingLg),
      decoration: BoxDecoration(
        color: context.themeColors.surfaceCard,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: hasOngoing
                    ? null
                    : () async {
                        await provider.startPeriod(DateTime.now());
                      },
                icon: const Icon(Icons.play_arrow, size: 20),
                label: const Text(AppStrings.startPeriod),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPink,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimens.spacingLg,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  ),
                  disabledBackgroundColor: AppColors.grey.withValues(alpha: 0.2),
                  disabledForegroundColor: AppColors.grey,
                ),
              ),
            ),
            const SizedBox(width: AppDimens.spacingLg),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: hasOngoing
                    ? () async {
                        await provider.endPeriod(DateTime.now());
                      }
                    : null,
                icon: const Icon(Icons.stop, size: 20),
                label: const Text(AppStrings.endPeriod),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPink,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimens.spacingLg,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  ),
                  disabledBackgroundColor: AppColors.grey.withValues(alpha: 0.2),
                  disabledForegroundColor: AppColors.grey,
                ),
              ),
            ),
          ],
        ),
    );
  }
}
