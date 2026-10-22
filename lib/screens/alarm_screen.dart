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

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _loadTaskAndPlayAlarm();
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
      final tasks = await DatabaseHelper.instance.getAllTasks();
      final task = tasks.firstWhere(
        (t) => t.id == widget.taskId,
        orElse: () => TaskItem(
          id: widget.taskId,
          title: 'Scheduled Task Reminder',
          description: 'Your task alarm is ready for attention.',
          scheduledDateTime: DateTime.now(),
          category: 'General',
          priority: 'High',
        ),
      );

      if (!mounted) return;
      setState(() {
        _task = task;
        _isLoading = false;
      });

      final started = await _startAlarmPlayback(task);
      if (!mounted) return;
      if (started) {
        await HapticFeedback.heavyImpact();
        setState(() {
          _isRinging = true;
          _audioError = null;
        });
      } else {
        setState(() {
          _audioError =
              'Alarm sound could not start. Check the selected audio file and try again.';
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
    await HapticFeedback.mediumImpact();

    await AudioService.instance.stopPreview();
    _activeAlarmTaskId = null;
    try {
      await AlarmService.instance.cancelTaskAlarm(widget.taskId);
    } catch (e, stack) {
      debugPrint(
          '[AlarmScreen] Failed to cancel alarm ${widget.taskId}: $e\n$stack');
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _snoozeAlarm() async {
    if (_isActionTaken || _task == null) return;
    setState(() => _isActionTaken = true);
    await HapticFeedback.mediumImpact();

    await AudioService.instance.stopPreview();
    _activeAlarmTaskId = null;

    final snoozedTime = DateTime.now().add(const Duration(minutes: 10));
    final snoozedTask = _task!.copyWith(scheduledDateTime: snoozedTime);

    try {
      // Keep the snoozed time in SQLite so a process restart does not restore
      // the old, already-triggered schedule.
      await DatabaseHelper.instance.updateTask(snoozedTask);
      final scheduled =
          await AlarmService.instance.scheduleTaskAlarm(snoozedTask);
      if (!scheduled) {
        throw StateError('The notification could not be scheduled.');
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
      const SnackBar(
        content: Text('Alarm snoozed for 10 minutes'),
        backgroundColor: AppTheme.warningOrange,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context);
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
    final statusColor =
        _isRinging ? AppTheme.urgentRed : AppTheme.warningOrange;
    final statusLabel = _isRinging
        ? 'ALARM RINGING'
        : (_audioError == null ? 'STARTING ALARM' : 'AUDIO UNAVAILABLE');

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF171D23), AppTheme.darkBackground],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -100,
                left: -70,
                right: -70,
                child: IgnorePointer(
                  child: Container(
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentCyan.withValues(alpha: 0.12),
                          blurRadius: 100,
                          spreadRadius: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.sizeOf(context).height -
                        MediaQuery.paddingOf(context).vertical -
                        40,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: _isActionTaken
                                ? null
                                : () => Navigator.maybePop(context),
                            icon: const Icon(Icons.close_rounded),
                            color: AppTheme.textMuted,
                            tooltip: 'Close alarm',
                          ),
                          const Text(
                            'ALERTBOX',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.4,
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _StatusPill(label: statusLabel, color: statusColor),
                      const SizedBox(height: 28),
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final scale = 0.96 + (_pulseController.value * 0.04);
                          return Transform.scale(scale: scale, child: child);
                        },
                        child: Container(
                          width: 148,
                          height: 148,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.primaryGradient,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppTheme.accentCyan.withValues(alpha: 0.28),
                                blurRadius: 38,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(7),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.darkBackground,
                            ),
                            child: const Icon(
                              Icons.alarm_rounded,
                              size: 62,
                              color: AppTheme.accentCyan,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        task.title,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textWhite,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          height: 1.18,
                        ),
                      ),
                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          task.description,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      _TaskMetaCard(task: task),
                      if (_audioError != null) ...[
                        const SizedBox(height: 14),
                        _AudioErrorCard(
                          message: _audioError!,
                          onRetry: _retryPlayback,
                        ),
                      ],
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: FilledButton.icon(
                          onPressed: _isActionTaken ? null : _dismissAlarm,
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          label: const Text(
                            'Dismiss Alarm',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.urgentRed,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                AppTheme.urgentRed.withValues(alpha: 0.35),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton.icon(
                          onPressed: _isActionTaken ? null : _snoozeAlarm,
                          icon: const Icon(Icons.snooze_rounded),
                          label: const Text(
                            'Snooze for 10 minutes',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.warningOrange,
                            side: BorderSide(
                              color:
                                  AppTheme.warningOrange.withValues(alpha: 0.7),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskMetaCard extends StatelessWidget {
  final TaskItem task;

  const _TaskMetaCard({required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardNavy.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _MetaItem(
              icon: Icons.schedule_rounded,
              label: 'Scheduled',
              value: '${task.formattedDate}\n${task.formattedTime}',
              color: AppTheme.accentCyan,
            ),
          ),
          Container(width: 1, height: 42, color: Colors.white12),
          Expanded(
            child: _MetaItem(
              icon: Icons.sell_outlined,
              label: 'Category',
              value: task.category,
              color: AppTheme.primaryPurple,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetaItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AudioErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _AudioErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: AppTheme.warningOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppTheme.warningOrange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.volume_off_rounded,
              color: AppTheme.warningOrange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
