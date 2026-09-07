import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/period_record.dart';
import 'package:intl/intl.dart';
import '../providers/period_provider.dart';
import '../providers/settings_provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../constants/app_theme.dart';
import 'add_record_calendar_page.dart';

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
            tooltip: AppStrings.multiSelectCalendar,
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
          100,
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
                    AppStrings.noOngoingPeriod,
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
                  AppStrings.addPeriodRecord,
                  style: AppTheme.titleLarge.copyWith(
                    color: context.themeColors.onSurface,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () =>
                    _showAddRecordDialog(context.read<PeriodProvider>()),
                icon: const Icon(Icons.calendar_month_rounded, size: 16),
                label: const Text(AppStrings.multiSelectCalendar),
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
            height: 52,
            child: ElevatedButton(
              onPressed: _endDate == null
                  ? null
                  : () => _saveRange(context.read<PeriodProvider>()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: AppColors.white,
                elevation: AppDimens.elevationNone,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spacingLg,
                  vertical: AppDimens.spacingXs,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                textStyle: AppTheme.buttonLabel,
              ),
              child: Text(
                _endDate == null
                    ? AppStrings.selectEndDate
                    : AppStrings.saveRecord,
              ),
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
        return _buildDatePickerTheme(context, child);
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

  /// 构建 DatePicker 主题，使弹出的日历与项目"温暖陶土色"设计语言统一。
  ///
  /// 优化点：
  /// - 使用项目品牌色（陶土色 `brandPrimary`）替代默认蓝色调
  /// - 圆角使用 `AppDimens.radiusMd`（12px）与卡片圆角保持一致
  /// - 选中日期使用实心陶土色圆角方块
  /// - 头部年份/月份使用 `AppTheme.titleLarge` 样式
  /// - 日期数字使用 `AppTheme.bodyMedium` 统一字号
  /// - 暖中性背景色（`surfaceCard` / `surfaceTile`）适配明暗主题
  /// - 头部切换箭头使用品牌色
  Widget _buildDatePickerTheme(BuildContext context, Widget? child) {
    final themeColors = context.themeColors;
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.brandPrimary,
              onPrimary: AppColors.white,
              surface: themeColors.surfaceCard,
              onSurface: themeColors.onSurface,
              surfaceContainerHighest: themeColors.surfaceTile,
            ),
        datePickerTheme: DatePickerThemeData(
          backgroundColor: themeColors.surfaceCard,
          surfaceTintColor: AppColors.transparent,
          elevation: AppDimens.elevationNone,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radius2xl),
          ),
          headerBackgroundColor: AppColors.transparent,
          headerForegroundColor: themeColors.onSurface,
          headerHeadlineStyle: AppTheme.headingSmall.copyWith(
            color: themeColors.onSurface,
          ),
          headerHelpStyle: AppTheme.bodySmall.copyWith(
            color: themeColors.onSurfaceSecondary,
          ),
          weekdayStyle: TextStyle(
            color: themeColors.onSurfaceTertiary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          yearStyle: TextStyle(
            color: themeColors.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          dayStyle: AppTheme.bodyMedium.copyWith(
            color: themeColors.onSurface,
          ),
          dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.brandPrimary;
            }
            return AppColors.transparent;
          }),
          dayForegroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.white;
            }
            if (states.contains(WidgetState.disabled)) {
              return themeColors.onSurfaceTertiary.withValues(alpha: 0.4);
            }
            return themeColors.onSurface;
          }),
          dayOverlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return AppColors.brandPrimary.withValues(alpha: 0.12);
            }
            if (states.contains(WidgetState.hovered)) {
              return AppColors.brandPrimary.withValues(alpha: 0.08);
            }
            return AppColors.transparent;
          }),
          todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.brandPrimary;
            }
            return AppColors.brandPrimary.withValues(alpha: 0.1);
          }),
          todayForegroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.white;
            }
            return AppColors.brandPrimary;
          }),
          todayBorder: const BorderSide(color: AppColors.brandPrimary, width: 0),
          yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.brandPrimary;
            }
            return AppColors.transparent;
          }),
          yearForegroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.white;
            }
            if (states.contains(WidgetState.disabled)) {
              return themeColors.onSurfaceTertiary.withValues(alpha: 0.4);
            }
            return themeColors.onSurfaceSecondary;
          }),
          yearOverlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return AppColors.brandPrimary.withValues(alpha: 0.12);
            }
            if (states.contains(WidgetState.hovered)) {
              return AppColors.brandPrimary.withValues(alpha: 0.08);
            }
            return AppColors.transparent;
          }),
          cancelButtonStyle: ButtonStyle(
            foregroundColor: WidgetStateProperty.all(themeColors.onSurfaceSecondary),
            textStyle: WidgetStateProperty.all(AppTheme.labelLarge),
          ),
          confirmButtonStyle: ButtonStyle(
            foregroundColor: WidgetStateProperty.all(AppColors.brandPrimary),
            textStyle: WidgetStateProperty.all(AppTheme.labelLarge.copyWith(
              fontWeight: FontWeight.w600,
            )),
          ),
          dividerColor: themeColors.divider,
        ),
      ),
      child: child!,
    );
  }

  Future<void> _saveRange(PeriodProvider provider) async {
    if (_endDate == null) return;
    final success =
        await provider.savePeriodRecord(_startDate, _endDate!);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? AppStrings.recordSaved : AppStrings.saveFailed),
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

    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          success ? '已保存 ${ranges.length} 条记录' : AppStrings.saveFailed2,
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
            // 不使用 ListView.separated + shrinkWrap（shrinkWrap 会测量全部子项，
            // 失去懒加载优势）。改为 Column + for 循环直接展开，
            // 记录数量通常不超过几十条，成本可忽略。
            Column(
              children: [
                for (int i = 0; i < records.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _buildRecordRow(records[i], provider),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRecordRow(PeriodRecord record, PeriodProvider provider) {
    // 直接使用 PeriodRecord 的 startDateTime / endDateTime getter，
    // 避免重复手动解析日期字符串。
    final start = record.startDateTime;
    final end = record.endDateTime;
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
                // 心情/症状标签
                if (record.mood != null || record.symptoms != null) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      if (record.mood != null)
                        Text(
                          record.mood!,
                          style: const TextStyle(fontSize: 14),
                        ),
                      if (record.symptoms != null)
                        ...(record.symptoms!.split(',')
                            .where((s) => s.isNotEmpty))
                            .map((s) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.brandSurface,
                                    borderRadius: BorderRadius.circular(
                                        AppDimens.radiusSm),
                                  ),
                                  child: Text(
                                    s,
                                    style: AppTheme.bodySmall.copyWith(
                                      color: AppColors.brandPrimary,
                                    ),
                                  ),
                                )),
                    ],
                  ),
                ],
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
              if (value == 'edit') {
                _showEditDialog(record, provider);
              } else if (value == 'delete') {
                _showDeleteConfirmDialog(record, provider);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    const Icon(Icons.edit_calendar_rounded,
                        color: AppColors.brandPrimary, size: 18),
                    const SizedBox(width: AppDimens.spacingSm),
                    Text(
                      AppStrings.editRecord,
                      style: AppTheme.bodyMedium.copyWith(
                        color: context.themeColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
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

  void _showEditDialog(PeriodRecord record, PeriodProvider provider) {
    final records = provider.records;
    final currentIndex = records.indexWhere((r) => r.id == record.id);

    // records 按 startDate DESC 排序：索引更小 = 时间更晚（后文），
    // 索引更大 = 时间更早（前文）。
    //
    // ── 隔离保护 ──
    // prevRecord（前文记录）：时间更早的一条，其 endDateTime 是
    //   开始日期选择器的下界 —— 新的开始日期不能早于前文的结束日期。
    // nextRecord（后文记录）：时间更晚的一条，其 startDateTime 是
    //   结束日期选择器的上界 —— 新的结束日期不能晚于后文的开始日期。
    final prevRecord =
        (currentIndex >= 0 && currentIndex < records.length - 1)
            ? records[currentIndex + 1]
            : null;
    final nextRecord =
        (currentIndex > 0) ? records[currentIndex - 1] : null;

    // 前文记录的结束日期（开始日期不能早于此日期 + 1 天）
    final prevEndDate = prevRecord?.endDateTime;
    // 后文记录的开始日期（结束日期不能晚于此日期 - 1 天）
    final nextStartDate = nextRecord?.startDateTime;

    DateTime editStart = record.startDateTime;
    DateTime? editEnd = record.endDateTime;
    bool isOngoing = record.isOngoing;

    // ── 症状/心情/备注/经量 ──
    String? editMood = record.mood;
    int? editFlowLevel = record.flowLevel;
    List<String> editSymptoms = record.symptoms != null
        ? record.symptoms!.split(',').where((s) => s.isNotEmpty).toList()
        : [];
    String editNotes = record.notes ?? '';

    // 可选心情列表
    const moodOptions = ['😊', '😐', '😢', '😡', '🥵', '🤒'];
    // 可选症状列表
    const symptomOptions = [
      '痛经',
      '头痛',
      '腰酸',
      '腹胀',
      '疲劳',
      '失眠',
      '食欲变化',
      '情绪波动',
      '乳房胀痛',
      '痤疮',
    ];

    // 校验错误信息（冲突时显示，阻止保存）
    String? errorMsg;
    // 异常提示信息（经期长度异常但允许保存，需用户二次确认）
    String? warningMsg;
    bool warningConfirmed = false;

    // ── 日期选择器可选范围 ──
    // 开始日期：不早于前文记录结束日期的下一天，不晚于今天 +1 年
    DateTime startFirstDate = DateTime(editStart.year - 5);
    if (prevEndDate != null) {
      startFirstDate = prevEndDate.add(const Duration(days: 1));
    }
    final startLastDate =
        nextStartDate ?? DateTime(editStart.year + 1);

    // 结束日期：不早于开始日期，不晚于后文记录开始日期的前一天
    DateTime endFirstDate = editStart;
    DateTime? endLastDate;
    if (nextStartDate != null) {
      endLastDate = nextStartDate.subtract(const Duration(days: 1));
    }

    // ── 校验函数 ──
    /// 执行完整校验，返回是否通过。
    /// [forSave] 为 true 时做完整冲突检查（阻止保存）；
    /// 为 false 时只做实时提示。
    bool validate({bool forSave = false}) {
      errorMsg = null;

      // 基本逻辑：开始日期不能晚于结束日期
      if (!isOngoing && editEnd != null && editEnd!.isBefore(editStart)) {
        errorMsg = AppStrings.editConflictStartAfterEnd;
        return false;
      }

      // 边界判定 1：不能与后文记录重叠
      // 如果有后文记录（nextStartDate），结束日期不能晚于后文开始日期的前一天
      if (!isOngoing && editEnd != null && nextStartDate != null) {
        if (!editEnd!.isBefore(nextStartDate)) {
          errorMsg = AppStrings.editConflictNextOverlap;
          return false;
        }
      }

      // 边界判定 2：不能与前文记录重叠
      // 如果有前文记录（prevEndDate），开始日期不能早于前文结束日期的后一天
      if (prevEndDate != null) {
        if (editStart.isBefore(prevEndDate.add(const Duration(days: 1)))) {
          errorMsg = AppStrings.editConflictPrevOverlap;
          return false;
        }
      }

      // 进行中的经期：开始日期不能晚于后文记录的开始日期
      if (isOngoing && nextStartDate != null) {
        if (!editStart.isBefore(nextStartDate)) {
          errorMsg = AppStrings.editConflictNextOverlap;
          return false;
        }
      }

      // 异常长度提示（不阻止保存，但需确认）
      warningMsg = null;
      if (!isOngoing && editEnd != null) {
        final days = editEnd!.difference(editStart).inDays + 1;
        if (days < 2) {
          warningMsg = '经期仅$days天，时长偏短，确认是否正确？';
        } else if (days > 10) {
          warningMsg = '经期$days天，时长偏长，确认是否正确？';
        }
      }

      // 如果是保存操作且有异常提示但用户尚未确认，阻止本次保存
      if (forSave && warningMsg != null && !warningConfirmed) {
        return false;
      }

      return true;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // 每次重建时重新计算校验
          validate();
          // 保存按钮是否可点击
          final canSave = (editEnd != null || isOngoing) && errorMsg == null;
          // 是否需要显示"确认异常"按钮
          final needsWarningConfirm =
              warningMsg != null && !warningConfirmed && errorMsg == null;

          return AlertDialog(
            title: const Text(AppStrings.editRecordTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.editRecordHint,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppColors.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spacingLg),
                  // 开始日期
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: editStart,
                        firstDate: startFirstDate,
                        lastDate: startLastDate,
                        locale: const Locale('zh', 'CN'),
                        builder: (context, child) {
                          return _buildDatePickerTheme(context, child);
                        },
                      );
                      if (picked != null) {
                        setDialogState(() {
                          editStart = picked;
                          // 如果结束日期早于新的开始日期，也调整结束日期
                          if (editEnd != null && editEnd!.isBefore(editStart)) {
                            editEnd = editStart;
                          }
                          // 重新计算结束日期选择器的下界
                          endFirstDate = editStart;
                          // 用户修改了日期，重置确认状态
                          warningConfirmed = false;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimens.spacingMd,
                        horizontal: AppDimens.spacingMd,
                      ),
                      decoration: BoxDecoration(
                        color: ctx.themeColors.surfaceTile,
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusMd),
                      ),
                      child: Row(
                        children: [
                          Text(
                            AppStrings.startDate,
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppColors.inkSecondary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${editStart.year}年${editStart.month}月${editStart.day}日',
                            style: AppTheme.titleMedium.copyWith(
                              color: ctx.themeColors.onSurface,
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
                  ),
                  const SizedBox(height: AppDimens.spacingMd),
                  // 结束日期
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: editEnd ?? editStart,
                        firstDate: endFirstDate,
                        lastDate: endLastDate ??
                            DateTime(editStart.year + 1),
                        locale: const Locale('zh', 'CN'),
                        builder: (context, child) {
                          return _buildDatePickerTheme(context, child);
                        },
                      );
                      if (picked != null) {
                        setDialogState(() {
                          editEnd = picked;
                          isOngoing = false;
                          warningConfirmed = false;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimens.spacingMd,
                        horizontal: AppDimens.spacingMd,
                      ),
                      decoration: BoxDecoration(
                        color: ctx.themeColors.surfaceTile,
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusMd),
                      ),
                      child: Row(
                        children: [
                          Text(
                            AppStrings.endDate,
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppColors.inkSecondary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            isOngoing
                                ? '进行中'
                                : (editEnd != null
                                    ? '${editEnd!.year}年${editEnd!.month}月${editEnd!.day}日'
                                    : AppStrings.selectDate),
                            style: AppTheme.titleMedium.copyWith(
                              color: isOngoing || editEnd == null
                                  ? AppColors.inkTertiary
                                  : ctx.themeColors.onSurface,
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
                  ),
                  // 清除结束日期按钮（仅当当前有结束日期时显示）
                  if (!isOngoing && editEnd != null) ...[
                    const SizedBox(height: AppDimens.spacingSm),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            editEnd = null;
                            isOngoing = true;
                            warningConfirmed = false;
                          });
                        },
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        label: const Text(AppStrings.clearEndDate),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.inkSecondary,
                          textStyle: AppTheme.labelMedium,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.spacingSm,
                          ),
                        ),
                      ),
                    ),
                  ],
                  // 进行中标签提示
                  if (isOngoing) ...[
                    const SizedBox(height: AppDimens.spacingSm),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spacingMd,
                        vertical: AppDimens.spacingXs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandSurface,
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusSm),
                      ),
                      child: Text(
                        AppStrings.clearEndDateHint,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ),
                  ],
                  // ── 经量选择 ──
                  const SizedBox(height: AppDimens.spacingLg),
                  Text(
                    '经量',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppColors.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spacingSm),
                  Wrap(
                    spacing: AppDimens.spacingSm,
                    runSpacing: AppDimens.spacingSm,
                    children: [
                      ('偏少', PeriodRecord.flowLight),
                      ('正常', PeriodRecord.flowNormal),
                      ('偏多', PeriodRecord.flowHeavy),
                    ].map((item) {
                      final label = item.$1;
                      final level = item.$2;
                      final isSelected = editFlowLevel == level;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            editFlowLevel = isSelected ? null : level;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.spacingMd,
                            vertical: AppDimens.spacingXs,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.brandPrimary.withValues(alpha: 0.12)
                                : ctx.themeColors.surfaceTile,
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusFull),
                            border: isSelected
                                ? Border.all(
                                    color: AppColors.brandPrimary, width: 1.2)
                                : Border.all(
                                    color: ctx.themeColors.divider
                                        .withValues(alpha: 0.3),
                                    width: 0.5),
                          ),
                          child: Text(
                            label,
                            style: AppTheme.bodySmall.copyWith(
                              color: isSelected
                                  ? AppColors.brandPrimary
                                  : ctx.themeColors.onSurfaceSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  // ── 心情选择 ──
                  const SizedBox(height: AppDimens.spacingLg),
                  Text(
                    '心情',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppColors.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spacingSm),
                  Wrap(
                    spacing: AppDimens.spacingSm,
                    runSpacing: AppDimens.spacingSm,
                    children: moodOptions.map((mood) {
                      final isSelected = editMood == mood;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            editMood = isSelected ? null : mood;
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.brandPrimary.withValues(alpha: 0.15)
                                : ctx.themeColors.surfaceTile,
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusFull),
                            border: isSelected
                                ? Border.all(
                                    color: AppColors.brandPrimary, width: 1.5)
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(mood, style: const TextStyle(fontSize: 20)),
                        ),
                      );
                    }).toList(),
                  ),
                  // ── 症状选择 ──
                  const SizedBox(height: AppDimens.spacingLg),
                  Text(
                    '症状',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppColors.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spacingSm),
                  Wrap(
                    spacing: AppDimens.spacingSm,
                    runSpacing: AppDimens.spacingSm,
                    children: symptomOptions.map((symptom) {
                      final isSelected = editSymptoms.contains(symptom);
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            if (isSelected) {
                              editSymptoms.remove(symptom);
                            } else {
                              editSymptoms.add(symptom);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.spacingMd,
                            vertical: AppDimens.spacingXs,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.brandPrimary.withValues(alpha: 0.12)
                                : ctx.themeColors.surfaceTile,
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusFull),
                            border: isSelected
                                ? Border.all(
                                    color: AppColors.brandPrimary, width: 1.2)
                                : Border.all(
                                    color: ctx.themeColors.divider
                                        .withValues(alpha: 0.3),
                                    width: 0.5),
                          ),
                          child: Text(
                            symptom,
                            style: AppTheme.bodySmall.copyWith(
                              color: isSelected
                                  ? AppColors.brandPrimary
                                  : ctx.themeColors.onSurfaceSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  // ── 备注输入 ──
                  const SizedBox(height: AppDimens.spacingLg),
                  Text(
                    '备注',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppColors.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spacingSm),
                  TextField(
                    controller: TextEditingController(text: editNotes),
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: '记录其他感受...',
                      hintStyle: AppTheme.bodySmall.copyWith(
                        color: AppColors.inkTertiary,
                      ),
                      filled: true,
                      fillColor: ctx.themeColors.surfaceTile,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spacingMd,
                        vertical: AppDimens.spacingSm,
                      ),
                    ),
                    onChanged: (value) {
                      editNotes = value;
                    },
                  ),
                  // ── 冲突错误提示 ──
                  if (errorMsg != null) ...[
                    const SizedBox(height: AppDimens.spacingSm),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spacingMd,
                        vertical: AppDimens.spacingXs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusSm),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppColors.error, size: 16),
                          const SizedBox(width: AppDimens.spacingSm),
                          Expanded(
                            child: Text(
                              errorMsg!,
                              style: AppTheme.bodySmall.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // ── 异常长度提示（不阻止保存，需确认） ──
                  if (errorMsg == null && warningMsg != null) ...[
                    const SizedBox(height: AppDimens.spacingSm),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spacingMd,
                        vertical: AppDimens.spacingXs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusSm),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: AppColors.warning, size: 16),
                          const SizedBox(width: AppDimens.spacingSm),
                          Expanded(
                            child: Text(
                              warningMsg!,
                              style: AppTheme.bodySmall.copyWith(
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(AppStrings.cancel),
              ),
              // 异常确认按钮：用户需要先确认异常提示后才能保存
              if (needsWarningConfirm)
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      warningConfirmed = true;
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.warning,
                  ),
                  child: const Text('确认异常'),
                ),
              ElevatedButton(
                // 没有结束日期、不是进行中、有冲突错误、或需要确认异常时禁用
                onPressed: canSave &&
                        (!needsWarningConfirm)
                    ? () async {
                        // 最终校验
                        if (!validate(forSave: true)) return;

                        // 构造更新后的记录
                        final startStr =
                            editStart.toIso8601String().split('T')[0];
                        final endStr = isOngoing
                            ? null
                            : (editEnd != null
                                ? editEnd!.toIso8601String().split('T')[0]
                                : null);
                        final periodLength = (endStr != null)
                            ? (editEnd!.difference(editStart).inDays + 1)
                                .clamp(1, 999)
                            : null;
                        final updated = record.copyWith(
                          startDate: startStr,
                          endDate: endStr,
                          periodLength: periodLength,
                          flowLevel: editFlowLevel,
                          mood: editMood,
                          symptoms: editSymptoms.isEmpty
                              ? null
                              : editSymptoms.join(','),
                          notes: editNotes.isEmpty ? null : editNotes,
                          clearEndDate: isOngoing,
                          clearPeriodLength: isOngoing,
                          clearFlowLevel: editFlowLevel == null,
                          clearMood: editMood == null,
                          clearSymptoms: editSymptoms.isEmpty,
                          clearNotes: editNotes.isEmpty,
                        );
                        final success =
                            await provider.updateRecord(updated);
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success
                                ? AppStrings.recordUpdated
                                : AppStrings.updateFailed),
                            backgroundColor: success
                                ? AppColors.brandPrimary
                                : AppColors.error,
                          ),
                        );
                      }
                    : null,
                child: const Text(AppStrings.save),
              ),
            ],
          );
        },
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
              final id = record.id;
              if (id != null) {
                provider.deleteRecord(id);
              }
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

