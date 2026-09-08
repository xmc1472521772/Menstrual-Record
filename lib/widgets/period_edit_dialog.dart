import 'package:flutter/material.dart';

import '../models/period_record.dart';
import '../providers/period_provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../constants/app_theme.dart';

/// 编辑经期记录对话框（P1-6 从 record_screen.dart 迁出，行为不变）。
///
/// 包含：起止日期选择（带前后记录隔离边界）、进行中状态切换、
/// 心情/症状/备注编辑、日期冲突校验与异常经期长度二次确认。
///
/// [context] 为调用方页面的 context（SnackBar 反馈用），
/// [record] 为待编辑记录，[provider] 用于读取相邻记录与写回更新。
void showPeriodEditDialog(
  BuildContext context,
  PeriodRecord record,
  PeriodProvider provider,
) {
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
  final prevRecord = (currentIndex >= 0 && currentIndex < records.length - 1)
      ? records[currentIndex + 1]
      : null;
  final nextRecord = (currentIndex > 0) ? records[currentIndex - 1] : null;

  // 前文记录的结束日期（开始日期不能早于此日期 + 1 天）
  final prevEndDate = prevRecord?.endDateTime;
  // 后文记录的开始日期（结束日期不能晚于此日期 - 1 天）
  final nextStartDate = nextRecord?.startDateTime;

  DateTime editStart = record.startDateTime;
  DateTime? editEnd = record.endDateTime;
  bool isOngoing = record.isOngoing;

  // ── 症状/心情/备注 ──
  String? editMood = record.mood;
  List<String> editSymptoms = record.symptoms != null
      ? record.symptoms!.split(',').where((s) => s.isNotEmpty).toList()
      : [];
  String editNotes = record.notes ?? '';
  // 备注输入控制器：只创建一次，dialog 关闭时 dispose。
  // 原先在 TextField 处内联 new，每次重建都会丢光标/输入状态。
  final notesController = TextEditingController(text: editNotes);

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
  final startLastDate = nextStartDate ?? DateTime(editStart.year + 1);

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
                        return buildPeriodDatePickerTheme(context, child);
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
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
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
                      lastDate: endLastDate ?? DateTime(editStart.year + 1),
                      locale: const Locale('zh', 'CN'),
                      builder: (context, child) {
                        return buildPeriodDatePickerTheme(context, child);
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
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
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
                              ? AppStrings.ongoing
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
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                    ),
                    child: Text(
                      AppStrings.clearEndDateHint,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ),
                ],
                // ── 心情选择 ──
                const SizedBox(height: AppDimens.spacingLg),
                Text(
                  AppStrings.mood,
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
                  AppStrings.symptoms,
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
                  AppStrings.notes,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppColors.inkSecondary,
                  ),
                ),
                const SizedBox(height: AppDimens.spacingSm),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: AppStrings.notesHint,
                    hintStyle: AppTheme.bodySmall.copyWith(
                      color: AppColors.inkTertiary,
                    ),
                    filled: true,
                    fillColor: ctx.themeColors.surfaceTile,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
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
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
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
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
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
                child: const Text(AppStrings.confirmWarning),
              ),
            ElevatedButton(
              // 没有结束日期、不是进行中、有冲突错误、或需要确认异常时禁用
              onPressed: canSave && (!needsWarningConfirm)
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
                        mood: editMood,
                        symptoms: editSymptoms.isEmpty
                            ? null
                            : editSymptoms.join(','),
                        notes: editNotes.isEmpty ? null : editNotes,
                        clearEndDate: isOngoing,
                        clearPeriodLength: isOngoing,
                        clearMood: editMood == null,
                        clearSymptoms: editSymptoms.isEmpty,
                        clearNotes: editNotes.isEmpty,
                      );
                      final success = await provider.updateRecord(updated);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      if (!context.mounted) return;
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
  ).whenComplete(notesController.dispose);
}

/// 构建编辑/添加记录共用的 DatePicker 主题，使弹出的日历与项目
/// "温暖陶土色"设计语言统一（P1-6 从 record_screen.dart 迁出，
/// 编辑对话框与添加卡片日期选择共用）。
///
/// 优化点：
/// - 使用项目品牌色（陶土色 `brandPrimary`）替代默认蓝色调
/// - 圆角使用 `AppDimens.radiusMd`（12px）与卡片圆角保持一致
/// - 选中日期使用实心陶土色圆角方块
/// - 头部年份/月份使用 `AppTheme.titleLarge` 样式
/// - 日期数字使用 `AppTheme.bodyMedium` 统一字号
/// - 暖中性背景色（`surfaceCard` / `surfaceTile`）适配明暗主题
/// - 头部切换箭头使用品牌色
Widget buildPeriodDatePickerTheme(BuildContext context, Widget? child) {
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
          foregroundColor:
              WidgetStateProperty.all(themeColors.onSurfaceSecondary),
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
