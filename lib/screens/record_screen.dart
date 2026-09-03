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
  late DateTime _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: AppDimens.spacingXl,
        title: const Text(AppStrings.record),
        actions: [
          IconButton.filled(
            onPressed: () =>
                _showAddRecordDialog(context, context.read<PeriodProvider>()),
            icon: const Icon(Icons.add_rounded, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: AppColors.white,
            ),
            tooltip: '多选日历',
          ),
          const SizedBox(width: AppDimens.spacingXl),
        ],
      ),
      body: Consumer<PeriodProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spacingXl,
              AppDimens.spacingSm,
              AppDimens.spacingXl,
              AppDimens.spacing2xl,
            ),
            child: Column(
              children: [
                _buildTodayStrip(provider),
                const SizedBox(height: AppDimens.spacingLg),
                _buildAddCard(provider),
                const SizedBox(height: AppDimens.spacingLg),
                _buildHistoryCard(provider),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Today strip ──────────────────────────────────────────────────
  Widget _buildTodayStrip(PeriodProvider provider) {
    final hasOngoing = provider.records.any((r) => r.isOngoing);
    final cycleData = provider.cycleData;

    if (hasOngoing) {
      final day = cycleData?.currentCycleDay ?? 1;
      return Container(
        padding: const EdgeInsets.all(AppDimens.spacingLg),
        decoration: BoxDecoration(
          color: AppColors.brandSurface,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        ),
        child: Row(
          children: [
            _stripIcon(Icons.favorite_rounded, AppColors.brandPrimary),
            const SizedBox(width: AppDimens.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.periodOngoing,
                    style: AppTheme.titleMedium.copyWith(
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${AppStrings.currentDay} $day ${AppStrings.days}',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppColors.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 36,
              child: OutlinedButton(
                onPressed: () async {
                  await provider.endPeriod(DateTime.now());
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandPrimary,
                  side: const BorderSide(color: AppColors.brandPrimary),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spacingMd,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimens.radiusFull),
                  ),
                  textStyle: AppTheme.labelMedium,
                ),
                child: const Text(AppStrings.endPeriod),
              ),
            ),
          ],
        ),
      );
    }

    final predicted = cycleData?.predictedNextPeriod;
    final daysUntil = cycleData?.daysUntilPredicted;

    return Container(
      padding: const EdgeInsets.all(AppDimens.spacingLg),
      decoration: BoxDecoration(
        color: context.themeColors.surfaceTile,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Row(
        children: [
          _stripIcon(Icons.calendar_today_rounded, AppColors.inkSecondary),
          const SizedBox(width: AppDimens.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '暂无进行中的经期',
                  style: AppTheme.titleMedium.copyWith(
                    color: AppColors.ink,
                  ),
                ),
                if (predicted != null && daysUntil != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${AppStrings.predictedNextPeriod} ${predicted.month}月${predicted.day}日 · $daysUntil ${AppStrings.days}后',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppColors.inkSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stripIcon(IconData icon, Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  // ─── Add card ─────────────────────────────────────────────────────
  Widget _buildAddCard(PeriodProvider provider) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spacingLg),
      decoration: BoxDecoration(
        color: context.themeColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '添加经期记录',
                  style: AppTheme.titleLarge.copyWith(
                    color: context.themeColors.onSurface,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _showAddRecordDialog(context, provider),
                icon: const Icon(Icons.calendar_month_rounded, size: 16),
                label: const Text('多选日历'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.brandPrimary,
                  textStyle: AppTheme.labelMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spacingSm),
          _buildDateRow(
            label: AppStrings.startDate,
            date: _startDate,
            onTap: () => _pickDate(isStart: true),
          ),
          const Divider(height: 1),
          _buildDateRow(
            label: AppStrings.endDate,
            date: _endDate,
            onTap: () => _pickDate(isStart: false),
          ),
          const SizedBox(height: AppDimens.spacingLg),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () => _saveRange(provider),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: AppColors.white,
                elevation: AppDimens.elevationNone,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                textStyle: AppTheme.titleMedium,
              ),
              child: const Text('保存记录'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRow({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    final text = date != null
        ? '${date.year}年${date.month}月${date.day}日'
        : AppStrings.selectDate;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.spacingMd),
        child: Row(
          children: [
            Text(
              label,
              style: AppTheme.bodyMedium.copyWith(
                color: AppColors.inkSecondary,
              ),
            ),
            const Spacer(),
            Text(
              text,
              style: AppTheme.titleMedium.copyWith(
                color: date != null
                    ? context.themeColors.onSurface
                    : AppColors.inkTertiary,
              ),
            ),
            const SizedBox(width: AppDimens.spacingSm),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.inkTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate ?? _startDate),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      locale: const Locale('zh', 'CN'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.brandPrimary,
                  onPrimary: AppColors.white,
                  surface: AppColors.white,
                  onSurface: AppColors.ink,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = null;
        }
      } else {
        if (picked.isBefore(_startDate)) {
          _endDate = _startDate;
        } else {
          _endDate = picked;
        }
      }
    });
  }

  Future<void> _saveRange(PeriodProvider provider) async {
    final end = _endDate ?? _startDate;
    final success = await provider.savePeriodRecord(_startDate, end);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '记录已保存' : '保存失败，请检查日期是否冲突'),
        backgroundColor: success ? AppColors.brandPrimary : AppColors.error,
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

  // ─── History ──────────────────────────────────────────────────────
  Widget _buildHistoryCard(PeriodProvider provider) {
    final records = provider.records;

    return Container(
      padding: const EdgeInsets.all(AppDimens.spacingLg),
      decoration: BoxDecoration(
        color: context.themeColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppStrings.historyRecords,
                  style: AppTheme.titleLarge.copyWith(
                    color: context.themeColors.onSurface,
                  ),
                ),
              ),
              if (records.isNotEmpty)
                Text(
                  '共 ${records.length} 条',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppColors.inkTertiary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDimens.spacingSm),
          if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimens.spacing2xl,
              ),
              child: Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.history_rounded,
                      size: 36,
                      color: AppColors.inkTertiary,
                    ),
                    const SizedBox(height: AppDimens.spacingSm),
                    Text(
                      AppStrings.noRecords,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppColors.inkTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: records.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _buildRecordRow(records[index], provider),
            ),
        ],
      ),
    );
  }

  Widget _buildRecordRow(PeriodRecord record, PeriodProvider provider) {
    final start = DateFormat('yyyy-MM-dd').parse(record.startDate);
    final end = record.endDate != null
        ? DateFormat('yyyy-MM-dd').parse(record.endDate!)
        : null;
    final isOngoing = record.isOngoing;

    final rangeText = end != null
        ? '${DateFormat('MM月dd日').format(start)} - ${DateFormat('MM月dd日').format(end)}'
        : '${DateFormat('MM月dd日').format(start)} - 进行中';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spacingMd),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isOngoing
                  ? AppColors.brandSurface
                  : context.themeColors.surfaceTile,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${start.month}月',
                  style: const TextStyle(
                    color: AppColors.inkSecondary,
                    fontSize: 10,
                    height: 1.1,
                  ),
                ),
                Text(
                  '${start.day}',
                  style: TextStyle(
                    color: isOngoing
                        ? AppColors.brandPrimary
                        : context.themeColors.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rangeText,
                  style: AppTheme.titleMedium.copyWith(
                    color: context.themeColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '持续 ${record.periodDays} ${AppStrings.days}',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppColors.inkSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (isOngoing)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spacingSm,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: AppColors.brandSurface,
                borderRadius: BorderRadius.circular(AppDimens.radiusFull),
              ),
              child: Text(
                '进行中',
                style: AppTheme.labelMedium.copyWith(
                  color: AppColors.brandPrimary,
                  fontSize: 11,
                ),
              ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              size: 18,
              color: AppColors.inkTertiary,
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
                    const Icon(Icons.delete_outline_rounded,
                        color: AppColors.error, size: 18),
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
        ],
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
              backgroundColor: AppColors.brandPrimary,
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
    color: AppColors.brandPrimary.withValues(alpha: 0.15),
    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
  );
  static final BoxDecoration _selectedDecoration = BoxDecoration(
    color: AppColors.brandPrimary,
    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
  );
  static final BoxDecoration _selectedFutureDecoration = BoxDecoration(
    color: AppColors.brandPrimary.withValues(alpha: 0.25),
    border: Border.all(
      color: AppColors.brandPrimary.withValues(alpha: 0.5),
      width: 1.2,
    ),
    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
  );
  static final BoxDecoration _selectedFutureTodayDecoration = BoxDecoration(
    color: AppColors.brandPrimary.withValues(alpha: 0.25),
    border: Border.all(
      color: AppColors.brandPrimary,
      width: 1.5,
    ),
    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
  );
  static final BoxDecoration _todayDecoration = BoxDecoration(
    border: Border.all(color: AppColors.brandPrimary, width: 1.5),
    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
  );
  static const EdgeInsets _cellMargin = EdgeInsets.all(3);
  static const TextStyle _existingTodayStyle = TextStyle(
    color: AppColors.brandPrimary,
    fontSize: 13,
  );
  static final TextStyle _existingStyle = TextStyle(
    color: AppColors.brandPrimary.withValues(alpha: 0.4),
    fontSize: 13,
  );
  static const TextStyle _selectedTodayStyle = TextStyle(
    color: AppColors.brandPrimary,
    fontWeight: FontWeight.w600,
    fontSize: 13,
  );
  static const TextStyle _selectedStyle = TextStyle(
    color: AppColors.white,
    fontWeight: FontWeight.w600,
    fontSize: 13,
  );
  static const TextStyle _selectedFutureStyle = TextStyle(
    color: AppColors.brandPrimary,
    fontWeight: FontWeight.w600,
    fontSize: 13,
  );
  static const TextStyle _selectedFutureTodayStyle = TextStyle(
    color: AppColors.brandPrimary,
    fontWeight: FontWeight.w600,
    fontSize: 13,
  );
  static const TextStyle _todayStyle = TextStyle(
    color: AppColors.brandPrimary,
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
              color: AppColors.brandSoft.withValues(alpha: 0.4),
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
                      color: AppColors.brandPrimary,
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
