import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../app.dart';
import '../models/clock_alarm.dart';
import '../screens/clock_alarm_ringing_screen.dart';
import 'alarm_service.dart';
import 'clock_alarm_database_helper.dart';

/// Dedicated service for scheduling and managing mobile Clock-Style alarms.
/// Uses a separate notification channel, dedicated ID space, and full-screen intent.
class ClockAlarmService {
  static final ClockAlarmService instance = ClockAlarmService._init();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'alertbox_clock_alarms_channel_v1';
  static const String channelName = 'AlertBox Clock Alarms';
  static const String channelDescription =
      'High priority clock alarm alerts with full-screen triggers and alarm sound';

  bool _isInitialized = false;
  Future<void>? _initFuture;
  final Map<String, Timer> _foregroundTimers = <String, Timer>{};
  String? _pendingAlarmId;
  String? _lastNavigatedAlarmId;
  DateTime? _lastNavigatedAt;
  int _navigationAttempts = 0;
  bool _navigationScheduled = false;

  ClockAlarmService._init();

  /// Notification ID base offset to avoid any collisions with task reminders.
  /// Each alarm gets a base ID = 100000 + (numericId * 10).
  /// Suffix 0: One-time alarm
  /// Suffix 1..7: Weekdays Monday through Sunday
  /// Suffix 9: Snooze alarm
  int getAlarmBaseId(int numericId) {
    return 100000 + (numericId * 10);
  }

