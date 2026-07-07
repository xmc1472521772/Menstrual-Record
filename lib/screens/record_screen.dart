import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../models/period_record.dart';
import 'package:intl/intl.dart';
import '../providers/period_provider.dart';
import '../providers/settings_provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../constants/app_theme.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.record),
      ),
      body: Consumer<PeriodProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimens.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAddButton(context, provider),
                const SizedBox(height: AppDimens.spacing2xl),
                _buildHistorySection(provider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, PeriodProvider provider) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showAddRecordDialog(context, provider),
        icon: const Icon(Icons.add, size: 22),
        label: const Text('添加经期记录'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            vertical: AppDimens.spacingLg,
          ),
        ),
      ),
    );
  }

  void _showAddRecordDialog(BuildContext context, PeriodProvider provider) {
    final cycleData = provider.cycleData;
    final defaultDays = cycleData != null && cycleData.averagePeriodLength > 0
        ? cycleData.averagePeriodLength.round()
        : context.read<SettingsProvider>().periodLength;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => AddRecordCalendarPage(
          provider: provider,
          defaultDays: defaultDays,
          today: today,
        ),
      ),
    );
  }

  Widget _buildHistorySection(PeriodProvider provider) {
    final records = provider.records;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppStrings.historyRecords,
              style: AppTheme.headingSmall.copyWith(
                color: context.themeColors.onSurface,
              ),
            ),
            if (records.isNotEmpty)
              Text(
                '共 ${records.length} 条记录',
                style: AppTheme.bodySmall.copyWith(
                  color: context.themeColors.onSurfaceTertiary,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppDimens.spacingMd),
        if (records.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimens.spacing3xl),
            decoration: BoxDecoration(
              color: context.themeColors.surfaceCard,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.history,
                  size: 48,
                  color: context.themeColors.onSurfaceTertiary,
                ),
                const SizedBox(height: AppDimens.spacingMd),
                Text(
                  AppStrings.noRecords,
                  style: AppTheme.bodyMedium.copyWith(
                    color: context.themeColors.onSurfaceTertiary,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              return _buildRecordCard(record, provider);
            },
          ),
      ],
    );
  }

  Widget _buildRecordCard(PeriodRecord record, PeriodProvider provider) {
    final startDate = DateFormat('yyyy-MM-dd').parse(record.startDate);
    final endDate = record.endDate != null
        ? DateFormat('yyyy-MM-dd').parse(record.endDate!)
        : null;
    final isOngoing = record.isOngoing;

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimens.spacingSm),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spacingLg,
          vertical: AppDimens.spacingSm,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isOngoing
                ? AppColors.warning.withValues(alpha: 0.15)
                : AppColors.lightPink,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          ),
          child: Icon(
            isOngoing ? Icons.play_circle_filled : Icons.favorite,
            color: isOngoing ? AppColors.warning : AppColors.primaryPink,
            size: 24,
          ),
        ),
        title: Text(
          '${DateFormat('yyyy年MM月dd日').format(startDate)} - ${endDate != null ? DateFormat('yyyy年MM月dd日').format(endDate) : '进行中'}',
          style: AppTheme.titleMedium.copyWith(color: context.themeColors.onSurface),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppDimens.spacingXs),
            Text(
              '持续 ${record.periodDays} 天',
              style: AppTheme.bodySmall.copyWith(
                color: context.themeColors.onSurfaceSecondary,
              ),
            ),
            if (isOngoing) ...[
              const SizedBox(height: AppDimens.spacingXs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spacingSm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                ),
                child: Text(
                  '进行中',
                  style: AppTheme.labelMedium.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            color: context.themeColors.onSurfaceTertiary,
          ),
          onSelected: (value) {
            if (value == 'delete') {
              _showDeleteConfirmDialog(record, provider);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete, color: AppColors.error, size: 20),
                  const SizedBox(width: AppDimens.spacingSm),
                  Text(
                    '删除记录',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(PeriodRecord record, PeriodProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.confirm),
        content: const Text(AppStrings.deleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () {
              provider.deleteRecord(record.id!);
              Navigator.pop(context);
            },
            child: Text(
              AppStrings.delete,
              style: AppTheme.labelLarge.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Full Page Infinite Scrolling Calendar ──────────────────────

class AddRecordCalendarPage extends StatefulWidget {
  final PeriodProvider provider;
  final int defaultDays;
  final DateTime today;

  const AddRecordCalendarPage({
    super.key,
    required this.provider,
    required this.defaultDays,
    required this.today,
  });

  @override
  State<AddRecordCalendarPage> createState() => _AddRecordCalendarPageState();
}

class _AddRecordCalendarPageState extends State<AddRecordCalendarPage> {
  static const int _totalMonths = 72;
  static const int _monthsBefore = 36;

  late final ScrollController _scrollController;
  late Set<int> _selectedDays;
  late final Set<int> _existingDays;
  String? _conflictMsg;
  double? _exactInitialOffset;
  bool _didInitialScroll = false;
  double _cellWidth = 49.0;

  // Precomputed month metadata cache — avoids per-frame DateTime/string allocations
  late final Map<int, _MonthInfo> _monthCache;

  // Integer key: year*10000 + month*100 + day — avoids string allocation
  static int _dayKeyInt(DateTime d) => d.year * 10000 + d.month * 100 + d.day;
  static int _keyToYear(int k) => k ~/ 10000;
  static int _keyToMonth(int k) => (k % 10000) ~/ 100;
  static int _keyToDay(int k) => k % 100;

  @override
  void initState() {
    super.initState();
    _selectedDays = {};
    _existingDays = _buildExistingDaysSet();
    _scrollController = ScrollController();
    _monthCache = _buildMonthCache();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cellWidth = (MediaQuery.of(context).size.width - AppDimens.spacingSm * 2) / 7;
    if (!_didInitialScroll) {
      _didInitialScroll = true;
      _exactInitialOffset = _computeExactOffset();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.jumpTo(
          _exactInitialOffset!.clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          ),
        );
        _retryEnsureVisible();
      });
    }
  }

  double _computeExactOffset() {
    const monthTitleHeight = 35.0;
    const monthBottomGap = AppDimens.spacingSm;
    double offset = 0;
    for (int i = 0; i < _monthsBefore; i++) {
      final info = _monthCache[i]!;
      offset += monthTitleHeight + info.rows * _cellWidth + monthBottomGap;
    }
    return offset;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _retryEnsureVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _currentMonthKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: Duration.zero,
          alignment: 0.0,
        );
      } else {
        _retryEnsureVisible();
      }
    });
  }

  void _scrollToCurrentMonth() {
    final ctx = _currentMonthKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: 0.0,
      );
    } else if (_scrollController.hasClients && _exactInitialOffset != null) {
      _scrollController.jumpTo(
        _exactInitialOffset!.clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx2 = _currentMonthKey.currentContext;
        if (ctx2 != null) {
          Scrollable.ensureVisible(
            ctx2,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: 0.0,
          );
        }
      });
    }
  }

  Set<int> _buildExistingDaysSet() {
    final set = <int>{};
    for (final record in widget.provider.records) {
      if (record.isOngoing) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        var cur = DateTime(
          record.startDateTime.year,
          record.startDateTime.month,
          record.startDateTime.day,
        );
        while (!cur.isAfter(today)) {
          set.add(_dayKeyInt(cur));
          cur = cur.add(const Duration(days: 1));
        }
      } else {
        var cur = DateTime(
          record.startDateTime.year,
          record.startDateTime.month,
          record.startDateTime.day,
        );
        final end = record.endDateTime!;
        while (!cur.isAfter(end)) {
          set.add(_dayKeyInt(cur));
          cur = cur.add(const Duration(days: 1));
        }
      }
    }
    return set;
  }

  Map<int, _MonthInfo> _buildMonthCache() {
    final cache = <int, _MonthInfo>{};
    for (int i = 0; i < _totalMonths; i++) {
      final offset = i - _monthsBefore;
      final year = widget.today.year;
      final month = widget.today.month + offset;
      // DateTime normalization handles month overflow/underflow
      final firstDay = DateTime(year, month, 1);
      final y = firstDay.year;
      final m = firstDay.month;
      final daysInMonth = DateTime(y, m + 1, 0).day;
      final prevDays = firstDay.weekday - 1;
      final totalCells = ((prevDays + daysInMonth + 6) ~/ 7) * 7;
      cache[i] = _MonthInfo(
        year: y,
        month: m,
        daysInMonth: daysInMonth,
        prevDays: prevDays,
        totalCells: totalCells,
        rows: totalCells ~/ 7,
      );
    }
    return cache;
  }

  void _onDayTap(DateTime day) {
    final key = _dayKeyInt(day);
    if (_existingDays.contains(key)) return;

    if (_selectedDays.isEmpty) {
      _autoSelectFrom(day);
      return;
    }

    setState(() {
      if (_selectedDays.contains(key)) {
        _selectedDays.remove(key);
      } else {
        _selectedDays.add(key);
      }
      _validateConflict();
    });
  }

  void _autoSelectFrom(DateTime startDay) {
    final days = widget.defaultDays;
    final newSelection = <int>{};

    for (int i = 0; i < days; i++) {
      final d = startDay.add(Duration(days: i));
      final key = _dayKeyInt(d);
      if (_existingDays.contains(key)) break;
      newSelection.add(key);
    }

    setState(() {
      _selectedDays = newSelection;
      _validateConflict();
    });
  }

  void _validateConflict() {
    for (final key in _selectedDays) {
      if (_existingDays.contains(key)) {
        _conflictMsg = '所选日期与已有记录冲突';
        return;
      }
    }
    _conflictMsg = null;
  }

  List<(DateTime, DateTime)> _buildRanges() {
    if (_selectedDays.isEmpty) return [];

    final sortedKeys = _selectedDays.toList()..sort();
    final dates = sortedKeys
        .map((k) => DateTime(_keyToYear(k), _keyToMonth(k), _keyToDay(k)))
        .toList();

    final ranges = <(DateTime, DateTime)>[];
    var start = dates[0];
    var end = dates[0];

    for (int i = 1; i < dates.length; i++) {
      if (dates[i].difference(end).inDays == 1) {
        end = dates[i];
      } else {
        ranges.add((start, end));
        start = dates[i];
        end = dates[i];
      }
    }
    ranges.add((start, end));
    return ranges;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加经期记录'),
        actions: [
          TextButton(
            onPressed: _scrollToCurrentMonth,
            style: TextButton.styleFrom(
              backgroundColor: AppColors.info,
              foregroundColor: AppColors.white,
              minimumSize: const Size(40, 36),
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spacingMd,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
            ),
            child: const Text(
              '今',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: AppDimens.spacingSm),
        ],
      ),
      body: Column(
        children: [
          _buildHint(),
          _weekdayHeader,
          const Divider(height: 1),
          Expanded(child: _buildMonthList()),
          _buildBottomPanel(),
        ],
      ),
    );
  }

  Widget _buildHint() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spacingLg,
        AppDimens.spacingSm,
        AppDimens.spacingLg,
        AppDimens.spacingSm,
      ),
      child: Text(
        '首次点击自动选中 ${widget.defaultDays} 天，之后点击可逐天添加/移除',
        style: AppTheme.bodySmall.copyWith(
          color: context.themeColors.onSurfaceTertiary,
        ),
      ),
    );
  }

  static const Widget _weekdayHeader = _WeekdayHeaderWidget();

  static final BoxDecoration _existingDecoration = BoxDecoration(
    color: AppColors.primaryPink.withValues(alpha: 0.15),
    borderRadius: BorderRadius.circular(6),
  );
  static final BoxDecoration _selectedDecoration = BoxDecoration(
    color: AppColors.primaryPink,
    borderRadius: BorderRadius.circular(6),
  );
  static final BoxDecoration _selectedFutureDecoration = BoxDecoration(
    color: AppColors.primaryPink.withValues(alpha: 0.25),
    border: Border.all(
      color: AppColors.primaryPink.withValues(alpha: 0.5),
      width: 1.2,
    ),
    borderRadius: BorderRadius.circular(6),
  );
  static final BoxDecoration _selectedFutureTodayDecoration = BoxDecoration(
    color: AppColors.primaryPink.withValues(alpha: 0.25),
    border: Border.all(
      color: AppColors.info,
      width: 1.5,
    ),
    borderRadius: BorderRadius.circular(6),
  );
  static final BoxDecoration _todayDecoration = BoxDecoration(
    border: Border.all(color: AppColors.info, width: 1.5),
    borderRadius: BorderRadius.circular(6),
  );
  static const EdgeInsets _cellMargin = EdgeInsets.all(3);
  static const TextStyle _existingTodayStyle = TextStyle(
    color: AppColors.info,
    fontSize: 13,
  );
  static final TextStyle _existingStyle = TextStyle(
    color: AppColors.primaryPink.withValues(alpha: 0.4),
    fontSize: 13,
  );
  static const TextStyle _selectedTodayStyle = TextStyle(
    color: AppColors.info,
    fontWeight: FontWeight.w600,
    fontSize: 13,
  );
  static const TextStyle _selectedStyle = TextStyle(
    color: AppColors.white,
    fontWeight: FontWeight.w600,
    fontSize: 13,
  );
  static const TextStyle _selectedFutureStyle = TextStyle(
    color: AppColors.primaryPink,
    fontWeight: FontWeight.w600,
    fontSize: 13,
  );
  static const TextStyle _selectedFutureTodayStyle = TextStyle(
    color: AppColors.info,
    fontWeight: FontWeight.w600,
    fontSize: 13,
  );
  static const TextStyle _todayStyle = TextStyle(
    color: AppColors.info,
    fontWeight: FontWeight.w600,
    fontSize: 13,
  );
  TextStyle _pastStyle(BuildContext context) => TextStyle(
    color: context.themeColors.onSurface,
    fontSize: 13,
  );
  TextStyle _futureStyle(BuildContext context) => TextStyle(
    color: context.themeColors.onSurfaceTertiary.withValues(alpha: 0.4),
    fontSize: 13,
  );
  TextStyle _monthTitleStyle(BuildContext context) => TextStyle(
    color: context.themeColors.onSurface,
    fontWeight: FontWeight.w600,
    fontSize: 16,
  );

  final GlobalKey _currentMonthKey = GlobalKey();

  Widget _buildMonthList() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _totalMonths,
      // Keep built items alive to avoid gesture recognizer re-registration
      addAutomaticKeepAlives: true,
      // Pre-render nearby months for smoother scrolling
      scrollCacheExtent: const ScrollCacheExtent.pixels(800),
      itemBuilder: (context, index) {
        final info = _monthCache[index]!;
        final isCurrentMonth = info.year == widget.today.year &&
            info.month == widget.today.month;
        final monthKey = ValueKey('${info.year}-${info.month}');
        return KeyedSubtree(
          key: isCurrentMonth ? _currentMonthKey : monthKey,
          child: _buildMonthView(info),
        );
      },
      findChildIndexCallback: (key) {
        if (key is ValueKey<String>) {
          final parts = key.value.split('-');
          final y = int.parse(parts[0]);
          final m = int.parse(parts[1]);
          final offset = (y - widget.today.year) * 12 + m - widget.today.month;
          final index = offset + _monthsBefore;
          if (index >= 0 && index < _totalMonths) return index;
        }
        return null;
      },
    );
  }

  Widget _buildMonthView(_MonthInfo info) {
    final year = info.year;
    final month = info.month;
    final daysInMonth = info.daysInMonth;
    final prevDays = info.prevDays;
    final rows = info.rows;

    // Precompute today comparison values once per month
    final isTodayYear = year == widget.today.year;
    final isTodayMonth = month == widget.today.month;
    final todayDay = widget.today.day;
    final todayKey = widget.today.year * 10000 + widget.today.month * 100 + widget.today.day;

    final monthTitle = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spacingMd,
        AppDimens.spacingMd,
        AppDimens.spacingMd,
        4,
      ),
      child: Text(
        '$year年$month月',
        style: _monthTitleStyle(context),
      ),
    );

    final rowWidgets = List<SizedBox>.generate(rows, (row) {
      return SizedBox(
        height: _cellWidth,
        child: Row(
          children: List<Widget>.generate(7, (col) {
            final i = row * 7 + col;
            final dayOffset = i - prevDays;
            if (dayOffset < 0 || dayOffset >= daysInMonth) {
              return const Expanded(child: SizedBox());
            }

            final dayNum = dayOffset + 1;
            final key = year * 10000 + month * 100 + dayNum;
            final isExisting = _existingDays.contains(key);
            final isSelected = _selectedDays.contains(key);
            final isToday = isTodayYear && isTodayMonth && dayNum == todayDay;
            final isPast = !isToday && key < todayKey;
            final isFuture = !isToday && !isPast;

            final cell = _buildDayCell(
              dayNum,
              isExisting,
              isSelected && !isFuture,
              isSelected && isFuture,
              isToday,
              isPast,
            );

            // Skip GestureDetector for non-interactive existing-day cells
            if (isExisting) {
              return Expanded(child: cell);
            }

            final day = DateTime(year, month, dayNum);
            return Expanded(
              child: GestureDetector(
                onTap: () => _onDayTap(day),
                child: cell,
              ),
            );
          }),
        ),
      );
    });

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        monthTitle,
        ...rowWidgets,
        const SizedBox(height: AppDimens.spacingSm),
      ],
    );
  }

  Widget _buildDayCell(
    int dayNum,
    bool isExisting,
    bool isSelected,
    bool isSelectedFuture,
    bool isToday,
    bool isPast,
  ) {
    final label = '$dayNum';

    if (isExisting) {
      return Container(
        margin: _cellMargin,
        decoration: _existingDecoration,
        alignment: Alignment.center,
        child: Text(
          label,
          style: isToday ? _existingTodayStyle : _existingStyle,
        ),
      );
    }

    if (isSelected) {
      return Container(
        margin: _cellMargin,
        decoration: _selectedDecoration,
        alignment: Alignment.center,
        child: Text(
          label,
          style: isToday ? _selectedTodayStyle : _selectedStyle,
        ),
      );
    }

    if (isSelectedFuture) {
      return Container(
        margin: _cellMargin,
        decoration:
            isToday ? _selectedFutureTodayDecoration : _selectedFutureDecoration,
        alignment: Alignment.center,
        child: Text(
          label,
          style:
              isToday ? _selectedFutureTodayStyle : _selectedFutureStyle,
        ),
      );
    }

    if (isToday) {
      return Container(
        margin: _cellMargin,
        decoration: _todayDecoration,
        alignment: Alignment.center,
        child: Text(label, style: _todayStyle),
      );
    }

    return Container(
      margin: _cellMargin,
      alignment: Alignment.center,
      child: Text(
        label,
        style: isPast ? _pastStyle(context) : _futureStyle(context),
      ),
    );
  }

  Widget _buildBottomPanel() {
    final canSave = _selectedDays.isNotEmpty && _conflictMsg == null;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedDays.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spacingLg,
                vertical: AppDimens.spacingXs,
              ),
              color: AppColors.lightPink.withValues(alpha: 0.4),
              child: Builder(
                builder: (context) {
                  final ranges = _buildRanges();
                  final totalDays = _selectedDays.length;
                  final rangeText = ranges.map((r) {
                    final s = DateFormat('MM/dd').format(r.$1);
                    final e = DateFormat('MM/dd').format(r.$2);
                    return r.$1 == r.$2 ? s : '$s-$e';
                  }).join('、');
                  return Text(
                    '已选 $totalDays 天：$rangeText',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppColors.primaryPink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
            ),
          ],
          if (_conflictMsg != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spacingLg,
                vertical: AppDimens.spacingXs,
              ),
              color: AppColors.error.withValues(alpha: 0.1),
              child: Text(
                _conflictMsg!,
                style: AppTheme.bodySmall.copyWith(color: AppColors.error),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppDimens.spacingLg),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(AppStrings.cancel),
                  ),
                ),
                const SizedBox(width: AppDimens.spacingMd),
                Expanded(
                  child: ElevatedButton(
                    onPressed: canSave
                        ? () async {
                            final ranges = _buildRanges();
                            final success =
                                await widget.provider.saveMultipleRecords(ranges);
                            if (success && mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('已保存 ${ranges.length} 条记录'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            } else if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('保存失败'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        : null,
                    child: const Text(AppStrings.confirm),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Precomputed month metadata — avoids repeated DateTime arithmetic during scroll.
class _MonthInfo {
  final int year;
  final int month;
  final int daysInMonth;
  final int prevDays; // number of empty cells before day 1
  final int totalCells;
  final int rows;

  const _MonthInfo({
    required this.year,
    required this.month,
    required this.daysInMonth,
    required this.prevDays,
    required this.totalCells,
    required this.rows,
  });
}

/// Static weekday header — never rebuilds.
class _WeekdayHeaderWidget extends StatelessWidget {
  const _WeekdayHeaderWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spacingMd,
        vertical: AppDimens.spacingSm,
      ),
      color: context.themeColors.surfaceCard,
      child: Row(
        children: [
          Expanded(child: Center(child: Text('一', style: TextStyle(color: context.themeColors.onSurfaceTertiary, fontSize: 14)))),
          Expanded(child: Center(child: Text('二', style: TextStyle(color: context.themeColors.onSurfaceTertiary, fontSize: 14)))),
          Expanded(child: Center(child: Text('三', style: TextStyle(color: context.themeColors.onSurfaceTertiary, fontSize: 14)))),
          Expanded(child: Center(child: Text('四', style: TextStyle(color: context.themeColors.onSurfaceTertiary, fontSize: 14)))),
          Expanded(child: Center(child: Text('五', style: TextStyle(color: context.themeColors.onSurfaceTertiary, fontSize: 14)))),
          Expanded(child: Center(child: Text('六', style: TextStyle(color: context.themeColors.onSurfaceTertiary, fontSize: 14)))),
          Expanded(child: Center(child: Text('日', style: TextStyle(color: context.themeColors.onSurfaceTertiary, fontSize: 14)))),
        ],
      ),
    );
  }
}
