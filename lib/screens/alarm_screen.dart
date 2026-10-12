import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/task_item.dart';
import '../services/alarm_service.dart';
import '../services/audio_service.dart';
import '../services/database_helper.dart';

class AlarmScreen extends StatefulWidget {
  final String taskId;

  const AlarmScreen({super.key, required this.taskId});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> with SingleTickerProviderStateMixin {
  TaskItem? _task;
  bool _isLoading = true;
  bool _isActionTaken = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _loadTaskAndPlayAlarm();
  }

  Future<void> _loadTaskAndPlayAlarm() async {
    try {
      final tasks = await DatabaseHelper.instance.getAllTasks();
      final task = tasks.firstWhere(
        (t) => t.id == widget.taskId,
        orElse: () => TaskItem(
          id: widget.taskId,
          title: 'Scheduled Task Reminder',
          description: 'Your task alarm is ringing!',
          scheduledDateTime: DateTime.now(),
          category: 'General',
          priority: 'High',
        ),
      );

      setState(() {
        _task = task;
        _isLoading = false;
      });

      // Play looping alarm sound safely
      await AudioService.instance.playAlarm(
        soundType: task.alarmSoundType,
        soundUri: task.alarmSoundUri,
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _dismissAlarm() async {
    if (_isActionTaken) return;
    _isActionTaken = true;

    await AudioService.instance.stopPreview();
    if (_task != null) {
      await AlarmService.instance.cancelTaskAlarm(_task!.id);
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _snoozeAlarm() async {
    if (_isActionTaken) return;
    _isActionTaken = true;

    await AudioService.instance.stopPreview();
    if (_task != null) {
      // Reschedule task alarm 10 minutes from now
      final snoozedTime = DateTime.now().add(const Duration(minutes: 10));
      final snoozedTask = _task!.copyWith(scheduledDateTime: snoozedTime);
      await AlarmService.instance.scheduleTaskAlarm(snoozedTask);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Alarm snoozed for 10 minutes'),
        backgroundColor: AppTheme.warningOrange,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    AudioService.instance.stopPreview();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.darkBackground,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.accentCyan),
        ),
      );
    }

    final task = _task!;

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Indicator & Title
              Column(
                children: [
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.urgentRed.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.urgentRed.withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.alarm_on_rounded, size: 16, color: AppTheme.urgentRed),
                        SizedBox(width: 8),
                        Text(
                          'ALARM RINGING',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.urgentRed,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Pulsing Alarm Icon
                  ScaleTransition(
                    scale: Tween<double>(begin: 0.95, end: 1.05).animate(
                      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryPurple.withValues(alpha: 0.5),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.alarm_rounded,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Task Title
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textWhite,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Task Description / Notes
                  if (task.description.isNotEmpty) ...[
                    Text(
                      task.description,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.textMuted,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Scheduled Time & Category
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.access_time_rounded, size: 16, color: AppTheme.accentCyan),
                      const SizedBox(width: 6),
                      Text(
                        task.formattedTime,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentCyan,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.cardNavy,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          task.category,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textWhite,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Bottom Actions: Snooze & Dismiss
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _isActionTaken ? null : _dismissAlarm,
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 22),
                      label: const Text(
                        'Dismiss Alarm',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.urgentRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: _isActionTaken ? null : _snoozeAlarm,
                      icon: const Icon(Icons.snooze_rounded, size: 22),
                      label: const Text(
                        'Snooze (10 mins)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textWhite,
                        side: BorderSide(color: AppTheme.accentCyan.withValues(alpha: 0.6)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
