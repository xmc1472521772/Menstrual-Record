import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/period_record.dart';
import 'package:intl/intl.dart';
import '../providers/period_provider.dart';
import '../providers/settings_provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../constants/app_theme.dart';
import '../utils/period_validation.dart';
import 'add_record_calendar_page.dart';
import '../widgets/period_edit_dialog.dart';

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

/// 构建历史记录行的心情/症状标签列表。
///
/// 空白安全：mood/symptoms 为非 null 空串或含空白项的历史脏数据
/// 不会产生任何子项，从而不占行高（[Wrap] 无子项时高度为 0）。
/// 此前直接判 null，`Text('')` 也会占一行高（约 +25px），表现为
/// 越靠后的记录行间距越大、行与行错位。
List<Widget> buildRecordTags(PeriodRecord record) {
  final moodText = record.mood?.trim();
  final symptomTexts = (record.symptoms ?? '')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  if ((moodText == null || moodText.isEmpty) && symptomTexts.isEmpty) {
    return const [];
  }

  return [
    const SizedBox(height: 4),
    Wrap(
      spacing: 4,
      runSpacing: 2,
      children: [
        if (moodText != null && moodText.isNotEmpty)
          Text(
            moodText,
            // 统一走主题样式：裸 TextStyle 无 height，
            // 不同厂商字体度量不同导致行高不一致。
            style: AppTheme.bodyMedium,
          ),
        ...symptomTexts.map(
          (s) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.brandSurface,
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            ),
            child: Text(
              s,
              style: AppTheme.bodySmall.copyWith(
                color: AppColors.brandPrimary,
              ),
            ),
          ),
        ),
      ],
    ),
  ];
}

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  late DateTime _startDate;
  DateTime? _endDate;

  /// 异常经期长度（<2 天或 >10 天）的保存确认标志。
  /// 与编辑对话框的「确认异常」口径一致：首次点保存仅提示，
  /// 用户再次点保存才落库；日期变化后重置。
  bool _lengthWarningConfirmed = false;

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
        toolbarHeight: AppDimens.appBarHeight,
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
          AppDimens.navBarClearance,
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
            // 图标位于白色半透明容器内（叠在主题 surfaceTile 上），
            // 深色模式下容器会随主题变灰，图标色需跟随主题保证对比度。
            _stripIcon(Icons.calendar_today_rounded,
                context.themeColors.onSurfaceSecondary),
            const SizedBox(width: AppDimens.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.noOngoingPeriod,
                    style: AppTheme.titleMedium.copyWith(
                      color: context.themeColors.onSurface,
                    ),
                  ),
                if (predicted != null && daysUntil != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${AppStrings.predictedNextPeriod} ${predicted.month}月${predicted.day}日 · $daysUntil ${AppStrings.days}后',
                    style: AppTheme.bodySmall.copyWith(
                      color: context.themeColors.onSurfaceSecondary,
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
            onTap: () =>
                _pickDate(isStart: true, provider: context.read<PeriodProvider>()),
          ),
          const Divider(height: 1),
          _buildDateRow(
            label: AppStrings.endDate,
            date: _endDate,
            onTap: () => _pickDate(
                isStart: false, provider: context.read<PeriodProvider>()),
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
                color: context.themeColors.onSurfaceSecondary,
              ),
            ),
            const Spacer(),
            Text(
              text,
              style: AppTheme.titleMedium.copyWith(
                color: date != null
                    ? context.themeColors.onSurface
                    : context.themeColors.onSurfaceTertiary,
              ),
            ),
            const SizedBox(width: AppDimens.spacingSm),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: context.themeColors.onSurfaceTertiary,
            ),
          ],
        ),
      ),
    );
  }

  /// 弹出日期选择器并应用新增记录的校验规则。
  ///
  /// 选择限制：
  /// - 选择器 `lastDate` 收紧为今天 —— 未来日期在日历上直接灰掉，
  ///   杜绝「尚未发生的经期」污染周期预测；
  /// - 结束日期选择器 `firstDate` 为开始日期，从源头保证 end >= start；
  /// - 选定后立即对整个候选区间做冲突校验（不与已有记录重叠），
  ///   不通过则提示原因并保持原选择不变。
  Future<void> _pickDate({
    required bool isStart,
    required PeriodProvider provider,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate ?? _startDate),
      firstDate: DateTime(now.year - 5),
      lastDate: today,
      locale: const Locale('zh', 'CN'),
      builder: (context, child) {
        return buildPeriodDatePickerTheme(context, child);
      },
    );
    if (picked == null) return;

    // 候选区间：选开始日时若原结束日早于新开始日则联动清空（沿用原逻辑）；
    // 选结束日时钳制到不早于开始日（选择器已限制，此处防御性兜底）。
    DateTime candidateStart = _startDate;
    DateTime? candidateEnd = _endDate;
    if (isStart) {
      candidateStart = picked;
      if (candidateEnd != null && candidateEnd.isBefore(picked)) {
        candidateEnd = null;
      }
    } else {
      candidateEnd = picked.isBefore(_startDate) ? _startDate : picked;
    }

    // 选定后立即校验：不晚于今天 + 不与已有记录重叠。
    // 提供精确原因，避免用户到保存时才看到笼统的失败。
    final error = validateNewPeriodRange(
      start: candidateStart,
      end: candidateEnd ?? candidateStart,
      today: today,
      records: provider.records,
    );
    if (error != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _startDate = candidateStart;
      _endDate = candidateEnd;
      // 日期变化后，此前的异常长度确认不再有效
      _lengthWarningConfirmed = false;
    });
  }

  Future<void> _saveRange(PeriodProvider provider) async {
    if (_endDate == null) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 保存前全量校验：选择日期后记录可能已变化（如从多选日历返回时
    // 新增了记录），不能只依赖选择时的判断，必须以最新记录重新校验。
    final error = validateNewPeriodRange(
      start: _startDate,
      end: _endDate!,
      today: today,
      records: provider.records,
    );
    if (error != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // 异常长度（<2 天 / >10 天）不直接拦截，首次点保存仅提示，
    // 需用户再次点击确认，防止误选导致的畸形区间记录。
    final days = _endDate!.difference(_startDate).inDays + 1;
    final warning = periodLengthWarning(days);
    if (warning != null && !_lengthWarningConfirmed) {
      if (!mounted) return;
      setState(() => _lengthWarningConfirmed = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$warning ${AppStrings.lengthWarningConfirm}'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final success =
        await provider.savePeriodRecord(_startDate, _endDate!);
    if (!mounted) return;
    if (success) _lengthWarningConfirmed = false;

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
          success
              ? AppStrings.savedNRecords.replaceAll('{}', '${ranges.length}')
              : AppStrings.saveFailed2,
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
                  AppStrings.recordsCount
                      .replaceAll('{}', '${records.length}'),
                  style: AppTheme.bodySmall.copyWith(
                    color: context.themeColors.onSurfaceTertiary,
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
                    Icon(
                      Icons.history_rounded,
                      size: 36,
                      color: context.themeColors.onSurfaceTertiary,
                    ),
                    const SizedBox(height: AppDimens.spacingSm),
                    Text(
                      AppStrings.noRecords,
                      style: AppTheme.bodySmall.copyWith(
                        color: context.themeColors.onSurfaceTertiary,
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
            // 文本缩放已由 app.dart 根节点全局钳制（max 1.3）。
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
        // 顶部锚定对齐：行高由内容决定（心情/症状标签会让文字列比 46 的
        // 日期徽标高），若用默认的 center 对齐，文字列会相对徽标上下同时
        // 伸展，首行顶到徽标之上，表现为"右侧信息往上靠、有无标签的行
        // 对齐不一致"。改为 start 后无论右侧多高，徽标顶边与信息顶边恒对齐。
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  // 徽标文字不随系统字体缩放：固定容器内跟随缩放会溢出错位，
                  // 固定字号才能保证所有机型上徽标视觉一致。
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    color: context.themeColors.onSurfaceSecondary,
                    fontSize: 10,
                    height: 1.1,
                  ),
                ),
                Text(
                  '${start.day}',
                  textScaler: TextScaler.noScaling,
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
                  // 单行 + 省略号：窄屏或大字体下禁止换行，
                  // 避免行高参差不齐导致历史列表排版不齐。
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.titleMedium.copyWith(
                    color: context.themeColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${AppStrings.duration} ${record.periodDays} ${AppStrings.days}',
                  style: AppTheme.bodySmall.copyWith(
                    color: context.themeColors.onSurfaceSecondary,
                  ),
                ),
                // 心情/症状标签：先过滤空白内容再决定是否渲染。
                // 历史数据里存在 mood/symptoms 为非 null 空串（或含空白项）
                // 的记录，直接判 null 会让 Wrap 渲染出"看不见的空行"
                // （Text('') 也占一行高，约 +25px），表现为越靠后的记录
                // 行间距越大、行与行错位。
                ...buildRecordTags(record),
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
                AppStrings.ongoing,
                style: AppTheme.labelMedium.copyWith(
                  color: AppColors.brandPrimary,
                  fontSize: 11,
                ),
              ),
            ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              size: 18,
              color: context.themeColors.onSurfaceTertiary,
            ),
            onSelected: (value) {
              if (value == 'edit') {
                showPeriodEditDialog(context, record, provider);
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
                      AppStrings.deleteRecordLabel,
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
