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
  debugPrint(
      '[AlarmService] Background notification tapped with payload: $payload');
  if (payload != null && payload.isNotEmpty) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => AlarmScreen(taskId: payload),
      ),
    );
  }
}

class AlarmPermissionStatus {
  final bool? notificationsEnabled;
  final bool? exactAlarmsEnabled;
  final bool? fullScreenIntentEnabled;

  const AlarmPermissionStatus({
    required this.notificationsEnabled,
    required this.exactAlarmsEnabled,
    required this.fullScreenIntentEnabled,
  });

  @override
  String toString() {
    return 'notifications=$notificationsEnabled, '
        'exactAlarms=$exactAlarmsEnabled, '
        'fullScreenIntent=$fullScreenIntentEnabled';
  }
}

class AlarmService {
  static final AlarmService instance = AlarmService._init();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  AlarmPermissionStatus? _permissionStatus;

  AlarmService._init();

  AlarmPermissionStatus? get permissionStatus => _permissionStatus;

  /// Initialize notification settings, timezones, and permission requests
  Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('UTC'));
    } catch (e) {
      debugPrint('[AlarmService] Error setting timezone location: $e');
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        debugPrint(
            '[AlarmService] Foreground notification tapped with payload: $payload');
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

    // Request Android 13+ notification access, exact alarms, and full-screen
    // intent access. These permissions are independently controlled on real
    // devices, especially on Android 13 and newer.
    final androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      // Explicitly create high-priority alarm notification channel
      const androidChannel = AndroidNotificationChannel(
        'task_alert_alarms_channel_v3',
        'TaskAlert High-Priority Alarms',
        description:
            'High-priority sound and full-screen alarm reminders for scheduled tasks',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );
      await androidPlugin.createNotificationChannel(androidChannel);

      final notifGranted = await androidPlugin.requestNotificationsPermission();
      final exactGranted = await androidPlugin.requestExactAlarmsPermission();
      bool? fullScreenGranted;
      try {
        fullScreenGranted =
            await androidPlugin.requestFullScreenIntentPermission();
      } catch (e, stack) {
        debugPrint(
            '[AlarmService] Full-screen intent permission check failed: $e\n$stack');
      }

      final notificationsEnabled =
          await androidPlugin.areNotificationsEnabled();
      final exactAlarmsEnabled =
          await androidPlugin.canScheduleExactNotifications();
      _permissionStatus = AlarmPermissionStatus(
        notificationsEnabled: notificationsEnabled ?? notifGranted,
        exactAlarmsEnabled: exactAlarmsEnabled ?? exactGranted,
        fullScreenIntentEnabled: fullScreenGranted,
      );

      debugPrint(
          '[AlarmService] Android capability status: $_permissionStatus');
      final channels = await androidPlugin.getNotificationChannels();
      final alarmChannel = channels?.where((c) => c.id == _alarmChannelId);
      if (alarmChannel != null && alarmChannel.isNotEmpty) {
        final channel = alarmChannel.first;
        debugPrint(
            '[AlarmService] Alarm channel ${channel.id}: importance=${channel.importance}, playSound=${channel.playSound}, vibration=${channel.enableVibration}');
      }
    }

    // Handle App Launch from Terminated State via Notification
    final launchDetails =
        await _notificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final payload = launchDetails?.notificationResponse?.payload;
      debugPrint(
          '[AlarmService] App launched from notification with payload: $payload');
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

  static const String _alarmChannelId = 'task_alert_alarms_channel_v3';

  /// Refreshes Android notification and exact-alarm capability diagnostics.
  Future<AlarmPermissionStatus?> refreshPermissionStatus() async {
    if (!_isInitialized) {
      await init();
    }

    final androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return _permissionStatus;

    final status = AlarmPermissionStatus(
      notificationsEnabled: await androidPlugin.areNotificationsEnabled(),
      exactAlarmsEnabled: await androidPlugin.canScheduleExactNotifications(),
      fullScreenIntentEnabled: _permissionStatus?.fullScreenIntentEnabled,
    );
    _permissionStatus = status;
    debugPrint('[AlarmService] Refreshed Android capability status: $status');
    return status;
  }

  /// Reopens the Android permission flows when a task cannot be scheduled.
  Future<AlarmPermissionStatus?> requestAlarmPermissions() async {
    if (!_isInitialized) {
      await init();
    }

    final androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return _permissionStatus;

    try {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
      await androidPlugin.requestFullScreenIntentPermission();
    } catch (e, stack) {
      debugPrint(
          '[AlarmService] Failed to reopen alarm permission settings: $e\n$stack');
    }
    return refreshPermissionStatus();
  }

  /// Generate a stable numeric notification ID from task ID string
  int _getNotificationId(String taskId) {
    return taskId.hashCode.abs() & 0x7FFFFFFF;
  }

  /// Schedule a notification alarm for an eligible task
  Future<bool> scheduleTaskAlarm(TaskItem task) async {
    if (!_isInitialized) {
      await init();
    }

    await refreshPermissionStatus();
    if (_permissionStatus?.notificationsEnabled == false) {
      debugPrint(
          '[AlarmService] Notifications are disabled; cannot schedule task ${task.id}.');
      return false;
    }

    final notificationId = _getNotificationId(task.id);

    // If task is completed or deleted, ensure any existing alarm is cancelled
    if (task.isCompleted) {
      debugPrint(
          '[AlarmService] Task ${task.id} is completed. Cancelling alarm ID $notificationId');
      await cancelTaskAlarm(task.id);
      return true;
    }

    // Do not schedule alarms for past times
    if (task.scheduledDateTime.isBefore(DateTime.now())) {
      debugPrint(
          '[AlarmService] Task ${task.id} scheduledDateTime ${task.scheduledDateTime} is in the past. Skipping schedule.');
      return false;
    }

    // Cancel any existing alarm with this ID first to prevent duplicates
    await _notificationsPlugin.cancel(notificationId);

    const androidDetails = AndroidNotificationDetails(
      _alarmChannelId,
      'TaskAlert High-Priority Alarms',
      channelDescription:
          'High-priority sound and full-screen alarm reminders for scheduled tasks',
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

    debugPrint(
        '[AlarmService] Scheduling alarm for task ID "${task.id}" ("${task.title}"):');
    debugPrint('  - Target Local Scheduled Time: ${task.scheduledDateTime}');
    debugPrint('  - Device Current Local Time:  ${DateTime.now()}');
    debugPrint('  - Target UTC TZDateTime:      $tzDateTime');
    debugPrint('  - Notification ID:            $notificationId');

    final exactAlarmsEnabled = _permissionStatus?.exactAlarmsEnabled;
    if (exactAlarmsEnabled == false) {
      debugPrint(
          '[AlarmService] Exact alarms are not permitted; using inexact fallback for task ${task.id}.');
    } else {
      try {
        await _notificationsPlugin.zonedSchedule(
          notificationId,
          '⏰ Task Alarm: ${task.title}',
          task.description.isNotEmpty
              ? task.description
              : 'Your task time has arrived!',
          tzDateTime,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: task.id,
        );
        debugPrint(
            '[AlarmService] Successfully scheduled exact alarm ID $notificationId');
        return true;
      } catch (e, stack) {
        debugPrint('[AlarmService] Exact alarm schedule failed: $e\n$stack');
      }
    }

    try {
      await _notificationsPlugin.zonedSchedule(
        notificationId,
        '⏰ Task Alarm: ${task.title}',
        task.description.isNotEmpty
            ? task.description
            : 'Your task time has arrived!',
        tzDateTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: task.id,
      );
      debugPrint(
          '[AlarmService] Successfully scheduled inexact fallback alarm ID $notificationId');
      return true;
    } catch (e, stack) {
      debugPrint('[AlarmService] Inexact alarm schedule failed: $e\n$stack');
      return false;
    }
  }

  /// Cancel a pending task alarm by task ID
  Future<void> cancelTaskAlarm(String taskId) async {
    if (!_isInitialized) {
      await init();
    }
    final notificationId = _getNotificationId(taskId);
    await _notificationsPlugin.cancel(notificationId);
    debugPrint(
        '[AlarmService] Cancelled notification ID $notificationId for task $taskId');
  }

  /// Reconcile all tasks on app startup
  Future<void> reconcileAllAlarms(List<TaskItem> tasks) async {
    if (!_isInitialized) {
      await init();
    }

    final now = DateTime.now();
    debugPrint(
        '[AlarmService] Reconciling alarms for ${tasks.length} total tasks...');

    for (final task in tasks) {
      if (task.isCompleted || task.scheduledDateTime.isBefore(now)) {
        await cancelTaskAlarm(task.id);
      } else {
        await scheduleTaskAlarm(task);
      }
    }
  }
}
