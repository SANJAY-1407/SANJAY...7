import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../app.dart';
import '../models/task_item.dart';
import '../screens/alarm_screen.dart';

class AlarmService {
  static final AlarmService instance = AlarmService._init();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  AlarmService._init();

  /// Initialize notification settings, timezones, and permission requests
  Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.local);
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          // Navigate to AlarmScreen when notification is tapped
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => AlarmScreen(taskId: payload),
            ),
          );
        }
      },
    );

    // Request Android 13+ runtime notification permissions
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }

    _isInitialized = true;
  }

  /// Generate a stable numeric notification ID from task ID string
  int _getNotificationId(String taskId) {
    return taskId.hashCode.abs() & 0x7FFFFFFF;
  }

  /// Schedule a notification alarm for an eligible task
  Future<void> scheduleTaskAlarm(TaskItem task) async {
    if (!_isInitialized) {
      await init();
    }

    final notificationId = _getNotificationId(task.id);

    // If task is completed or deleted, ensure any existing alarm is cancelled
    if (task.isCompleted) {
      await cancelTaskAlarm(task.id);
      return;
    }

    // Do not schedule alarms for past times
    if (task.scheduledDateTime.isBefore(DateTime.now())) {
      return;
    }

    // Cancel any existing alarm with this ID first to prevent duplicates
    await _notificationsPlugin.cancel(notificationId);

    const androidDetails = AndroidNotificationDetails(
      'task_alert_alarms_channel',
      'TaskAlert Alarms & Reminders',
      channelDescription: 'High-priority reminders and alarms for your scheduled tasks',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    final tzDateTime = tz.TZDateTime.from(task.scheduledDateTime, tz.local);

    try {
      await _notificationsPlugin.zonedSchedule(
        notificationId,
        '⏰ Task Alarm: ${task.title}',
        task.description.isNotEmpty ? task.description : 'Your task time has arrived!',
        tzDateTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: task.id,
      );
    } catch (e) {
      try {
        await _notificationsPlugin.zonedSchedule(
          notificationId,
          '⏰ Task Alarm: ${task.title}',
          task.description.isNotEmpty ? task.description : 'Your task time has arrived!',
          tzDateTime,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: task.id,
        );
      } catch (_) {}
    }
  }

  /// Cancel a pending task alarm by task ID
  Future<void> cancelTaskAlarm(String taskId) async {
    if (!_isInitialized) {
      await init();
    }
    final notificationId = _getNotificationId(taskId);
    await _notificationsPlugin.cancel(notificationId);
  }

  /// Reconcile all tasks on app startup
  Future<void> reconcileAllAlarms(List<TaskItem> tasks) async {
    if (!_isInitialized) {
      await init();
    }

    for (final task in tasks) {
      if (task.isCompleted || task.scheduledDateTime.isBefore(DateTime.now())) {
        await cancelTaskAlarm(task.id);
      } else {
        await scheduleTaskAlarm(task);
      }
    }
  }
}
