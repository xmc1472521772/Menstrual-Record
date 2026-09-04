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

/// 多选日历默认延展天数（X）的取值规则：
/// 1) 已完成（已结束）的经期记录达到 3 条及以上（"足够多"，与
///    [PredictionService] 加权平均的门槛一致）时，取这些记录的经期天数平均值；
/// 2) 否则以设置中的经期天数为准。
/// 抽成纯函数便于单测。此前任何一条已完成记录就会让平均值覆盖设置值，
/// 导致用户修改"经期天数"后日历自动延展不跟随设置（被误认为持久化失效）。
int computeDefaultPeriodDays({
  required int completedRecordCount,
  required double averagePeriodLength,
  required int settingsPeriodLength,
}) {
  if (completedRecordCount >= 3 && averagePeriodLength > 0) {
    return averagePeriodLength.round();
  }
  return settingsPeriodLength;
}

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
              onPressed: () => _showAddRecordDialog(
                    context.read<PeriodProvider>(),
                  ),
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
      // 把 provider 监听拆到真正依赖数据的两个区块（今日条 / 历史列表），
      // 「添加卡片」只在本地的 setState 下重建，添加经期触发的 notifyListeners
      // 不再连带重建它，减少一次无关的子树重建。
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.spacingXl,
          AppDimens.spacingSm,
          AppDimens.spacingXl,
          AppDimens.spacing2xl,
        ),
        child: Column(
          children: [
            Consumer<PeriodProvider>(
              builder: (context, provider, _) => _buildTodayStrip(provider),
            ),
            const SizedBox(height: AppDimens.spacingLg),
            _buildAddCard(),
            const SizedBox(height: AppDimens.spacingLg),
            Consumer<PeriodProvider>(
              builder: (context, provider, _) => _buildHistoryCard(provider),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Today strip ──────────────────────────────────────────────────
  Widget _buildTodayStrip(PeriodProvider provider) {
    final hasOngoing = provider.hasOngoingPeriod;
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
  /// 添加卡片只依赖本地状态（_startDate / _endDate），不需要监听 provider。
  /// 仅在回调里通过 [context.read] 取 provider，避免其在数据变化时随 Consumer 重建。
  Widget _buildAddCard() {
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
                onPressed: () =>
                    _showAddRecordDialog(context.read<PeriodProvider>()),
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
              onPressed: () => _saveRange(context.read<PeriodProvider>()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: AppColors.white,
                elevation: AppDimens.elevationNone,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                textStyle: AppTheme.buttonLabel,
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

  Future<void> _showAddRecordDialog(PeriodProvider provider) async {
    final cycleData = provider.cycleData;
    // X 的取值规则见 [computeDefaultPeriodDays]：设置值为主，已完成记录
    // 达到 3 条才切换到其经期天数平均值。
    // 注意必须先 ensureLoaded：SettingsProvider 懒创建后首次访问时
    // loadSettings 可能尚未完成，直接读 periodLength 会拿到构造默认值。
    final settingsProvider = context.read<SettingsProvider>();
    await settingsProvider.ensureLoaded();
    final completedCount = provider.records.where((r) => !r.isOngoing).length;
    final defaultDays = computeDefaultPeriodDays(
      completedRecordCount: completedCount,
      averagePeriodLength: cycleData?.averagePeriodLength ?? 0,
      settingsPeriodLength: settingsProvider.periodLength,
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 默认带出起始日：优先「上次记录的下一天」以顺延记录；若上次记录结束已较久
    // （顺延日早于今日）则按今日新开，避免把很久以前的日期误当默认。
    DateTime defaultStart = today;
    final recs = provider.records;
    if (recs.isNotEmpty) {
      final latest = recs.first; // records 按 start_date DESC，首条即最近一次
      if (!latest.isOngoing) {
        final end = latest.endDateTime!;
        final next = DateTime(end.year, end.month, end.day + 1);
        if (!next.isBefore(today)) defaultStart = next;
      }
    }

    if (!mounted) return;
    final ranges = await Navigator.push<List<(DateTime, DateTime)>>(
      context,
      MaterialPageRoute(
        builder: (ctx) => AddRecordCalendarPage(
          provider: provider,
          defaultDays: defaultDays,
          today: today,
          defaultStart: defaultStart,
        ),
      ),
    );

    if (!mounted || ranges == null || ranges.isEmpty) return;

    // 页面已经关闭，这里在后台落库并用 SnackBar 反馈结果
    final success = await provider.saveMultipleRecords(ranges);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? '已保存 ${ranges.length} 条记录' : '保存失败',
        ),
        backgroundColor: success ? AppColors.success : AppColors.error,
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

  /// 打开时默认带出的起始日。不传则取 [today]。
  /// 用于「默认带出今日 / 上次记录的下一天」实现一键保存。
  final DateTime? defaultStart;

  const AddRecordCalendarPage({
    super.key,
    required this.provider,
    required this.defaultDays,
    required this.today,
    this.defaultStart,
  });

  @override
  State<AddRecordCalendarPage> createState() => _AddRecordCalendarPageState();
}

class _AddRecordCalendarPageState extends State<AddRecordCalendarPage> {
  static const int _totalMonths = 72;
  static const int _monthsBefore = 36;

  late ScrollController _scrollController;
  late Set<int> _selectedDays;
  late final Set<int> _existingDays;
  String? _conflictMsg;
  double? _exactInitialOffset;
  bool _didInitialScroll = false;
  double _cellWidth = 49.0;

  /// 打开时默认带出的起始日（今日或上次记录顺延），用于一键保存。
  late final DateTime _defaultStartDay;

  /// 用户是否手动编辑过选择（点选/取消过任何一天）。
  /// 用于区分「点击新日期」时的两种语义：仍是打开时的默认预选 →
  /// 视为改起点（替换）；已编辑过 → 视为追加一段新区间（多段补录）。
  bool _userEditedSelection = false;

  // Precomputed month metadata cache — avoids per-frame DateTime/string allocations
  late final Map<int, _MonthInfo> _monthCache;

  // 说明：日历曾经给每个可点格子挂 ValueNotifier + ValueListenableBuilder 做
  // 「点击只重建单个格子」的局部刷新。当时列表 keep-alive 开启，整页 setState
  // 会让上千个已滑过的格子全部重建，才需要这套机制。
  // 现在月份列表已关闭 keep-alive（addAutomaticKeepAlives: false），同一时刻
  // 只有视口附近的几个月份存活（约 2~3 个月、~150 个格子）。整页 setState 的
  // 重建量已被严格限界且远小于旧方案，因此移除逐格 Notifier：既消除无限滚动时
  // _cellNotifiers 无界累积（数千个 ValueNotifier 常驻）与滚动建格时的对象分配，
  // 也让代码回到最简路径。底部面板随整页重建自然更新，无需额外通知。

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
    _monthCache = _buildMonthCache();
    // 打开即预选「默认起始日」起 defaultDays 天（默认今日，可由上次记录顺延），
    // 用户无需先点选即可一键「确定」完成记录；若默认日落在已有记录内（进行中经期）
    // 则跳过，待用户点选其它日期。底部面板同步即时显示「已选 N 天」。
    _defaultStartDay = widget.defaultStart ?? widget.today;
    _autoSelectFrom(_defaultStartDay);
    // ScrollController 延迟到 didChangeDependencies 创建：初始滚动偏移依赖
    // MediaQuery 屏宽（initState 时 context 尚未就绪），在那里算出精确偏移后用
    // 声明式 initialScrollOffset 定位，避免 addPostFrameCallback+jumpTo 在路由
    // 进出场动画期间反复调度帧（表现为测试挂起 / 真机卡顿、掉帧、耗电）。
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cellWidth = (MediaQuery.of(context).size.width - AppDimens.spacingSm * 2) / 7;
    // 只创建一次：用真实的屏宽算出当前月（_monthsBefore 之前那个月）起始偏移，
    // 声明式地让 ListView 首帧就定位到当前月，无需 post-frame 回调。
    if (!_didInitialScroll) {
      _didInitialScroll = true;
      _exactInitialOffset = _computeExactOffset();
      _scrollController = ScrollController(
        initialScrollOffset: _exactInitialOffset ?? 0.0,
      );
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

  /// 回到「当前月」：直接按预计算出的精确偏移量滚动（当前月的起始位置）。
  /// 不依赖 GlobalKey 取 context —— 在 ListView.builder 的 item 上挂 GlobalKey
  /// 会与 [findChildIndexCallback] 冲突，路由出栈时引发无限重建、pumpAndSettle
  /// 永不收敛（表现为添加经期后返回卡死）。
  void _scrollToCurrentMonth() {
    if (!_scrollController.hasClients || _exactInitialOffset == null) return;
    _scrollController.animateTo(
      _exactInitialOffset!.clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
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

  void _onDayTap(int key, DateTime day) {
    if (_existingDays.contains(key)) return;

    // 整页重建：由于月份列表关闭了 keep-alive，同一时刻存活的月份只有
    // 视口附近的 2~3 个（~150 个格子），重建量有界且远小于旧逐格 Notifier
    // 方案的无界累积。底部面板的选中摘要随本次重建一起刷新。
    setState(() {
      if (_selectedDays.contains(key)) {
        // 已选中的天：点击移除，支持逐天微调。
        _selectedDays.remove(key);
        _userEditedSelection = true;
      } else if (_isAdjacentToSelection(key)) {
        // 与当前选择相邻：视为在现有区间上逐天增减，只加入该天。
        _selectedDays.add(key);
        _userEditedSelection = true;
      } else {
        // 全新起点（与所有已选天都不相邻，含选择为空）：从该天起自动
        // 往后延 defaultDays 天（遇到已有记录即停）。仍是打开时的默认
        // 预选（未编辑过）时直接替换为新起点；已编辑过则追加为新区间，
        // 便于一次圈出多段记录、批量补录。
        _autoSelectFrom(day, replace: !_userEditedSelection);
        _userEditedSelection = true;
        return;
      }
      _validateConflict();
    });
  }

  /// [key] 对应日期是否与当前选择集中的某天前后相邻。
  /// 用 DateTime 计算相邻，避免整数 key 在跨月处（如 20260131/20260201）
  /// 被误判为不相邻。
  bool _isAdjacentToSelection(int key) {
    if (_selectedDays.isEmpty) return false;
    final day = DateTime(_keyToYear(key), _keyToMonth(key), _keyToDay(key));
    final prevKey = _dayKeyInt(day.subtract(const Duration(days: 1)));
    final nextKey = _dayKeyInt(day.add(const Duration(days: 1)));
    return _selectedDays.contains(prevKey) || _selectedDays.contains(nextKey);
  }

  /// 从 [startDay] 起往后选中 [widget.defaultDays] 天（遇到已有记录即停）。
  /// [replace] 为 true 时替换当前选择（打开页面的默认预选 / 改起点）；
  /// 为 false 时在现有选择上追加新区间（一次会话圈出多段记录）。
  /// 仅供 [initState] 或 [_onDayTap]（其内部已包 setState）调用，自身不触发重建。
  void _autoSelectFrom(DateTime startDay, {bool replace = true}) {
    final days = widget.defaultDays;
    final newSelection = replace ? <int>{} : Set<int>.of(_selectedDays);

    for (int i = 0; i < days; i++) {
      final d = startDay.add(Duration(days: i));
      final key = _dayKeyInt(d);
      if (_existingDays.contains(key)) break;
      newSelection.add(key);
    }

    _selectedDays = newSelection;
    _validateConflict();
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
        '点击日期自动从该天起选中 ${widget.defaultDays} 天，点相邻日期可逐天增减',
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
  // 选中实底色上的「今天」必须用白字：此前沿用陶土红文字，与实色背景同色，
  // 导致今天的日期数字被完全盖住不可见。
  static const TextStyle _selectedTodayStyle = TextStyle(
    color: AppColors.white,
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

  Widget _buildMonthList() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _totalMonths,
      // 不再 keepAlive：保活会让所有滑过的月份都常驻并参与 cell 重建，
      // 点击一天时反而要重建上千个 cell。改用下面的局部刷新来保证流畅度。
      addAutomaticKeepAlives: false,
      // Pre-render nearby months for smoother scrolling
      scrollCacheExtent: const ScrollCacheExtent.pixels(800),
      itemBuilder: (context, index) {
        final info = _monthCache[index]!;
        final monthKey = ValueKey('${info.year}-${info.month}');
        return KeyedSubtree(
          key: monthKey,
          child: _buildMonthView(info),
        );
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
            final isToday = isTodayYear && isTodayMonth && dayNum == todayDay;
            final isPast = !isToday && key < todayKey;
            final isFuture = !isToday && !isPast;

            return _buildCellSlot(
              key: key,
              dayNum: dayNum,
              isExisting: isExisting,
              isFuture: isFuture,
              isToday: isToday,
              isPast: isPast,
              year: year,
              month: month,
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

  /// 构建一个日历格子。
  ///
  /// 选中状态直接读取 [_selectedDays]：月份列表已关闭 keep-alive，整页 setState
  /// 只重建存活的 2~3 个月份，无需 per-cell Notifier（见类顶部说明）。
  Widget _buildCellSlot({
    required int key,
    required int dayNum,
    required bool isExisting,
    required bool isFuture,
    required bool isToday,
    required bool isPast,
    required int year,
    required int month,
  }) {
    final isSelected = _selectedDays.contains(key);
    final cell = _buildDayCell(
      dayNum,
      isExisting,
      isSelected && !isFuture,
      isSelected && isFuture,
      isToday,
      isPast,
    );

    // 已有记录的格子不可点击，省掉手势识别器的注册开销
    if (isExisting) {
      return Expanded(child: cell);
    }

    return Expanded(
      child: GestureDetector(
        // DateTime 只在真正点击时才构造，滚动时不产生分配
        onTap: () => _onDayTap(key, DateTime(year, month, dayNum)),
        child: cell,
      ),
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
    // 面板随整页重建自然刷新（选中变化走 _onDayTap 里的 setState）。
    return _buildBottomPanelContent();
  }

  Widget _buildBottomPanelContent() {
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
                        ? () {
                            // 只做取数 + 关闭页面，DB 写入交给 RecordScreen 在后台执行，
                            // 这样点击「确定」后页面立刻返回，不会有等待感。
                            final ranges = _buildRanges();
                            Navigator.pop(context, ranges);
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
