import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';
import '../models/alarm_sound_config.dart';
import '../models/clock_alarm.dart';
import '../services/audio_service.dart';
import '../services/clock_alarm_database_helper.dart';
import '../services/clock_alarm_service.dart';
import 'sound_selection_screen.dart';

/// Screen for creating a new Clock Alarm or editing an existing one.
class ClockAlarmEditScreen extends StatefulWidget {
  final ClockAlarm? initialAlarm;

  const ClockAlarmEditScreen({super.key, this.initialAlarm});

  @override
  State<ClockAlarmEditScreen> createState() => _ClockAlarmEditScreenState();
}

class _ClockAlarmEditScreenState extends State<ClockAlarmEditScreen> {
  late TimeOfDay _selectedTime;
  late TextEditingController _labelController;
  late Set<int> _repeatDays;
  late String _soundType;
  late String _soundName;
  late String _soundUri;
  late int _snoozeMinutes;
  late bool _vibrate;
  bool _isSaving = false;

  bool get _isEditing => widget.initialAlarm != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialAlarm;
    if (initial != null) {
      _selectedTime = TimeOfDay(hour: initial.hour, minute: initial.minute);
      _labelController = TextEditingController(text: initial.label);
      _repeatDays = Set<int>.from(initial.repeatDays);
      _soundType = initial.soundType;
      _soundName = initial.soundName;
      _soundUri = initial.soundUri;
      _snoozeMinutes = initial.snoozeMinutes;
      _vibrate = initial.vibrate;
    } else {
      final now = TimeOfDay.now();
      _selectedTime = TimeOfDay(hour: (now.hour + 1) % 24, minute: 0);
      _labelController = TextEditingController();
      _repeatDays = <int>{};
      _soundType = 'default';
      _soundName = 'Default Alarm Sound';
      _soundUri = 'default_alarm';
      _snoozeMinutes = 10;
      _vibrate = true;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    AudioService.instance.stopPreview();
    super.dispose();
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minuteStr = time.minute.toString().padLeft(2, '0');
    return '$hour:$minuteStr';
  }

  String _periodString(TimeOfDay time) {
    return time.period == DayPeriod.am ? 'AM' : 'PM';
  }

  String _calculateCountdownText() {
    final now = DateTime.now();
    final tempAlarm = ClockAlarm(
      id: 'temp',
      numericId: 0,
      hour: _selectedTime.hour,
      minute: _selectedTime.minute,
      repeatDays: _repeatDays,
      createdAt: now,
    );
    return tempAlarm.timeUntilNextOccurrence(now);
  }

  Future<void> _pickTime() async {
    HapticFeedback.lightImpact();
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.accentCyan,
              onPrimary: AppTheme.darkBackground,
              surface: AppTheme.cardNavy,
              onSurface: AppTheme.textWhite,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: AppTheme.cardNavy,
              hourMinuteColor: AppTheme.surfaceLight,
              hourMinuteTextColor: AppTheme.textWhite,
              dayPeriodColor: AppTheme.surfaceLight,
              dayPeriodTextColor: AppTheme.accentCyan,
              dialBackgroundColor: AppTheme.surfaceLight,
              dialHandColor: AppTheme.accentCyan,
              dialTextColor: AppTheme.textWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: AppTheme.primaryPurple.withValues(alpha: 0.3)),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _selectSound() async {
    HapticFeedback.lightImpact();
    final result = await Navigator.push<AlarmSoundConfig>(
      context,
      MaterialPageRoute(
        builder: (context) => SoundSelectionScreen(
          currentConfig: AlarmSoundConfig(
            soundType: _soundType,
            soundName: _soundName,
            soundUri: _soundUri,
          ),
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _soundType = result.soundType;
        _soundName = result.soundName;
        _soundUri = result.soundUri;
      });
    }
  }

  Future<void> _previewSound() async {
    HapticFeedback.lightImpact();
    if (AudioService.instance.isPlaying) {
      await AudioService.instance.stopPreview();
      setState(() {});
    } else {
      await AudioService.instance.playPreview(
        soundType: _soundType,
        soundUri: _soundUri,
      );
      setState(() {});
    }
  }

