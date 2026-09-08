import '../constants/app_strings.dart';
import '../models/period_record.dart';
import 'date_utils.dart';

/// 校验「添加经期记录」的候选区间，返回错误提示；null 表示通过。
///
/// 规则（与编辑记录对话框的隔离保护口径一致：两条记录不能共享任何一天）：
/// 1. 结束日期不能早于开始日期（UI 已联动保证，此处防御性兜底）；
/// 2. 起止日期都不能晚于 [today] —— 未来日期的记录尚未发生，
///    会污染周期差分与预测计算；
/// 3. 区间不能与任何已有记录重叠。进行中的经期视为占用
///    [开始日, 今天]；异常数据（已结束但缺结束日）按保守策略同样视为占用到今天。
///    重叠记录会破坏周期差分计算与编辑对话框「前文/后文隔离」的前提。
String? validateNewPeriodRange({
  required DateTime start,
  required DateTime end,
  required DateTime today,
  required List<PeriodRecord> records,
}) {
  if (end.isBefore(start)) return AppStrings.endDateCannotBeBeforeStart;
  if (start.isAfter(today) || end.isAfter(today)) {
    return AppStrings.dateCannotBeFuture;
  }

  final startDay = AppDateUtils.startOfDay(start);
  final endDay = AppDateUtils.startOfDay(end);
  for (final record in records) {
    final recStart = AppDateUtils.startOfDay(record.startDateTime);
    final DateTime recEnd;
    if (record.isOngoing) {
      recEnd = today;
    } else {
      final e = record.endDateTime;
      // 数据异常兜底：已结束却缺结束日 → 保守视为占用到今天
      recEnd = e != null ? AppDateUtils.startOfDay(e) : today;
    }
    // 共享任意一天即重叠；相邻（前段结束日的次日，或结束日早于后段开始日的前一天）允许
    if (!endDay.isBefore(recStart) && !startDay.isAfter(recEnd)) {
      return AppStrings.dateRangeOverlap;
    }
  }
  return null;
}

/// 经期长度异常提示（与编辑记录对话框口径一致：<2 天偏短、>10 天偏长）。
/// 返回警告文案；null 表示长度正常。异常不阻止保存，由 UI 要求二次确认。
String? periodLengthWarning(int days) {
  if (days < 2) return '经期仅$days天，时长偏短，确认是否正确？';
  if (days > 10) return '经期$days天，时长偏长，确认是否正确？';
  return null;
}
