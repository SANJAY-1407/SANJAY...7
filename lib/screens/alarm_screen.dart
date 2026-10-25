import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _AlarmScreenState extends State<AlarmScreen>
    with SingleTickerProviderStateMixin {
  static String? _activeAlarmTaskId;
  static Future<bool>? _activePlayback;

  TaskItem? _task;
  bool _isLoading = true;
  bool _isRinging = false;
  bool _isActionTaken = false;
  String? _audioError;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    debugPrint(
        '[AlarmScreen] Alarm UI launched for task ID ${widget.taskId}; starting task lookup and playback.');
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadTaskAndPlayAlarm());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _pulseController.stop();
    } else if (!_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
  }

  Future<void> _loadTaskAndPlayAlarm() async {
    try {
      final task = await DatabaseHelper.instance.getTaskById(widget.taskId);
      final resolvedTask = task ??
          TaskItem(
            id: widget.taskId,
            title: 'Scheduled Task Reminder',
            description: 'Your task alarm is ready for attention.',
            scheduledDateTime: DateTime.now(),
            category: 'Personal',
            priority: 'High',
          );

      if (!mounted) return;
      setState(() {
        _task = resolvedTask;
        _isLoading = false;
      });

      debugPrint(
          '[AlarmScreen] Task loaded for task ID ${resolvedTask.id}; starting alarm playback.');

      final started = await _startAlarmPlayback(resolvedTask);
      if (!mounted) return;
      if (started) {
        debugPrint(
            '[AlarmScreen] Alarm playback started for task ID ${resolvedTask.id}.');
        await HapticFeedback.heavyImpact();
        setState(() {
          _isRinging = true;
          _audioError = null;
        });
      } else {
        debugPrint(
            '[AlarmScreen] Alarm playback did not start for task ID ${resolvedTask.id}.');
        setState(() {
          _audioError =
              'Alarm sound could not start. Using fallback audio.';
        });
      }
    } catch (e, stack) {
      debugPrint(
          '[AlarmScreen] Failed to load alarm task ${widget.taskId}: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _audioError = 'Alarm details could not be loaded.';
      });
    }
  }

  Future<bool> _startAlarmPlayback(TaskItem task) async {
    if (_activeAlarmTaskId == task.id && AudioService.instance.isPlaying) {
      return true;
    }

    if (_activeAlarmTaskId == task.id && _activePlayback != null) {
      return _activePlayback!;
    }

    _activeAlarmTaskId = task.id;
    final playback = AudioService.instance.playAlarm(
      soundType: task.alarmSoundType,
      soundUri: task.alarmSoundUri,
    );
    _activePlayback = playback;

    final started = await playback;
    if (identical(_activePlayback, playback)) {
      _activePlayback = null;
    }
    if (!started && _activeAlarmTaskId == task.id) {
      _activeAlarmTaskId = null;
    }
    return started;
  }

  Future<void> _dismissAlarm() async {
    if (_isActionTaken) return;
    setState(() => _isActionTaken = true);
    await HapticFeedback.heavyImpact();

    // Stop audio immediately
    await AudioService.instance.stopPreview();
    _activeAlarmTaskId = null;

    try {
      await AlarmService.instance.cancelTaskAlarm(widget.taskId);
    } catch (e, stack) {
      debugPrint(
          '[AlarmScreen] Failed to cancel alarm ${widget.taskId}: $e\n$stack');
    }

    // Notice: Task is intentionally NOT marked completed.
    // Dismissing an alarm simply silences the alarm.
    // Task completion remains a distinct user action.

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _snoozeAlarm() async {
    if (_isActionTaken || _task == null) return;
    setState(() => _isActionTaken = true);
    await HapticFeedback.mediumImpact();

    // Stop audio immediately
    await AudioService.instance.stopPreview();
    _activeAlarmTaskId = null;

    final snoozedTime = DateTime.now().add(const Duration(minutes: 10));
    final snoozedTask = _task!.copyWith(scheduledDateTime: snoozedTime);

    try {
      await DatabaseHelper.instance.updateTask(snoozedTask);
      final scheduled =
          await AlarmService.instance.scheduleTaskAlarm(snoozedTask);
      if (!scheduled) {
        throw StateError('The snooze notification could not be scheduled.');
      }
    } catch (e, stack) {
      debugPrint(
          '[AlarmScreen] Failed to snooze alarm ${widget.taskId}: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _isActionTaken = false;
        _audioError =
            'Snooze could not be scheduled. Check notification permissions.';
      });
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.snooze_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(child: Text('Alarm snoozed for 10 minutes')),
          ],
        ),
        backgroundColor: AppTheme.warningOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _retryPlayback() async {
    final task = _task;
    if (task == null || _isActionTaken) return;
    setState(() => _audioError = null);
    final started = await _startAlarmPlayback(task);
    if (!mounted) return;
    setState(() {
      _isRinging = started;
      if (!started) {
        _audioError =
            'Alarm sound could not start. Check the selected audio file.';
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    if (_activeAlarmTaskId == widget.taskId) {
      _activeAlarmTaskId = null;
      AudioService.instance.stopPreview();
    }
    super.dispose();
  }

  Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'work':
        return AppTheme.categoryWork;
      case 'study':
        return AppTheme.categoryStudy;
      case 'health':
      case 'fitness':
        return AppTheme.categoryHealth;
      case 'shopping':
        return AppTheme.categoryShopping;
      case 'bills':
        return AppTheme.categoryBills;
      case 'family':
        return AppTheme.categoryFamily;
      default:
        return AppTheme.categoryPersonal;
    }
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return AppTheme.urgentRed;
      case 'medium':
        return AppTheme.warningOrange;
      default:
        return AppTheme.accentCyan;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _task == null) {
      return const Scaffold(
        backgroundColor: AppTheme.darkBackground,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.accentCyan),
        ),
      );
    }

    final task = _task!;
    final categoryColor = _categoryColor(task.category);
    final priorityColor = _priorityColor(task.priority);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _dismissAlarm();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.darkBackground,
        body: SafeArea(
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF141923), AppTheme.darkBackground],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  // App Bar / Tag
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppTheme.cardNavy,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isRinging
                                ? AppTheme.accentCyan.withValues(alpha: 0.6)
                                : Colors.white12,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.alarm_on_rounded,
                              size: 16,
                              color: _isRinging
                                  ? AppTheme.accentCyan
                                  : AppTheme.textMuted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isRinging ? 'TASK ALARM RINGING' : 'ALERTBOX ALARM',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: _isRinging
                                    ? AppTheme.accentCyan
                                    : AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _isActionTaken ? null : _dismissAlarm,
                        icon: const Icon(Icons.close_rounded),
                        color: AppTheme.textMuted,
                        tooltip: 'Dismiss',
                      ),
                    ],
                  ),

                  const Spacer(flex: 1),

                  // Pulsing Visual Alarm Icon
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.primaryPurple.withValues(alpha: 0.35),
                            AppTheme.accentCyan.withValues(alpha: 0.1),
                            Colors.transparent,
                          ],
                        ),
                        border: Border.all(
                          color: AppTheme.accentCyan.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.notifications_active_rounded,
                          size: 58,
                          color: AppTheme.accentCyan,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Scheduled Time
                  Text(
                    task.formattedTime,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textWhite,
                      letterSpacing: -1.2,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    task.formattedDate,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accentCyan,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Task Title Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardNavy,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          task.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textWhite,
                          ),
                        ),
                        if (task.description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            task.description,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textMuted,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        // Badges Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Category Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: categoryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: categoryColor.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                task.category,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: categoryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Priority Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: priorityColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: priorityColor.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                '${task.priority} Priority',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: priorityColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (_audioError != null) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _retryPlayback,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.warningOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                AppTheme.warningOrange.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.refresh_rounded,
                              size: 16,
                              color: AppTheme.warningOrange,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _audioError!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.warningOrange,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const Spacer(flex: 2),

                  // Dismiss Button (Big Primary Action)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isActionTaken ? null : _dismissAlarm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentCyan,
                        foregroundColor: AppTheme.darkBackground,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 22),
                          SizedBox(width: 10),
                          Text(
                            'Dismiss Alarm',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Snooze Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _isActionTaken ? null : _snoozeAlarm,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textWhite,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.snooze_rounded,
                              size: 20, color: AppTheme.warningOrange),
                          SizedBox(width: 8),
                          Text(
                            'Snooze for 10 minutes',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
