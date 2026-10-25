import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import '../app.dart';
import '../models/task_item.dart';
import '../screens/alarm_screen.dart';
import 'clock_alarm_service.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  final payload = response.payload;
  debugPrint(
      '[AlarmService] Background notification response received for payload: $payload');
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

  bool get canScheduleExact =>
      notificationsEnabled == true && exactAlarmsEnabled == true;

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

  static const String taskAlarmChannelId = 'task_alert_alarms_channel_v3';
  static const String clockAlarmChannelId = 'alertbox_clock_alarms_channel_v1';

  AlarmService._init();

  AlarmPermissionStatus? get permissionStatus => _permissionStatus;

  /// Initialize notification settings, timezones, channels, and launch handlers.
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
        '[AlarmService] Initializing on device timezone offset: ${deviceNow.timeZoneOffset}');

    const androidSettings = AndroidInitializationSettings('ic_stat_alertbox');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        debugPrint(
            '[AlarmService] Foreground notification response received: $payload');
        if (payload != null && payload.isNotEmpty) {
          _routePayload(payload);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      // Create high-priority task alarms channel
      const taskChannel = AndroidNotificationChannel(
        taskAlarmChannelId,
        'AlertBox High-Priority Alarms',
        description:
            'High-priority sound and full-screen alarm reminders for scheduled tasks',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );
      await androidPlugin.createNotificationChannel(taskChannel);

      // Also ensure clock alarms channel exists
      const clockChannel = AndroidNotificationChannel(
        clockAlarmChannelId,
        'AlertBox Clock Alarms',
        description:
            'High priority clock alarm alerts with full-screen triggers and alarm sound',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );
      await androidPlugin.createNotificationChannel(clockChannel);

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
    }

    // Handle App Launch from Terminated State via Notification
    final launchDetails =
        await _notificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final payload = launchDetails?.notificationResponse?.payload;
      debugPrint('[AlarmService] App launched from notification: $payload');
      if (payload != null && payload.isNotEmpty) {
        _routePayload(payload);
      }
    }

    _isInitialized = true;
    debugPrint('[AlarmService] Initialized successfully.');
  }

  void _routePayload(String payload) {
    if (payload.startsWith('clock_alarm:')) {
      final alarmId = payload.substring('clock_alarm:'.length);
      ClockAlarmService.instance.navigateToRingingScreen(alarmId);
    } else if (payload.startsWith('task_alarm:')) {
      final taskId = payload.substring('task_alarm:'.length);
      _queueAlarmNavigation(taskId);
    } else {
      _queueAlarmNavigation(payload);
    }
  }

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
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
      try {
        await androidPlugin.requestFullScreenIntentPermission();
      } catch (e, stack) {
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
      return enabled ?? false;
    } catch (e, stack) {
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

    final cleanTaskId = taskId.startsWith('task_alarm:')
        ? taskId.substring('task_alarm:'.length)
        : taskId;

    final now = DateTime.now();
    if (_lastQueuedAlarmTaskId == cleanTaskId &&
        _lastQueuedAlarmAt != null &&
        now.difference(_lastQueuedAlarmAt!) < const Duration(seconds: 4)) {
      debugPrint(
          '[AlarmService] Ignoring duplicate alarm navigation for task $cleanTaskId');
      return;
    }

    _lastQueuedAlarmTaskId = cleanTaskId;
    _lastQueuedAlarmAt = now;
    _pendingAlarmTaskId = cleanTaskId;
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
            '[AlarmService] Navigator was unavailable for alarm task $taskId');
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
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        debugPrint(
            '[AlarmService] Foreground alarm time reached for task ${task.id}');
        _queueAlarmNavigation(task.id);
      }
    });
  }

  /// Generate a stable, collision-free numeric notification ID for task reminders.
  /// Offset starts at 200,000 to cleanly segregate from Clock alarms (100,000..199,999).
  int getTaskNotificationId(String taskId) {
    final parsed = int.tryParse(taskId);
    if (parsed != null) {
      return 200000 + (parsed % 1000000000).abs();
    }
    var hash = 0x811C9DC5;
    for (final codeUnit in taskId.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x3FFFFFFF;
    }
    return 200000 + (hash % 1000000000).abs();
  }

  /// Schedule a reliable alarm reminder for an eligible task
  Future<bool> scheduleTaskAlarm(TaskItem task) async {
    if (!_isInitialized) {
      await init();
    }

    _cancelForegroundAlarmTimer(task.id);
    final notificationId = getTaskNotificationId(task.id);

    // If task is completed or reminder is disabled, cancel any existing alarm
    if (task.isCompleted || !task.reminderEnabled) {
      debugPrint(
          '[AlarmService] Task ${task.id} (completed=${task.isCompleted}, reminderEnabled=${task.reminderEnabled}). Cancelling alarm ID $notificationId');
      await cancelTaskAlarm(task.id);
      return true;
    }

    // Do not schedule alarms for past times
    if (task.scheduledDateTime.isBefore(DateTime.now())) {
      debugPrint(
          '[AlarmService] Task ${task.id} scheduledDateTime ${task.scheduledDateTime} is in the past. Skipping schedule.');
      await cancelTaskAlarm(task.id);
      return false;
    }

    final permissions = await refreshPermissionStatus();
    if (permissions?.notificationsEnabled == false) {
      debugPrint(
          '[AlarmService] Notifications are disabled; cannot schedule task ${task.id}.');
      return false;
    }

    if (permissions?.exactAlarmsEnabled == false) {
      debugPrint(
          '[AlarmService] Exact alarms are not permitted; cannot schedule task ${task.id}.');
      return false;
    }

    if (permissions?.fullScreenIntentEnabled == false) {
      debugPrint(
          '[AlarmService] Full-screen intent permission is not permitted; cannot guarantee task alarm ${task.id}.');
      return false;
    }

    final fullScreenEnabled = permissions?.fullScreenIntentEnabled ?? false;

    debugPrint('[AlarmService] Scheduling exact alarm for task "${task.title}":');
    debugPrint('  - Task ID:                   ${task.id}');
    debugPrint('  - Notification ID:           $notificationId');
    debugPrint('  - Target Local Scheduled:    ${task.scheduledDateTime}');
    debugPrint('  - FullScreenIntent Enabled:  $fullScreenEnabled');

    try {
      // ClockAlarmService owns the shared Android AlarmManager-backed
      // scheduling path. Task persistence and task-specific sound playback
      // remain in this service and AlarmScreen.
      await ClockAlarmService.instance.scheduleTaskReminder(
        task,
        notificationId,
        fullScreenIntent: fullScreenEnabled,
      );

      _scheduleForegroundAlarmTimer(task);
      debugPrint(
          '[AlarmService] Alarm successfully scheduled for task ${task.id} at ${task.scheduledDateTime}');
      return true;
    } catch (e, stack) {
      debugPrint(
          '[AlarmService] Exact alarm schedule failed for task ${task.id}: $e\n$stack');
      return false;
    }
  }

  /// Cancel a pending task alarm by task ID
  Future<void> cancelTaskAlarm(String taskId) async {
    if (!_isInitialized) {
      await init();
    }
    final notificationId = getTaskNotificationId(taskId);
    _cancelForegroundAlarmTimer(taskId);
    await ClockAlarmService.instance.cancelNotification(notificationId);
    debugPrint(
        '[AlarmService] Cancelled notification ID $notificationId for task $taskId');
  }

  /// Reconcile all tasks on app startup or resume
  Future<void> reconcileAllAlarms(List<TaskItem> tasks) async {
    if (!_isInitialized) {
      await init();
    }

    final now = DateTime.now();
    debugPrint(
        '[AlarmService] Reconciling alarms for ${tasks.length} total tasks...');

    for (final task in tasks) {
      if (task.isCompleted ||
          !task.reminderEnabled ||
          task.scheduledDateTime.isBefore(now)) {
        await cancelTaskAlarm(task.id);
      } else {
        await scheduleTaskAlarm(task);
      }
    }
  }
}