  void _toggleWeekday(int day) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_repeatDays.contains(day)) {
        _repeatDays.remove(day);
      } else {
        _repeatDays.add(day);
      }
    });
  }

  void _applyPreset(String preset) {
    HapticFeedback.selectionClick();
    setState(() {
      switch (preset) {
        case 'once':
          _repeatDays.clear();
          break;
        case 'daily':
          _repeatDays = {1, 2, 3, 4, 5, 6, 7};
          break;
        case 'weekdays':
          _repeatDays = {1, 2, 3, 4, 5};
          break;
        case 'weekends':
          _repeatDays = {6, 7};
          break;
      }
    });
  }

  Future<void> _saveAlarm() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final initial = widget.initialAlarm;
      final numericId = initial != null
          ? initial.numericId
          : await ClockAlarmDatabaseHelper.instance.getNextNumericId();

      final alarm = ClockAlarm(
        id: initial?.id ?? 'clock_alarm_${DateTime.now().millisecondsSinceEpoch}_$numericId',
        numericId: numericId,
        hour: _selectedTime.hour,
        minute: _selectedTime.minute,
        label: _labelController.text.trim(),
        isEnabled: true,
        repeatDays: _repeatDays,
        soundType: _soundType,
        soundName: _soundName,
        soundUri: _soundUri,
        snoozeMinutes: _snoozeMinutes,
        vibrate: _vibrate,
        createdAt: initial?.createdAt ?? DateTime.now(),
      );

      if (_isEditing) {
        await ClockAlarmDatabaseHelper.instance.updateAlarm(alarm);
      } else {
        await ClockAlarmDatabaseHelper.instance.insertAlarm(alarm);
      }

      // Schedule exact alarm with AlarmManager
      final scheduled = await ClockAlarmService.instance.scheduleAlarm(alarm);
      if (!scheduled) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Alarm saved, but alarm permissions are incomplete. Enable them in Settings to guarantee ringing.'),
          ),
        );
        return;
      }

      if (!mounted) return;
      final countdown = alarm.timeUntilNextOccurrence(DateTime.now());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.alarm_on_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Alarm set for $countdown'),
              ),
            ],
          ),
          backgroundColor: AppTheme.primaryPurple,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop(alarm);
    } catch (e, stack) {
      debugPrint('[ClockAlarmEditScreen] Save error: $e\n$stack');
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving alarm: $e'),
          backgroundColor: AppTheme.urgentRed,
        ),
      );
    }
  }

  Future<void> _deleteAlarm() async {
    final initial = widget.initialAlarm;
    if (initial == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardNavy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.primaryPurple.withValues(alpha: 0.3)),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AppTheme.urgentRed),
            SizedBox(width: 10),
            Text('Delete Alarm?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Delete alarm for ${_formatTimeOfDay(_selectedTime)} ${_periodString(_selectedTime)}?',
          style: const TextStyle(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.urgentRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ClockAlarmService.instance.cancelAlarm(initial);
      await ClockAlarmDatabaseHelper.instance.deleteAlarm(initial.id);
      if (!mounted) return;
      Navigator.of(context).pop('deleted');
    }
  }

  @override
  Widget build(BuildContext context) {
    const weekdays = [
      {'id': 1, 'name': 'M'},
      {'id': 2, 'name': 'T'},
      {'id': 3, 'name': 'W'},
      {'id': 4, 'name': 'T'},
      {'id': 5, 'name': 'F'},
      {'id': 6, 'name': 'S'},
      {'id': 7, 'name': 'S'},
    ];

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: Text(
          _isEditing ? 'Edit Alarm' : 'Set Alarm',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveAlarm,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentCyan),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: AppTheme.accentCyan,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Interactive Time Hero Card
            GestureDetector(
              onTap: _pickTime,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: AppTheme.cardGradient,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppTheme.accentCyan.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentCyan.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _formatTimeOfDay(_selectedTime),
                          style: const TextStyle(
                            fontSize: 60,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textWhite,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _periodString(_selectedTime),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accentCyan,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.touch_app_outlined,
                          size: 16,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Alarm will ring ${_calculateCountdownText()}',
                          style: const TextStyle(
                            color: AppTheme.accentCyan,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 2. Alarm Label Input
            const Text(
              'Label',
              style: TextStyle(
                color: AppTheme.textWhite,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _labelController,
              style: const TextStyle(color: AppTheme.textWhite),
              decoration: InputDecoration(
                hintText: 'e.g. Wake up, Morning jog, Medicine',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                prefixIcon: const Icon(Icons.label_outline_rounded, color: AppTheme.accentCyan),
                suffixIcon: _labelController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        onPressed: () {
                          _labelController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.cardNavy,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppTheme.primaryPurple.withValues(alpha: 0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppTheme.primaryPurple.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.accentCyan),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 24),

            // 3. Repeat Days Selector
            const Text(
              'Repeat',
              style: TextStyle(
                color: AppTheme.textWhite,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),

            // Weekday circles
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: weekdays.map((day) {
                final dayId = day['id'] as int;
                final isSelected = _repeatDays.contains(dayId);
                return GestureDetector(
                  onTap: () => _toggleWeekday(dayId),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isSelected ? AppTheme.primaryGradient : null,
                      color: isSelected ? null : AppTheme.cardNavy,
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : AppTheme.primaryPurple.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        day['name'] as String,
                        style: TextStyle(
                          color: isSelected ? AppTheme.darkBackground : AppTheme.textWhite,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 12),

            // Quick repeat presets
            Wrap(
              spacing: 8,
              children: [
                _buildPresetChip('Once', _repeatDays.isEmpty, () => _applyPreset('once')),
                _buildPresetChip('Daily', _repeatDays.length == 7, () => _applyPreset('daily')),
                _buildPresetChip(
                  'Weekdays',
                  _repeatDays.length == 5 &&
                      !_repeatDays.contains(6) &&
                      !_repeatDays.contains(7),
                  () => _applyPreset('weekdays'),
                ),
                _buildPresetChip(
                  'Weekends',
                  _repeatDays.length == 2 &&
                      _repeatDays.contains(6) &&
                      _repeatDays.contains(7),
                  () => _applyPreset('weekends'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 4. Sound & Audio Selection
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardNavy,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.accentCyan.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.audiotrack_rounded, color: AppTheme.accentCyan),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Alarm Sound',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _soundName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _previewSound,
                        icon: Icon(
                          AudioService.instance.isPlaying
                              ? Icons.stop_circle_rounded
                              : Icons.play_circle_fill_rounded,
                          color: AppTheme.accentCyan,
                          size: 32,
                        ),
                        tooltip: 'Preview sound',
                      ),
                      IconButton(
                        onPressed: _selectSound,
                        icon: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppTheme.textMuted,
                        ),
                        tooltip: 'Change sound',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 5. Snooze Duration Settings
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardNavy,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.snooze_rounded, color: AppTheme.accentCyan, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Snooze Duration',
                        style: TextStyle(
                          color: AppTheme.textWhite,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [5, 10, 15, 20].map((mins) {
                      final isSelected = _snoozeMinutes == mins;
                      return ChoiceChip(
                        label: Text('$mins min'),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            HapticFeedback.selectionClick();
                            setState(() => _snoozeMinutes = mins);
                          }
                        },
                        selectedColor: AppTheme.accentCyan,
                        backgroundColor: AppTheme.darkBackground,
                        labelStyle: TextStyle(
                          color: isSelected ? AppTheme.darkBackground : AppTheme.textWhite,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 6. Vibration Switch
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.cardNavy,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.vibration_rounded, color: AppTheme.accentCyan, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Vibrate',
                      style: TextStyle(
                        color: AppTheme.textWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Switch(
                    value: _vibrate,
                    activeThumbColor: AppTheme.accentCyan,
                    activeTrackColor: AppTheme.accentCyan.withValues(alpha: 0.4),
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      setState(() => _vibrate = val);
                    },
                  ),
                ],
              ),
            ),

            if (_isEditing) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _deleteAlarm,
                  icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.urgentRed),
                  label: const Text(
                    'Delete Alarm',
                    style: TextStyle(
                      color: AppTheme.urgentRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, bool isSelected, VoidCallback onTap) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: isSelected
          ? AppTheme.accentCyan.withValues(alpha: 0.2)
          : AppTheme.cardNavy,
      side: BorderSide(
        color: isSelected ? AppTheme.accentCyan : AppTheme.primaryPurple.withValues(alpha: 0.2),
      ),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.accentCyan : AppTheme.textMuted,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }
}
