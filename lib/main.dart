import 'dart:async';

import 'package:flutter/material.dart';
import 'app.dart';
import 'services/alarm_service.dart';
import 'services/clock_alarm_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaskAlertApp());

  // Do not delay Flutter's first frame while notification channels, Android
  // permission diagnostics, or launch details are being read. This is
  // especially important when Android starts the activity from a full-screen
  // notification while the process is cold.
  unawaited(AlarmService.instance.init());

  // Initialize the dedicated Clock-style alarm service independently.
  // ClockAlarmService creates its own notification channel and reconciles
  // persisted alarms without touching the task reminder flow.
  unawaited(ClockAlarmService.instance.init());
}
