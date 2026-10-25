import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';
import '../models/clock_alarm.dart';
import '../services/audio_service.dart';
import '../services/clock_alarm_database_helper.dart';
import '../services/clock_alarm_service.dart';

/// Full-screen mobile Clock-style ringing experience.
/// Displays large clock time, label, repeat info, pulsing visuals,
/// and prominent Snooze & Dismiss buttons.
class ClockAlarmRingingScreen extends StatefulWidget {
  final String alarmId;

  const ClockAlarmRingingScreen({super.key, required this.alarmId});

  @override
  State<ClockAlarmRingingScreen> createState() => _ClockAlarmRingingScreenState();
}

class _ClockAlarmRingingScreenState extends State<ClockAlarmRingingScreen>
    with SingleTickerProviderStateMixin {
  ClockAlarm? _alarm;
  bool _isLoading = true;
  bool _isRinging = false;
  bool _isActionTaken = false;
  String? _audioError;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadAlarmAndPlay());
    });
  }

  Future<void> _loadAlarmAndPlay() async {
    try {
      final alarm = await ClockAlarmDatabaseHelper.instance.getAlarmById(widget.alarmId);
      final resolvedAlarm = alarm ??
          ClockAlarm(
            id: widget.alarmId,
            numericId: 1,
            hour: DateTime.now().hour,
            minute: DateTime.now().minute,
            label: 'Alarm',
            isEnabled: true,
            createdAt: DateTime.now(),
          );

      if (!mounted) return;
      setState(() {
        _alarm = resolvedAlarm;
        _isLoading = false;
      });

      // Play the alarm sound through the alarm audio stream
      final started = await AudioService.instance.playAlarm(
        soundType: resolvedAlarm.soundType,
        soundUri: resolvedAlarm.soundUri,
      );

      if (!mounted) return;
      if (started) {
        await HapticFeedback.heavyImpact();
        setState(() {
          _isRinging = true;
          _audioError = null;
        });
      } else {
        setState(() {
          _audioError = 'Alarm sound could not start. Using fallback.';
        });
      }
    } catch (e, stack) {
      debugPrint('[ClockAlarmRingingScreen] Error loading alarm: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _audioError = 'Could not load alarm details.';
      });
    }
  }

  Future<void> _dismissAlarm() async {
    if (_isActionTaken) return;
    setState(() => _isActionTaken = true);
    await HapticFeedback.heavyImpact();

    // Stop audio immediately
    await AudioService.instance.stopPreview();

    final alarm = _alarm;
    if (alarm != null) {
      try {
        if (!alarm.isRepeating) {
          // If it's a one-time alarm, disable it so it won't ring again
          final updated = alarm.copyWith(isEnabled: false);
          await ClockAlarmDatabaseHelper.instance.updateAlarm(updated);
          await ClockAlarmService.instance.cancelAlarm(alarm);
        } else {
          // For repeating alarms, cancel current session and schedule next
          await ClockAlarmService.instance.scheduleAlarm(alarm);
        }
      } catch (e) {
        debugPrint('[ClockAlarmRingingScreen] Error during dismiss: $e');
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _snoozeAlarm() async {
    if (_isActionTaken || _alarm == null) return;
    setState(() => _isActionTaken = true);
    await HapticFeedback.mediumImpact();

    // Stop audio immediately
    await AudioService.instance.stopPreview();

    final alarm = _alarm!;
    try {
      await ClockAlarmService.instance.scheduleSnooze(alarm);
    } catch (e) {
      debugPrint('[ClockAlarmRingingScreen] Error during snooze: $e');
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Alarm snoozed for ${alarm.snoozeMinutes} minutes'),
        backgroundColor: AppTheme.warningOrange,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    // Guarantee sound stops when screen is closed
    AudioService.instance.stopPreview();
    super.dispose();
  }

  String _formatTodayDate() {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
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

    final alarm = _alarm!;
    final displayTime = alarm.formattedTime;
    final period = alarm.period;

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
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF141923), AppTheme.darkBackground],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // Alarm Type Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          size: 18,
                          color: _isRinging ? AppTheme.accentCyan : AppTheme.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isRinging ? 'ALARM RINGING' : 'ALERTBOX ALARM',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: _isRinging ? AppTheme.accentCyan : AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 1),

                  // Pulsing Alarm Icon Visual
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 140,
                      height: 140,
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
                          Icons.access_alarms_rounded,
                          size: 64,
                          color: AppTheme.accentCyan,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Large Time Display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        displayTime,
                        style: const TextStyle(
                          fontSize: 68,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textWhite,
                          letterSpacing: -1.5,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        period,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentCyan,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Alarm Label
                  if (alarm.label.isNotEmpty) ...[
                    Text(
                      alarm.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textWhite,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],

                  // Date and Repeat info
                  Text(
                    '${_formatTodayDate()} • ${alarm.repeatSummary}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                    ),
                  ),

                  if (_audioError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.warningOrange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _audioError!,
                        style: const TextStyle(
                          color: AppTheme.warningOrange,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],

                  const Spacer(flex: 2),

                  // Prominent Action Buttons
                  Row(
                    children: [
                      // Snooze Button
                      Expanded(
                        child: SizedBox(
                          height: 64,
                          child: OutlinedButton(
                            onPressed: _snoozeAlarm,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textWhite,
                              side: BorderSide(
                                color: AppTheme.primaryPurple.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                              backgroundColor: AppTheme.cardNavy,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.snooze_rounded, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  'Snooze (${alarm.snoozeMinutes}m)',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Dismiss / Stop Button
                      Expanded(
                        child: SizedBox(
                          height: 64,
                          child: ElevatedButton(
                            onPressed: _dismissAlarm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.urgentRed,
                              foregroundColor: Colors.white,
                              elevation: 8,
                              shadowColor: AppTheme.urgentRed.withValues(alpha: 0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.alarm_off_rounded, size: 24),
                                SizedBox(width: 8),
                                Text(
                                  'Dismiss',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
