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

  static const int _reminderNotificationId = 0;
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
  Future<void> schedulePeriodReminder({
    required DateTime predictedDate,
    required int reminderDays,
    required int reminderHour,
  }) async {
    // 等待时区初始化完成，防止通知被排到错误的绝对时刻
    await _ensureReady();
    await cancelAll();

    final scheduledDate = DateTime(
      predictedDate.year,
      predictedDate.month,
      predictedDate.day,
      reminderHour,
      0,
    ).subtract(Duration(days: reminderDays));

    final now = DateTime.now();
    if (scheduledDate.isBefore(now)) return;

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
      id: _reminderNotificationId,
      title: '经期提醒',
      body: '预计 $reminderDays 天后将来临，请做好准备',
      scheduledDate: tzDateTime,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    debugPrint('[notify] reminder scheduled: $tzDateTime (本地 $scheduledDate)');
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
      id: _reminderNotificationId,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}

