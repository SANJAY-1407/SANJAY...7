import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../app.dart';
import '../models/task_item.dart';
import '../screens/alarm_screen.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  final payload = response.payload;
  debugPrint('[AlarmService] Background notification tapped with payload: $payload');
  if (payload != null && payload.isNotEmpty) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => AlarmScreen(taskId: payload),
      ),
    );
  }
}

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
      tz.setLocalLocation(tz.getLocation('UTC'));
    } catch (e) {
      debugPrint('[AlarmService] Error setting timezone location: $e');
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        debugPrint('[AlarmService] Foreground notification tapped with payload: $payload');
        if (payload != null && payload.isNotEmpty) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => AlarmScreen(taskId: payload),
            ),
          );
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Request Android 13+ runtime notification permissions & exact alarms
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      // Explicitly create high-priority alarm notification channel
      const androidChannel = AndroidNotificationChannel(
        'task_alert_alarms_channel_v3',
        'TaskAlert High-Priority Alarms',
        description: 'High-priority sound and full-screen alarm reminders for scheduled tasks',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );
      await androidPlugin.createNotificationChannel(androidChannel);

      final notifGranted = await androidPlugin.requestNotificationsPermission();
      final exactGranted = await androidPlugin.requestExactAlarmsPermission();
      debugPrint('[AlarmService] Permissions granted - Notification: $notifGranted, Exact Alarm: $exactGranted');
    }

    // Handle App Launch from Terminated State via Notification
    final launchDetails = await _notificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final payload = launchDetails?.notificationResponse?.payload;
      debugPrint('[AlarmService] App launched from notification with payload: $payload');
      if (payload != null && payload.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => AlarmScreen(taskId: payload),
            ),
          );
        });
      }
    }

    _isInitialized = true;
    debugPrint('[AlarmService] Initialized successfully.');
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
      debugPrint('[AlarmService] Task ${task.id} is completed. Cancelling alarm ID $notificationId');
      await cancelTaskAlarm(task.id);
      return;
    }

    // Do not schedule alarms for past times
    if (task.scheduledDateTime.isBefore(DateTime.now())) {
      debugPrint('[AlarmService] Task ${task.id} scheduledDateTime ${task.scheduledDateTime} is in the past. Skipping schedule.');
      return;
    }

    // Cancel any existing alarm with this ID first to prevent duplicates
    await _notificationsPlugin.cancel(notificationId);

    const androidDetails = AndroidNotificationDetails(
      'task_alert_alarms_channel_v3',
      'TaskAlert High-Priority Alarms',
      channelDescription: 'High-priority sound and full-screen alarm reminders for scheduled tasks',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      visibility: NotificationVisibility.public,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    // Convert local DateTime directly to UTC TZDateTime to preserve exact epoch time
    final tzDateTime = tz.TZDateTime.from(
      task.scheduledDateTime.toUtc(),
      tz.getLocation('UTC'),
    );

    debugPrint('[AlarmService] Scheduling alarm for task ID "${task.id}" ("${task.title}"):');
    debugPrint('  - Target Local Scheduled Time: ${task.scheduledDateTime}');
    debugPrint('  - Device Current Local Time:  ${DateTime.now()}');
    debugPrint('  - Target UTC TZDateTime:      $tzDateTime');
    debugPrint('  - Notification ID:            $notificationId');

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
      debugPrint('[AlarmService] Successfully scheduled exact alarm ID $notificationId');
    } catch (e, stack) {
      debugPrint('[AlarmService] Exact alarm schedule failed: $e\n$stack');
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
        debugPrint('[AlarmService] Successfully scheduled fallback inexact alarm ID $notificationId');
      } catch (err, stackTrace) {
        debugPrint('[AlarmService] Fallback inexact alarm schedule failed: $err\n$stackTrace');
      }
    }
  }

  /// Cancel a pending task alarm by task ID
  Future<void> cancelTaskAlarm(String taskId) async {
    if (!_isInitialized) {
      await init();
    }
    final notificationId = _getNotificationId(taskId);
    await _notificationsPlugin.cancel(notificationId);
    debugPrint('[AlarmService] Cancelled notification ID $notificationId for task $taskId');
  }

  /// Reconcile all tasks on app startup
  Future<void> reconcileAllAlarms(List<TaskItem> tasks) async {
    if (!_isInitialized) {
      await init();
    }

    final now = DateTime.now();
    debugPrint('[AlarmService] Reconciling alarms for ${tasks.length} total tasks...');

    for (final task in tasks) {
      if (task.isCompleted || task.scheduledDateTime.isBefore(now)) {
        await cancelTaskAlarm(task.id);
      } else {
        await scheduleTaskAlarm(task);
      }
    }
  }
}
