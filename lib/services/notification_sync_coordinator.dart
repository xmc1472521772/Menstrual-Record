import 'package:flutter/foundation.dart';
import '../database/settings_dao.dart';
import '../services/notification_service.dart';
import '../utils/date_utils.dart';

/// 通知同步协调器（D3 职责拆分）。
///
/// 从 [PeriodProvider] 迁出的三路通知同步副作用：
/// - 经期预告提醒（ID 0，预测日前 N 天单次）
/// - 经期每日记录提醒（ID 1，经期中每天重复）
/// - 排卵日提示（ID 2，排卵日当天单次）
///
/// 拆分动机：PeriodProvider 只保留「数据状态」职责，通知调度这一
/// platform-channel 副作用集中到本类，可独立 mock/测试；Provider 通过
/// [syncAll] 委托调用，公开 API 与去重语义（1.34.0 通知架构）完全不变。
///
/// 与旧实现的一致性约定：
/// - 三个子同步各自维护去重状态、互不短路；
/// - [_syncChain] 串行化防并发重复调度；
/// - 禁止 cancelAll，一律按 ID 精确取消；
/// - 所有异常内部吞并（fire-and-forget 安全）。
class NotificationSyncCoordinator {
  final SettingsDao _settingsDao;

  /// Allows injecting a [SettingsDao] for testing.
  NotificationSyncCoordinator({SettingsDao? settingsDao})
      : _settingsDao = settingsDao ?? SettingsDao();

  /// 上一次真正下发到通知插件的预测日期。
  /// `zonedSchedule` 是跨进程调用（十毫秒级），预测日期未变时不必重复调度。
  DateTime? _lastScheduledPrediction;

  /// 上一次调度经期预告提醒时的参数快照（"$reminderDays|$reminderHour"）。
  /// 用户在设置页修改提前天数/提醒时间后，即使预测日期未变也需重排。
  String? _lastScheduledReminderParams;

  /// 上一次同步每日记录提醒时的状态快照（"$enabled|$ongoing|$hour"）。
  String? _lastDailyLogState;

  /// 上一次同步排卵提醒时的状态快照（"$enabled|$ovulDayKey|$hour"）。
  String? _lastOvulationState;

  /// 串行化同步链：并发调用共享同一执行链。数据变更路径是 fire-and-forget
  /// 调用，设置页又可能在任意时刻显式调用——两次并发执行若都穿过「读设置
  /// → 比对去重键」的异步间隙，会造成同一提醒重复调度。链式串行后，后一次
  /// 执行总在前一次完成后运行，前一次写入的去重键即可短路后一次。
  Future<void> _syncChain = Future<void>.value();

  /// 同步全部提醒通知到当前数据/设置状态。
  ///
  /// [predictedNextPeriod]：当前周期预测的下次经期开始日（null 表示无预测）；
  /// [ovulationDay]：当前周期的排卵日（由预测结果派生，可为 null）；
  /// [hasOngoing]：是否存在进行中的经期。
  ///
  /// Safe to call without `await`: all failures are swallowed internally.
  Future<void> syncAll({
    required DateTime? predictedNextPeriod,
    required DateTime? ovulationDay,
    required bool hasOngoing,
  }) {
    _syncChain = _syncChain.then((_) async {
      await _syncPeriodReminder(predictedNextPeriod);
      await _syncDailyLogReminder(hasOngoing);
      await _syncOvulationReminder(ovulationDay);
    });
    return _syncChain;
  }

  /// 子同步 1：经期预告提醒。
  ///
  /// 依赖预测结果；无预测（无任何记录）时按 ID 精确取消残留提醒，
  /// 避免过期闹钟误弹（不能用 cancelAll —— 会误伤每日/排卵提醒）。
  Future<void> _syncPeriodReminder(DateTime? predicted) async {
    if (predicted == null) {
      final changed =
          _lastScheduledPrediction != null ||
              _lastScheduledReminderParams != null;
      _lastScheduledPrediction = null;
      _lastScheduledReminderParams = null;
      if (changed) {
        try {
          await NotificationService().cancel(
              NotificationService.periodReminderNotificationId);
        } catch (e) {
          debugPrint('Error cancelling stale reminder: $e');
        }
      }
      return;
    }

    try {
      final reminderDays = await _settingsDao.getReminderDays();
      final reminderHour = await _settingsDao.getReminderHour();

      // 预测日期与提醒参数均未变化则跳过重复调度（zonedSchedule 需要跨
      // 进程调用）。日期比较复用 [needsReschedule]（T9 纯函数抽取）。
      final paramsKey = '$reminderDays|$reminderHour';
      if (!needsReschedule(_lastScheduledPrediction, predicted) &&
          _lastScheduledReminderParams == paramsKey) {
        return;
      }
      _lastScheduledPrediction = predicted;
      _lastScheduledReminderParams = paramsKey;

      await NotificationService().schedulePeriodReminder(
        predictedDate: predicted,
        reminderDays: reminderDays,
        reminderHour: reminderHour,
      );
    } catch (e) {
      debugPrint('Error scheduling reminder: $e');
    }
  }

  /// 子同步 2：经期每日记录提醒。
  ///
  /// 经期进行中且开关开启时调度每日重复通知；经期结束或开关关闭时
  /// 取消。去重键覆盖「开关 + 经期状态 + 提醒时刻」三元组——仅有
  /// 经期状态变化（如经期结束但预测日期未变）时也会正确取消。
  Future<void> _syncDailyLogReminder(bool ongoing) async {
    try {
      final enabled =
          (await _settingsDao.getValue('reminder_period_daily') ?? '1') == '1';
      final reminderHour = await _settingsDao.getReminderHour();

      final stateKey = '$enabled|$ongoing|$reminderHour';
      if (_lastDailyLogState == stateKey) return;
      _lastDailyLogState = stateKey;

      await NotificationService().syncDailyLogReminder(
        enabled: enabled,
        isPeriodOngoing: ongoing,
        reminderHour: reminderHour,
      );
    } catch (e) {
      debugPrint('Error syncing daily log reminder: $e');
    }
  }

  /// 子同步 3：排卵日提示。
  ///
  /// 排卵日由预测结果派生（下次预测经期前 14 天）；开关关闭或无预测时
  /// 取消已有提醒。去重键覆盖「开关 + 排卵日 + 提醒时刻」三元组。
  Future<void> _syncOvulationReminder(DateTime? ovulationDay) async {
    try {
      final enabled =
          (await _settingsDao.getValue('reminder_ovulation') ?? '1') == '1';
      final reminderHour = await _settingsDao.getReminderHour();

      final ovulKey =
          ovulationDay == null ? -1 : AppDateUtils.dayKey(ovulationDay);
      final stateKey = '$enabled|$ovulKey|$reminderHour';
      if (_lastOvulationState == stateKey) return;
      _lastOvulationState = stateKey;

      await NotificationService().syncOvulationReminder(
        enabled: enabled,
        ovulationDate: ovulationDay,
        reminderHour: reminderHour,
      );
    } catch (e) {
      debugPrint('Error syncing ovulation reminder: $e');
    }
  }
}
