import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';
import '../models/alarm_sound_config.dart';
import '../models/task_item.dart';
import '../services/alarm_service.dart';
import '../services/alarm_sound_preferences.dart';
import '../services/audio_service.dart';
import '../services/database_helper.dart';
import 'sound_selection_screen.dart';

class TaskFormScreen extends StatefulWidget {
  final TaskItem? initialTask;
  final DateTime? initialDate;

  const TaskFormScreen({
    super.key,
    this.initialTask,
    this.initialDate,
  });

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late String _selectedCategory;
  late String _selectedPriority;
  late bool _reminderEnabled;

  // Sound selection state
  late String _alarmSoundType;
  late String _alarmSoundName;
  late String _alarmSoundUri;

  bool _isSaving = false;
  String? _schedulingError;

  bool get isEditing => widget.initialTask != null;

  final List<String> _categories = [
    'Personal',
    'Work',
    'Study',
    'Health',
    'Shopping',
    'Meetings',
    'Bills',
    'Fitness',
    'Family',
    'Other',
  ];

  final List<String> _priorities = ['Low', 'Medium', 'High'];

  @override
  void initState() {
    super.initState();
    final task = widget.initialTask;
    if (task != null) {
      _titleController = TextEditingController(text: task.title);
      _descriptionController = TextEditingController(text: task.description);
      _selectedDate = task.scheduledDateTime;
      _selectedTime = TimeOfDay.fromDateTime(task.scheduledDateTime);
      _selectedCategory = task.category;
      _selectedPriority = task.priority;
      _reminderEnabled = task.reminderEnabled;
      _alarmSoundType = task.alarmSoundType;
      _alarmSoundName = task.alarmSoundName;
      _alarmSoundUri = task.alarmSoundUri;
    } else {
      _titleController = TextEditingController();
      _descriptionController = TextEditingController();
      final now = DateTime.now();
      // Default to the next clean hour, carrying midnight into tomorrow.
      final nextCleanHour = DateTime(now.year, now.month, now.day, now.hour + 1);
      _selectedDate = widget.initialDate ?? nextCleanHour;
      _selectedTime = TimeOfDay.fromDateTime(nextCleanHour);

      _selectedCategory = 'Personal';
      _selectedPriority = 'Medium';
      _reminderEnabled = true;
      _alarmSoundType = 'default';
      _alarmSoundName = 'Default Alarm Sound';
      _alarmSoundUri = 'default_alarm';
      _loadDefaultAlarmSound();
    }
  }

