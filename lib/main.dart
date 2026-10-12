import 'package:flutter/material.dart';
import 'app.dart';
import 'services/alarm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AlarmService.instance.init();
  runApp(const TaskAlertApp());
}
