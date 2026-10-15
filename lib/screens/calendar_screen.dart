import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';
import '../models/task_item.dart';
import '../services/alarm_service.dart';
import '../services/database_helper.dart';
import '../widgets/animated_entry.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_header.dart';
import '../widgets/task_card.dart';
import 'task_form_screen.dart';

class CalendarScreen extends StatefulWidget {
  final List<TaskItem> tasks;
  final VoidCallback? onRefreshTasks;

  const CalendarScreen({
    super.key,
    required this.tasks,
    this.onRefreshTasks,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _focusedMonth;
  late DateTime _selectedDate;

  final List<String> _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  void _prevMonth() {
    HapticFeedback.lightImpact();
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    HapticFeedback.lightImpact();
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
  }

  void _goToToday() {
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    setState(() {
      _focusedMonth = DateTime(now.year, now.month, 1);
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Get tasks scheduled on a specific date
  List<TaskItem> _getTasksForDate(DateTime date) {
    return widget.tasks.where((t) {
      return t.scheduledDateTime.year == date.year &&
          t.scheduledDateTime.month == date.month &&
          t.scheduledDateTime.day == date.day;
    }).toList();
  }

  List<TaskItem> get _selectedDayTasks => _getTasksForDate(_selectedDate);

  Future<void> _toggleTaskCompletion(TaskItem task) async {
    setState(() {
      task.isCompleted = !task.isCompleted;
    });
    await DatabaseHelper.instance.updateTask(task);
    await AlarmService.instance.scheduleTaskAlarm(task);
    widget.onRefreshTasks?.call();
  }

  Future<void> _confirmDeleteTask(TaskItem task) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardNavy,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: AppTheme.primaryPurple.withValues(alpha: 0.3),
            ),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.urgentRed),
              SizedBox(width: 10),
              Text(
                'Delete Task?',
                style: TextStyle(
                  color: AppTheme.textWhite,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete "${task.title}"? This action cannot be undone.',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context, false);
              },
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.urgentRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteTask(task.id);
      await AlarmService.instance.cancelTaskAlarm(task.id);
      widget.onRefreshTasks?.call();
      setState(() {});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task "${task.title}" deleted.'),
          backgroundColor: AppTheme.urgentRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openAddTaskForSelectedDate() async {
    HapticFeedback.lightImpact();
    final newTask = await Navigator.push<TaskItem>(
      context,
      MaterialPageRoute(
        builder: (context) => TaskFormScreen(initialDate: _selectedDate),
      ),
    );

    if (newTask != null) {
      await DatabaseHelper.instance.insertTask(newTask);
      await AlarmService.instance.scheduleTaskAlarm(newTask);
      widget.onRefreshTasks?.call();
      setState(() {});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task "${newTask.title}" scheduled!'),
          backgroundColor: AppTheme.primaryPurple,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openEditTaskScreen(TaskItem task) async {
    HapticFeedback.lightImpact();
    final updatedTask = await Navigator.push<TaskItem>(
      context,
      MaterialPageRoute(
        builder: (context) => TaskFormScreen(initialTask: task),
      ),
    );

    if (updatedTask != null) {
      await DatabaseHelper.instance.updateTask(updatedTask);
      await AlarmService.instance.scheduleTaskAlarm(updatedTask);
      widget.onRefreshTasks?.call();
      setState(() {});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task "${updatedTask.title}" updated!'),
          backgroundColor: AppTheme.primaryPurple,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatSelectedDateTitle(DateTime dt) {
    final now = DateTime.now();
    if (_isSameDay(dt, now)) {
      return 'Agenda for Today (${dt.day} ${_months[dt.month - 1]})';
    }
    return 'Agenda for ${_months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final firstDayWeekday = DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday; // 1 = Mon, 7 = Sun
    final leadingPadding = firstDayWeekday - 1; // Number of empty grid cells
    final totalGridCells = leadingPadding + daysInMonth;
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Screen Header & Month Navigation (Responsive to prevent overflow)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_months[_focusedMonth.month - 1]} ${_focusedMonth.year}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textWhite,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Select a date to view or manage tasks',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Today Shortcut Button
                      TextButton(
                        onPressed: _goToToday,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: AppTheme.primaryPurple.withValues(alpha: 0.4),
                            ),
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Today',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentCyan,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Prev Month
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded, color: AppTheme.textWhite, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: _prevMonth,
                        tooltip: 'Previous Month',
                      ),
                      const SizedBox(width: 4),

                      // Next Month
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded, color: AppTheme.textWhite, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: _nextMonth,
                        tooltip: 'Next Month',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Calendar Card Container with Restrained Month Change Animations
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: Container(
                  key: ValueKey('${_focusedMonth.year}-${_focusedMonth.month}'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardNavy,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.25),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Weekday Labels Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: _weekdays.map((day) {
                          return SizedBox(
                            width: 36,
                            child: Text(
                              day,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentCyan,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),

                      // Calendar Grid View
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: totalGridCells,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemBuilder: (context, index) {
                          if (index < leadingPadding) {
                            return const SizedBox.shrink(); // Empty slot before first weekday
                          }

                          final dayNum = index - leadingPadding + 1;
                          final cellDate = DateTime(_focusedMonth.year, _focusedMonth.month, dayNum);
                          final isSelected = _isSameDay(cellDate, _selectedDate);
                          final isTodayDate = _isSameDay(cellDate, now);
                          final cellTasks = _getTasksForDate(cellDate);

                          final hasPending = cellTasks.any((t) => !t.isCompleted && !t.isOverdue);
                          final hasCompleted = cellTasks.any((t) => t.isCompleted);
                          final hasOverdue = cellTasks.any((t) => t.isOverdue);

                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedDate = cellDate;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              decoration: BoxDecoration(
                                gradient: isSelected ? AppTheme.primaryGradient : null,
                                color: isSelected
                                    ? null
                                    : (isTodayDate
                                        ? AppTheme.primaryPurple.withValues(alpha: 0.2)
                                        : AppTheme.darkBackground),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.transparent
                                      : (isTodayDate
                                          ? AppTheme.accentCyan
                                          : Colors.white10),
                                  width: isTodayDate && !isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$dayNum',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected || isTodayDate
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? Colors.white
                                          : (isTodayDate
                                              ? AppTheme.accentCyan
                                              : AppTheme.textWhite),
                                    ),
                                  ),
                                  if (cellTasks.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        if (hasOverdue)
                                          Container(
                                            width: 5,
                                            height: 5,
                                            margin: const EdgeInsets.symmetric(horizontal: 1),
                                            decoration: const BoxDecoration(
                                              color: AppTheme.urgentRed,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        if (hasPending)
                                          Container(
                                            width: 5,
                                            height: 5,
                                            margin: const EdgeInsets.symmetric(horizontal: 1),
                                            decoration: BoxDecoration(
                                              color: isSelected ? Colors.white : AppTheme.accentCyan,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        if (hasCompleted)
                                          Container(
                                            width: 5,
                                            height: 5,
                                            margin: const EdgeInsets.symmetric(horizontal: 1),
                                            decoration: const BoxDecoration(
                                              color: AppTheme.successGreen,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Selected Date Agenda Section
              SectionHeader(
                title: _formatSelectedDateTitle(_selectedDate),
                badgeText: '${_selectedDayTasks.length} Tasks',
                actionLabel: '+ Add Task',
                onActionPressed: _openAddTaskForSelectedDate,
              ),
              const SizedBox(height: 14),

              // Agenda Task List or Empty State with smooth transitions
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(
                  key: ValueKey('${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}-${_selectedDayTasks.length}'),
                  child: _selectedDayTasks.isEmpty
                      ? EmptyState(
                          title: 'No Tasks Scheduled 📅',
                          message: 'There are no tasks scheduled for ${_months[_selectedDate.month - 1]} ${_selectedDate.day}. Enjoy your free day or add a new task!',
                          actionLabel: 'Add Task for This Date',
                          onAction: _openAddTaskForSelectedDate,
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _selectedDayTasks.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final task = _selectedDayTasks[index];
                            return AnimatedEntry(
                              index: index,
                              child: TaskCard(
                                task: task,
                                onToggleCompleted: () => _toggleTaskCompletion(task),
                                onEditTask: () => _openEditTaskScreen(task),
                                onDeleteTask: () => _confirmDeleteTask(task),
                              ),
                            );
                          },
                        ),
                ),
              ),

              const SizedBox(height: 80), // Bottom Spacing
            ],
          ),
        ),
      ),
    );
  }
}
