import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';
import '../models/clock_alarm.dart';
import '../services/alarm_service.dart';
import '../services/clock_alarm_database_helper.dart';
import '../services/clock_alarm_service.dart';
import 'clock_alarm_edit_screen.dart';

/// Dedicated Clock-style Alarm list and management screen.
/// This screen is separate from all task-reminder functionality.
class ClockAlarmListScreen extends StatefulWidget {
  const ClockAlarmListScreen({super.key});

  @override
  State<ClockAlarmListScreen> createState() => _ClockAlarmListScreenState();
}

class _ClockAlarmListScreenState extends State<ClockAlarmListScreen>
    with WidgetsBindingObserver {
  List<ClockAlarm> _alarms = [];
  bool _isLoading = true;
  ClockAlarm? _nextAlarm;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAlarms();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh after returning from Android Settings (permission grants)
    if (state == AppLifecycleState.resumed) {
      _loadAlarms();
    }
  }

  Future<void> _loadAlarms() async {
    if (!mounted) return;
    try {
      final alarms = await ClockAlarmDatabaseHelper.instance.getAllAlarms();
      final nextAlarm = await ClockAlarmDatabaseHelper.instance.getNextActiveAlarm();
      if (!mounted) return;
      setState(() {
        _alarms = alarms;
        _nextAlarm = nextAlarm;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[ClockAlarmListScreen] Error loading alarms: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleAlarm(ClockAlarm alarm) async {
    HapticFeedback.selectionClick();
    final updated = alarm.copyWith(isEnabled: !alarm.isEnabled);
    await ClockAlarmDatabaseHelper.instance.updateAlarm(updated);

    if (updated.isEnabled) {
      final scheduled = await ClockAlarmService.instance.scheduleAlarm(updated);
      if (mounted && scheduled) {
        final countdown = updated.timeUntilNextOccurrence(DateTime.now());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Alarm enabled. Rings $countdown'),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (mounted && !scheduled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Alarm enabled but could not schedule. Check Alarms & Notifications permissions.',
            ),
            backgroundColor: AppTheme.warningOrange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      await ClockAlarmService.instance.cancelAlarm(updated);
    }

    await _loadAlarms();
  }

  Future<void> _openAddAlarm() async {
    HapticFeedback.lightImpact();
    final result = await Navigator.push<ClockAlarm>(
      context,
      MaterialPageRoute(
        builder: (context) => const ClockAlarmEditScreen(),
      ),
    );

    if (result != null) {
      await _loadAlarms();
    }
  }

  Future<void> _openEditAlarm(ClockAlarm alarm) async {
    HapticFeedback.lightImpact();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClockAlarmEditScreen(initialAlarm: alarm),
      ),
    );

    // result is either a ClockAlarm (updated) or 'deleted'
    if (result != null) {
      await _loadAlarms();
    }
  }

  Future<void> _requestPermissions() async {
    HapticFeedback.lightImpact();
    await AlarmService.instance.requestAlarmPermissions();
    await _loadAlarms();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Permission status refreshed. Try enabling an alarm again.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatAlarmTime(ClockAlarm alarm) {
    return '${alarm.formattedTime} ${alarm.period}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.alarm_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Alarms',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppTheme.textMuted),
            tooltip: 'Check permissions',
            onPressed: _requestPermissions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan))
          : _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddAlarm,
        backgroundColor: AppTheme.primaryPurple,
        foregroundColor: AppTheme.darkBackground,
        icon: const Icon(Icons.add_alarm_rounded),
        label: const Text(
          'New Alarm',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Next alarm banner
        if (_nextAlarm != null)
          SliverToBoxAdapter(child: _buildNextAlarmBanner(_nextAlarm!)),

        if (_alarms.isEmpty)
          SliverFillRemaining(
            child: _buildEmptyState(),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final alarm = _alarms[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildAlarmCard(alarm),
                  );
                },
                childCount: _alarms.length,
              ),
            ),
          ),
          // Bottom padding for FAB
          const SliverToBoxAdapter(child: SizedBox(height: 90)),
        ],
      ],
    );
  }

  Widget _buildNextAlarmBanner(ClockAlarm alarm) {
    final countdown = alarm.timeUntilNextOccurrence(DateTime.now());
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentCyan.withValues(alpha: 0.15),
            AppTheme.primaryPurple.withValues(alpha: 0.1),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.accentCyan.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.alarm_on_rounded, color: AppTheme.accentCyan, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next alarm: ${_formatAlarmTime(alarm)}',
                  style: const TextStyle(
                    color: AppTheme.accentCyan,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rings $countdown',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (alarm.label.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.cardNavy,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                alarm.label,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAlarmCard(ClockAlarm alarm) {
    final textColor = alarm.isEnabled ? AppTheme.textWhite : AppTheme.textMuted;
    final timeColor = alarm.isEnabled ? AppTheme.textWhite : AppTheme.textMuted;

    return GestureDetector(
      onTap: () => _openEditAlarm(alarm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: alarm.isEnabled ? AppTheme.cardNavy : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: alarm.isEnabled
                ? AppTheme.accentCyan.withValues(alpha: 0.2)
                : Colors.white12,
            width: 1.0,
          ),
          boxShadow: alarm.isEnabled
              ? [
                  BoxShadow(
                    color: AppTheme.accentCyan.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Time + label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time display
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        alarm.formattedTime,
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: timeColor,
                          letterSpacing: -1,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        alarm.period,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: alarm.isEnabled ? AppTheme.accentCyan : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Label (if any)
                  if (alarm.label.isNotEmpty) ...[
                    Text(
                      alarm.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],

                  // Repeat + sound row
                  Row(
                    children: [
                      Icon(
                        alarm.isRepeating ? Icons.repeat_rounded : Icons.alarm_rounded,
                        size: 13,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          alarm.repeatSummary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                      if (alarm.vibrate) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.vibration_rounded,
                          size: 13,
                          color: AppTheme.textMuted,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // Enable/disable toggle
            Switch(
              value: alarm.isEnabled,
              activeThumbColor: AppTheme.accentCyan,
              activeTrackColor: AppTheme.accentCyan.withValues(alpha: 0.35),
              inactiveThumbColor: AppTheme.textMuted,
              inactiveTrackColor: AppTheme.surfaceLight,
              onChanged: (_) => _toggleAlarm(alarm),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.cardNavy,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                ),
              ),
              child: const Icon(
                Icons.alarm_add_rounded,
                size: 56,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Alarms Set',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textWhite,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tap the button below to create your first alarm.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
