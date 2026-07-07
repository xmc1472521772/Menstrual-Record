import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const int _reminderNotificationId = 0;
  bool _tzInitialized = false;

  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);

    // Initialize timezone data (idempotent)
    if (!_tzInitialized) {
      tz.initializeTimeZones();
      // Try to set local timezone; fall back to UTC if detection fails
      try {
        debugPrint('Timezone initialized: ${tz.local.name}');
      } catch (_) {
        // timezone lookup may fail on some platforms; UTC is the fallback
      }
      _tzInitialized = true;
    }

    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestNotificationsPermission();
    }
    final ios = _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
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

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Convert to TZDateTime in the local timezone
    final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);

    await _notifications.zonedSchedule(
      _reminderNotificationId,
      '经期提醒',
      '预计 $reminderDays 天后将来临，请做好准备',
      tzDateTime,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null,
    );
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

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(_reminderNotificationId, title, body, details);
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}

