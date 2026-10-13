import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/alarm_sound_config.dart';
import '../models/task_item.dart';
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

  // Day 6 Alarm Sound Configuration State
  late String _alarmSoundType;
  late String _alarmSoundName;
  late String _alarmSoundUri;

  bool _isSaving = false;

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
      _alarmSoundType = task.alarmSoundType;
      _alarmSoundName = task.alarmSoundName;
      _alarmSoundUri = task.alarmSoundUri;
    } else {
      _titleController = TextEditingController();
      _descriptionController = TextEditingController();
      _selectedDate = widget.initialDate ?? DateTime.now();
      _selectedTime = TimeOfDay.now();
      _selectedCategory = 'Personal';
      _selectedPriority = 'Medium';
      _alarmSoundType = 'default';
      _alarmSoundName = 'Default Alarm Sound';
      _alarmSoundUri = 'default_alarm';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final initialDate = _selectedDate.isBefore(todayStart) ? todayStart : _selectedDate;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: todayStart,
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryPurple,
              onPrimary: Colors.white,
              surface: AppTheme.cardNavy,
              onSurface: AppTheme.textWhite,
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
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryPurple,
              onPrimary: Colors.white,
              surface: AppTheme.cardNavy,
              onSurface: AppTheme.textWhite,
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

  void _saveTask() {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final scheduledDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final now = DateTime.now();
    if (scheduledDateTime.isBefore(now.subtract(const Duration(minutes: 2)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text('Scheduled time cannot be in the past! Select a future date/time.'),
              ),
            ],
          ),
          backgroundColor: AppTheme.urgentRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final task = TaskItem(
      id: widget.initialTask?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      scheduledDateTime: scheduledDateTime,
      category: _selectedCategory,
      priority: _selectedPriority,
      isCompleted: widget.initialTask?.isCompleted ?? false,
      createdAt: widget.initialTask?.createdAt ?? DateTime.now(),
      alarmSoundType: _alarmSoundType,
      alarmSoundName: _alarmSoundName,
      alarmSoundUri: _alarmSoundUri,
    );

    Navigator.pop(context, task);
  }

  String _formatDateDisplay(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today (${dt.day}/${dt.month}/${dt.year})';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
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
      case 'low':
      default:
        return AppTheme.accentCyan;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Task' : 'Create New Task',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Task Title Field
                const Text(
                  'Task Title *',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textWhite,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(color: AppTheme.textWhite),
                  decoration: InputDecoration(
                    hintText: 'e.g. Submit Project or Team Meeting',
                    hintStyle: const TextStyle(color: AppTheme.textMuted),
                    filled: true,
                    fillColor: AppTheme.cardNavy,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppTheme.accentCyan),
                    ),
                    prefixIcon: const Icon(
                      Icons.task_rounded,
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
                const SizedBox(height: 20),

                // Task Description Field (Optional)
                const Text(
                  'Description / Notes (Optional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textWhite,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(color: AppTheme.textWhite),
                  decoration: InputDecoration(
                    hintText: 'Add additional details or reminders...',
                    hintStyle: const TextStyle(color: AppTheme.textMuted),
                    filled: true,
                    fillColor: AppTheme.cardNavy,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppTheme.accentCyan),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Date & Time Selectors Row
                Row(
                  children: [
                    // Date Selector
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Date',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textWhite,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.cardNavy,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_month_rounded,
                                    size: 20,
                                    color: AppTheme.accentCyan,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _formatDateDisplay(_selectedDate),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textWhite,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Time Selector
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Time',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textWhite,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _pickTime,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.cardNavy,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.access_time_filled_rounded,
                                    size: 20,
                                    color: AppTheme.accentCyan,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _formatTimeDisplay(_selectedTime),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textWhite,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Category Chips
                const Text(
                  'Category',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textWhite,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedCategory = cat;
                          });
                        }
                      },
                      selectedColor: AppTheme.primaryPurple,
                      backgroundColor: AppTheme.cardNavy,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textMuted,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected
                              ? AppTheme.accentCyan
                              : Colors.white12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Priority Selection
                const Text(
                  'Priority',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textWhite,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: _priorities.map((p) {
                    final isSelected = _selectedPriority == p;
                    final color = _getPriorityColor(p);
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedPriority = p;
                            });
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withValues(alpha: 0.25)
                                  : AppTheme.cardNavy,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? color : Colors.white10,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                p,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? color : AppTheme.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Day 6: Alarm Sound Selector Tile
                const Text(
                  'Alarm Sound',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textWhite,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
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
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardNavy,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.notifications_active_rounded,
                          size: 20,
                          color: AppTheme.accentCyan,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Selected Ringtone / Sound',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _alarmSoundName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textWhite,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: AppTheme.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // Save / Update Task Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _saveTask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      foregroundColor: AppTheme.textWhite,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 6,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            isEditing ? 'Update Task' : 'Save Task',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
