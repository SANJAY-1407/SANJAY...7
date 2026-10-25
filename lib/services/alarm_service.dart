import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../app.dart';
import '../models/task_item.dart';
import '../screens/alarm_screen.dart';
import 'clock_alarm_service.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  final payload = response.payload;
  debugPrint(
      '[AlarmService] Background notification response received for task ID: $payload');
  // This callback may run on a background isolate, where Flutter's UI
  // Navigator is not available. The main isolate receives the launch details
  // or foreground response and performs the navigation safely.
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
  static const MethodChannel _fullScreenIntentChannel =
      MethodChannel('com.example.taskalert/full_screen_intent');

  bool _isInitialized = false;
  Future<void>? _initializationFuture;
  AlarmPermissionStatus? _permissionStatus;
  final Map<String, Timer> _foregroundAlarmTimers = <String, Timer>{};
  String? _pendingAlarmTaskId;
  String? _lastQueuedAlarmTaskId;
  DateTime? _lastQueuedAlarmAt;
  bool _navigationScheduled = false;
  int _navigationAttempts = 0;

  AlarmService._init();

  AlarmPermissionStatus? get permissionStatus => _permissionStatus;

  /// Initialize notification settings, timezones, and permission diagnostics.
  Future<void> init() async {
    if (_isInitialized) return;

    final inFlight = _initializationFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final initialization = _initialize();
    _initializationFuture = initialization;
    try {
      await initialization;
    } finally {
      if (identical(_initializationFuture, initialization)) {
        _initializationFuture = null;
      }
    }
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    final deviceNow = DateTime.now();
    debugPrint(
        '[AlarmService] Initializing on device timezone ${deviceNow.timeZoneName} '
        '(${deviceNow.timeZoneOffset}). Scheduled times will be converted to UTC epochs.');

    const androidSettings = AndroidInitializationSettings('ic_stat_alertbox');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        debugPrint(
            '[AlarmService] Foreground notification response received: $payload');
        if (payload != null && payload.isNotEmpty) {
          if (payload.startsWith('clock_alarm:')) {
            final alarmId = payload.substring('clock_alarm:'.length);
            ClockAlarmService.instance.navigateToRingingScreen(alarmId);
          } else {
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (context) => AlarmScreen(taskId: payload),
              ),
            );
          }
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Create the channel during initialization, but do not launch Android
    // Settings before the first screen is visible. Exact-alarm access is a
    // special app access on Android 12+ and must be granted by the user.
    // The task screen shows the permission action when scheduling is blocked.
    final androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      // Explicitly create high-priority alarm notification channel
      const androidChannel = AndroidNotificationChannel(
        'task_alert_alarms_channel_v3',
        'AlertBox High-Priority Alarms',
        description:
            'High-priority sound and full-screen alarm reminders for scheduled tasks',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );
      await androidPlugin.createNotificationChannel(androidChannel);

      final notificationsEnabled =
          await androidPlugin.areNotificationsEnabled();
      final exactAlarmsEnabled =
          await androidPlugin.canScheduleExactNotifications();
      final fullScreenIntentEnabled = await _readFullScreenIntentAccess();
      _permissionStatus = AlarmPermissionStatus(
        notificationsEnabled: notificationsEnabled,
        exactAlarmsEnabled: exactAlarmsEnabled,
        fullScreenIntentEnabled: fullScreenIntentEnabled,
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
          '[AlarmService] App launched from notification: $payload');
      if (payload != null && payload.isNotEmpty) {
        if (payload.startsWith('clock_alarm:')) {
          final alarmId = payload.substring('clock_alarm:'.length);
          ClockAlarmService.instance.navigateToRingingScreen(alarmId);
        } else {
          _queueAlarmNavigation(payload);
        }
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
      fullScreenIntentEnabled: await _readFullScreenIntentAccess(),
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
      // These calls are intentionally made only from an explicit user action.
      // requestExactAlarmsPermission() opens the app's Alarms & reminders
      // settings page on Android 12+; it is not a normal runtime dialog.
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
      try {
        await androidPlugin.requestFullScreenIntentPermission();
      } catch (e, stack) {
        // Full-screen access is optional. A normal notification must still be
        // usable when the device or Android version does not offer this access.
        debugPrint(
            '[AlarmService] Full-screen intent permission request failed: $e\n$stack');
      }
    } catch (e, stack) {
      debugPrint(
          '[AlarmService] Failed to reopen alarm permission settings: $e\n$stack');
    }
    return refreshPermissionStatus();
  }

  Future<bool> _readFullScreenIntentAccess() async {
    try {
      final enabled = await _fullScreenIntentChannel
          .invokeMethod<bool>('canUseFullScreenIntent');
      final result = enabled ?? false;
      debugPrint(
          '[AlarmService] Full-screen intent access is ${result ? 'enabled' : 'disabled'}');
      return result;
    } catch (e, stack) {
      // If the native capability check is unavailable, use the safe fallback:
      // post a normal high-priority notification instead of requesting a
      // full-screen launch that could be suppressed by Android.
      debugPrint(
          '[AlarmService] Could not read full-screen intent access: $e\n$stack');
      return false;
    }
  }

  void _queueAlarmNavigation(String taskId) {
    if (taskId.startsWith('clock_alarm:')) {
      final alarmId = taskId.substring('clock_alarm:'.length);
      ClockAlarmService.instance.navigateToRingingScreen(alarmId);
      return;
    }

    final now = DateTime.now();
    if (_lastQueuedAlarmTaskId == taskId &&
        _lastQueuedAlarmAt != null &&
        now.difference(_lastQueuedAlarmAt!) < const Duration(seconds: 5)) {
      debugPrint(
          '[AlarmService] Ignoring duplicate alarm navigation for task $taskId');
      return;
    }

    _lastQueuedAlarmTaskId = taskId;
    _lastQueuedAlarmAt = now;
    _pendingAlarmTaskId = taskId;
    _navigationAttempts = 0;
    _scheduleAlarmNavigationDrain();
  }

  void _scheduleAlarmNavigationDrain() {
    if (_navigationScheduled || _pendingAlarmTaskId == null) return;
    _navigationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigationScheduled = false;
      _drainAlarmNavigation();
    });
  }

  void _drainAlarmNavigation() {
    final taskId = _pendingAlarmTaskId;
    if (taskId == null) return;

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      _navigationAttempts++;
      if (_navigationAttempts <= 50) {
        Timer(const Duration(milliseconds: 100),
            _scheduleAlarmNavigationDrain);
      } else {
        debugPrint(
            '[AlarmService] Navigator was unavailable after waiting for alarm task $taskId');
        _pendingAlarmTaskId = null;
      }
      return;
    }

    _pendingAlarmTaskId = null;
    debugPrint('[AlarmService] Opening alarm screen for task ID $taskId');
    unawaited(navigator.push(
      MaterialPageRoute(
        builder: (context) => AlarmScreen(taskId: taskId),
      ),
    ));
  }

  void _cancelForegroundAlarmTimer(String taskId) {
    _foregroundAlarmTimers.remove(taskId)?.cancel();
  }

  void _scheduleForegroundAlarmTimer(TaskItem task) {
    _cancelForegroundAlarmTimer(task.id);
    final delay = task.scheduledDateTime.difference(DateTime.now());
    if (delay.isNegative) return;

    _foregroundAlarmTimers[task.id] = Timer(delay, () {
      _foregroundAlarmTimers.remove(task.id);
      // Android intentionally keeps the user in the current activity while
      // the device is being actively used. The full-screen notification path
      // handles background/locked launches; this timer covers the app-open
      // case without trying to bypass Android's background-launch rules.
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        debugPrint(
            '[AlarmService] Foreground alarm time reached for task ${task.id}');
        _queueAlarmNavigation(task.id);
      }
    });
  }

  /// Generate a stable numeric notification ID from task ID string
  int _getNotificationId(String taskId) {
    // Dart's String.hashCode is not a persistence contract across process
    // launches. Task IDs are millisecond timestamps, so use the timestamp
    // directly and fall back to a deterministic code-unit hash for old data.
    final parsed = int.tryParse(taskId);
    if (parsed != null) {
      return parsed & 0x7FFFFFFF;
    }

    var hash = 0x811C9DC5;
    for (final codeUnit in taskId.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return hash == 0 ? 1 : hash;
  }

  /// Schedule a notification alarm for an eligible task
  Future<bool> scheduleTaskAlarm(TaskItem task) async {
    if (!_isInitialized) {
      await init();
    }

    _cancelForegroundAlarmTimer(task.id);
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

    final androidDetails = AndroidNotificationDetails(
      _alarmChannelId,
      'AlertBox High-Priority Alarms',
      channelDescription:
          'High-priority sound and full-screen alarm reminders for scheduled tasks',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: _permissionStatus?.fullScreenIntentEnabled == true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      visibility: NotificationVisibility.public,
      icon: 'ic_stat_alertbox',
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    // DateTime values created by the date/time pickers are device-local. Turn
    // that instant into an explicit UTC TZDateTime. Android AlarmManager uses
    // the UTC epoch, so this preserves the selected local wall-clock time on
    // every device timezone without relying on an abbreviated timezone name.
    final scheduledUtc = task.scheduledDateTime.toUtc();
    final tzDateTime = tz.TZDateTime.utc(
      scheduledUtc.year,
      scheduledUtc.month,
      scheduledUtc.day,
      scheduledUtc.hour,
      scheduledUtc.minute,
      scheduledUtc.second,
      scheduledUtc.millisecond,
      scheduledUtc.microsecond,
    );

    debugPrint('[AlarmService] Scheduling alarm for task ID "${task.id}":');
    debugPrint('  - Target Local Scheduled Time: ${task.scheduledDateTime}');
    debugPrint('  - Device Current Local Time:  ${DateTime.now()}');
    debugPrint('  - Target UTC TZDateTime:      $tzDateTime');
    debugPrint('  - Target UTC epoch millis:    ${tzDateTime.millisecondsSinceEpoch}');
    debugPrint('  - Notification ID:            $notificationId');

    final exactAlarmsEnabled = _permissionStatus?.exactAlarmsEnabled;
    if (exactAlarmsEnabled == false) {
      debugPrint(
          '[AlarmService] Exact alarms are not permitted; refusing to report task ${task.id} as scheduled.');
      return false;
    }

    try {
      await _notificationsPlugin.zonedSchedule(
        notificationId,
        'â° Task Alarm: ${task.title}',
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

      final pending = await _notificationsPlugin.pendingNotificationRequests();
      final registered = pending.any((request) =>
          request.id == notificationId && request.payload == task.id);
      debugPrint(
          '[AlarmService] Exact alarm request ${registered ? 'registered' : 'not found'} '
          'for task ${task.id}; pending request count=${pending.length}.');
      if (!registered) {
        debugPrint(
            '[AlarmService] Exact schedule verification failed for task ${task.id}.');
        return false;
      }
      _scheduleForegroundAlarmTimer(task);
      return true;
    } catch (e, stack) {
      debugPrint('[AlarmService] Exact alarm schedule failed for task ${task.id}: $e\n$stack');
      return false;
    }
  }

  /// Cancel a pending task alarm by task ID
  Future<void> cancelTaskAlarm(String taskId) async {
    if (!_isInitialized) {
      await init();
    }
    final notificationId = _getNotificationId(taskId);
    _cancelForegroundAlarmTimer(taskId);
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