  Future<void> _loadDefaultAlarmSound() async {
    final config = await AlarmSoundPreferences.load();
    if (!mounted || isEditing) return;
    setState(() {
      _alarmSoundType = config.soundType;
      _alarmSoundName = config.soundName;
      _alarmSoundUri = config.soundUri;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    AudioService.instance.stopPreview();
    super.dispose();
  }

  DateTime get _targetDateTime => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

  String get _countdownText {
    final now = DateTime.now();
    final diff = _targetDateTime.difference(now);
    if (diff.isNegative) {
      return 'Selected time is in the past';
    }
    final totalMinutes = diff.inMinutes;
    if (totalMinutes < 1) {
      return 'Rings in less than a minute';
    }
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = totalMinutes % 60;

    final parts = <String>[];
    if (days > 0) parts.add('$days day${days > 1 ? 's' : ''}');
    if (hours > 0) parts.add('$hours hour${hours > 1 ? 's' : ''}');
    if (minutes > 0) parts.add('$minutes min');

    return 'Rings in ${parts.join(', ')}';
  }

  Future<void> _pickDate() async {
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final initial =
        _selectedDate.isBefore(todayStart) ? todayStart : _selectedDate;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: todayStart,
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.accentCyan,
              onPrimary: AppTheme.darkBackground,
              surface: AppTheme.cardNavy,
              onSurface: AppTheme.textWhite,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: AppTheme.cardNavy,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: AppTheme.accentCyan.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _pickTime() async {
    HapticFeedback.lightImpact();
    final pickedTime = await showTimePicker(
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
                side: BorderSide(
                  color: AppTheme.accentCyan.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      setState(() {
        _selectedTime = pickedTime;
      });
    }
  }

  Future<void> _selectSound() async {
    HapticFeedback.lightImpact();
    await AudioService.instance.stopPreview();
    if (!mounted) return;

    final result = await Navigator.push<AlarmSoundConfig>(
      context,
      MaterialPageRoute(
        builder: (context) => SoundSelectionScreen(
          currentConfig: AlarmSoundConfig(
            soundType: _alarmSoundType,
            soundName: _alarmSoundName,
            soundUri: _alarmSoundUri,
          ),
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _alarmSoundType = result.soundType;
        _alarmSoundName = result.soundName;
        _alarmSoundUri = result.soundUri;
      });
    }
  }

  Future<void> _toggleAudioPreview() async {
    HapticFeedback.lightImpact();
    if (AudioService.instance.isPlaying) {
      await AudioService.instance.stopPreview();
      setState(() {});
    } else {
      await AudioService.instance.playPreview(
        soundType: _alarmSoundType,
        soundUri: _alarmSoundUri,
      );
      setState(() {});
    }
  }

  Future<void> _saveTask() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final targetTime = _targetDateTime;
    final now = DateTime.now();

    if (!targetTime.isAfter(now)) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Scheduled time cannot be in the past! Select a future date and time.',
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.urgentRed,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _schedulingError = null;
    });
    HapticFeedback.mediumImpact();

    final task = TaskItem(
      id: widget.initialTask?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      scheduledDateTime: targetTime,
      category: _selectedCategory,
      priority: _selectedPriority,
      isCompleted: widget.initialTask?.isCompleted ?? false,
      createdAt: widget.initialTask?.createdAt ?? DateTime.now(),
      completedAt: widget.initialTask?.completedAt,
      alarmSoundType: _alarmSoundType,
      alarmSoundName: _alarmSoundName,
      alarmSoundUri: _alarmSoundUri,
      reminderEnabled: _reminderEnabled,
    );

    try {
      // 1. Persist the task record to SQLite database
      if (isEditing) {
        await DatabaseHelper.instance.updateTask(task);
      } else {
        await DatabaseHelper.instance.insertTask(task);
      }

      // 2. Schedule or cancel alarm
      if (_reminderEnabled) {
        final scheduled =
            await AlarmService.instance.scheduleTaskAlarm(task);

        if (!scheduled) {
          // Check permissions to explain why it failed
          final permissions =
              await AlarmService.instance.refreshPermissionStatus();
          String reason = 'Alarm could not be scheduled.';
          if (permissions?.notificationsEnabled == false) {
            reason = 'Notification permission is disabled on your device.';
          } else if (permissions?.exactAlarmsEnabled == false) {
            reason =
                'Exact alarm permission is disabled. Please enable it in Settings.';
          }

          if (!mounted) return;
          setState(() {
            _isSaving = false;
            _schedulingError = reason;
          });

          _showPermissionDialog(task, reason);
          return;
        }
      } else {
        // User turned off reminder for this task
        await AlarmService.instance.cancelTaskAlarm(task.id);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.accentCyan, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _reminderEnabled
                      ? 'Task saved! Alarm set for ${task.formattedTime}.'
                      : 'Task saved without alarm.',
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.cardNavy,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );

      Navigator.pop(context, task);
    } catch (e, stack) {
      debugPrint('[TaskFormScreen] Error saving task: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _schedulingError = 'Error saving task: $e';
      });
    }
  }