  /// Initialize clock alarm notification channel and reconcile alarms safely.
  Future<void> init() async {
    if (_isInitialized) return;
    if (_initFuture != null) {
      await _initFuture;
      return;
    }

    final future = _initialize();
    _initFuture = future;
    try {
      await future;
    } finally {
      if (identical(_initFuture, future)) {
        _initFuture = null;
      }
    }

    // Safely reconcile alarms AFTER initialization is fully complete.
    // This decouples service initialization from SQLite lookup and prevents
    // any possibility of recursive initialization cycles.
    unawaited(reconcileAlarms());
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;

    // Create the high-priority alarm notification channel on Android
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      const clockChannel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );
      await androidPlugin.createNotificationChannel(clockChannel);
    }

    _isInitialized = true;
    debugPrint('[ClockAlarmService] Initialized successfully.');
  }

  /// Schedule a clock alarm
  Future<bool> scheduleAlarm(ClockAlarm alarm) async {
    if (!_isInitialized) {
      await init();
    }

    // First cancel all previous notification slots for this alarm
    await cancelAlarm(alarm);

    if (!alarm.isEnabled) {
      debugPrint('[ClockAlarmService] Alarm ${alarm.id} is disabled. Skipping schedule.');
      return true;
    }

    final permissionStatus = await AlarmService.instance.refreshPermissionStatus();
    if (permissionStatus?.notificationsEnabled == false) {
      debugPrint('[ClockAlarmService] Notifications are disabled.');
      return false;
    }
    if (permissionStatus?.exactAlarmsEnabled == false) {
      debugPrint('[ClockAlarmService] Exact alarms are not permitted.');
      return false;
    }

    final fullScreenEnabled = permissionStatus?.fullScreenIntentEnabled ?? false;
    final baseId = getAlarmBaseId(alarm.numericId);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: alarm.vibrate,
      fullScreenIntent: fullScreenEnabled,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      visibility: NotificationVisibility.public,
      icon: 'ic_stat_alertbox',
      ongoing: true,
      autoCancel: false,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);
    final now = DateTime.now();

    try {
      if (!alarm.isRepeating) {
        // One-time alarm
        final nextOccurrence = alarm.getNextOccurrence(now);
        final tzDateTime = _convertToTzDateTime(nextOccurrence);

        await _notificationsPlugin.zonedSchedule(
          baseId,
          alarm.label.isNotEmpty ? '⏰ Alarm: ${alarm.label}' : '⏰ Clock Alarm',
          '${alarm.formattedTime} ${alarm.period} • Tap to view',
          tzDateTime,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'clock_alarm:${alarm.id}',
        );

        _scheduleForegroundTimer(alarm.id, nextOccurrence);
        debugPrint('[ClockAlarmService] One-time alarm scheduled for $nextOccurrence (ID $baseId)');
      } else {
        // Repeating alarm for each selected weekday
        for (final weekday in alarm.repeatDays) {
          final nextDate = _getNextDateForWeekday(weekday, alarm.hour, alarm.minute, now);
          final tzDateTime = _convertToTzDateTime(nextDate);
          final notifId = baseId + weekday;

          await _notificationsPlugin.zonedSchedule(
            notifId,
            alarm.label.isNotEmpty ? '⏰ Alarm: ${alarm.label}' : '⏰ Clock Alarm',
            '${alarm.formattedTime} ${alarm.period} • ${alarm.repeatSummary}',
            tzDateTime,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            payload: 'clock_alarm:${alarm.id}',
          );

          debugPrint(
              '[ClockAlarmService] Repeating alarm for weekday $weekday scheduled for $nextDate (ID $notifId)');
        }

        // Set foreground timer for the earliest next occurrence
        final earliestNext = alarm.getNextOccurrence(now);
        _scheduleForegroundTimer(alarm.id, earliestNext);
      }
      return true;
    } catch (e, stack) {
      debugPrint('[ClockAlarmService] Failed to schedule alarm ${alarm.id}: $e\n$stack');
      return false;
    }
  }

  /// Cancel all scheduled notifications and foreground timers for an alarm
  Future<void> cancelAlarm(ClockAlarm alarm) async {
    _cancelForegroundTimer(alarm.id);
    final baseId = getAlarmBaseId(alarm.numericId);

    // Cancel one-time slot (0)
    await _notificationsPlugin.cancel(baseId);

    // Cancel weekday repeat slots (1..7)
    for (int weekday = 1; weekday <= 7; weekday++) {
      await _notificationsPlugin.cancel(baseId + weekday);
    }

    // Cancel snooze slot (9)
    await _notificationsPlugin.cancel(baseId + 9);

    debugPrint('[ClockAlarmService] Cancelled all notification slots for alarm ${alarm.id}');
  }

  /// Schedule a snooze occurrence for an alarm
  Future<bool> scheduleSnooze(ClockAlarm alarm) async {
    if (!_isInitialized) {
      await init();
    }

    final snoozeTime = DateTime.now().add(Duration(minutes: alarm.snoozeMinutes));
    final baseId = getAlarmBaseId(alarm.numericId);
    final snoozeNotifId = baseId + 9;

    // Cancel previous notifications for this alarm (including the ringing notification)
    await cancelAlarm(alarm);

    final permissionStatus = await AlarmService.instance.refreshPermissionStatus();
    final fullScreenEnabled = permissionStatus?.fullScreenIntentEnabled ?? false;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: alarm.vibrate,
      fullScreenIntent: fullScreenEnabled,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      visibility: NotificationVisibility.public,
      icon: 'ic_stat_alertbox',
      ongoing: true,
      autoCancel: false,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);
    final tzDateTime = _convertToTzDateTime(snoozeTime);

    try {
      await _notificationsPlugin.zonedSchedule(
        snoozeNotifId,
        alarm.label.isNotEmpty ? '⏰ Snoozed: ${alarm.label}' : '⏰ Snoozed Alarm',
        'Ringing again at ${_formatTime(snoozeTime)} (${alarm.snoozeMinutes} min snooze)',
        tzDateTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'clock_alarm:${alarm.id}',
      );

      _scheduleForegroundTimer(alarm.id, snoozeTime);
      debugPrint('[ClockAlarmService] Snooze scheduled for $snoozeTime (ID $snoozeNotifId)');
      return true;
    } catch (e, stack) {
      debugPrint('[ClockAlarmService] Failed to schedule snooze for ${alarm.id}: $e\n$stack');
      return false;
    }
  }

  /// Reconcile all saved alarms from the database
  Future<void> reconcileAlarms() async {
    try {
      final alarms = await ClockAlarmDatabaseHelper.instance.getAllAlarms();
      debugPrint('[ClockAlarmService] Reconciling ${alarms.length} saved clock alarms...');

      final now = DateTime.now();
      for (final alarm in alarms) {
        if (!alarm.isEnabled) {
          await cancelAlarm(alarm);
          continue;
        }

        if (!alarm.isRepeating) {
          // Check if one-time alarm passed while app was terminated.
          // If today's alarm time has passed and the alarm was created before
          // that time, it already fired — disable it rather than re-schedule.
          final todayAlarmTime = DateTime(now.year, now.month, now.day, alarm.hour, alarm.minute);
          if (alarm.createdAt.isBefore(todayAlarmTime) && todayAlarmTime.isBefore(now)) {
            debugPrint('[ClockAlarmService] One-time alarm ${alarm.id} passed. Disabling in DB.');
            await ClockAlarmDatabaseHelper.instance.updateAlarm(alarm.copyWith(isEnabled: false));
            await cancelAlarm(alarm);
            continue;
          }
        }

        // Re-schedule enabled alarm
        await scheduleAlarm(alarm);
      }
    } catch (e, stack) {
      debugPrint('[ClockAlarmService] Error during alarm reconciliation: $e\n$stack');
    }
  }

  /// Route to the full-screen ringing UI with duplicate debounce protection
  void navigateToRingingScreen(String alarmId) {
    final now = DateTime.now();
    if (_lastNavigatedAlarmId == alarmId &&
        _lastNavigatedAt != null &&
        now.difference(_lastNavigatedAt!) < const Duration(seconds: 4)) {
      debugPrint('[ClockAlarmService] Ignoring duplicate navigation for alarm $alarmId');
      return;
    }

    _lastNavigatedAlarmId = alarmId;
    _lastNavigatedAt = now;

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      _pendingAlarmId = alarmId;
      _navigationAttempts = 0;
      _scheduleNavigationDrain();
      return;
    }

    _pendingAlarmId = null;
    debugPrint('[ClockAlarmService] Navigating to ClockAlarmRingingScreen for $alarmId');
    navigator.push(
      MaterialPageRoute(
        builder: (context) => ClockAlarmRingingScreen(alarmId: alarmId),
      ),
    );
  }

  void _scheduleNavigationDrain() {
    if (_navigationScheduled || _pendingAlarmId == null) return;
    _navigationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigationScheduled = false;
      _drainNavigation();
    });
  }

  void _drainNavigation() {
    final alarmId = _pendingAlarmId;
    if (alarmId == null) return;

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      _navigationAttempts++;
      if (_navigationAttempts <= 50) {
        Timer(const Duration(milliseconds: 100), _scheduleNavigationDrain);
      } else {
        debugPrint('[ClockAlarmService] Navigator was unavailable for alarm $alarmId');
        _pendingAlarmId = null;
      }
      return;
    }

    _pendingAlarmId = null;
    debugPrint('[ClockAlarmService] Draining pending navigation for alarm $alarmId');
    navigator.push(
      MaterialPageRoute(
        builder: (context) => ClockAlarmRingingScreen(alarmId: alarmId),
      ),
    );
  }

  void _scheduleForegroundTimer(String alarmId, DateTime scheduledTime) {
    _cancelForegroundTimer(alarmId);
    final delay = scheduledTime.difference(DateTime.now());
    if (delay.isNegative) return;

    _foregroundTimers[alarmId] = Timer(delay, () {
      _foregroundTimers.remove(alarmId);
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        debugPrint('[ClockAlarmService] Foreground timer triggered for alarm $alarmId');
        navigateToRingingScreen(alarmId);
      }
    });
  }

  void _cancelForegroundTimer(String alarmId) {
    _foregroundTimers.remove(alarmId)?.cancel();
  }

  tz.TZDateTime _convertToTzDateTime(DateTime localDateTime) {
    final scheduledUtc = localDateTime.toUtc();
    return tz.TZDateTime.utc(
      scheduledUtc.year,
      scheduledUtc.month,
      scheduledUtc.day,
      scheduledUtc.hour,
      scheduledUtc.minute,
      scheduledUtc.second,
      scheduledUtc.millisecond,
      scheduledUtc.microsecond,
    );
  }

  DateTime _getNextDateForWeekday(int targetWeekday, int hour, int minute, DateTime now) {
    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      final checkDate = now.add(Duration(days: dayOffset));
      if (checkDate.weekday == targetWeekday) {
        final candidate = DateTime(
          checkDate.year,
          checkDate.month,
          checkDate.day,
          hour,
          minute,
        );
        if (dayOffset > 0 || candidate.isAfter(now.add(const Duration(seconds: 5)))) {
          return candidate;
        }
      }
    }
    // Fallback: next week
    return DateTime(now.year, now.month, now.day, hour, minute).add(const Duration(days: 7));
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour == 0 ? 12 : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
    final minuteStr = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minuteStr $period';
  }
}
