import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // ─── 通知 ID（一个功能一个固定 ID，取消时按 ID 精确取消）─────────
  /// 经期预告提醒（预测日前 N 天，单次）。
  static const int periodReminderNotificationId = 0;

  /// 经期每日记录提醒（经期中每天同一时刻，每日重复）。
  static const int dailyLogNotificationId = 1;

  /// 排卵日提示（排卵日当天，单次）。
  static const int ovulationReminderNotificationId = 2;

  bool _tzInitialized = false;

  /// [initialize] 是否已被调用（同步置位，见方法首行）。
  bool _initializeStarted = false;

  /// [initialize] 完成信号。
  ///
  /// `schedulePeriodReminder` 依赖 `tz.local` 已正确设置；若不等它完成，
  /// `tz.TZDateTime.local` 会退回 UTC，通知被排到错误的绝对时刻。
  final Completer<void> _ready = Completer<void>();

  /// 调度前确保初始化完成。initialize() 从未被调用时（如单元测试）直接放行。
  Future<void> _ensureReady() async {
    if (_initializeStarted && !_ready.isCompleted) {
      await _ready.future;
    }
  }

  Future<void> initialize() async {
    _initializeStarted = true;
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const initSettings = InitializationSettings(
        android: androidSettings,
      );

      await _notifications.initialize(settings: initSettings);

      // Initialize timezone data (idempotent)
      if (!_tzInitialized) {
        tz.initializeTimeZones();
        // 尝试获取系统时区名称并设置 local location
        // 之前未调用 setLocalLocation，导致 tz.local 恒为 UTC，
        // 通知时间被排到错误的绝对时刻。
        try {
          final localTimeZone = await FlutterTimezone.getLocalTimezone();
          final location = tz.getLocation(localTimeZone);
          tz.setLocalLocation(location);
          debugPrint('Timezone set to: ${tz.local.name}');
        } catch (e) {
          debugPrint('Failed to set local timezone: $e');
        }
        _tzInitialized = true;
      }

      await _requestPermissions();
    } finally {
      // 无论成功与否都要放行等待者，避免调度流程永久挂起
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  Future<void> _requestPermissions() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestNotificationsPermission();
    }
  }

  /// Schedules a reminder notification for the predicted next period.
  ///
  /// [predictedDate] is the predicted start date of the next period.
  /// [reminderDays] is how many days in advance to notify.
  /// [reminderHour] is the hour of day (0-23) to fire the notification.
  ///
  /// 只取消/调度本通道（ID 0）——每日提醒（ID 1）与排卵提醒（ID 2）
  /// 由 [syncDailyLogReminder] / [syncOvulationReminder] 独立管理，
  /// 互不影响。
  Future<void> schedulePeriodReminder({
    required DateTime predictedDate,
    required int reminderDays,
    required int reminderHour,
  }) async {
    // 等待时区初始化完成，防止通知被排到错误的绝对时刻
    await _ensureReady();

    final scheduledDate = DateTime(
      predictedDate.year,
      predictedDate.month,
      predictedDate.day,
      reminderHour,
      0,
    ).subtract(Duration(days: reminderDays));

    final now = DateTime.now();
    if (scheduledDate.isBefore(now)) {
      await cancel(periodReminderNotificationId);
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'period_reminder',
      '经期提醒',
      channelDescription: '经期来临提醒通知',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(
      android: androidDetails,
    );

    // 设置了 local location 后直接用 TZDateTime.local 构造正确时刻。
    final tzDateTime = tz.TZDateTime.local(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      scheduledDate.hour,
      scheduledDate.minute,
    );

    await _notifications.zonedSchedule(
      id: periodReminderNotificationId,
      title: '经期提醒',
      body: '预计 $reminderDays 天后将来临，请做好准备',
      scheduledDate: tzDateTime,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    debugPrint('[notify] reminder scheduled: $tzDateTime (本地 $scheduledDate)');
  }

  /// 同步经期每日记录提醒的开关状态（ID 1）。
  ///
  /// [enabled] 为 true 且当前处于经期中时，调度每日重复通知（每天
  /// [reminderHour] 点触发，`matchDateTimeComponents: time` 实现跨日
  /// 重复）；否则取消该通知。重复调用安全（幂等）。
  Future<void> syncDailyLogReminder({
    required bool enabled,
    required bool isPeriodOngoing,
    required int reminderHour,
  }) async {
    await _ensureReady();
    if (!enabled || !isPeriodOngoing) {
      await cancel(dailyLogNotificationId);
      return;
    }

    // 每日重复通知：scheduledDate 取今天或明天的 reminderHour 时刻
    // （必须是未来时刻），配合 matchDateTimeComponents 每天重复。
    final now = DateTime.now();
    var firstFire = DateTime(now.year, now.month, now.day, reminderHour, 0);
    if (!firstFire.isAfter(now)) {
      firstFire = firstFire.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'period_daily_log',
      '经期记录提醒',
      channelDescription: '经期期间每天提醒记录当日状态',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const details = NotificationDetails(android: androidDetails);

    final tzDateTime = tz.TZDateTime.local(
      firstFire.year,
      firstFire.month,
      firstFire.day,
      firstFire.hour,
      firstFire.minute,
    );

    await _notifications.zonedSchedule(
      id: dailyLogNotificationId,
      title: '经期记录提醒',
      body: '今天处于经期，记得记录今日经量与身体状态',
      scheduledDate: tzDateTime,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    debugPrint('[notify] daily log reminder scheduled: $tzDateTime');
  }

  /// 同步排卵日提示的开关状态（ID 2）。
  ///
  /// [enabled] 为 true 且 [ovulationDate] 非空时，在排卵日当天
  /// [reminderHour] 点调度单次提醒；排卵日已过或关闭时取消。
  /// [ovulationDate] 为 null 表示无预测数据，仅取消。
  Future<void> syncOvulationReminder({
    required bool enabled,
    required DateTime? ovulationDate,
    required int reminderHour,
  }) async {
    await _ensureReady();
    if (!enabled || ovulationDate == null) {
      await cancel(ovulationReminderNotificationId);
      return;
    }

    final scheduledDate = DateTime(
      ovulationDate.year,
      ovulationDate.month,
      ovulationDate.day,
      reminderHour,
      0,
    );

    final now = DateTime.now();
    if (!scheduledDate.isAfter(now)) {
      await cancel(ovulationReminderNotificationId);
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'ovulation_reminder',
      '排卵期提示',
      channelDescription: '排卵日当天提醒',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const details = NotificationDetails(android: androidDetails);

    final tzDateTime = tz.TZDateTime.local(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      scheduledDate.hour,
      scheduledDate.minute,
    );

    await _notifications.zonedSchedule(
      id: ovulationReminderNotificationId,
      title: '排卵期提示',
      body: '今天是预测排卵日，请关注身体变化',
      scheduledDate: tzDateTime,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    debugPrint('[notify] ovulation reminder scheduled: $tzDateTime');
  }

  Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'period_reminder',
      '经期提醒',
      channelDescription: '经期来临提醒通知',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(
      android: androidDetails,
    );

    await _notifications.show(
      id: periodReminderNotificationId,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  /// 按 ID 取消单个通知（不影响其他通道的已排通知）。
  Future<void> cancel(int id) async {
    await _notifications.cancel(id: id);
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}