  Future<void> _showPermissionDialog(TaskItem savedTask, String reason) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardNavy,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: AppTheme.warningOrange.withValues(alpha: 0.4),
            ),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: AppTheme.warningOrange, size: 26),
              SizedBox(width: 10),
              Text(
                'Alarm Permission Required',
                style: TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            '$reason\n\nYour task has been saved, but the alarm cannot ring until you grant exact alarm permissions.',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(this.context, savedTask);
              },
              child: const Text(
                'Keep Task Without Alarm',
                style: TextStyle(color: AppTheme.textMuted),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await AlarmService.instance.requestAlarmPermissions();
                final rescheduled =
                    await AlarmService.instance.scheduleTaskAlarm(savedTask);
                if (rescheduled && mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Alarm successfully scheduled for ${savedTask.formattedTime}!'),
                      backgroundColor: AppTheme.cardNavy,
                    ),
                  );
                  Navigator.pop(this.context, savedTask);
                } else if (mounted) {
                  setState(() {
                    _schedulingError =
                        'Permissions still missing. You can retry anytime.';
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentCyan,
                foregroundColor: AppTheme.darkBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Open Settings & Retry'),
            ),
          ],
        );
      },
    );
  }

  String _formatDateDisplay(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today';
    }
    final tomorrow = now.add(const Duration(days: 1));
    if (dt.year == tomorrow.year &&
        dt.month == tomorrow.month &&
        dt.day == tomorrow.day) {
      return 'Tomorrow';
    }
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatTimeDisplay(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final minute = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  Color _getPriorityColor(String p) {
    switch (p.toLowerCase()) {
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
    final isAudioPlaying = AudioService.instance.isPlaying;

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        elevation: 0,
        title: Text(
          isEditing ? 'Edit Task' : 'Create Task',
          style: const TextStyle(
            color: AppTheme.textWhite,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textWhite),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Task Title Field
                const Text(
                  'Task Title *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(
                    color: AppTheme.textWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. Project presentation or Doctor appointment',
                    hintStyle: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: AppTheme.cardNavy,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          const BorderSide(color: AppTheme.accentCyan, width: 1.5),
                    ),
                    prefixIcon: const Icon(
                      Icons.task_alt_rounded,
                      color: AppTheme.accentCyan,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a task title';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 18),

                // Description Field (Optional)
                const Text(
                  'Description (Optional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  style: const TextStyle(color: AppTheme.textWhite, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Add details, notes, or checklist items...',
                    hintStyle: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: AppTheme.cardNavy,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          const BorderSide(color: AppTheme.accentCyan, width: 1.5),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // Category Selector
                const Text(
                  'Category',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((category) {
                    final isSelected = _selectedCategory == category;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedCategory = category);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.accentCyan.withValues(alpha: 0.2)
                              : AppTheme.cardNavy,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.accentCyan
                                : Colors.white.withValues(alpha: 0.08),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? AppTheme.accentCyan
                                : AppTheme.textWhite,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 22),

                // Priority Selector
                const Text(
                  'Priority',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: _priorities.map((priority) {
                    final isSelected = _selectedPriority == priority;
                    final color = _getPriorityColor(priority);
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedPriority = priority);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withValues(alpha: 0.2)
                                : AppTheme.cardNavy,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? color
                                  : Colors.white.withValues(alpha: 0.08),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                priority,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: isSelected ? color : AppTheme.textWhite,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // Prominent Date & Time Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.cardNavy,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: AppTheme.accentCyan.withValues(alpha: 0.25),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.event_note_rounded,
                                  color: AppTheme.accentCyan, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'SCHEDULE & REMINDER',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                  color: AppTheme.accentCyan,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _countdownText,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textWhite,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Date Picker Button
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded,
                                  color: AppTheme.accentCyan, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Due Date',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                    Text(
                                      _formatDateDisplay(_selectedDate),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textWhite,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded,
                                  color: AppTheme.textMuted, size: 14),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Time Picker Button
                      InkWell(
                        onTap: _pickTime,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time_rounded,
                                  color: AppTheme.accentCyan, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Due Time',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                    Text(
                                      _formatTimeDisplay(_selectedTime),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textWhite,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded,
                                  color: AppTheme.textMuted, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Alarm / Reminder Toggle & Sound Configuration
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.cardNavy,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _reminderEnabled
                                  ? AppTheme.accentCyan.withValues(alpha: 0.2)
                                  : AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _reminderEnabled
                                  ? Icons.alarm_on_rounded
                                  : Icons.alarm_off_rounded,
                              color: _reminderEnabled
                                  ? AppTheme.accentCyan
                                  : AppTheme.textMuted,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Alarm Reminder',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textWhite,
                                  ),
                                ),
                                Text(
                                  _reminderEnabled
                                      ? 'Rings full-screen alarm at scheduled time'
                                      : 'No reminder will ring for this task',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _reminderEnabled,
                            activeThumbColor: AppTheme.accentCyan,
                            onChanged: (val) {
                              HapticFeedback.selectionClick();
                              setState(() => _reminderEnabled = val);
                            },
                          ),
                        ],
                      ),

                      if (_reminderEnabled) ...[
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 12),
                        // Sound Selection Row
                        InkWell(
                          onTap: _selectSound,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.music_note_rounded,
                                    color: AppTheme.accentCyan, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Alarm Ringtone',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textMuted,
                                        ),
                                      ),
                                      Text(
                                        _alarmSoundName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textWhite,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: isAudioPlaying
                                      ? 'Stop preview'
                                      : 'Preview sound',
                                  icon: Icon(
                                    isAudioPlaying
                                        ? Icons.stop_circle_rounded
                                        : Icons.play_circle_fill_rounded,
                                    color: AppTheme.accentCyan,
                                    size: 28,
                                  ),
                                  onPressed: _toggleAudioPreview,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                if (_schedulingError != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.warningOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.warningOrange.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: AppTheme.warningOrange, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _schedulingError!,
                            style: const TextStyle(
                              color: AppTheme.warningOrange,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Save Task Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveTask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentCyan,
                      foregroundColor: AppTheme.darkBackground,
                      disabledBackgroundColor:
                          AppTheme.accentCyan.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppTheme.darkBackground,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_rounded, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                isEditing ? 'Update Task' : 'Save Task',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
