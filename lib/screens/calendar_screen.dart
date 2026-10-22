import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';
import '../models/task_item.dart';
import '../services/alarm_service.dart';
import '../services/database_helper.dart';
import '../widgets/section_header.dart';

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

  final List<String> _weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun'
  ];
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

  /// Get tasks scheduled on a specific date for calendar grid indicators & timeline
  List<TaskItem> _getTasksForDate(DateTime date) {
    return widget.tasks.where((t) {
      return t.scheduledDateTime.year == date.year &&
          t.scheduledDateTime.month == date.month &&
          t.scheduledDateTime.day == date.day;
    }).toList();
  }

  List<TaskItem> get _selectedDayTasks => _getTasksForDate(_selectedDate);

  /// Count completed tasks for a date (uses completedAt or scheduledDateTime fallback)
  int _getCompletedCountForDate(DateTime date) {
    return widget.tasks.where((t) {
      if (!t.isCompleted) return false;
      if (t.completedAt != null) {
        return t.completedAt!.year == date.year &&
            t.completedAt!.month == date.month &&
            t.completedAt!.day == date.day;
      }
      return t.scheduledDateTime.year == date.year &&
          t.scheduledDateTime.month == date.month &&
          t.scheduledDateTime.day == date.day;
    }).length;
  }

  Future<void> _toggleTaskCompletion(TaskItem task) async {
    setState(() {
      task.isCompleted = !task.isCompleted;
      task.completedAt = task.isCompleted ? DateTime.now() : null;
    });
    await DatabaseHelper.instance.updateTask(task);
    try {
      await AlarmService.instance.scheduleTaskAlarm(task);
    } catch (e) {
      debugPrint('Alarm scheduling error: $e');
    }
    widget.onRefreshTasks?.call();
  }

  String _formatSelectedDateTitle(DateTime dt) {
    final now = DateTime.now();
    if (_isSameDay(dt, now)) {
      return 'Today (${dt.day} ${_months[dt.month - 1]})';
    }
    return '${_months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
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
    final daysInMonth =
        DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final firstDayWeekday = DateTime(_focusedMonth.year, _focusedMonth.month, 1)
        .weekday; // 1 = Mon, 7 = Sun
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
              // Screen Header & Month Navigation (UNTOUCHED PRESERVED HEADER)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Calendar',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMuted,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
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
                          'Select a date to view scheduled activity',
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          backgroundColor:
                              AppTheme.primaryPurple.withValues(alpha: 0.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color:
                                  AppTheme.primaryPurple.withValues(alpha: 0.4),
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

                      // Prev Month Button
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded,
                            color: AppTheme.textWhite, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: _prevMonth,
                        tooltip: 'Previous Month',
                      ),
                      const SizedBox(width: 4),

                      // Next Month Button
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded,
                            color: AppTheme.textWhite, size: 22),
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

              // Calendar Card Container (UNTOUCHED PRESERVED MONTHLY GRID & DOT INDICATORS)
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
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemBuilder: (context, index) {
                          if (index < leadingPadding) {
                            return const SizedBox
                                .shrink(); // Empty slot before first weekday
                          }

                          final dayNum = index - leadingPadding + 1;
                          final cellDate = DateTime(
                              _focusedMonth.year, _focusedMonth.month, dayNum);
                          final isSelected =
                              _isSameDay(cellDate, _selectedDate);
                          final isTodayDate = _isSameDay(cellDate, now);
                          final cellTasks = _getTasksForDate(cellDate);

                          final hasPending = cellTasks
                              .any((t) => !t.isCompleted && !t.isOverdue);
                          final hasCompleted =
                              cellTasks.any((t) => t.isCompleted);
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
                                gradient: isSelected
                                    ? AppTheme.primaryGradient
                                    : null,
                                color: isSelected
                                    ? null
                                    : (isTodayDate
                                        ? AppTheme.primaryPurple
                                            .withValues(alpha: 0.2)
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (hasOverdue)
                                          Container(
                                            width: 5,
                                            height: 5,
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 1),
                                            decoration: const BoxDecoration(
                                              color: AppTheme.urgentRed,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        if (hasPending)
                                          Container(
                                            width: 5,
                                            height: 5,
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 1),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? Colors.white
                                                  : AppTheme.accentCyan,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        if (hasCompleted)
                                          Container(
                                            width: 5,
                                            height: 5,
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 1),
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

              const SizedBox(height: 24),

              // ==========================================
              // NEW PRODUCTIVITY ENHANCEMENTS BELOW CALENDAR
              // ==========================================

              // FEATURE 1: Selected Day Summary
              _buildSelectedDaySummary(),

              const SizedBox(height: 24),

              // FEATURE 2: Daily Schedule Timeline
              _buildDailyTimeline(),

              const SizedBox(height: 24),

              // FEATURE 3: Monthly Productivity Heatmap
              _buildMonthlyHeatmap(),

              const SizedBox(height: 80), // Bottom Spacing for Navigation Bar
            ],
          ),
        ),
      ),
    );
  }

  /// FEATURE 1: Selected Day Summary Card
  Widget _buildSelectedDaySummary() {
    final dayTasks = _selectedDayTasks;
    final total = dayTasks.length;
    final completed = dayTasks.where((t) => t.isCompleted).length;
    final pending = dayTasks.where((t) => !t.isCompleted).length;
    final rate = total == 0 ? 0 : ((completed / total) * 100).round();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardNavy,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryPurple.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.accentCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: AppTheme.accentCyan,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DAY SUMMARY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.accentCyan,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      _formatSelectedDateTitle(_selectedDate),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textWhite,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '$rate% Done',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textWhite,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricPill('Total', '$total', AppTheme.textWhite),
              Container(width: 1, height: 24, color: Colors.white10),
              _buildMetricPill(
                  'Completed', '$completed', AppTheme.successGreen),
              Container(width: 1, height: 24, color: Colors.white10),
              _buildMetricPill('Pending', '$pending', AppTheme.warningOrange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// FEATURE 2: Daily Schedule Timeline
  Widget _buildDailyTimeline() {
    final dayTasks = List<TaskItem>.from(_selectedDayTasks);
    dayTasks.sort((a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Daily Schedule Timeline',
          badgeText: '${dayTasks.length} Items',
        ),
        const SizedBox(height: 12),
        if (dayTasks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppTheme.cardNavy.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.event_available_rounded,
                  size: 38,
                  color: AppTheme.accentCyan,
                ),
                const SizedBox(height: 10),
                Text(
                  'No reminders scheduled for ${_formatSelectedDateTitle(_selectedDate)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textWhite,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Use New Task in the navigation bar to create a reminder.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: dayTasks.length,
            itemBuilder: (context, index) {
              final task = dayTasks[index];
              final isLast = index == dayTasks.length - 1;
              final priorityColor = _getPriorityColor(task.priority);

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Time Label Column
                    SizedBox(
                      width: 65,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          task.formattedTime,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: task.isCompleted
                                ? AppTheme.textMuted
                                : AppTheme.accentCyan,
                          ),
                        ),
                      ),
                    ),

                    // Timeline Indicator Line & Dot Column
                    Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: task.isCompleted
                                ? AppTheme.successGreen
                                : priorityColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (task.isCompleted
                                        ? AppTheme.successGreen
                                        : priorityColor)
                                    .withValues(alpha: 0.5),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color:
                                  AppTheme.primaryPurple.withValues(alpha: 0.3),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),

                    // Timeline Task Card Box
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: task.isCompleted
                              ? AppTheme.cardNavy.withValues(alpha: 0.5)
                              : AppTheme.cardNavy,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: task.isCompleted
                                ? Colors.white10
                                : AppTheme.primaryPurple
                                    .withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentCyan
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    task.category,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.accentCyan,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color:
                                        priorityColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${task.priority} Priority',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: priorityColor,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => _toggleTaskCompletion(task),
                                  child: Icon(
                                    task.isCompleted
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    size: 20,
                                    color: task.isCompleted
                                        ? AppTheme.successGreen
                                        : AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              task.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: task.isCompleted
                                    ? AppTheme.textMuted
                                    : AppTheme.textWhite,
                                decoration: task.isCompleted
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (task.description.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                task.description,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  /// FEATURE 3: Monthly Productivity Heatmap
  Widget _buildMonthlyHeatmap() {
    final daysInMonth =
        DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final monthName = _months[_focusedMonth.month - 1];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardNavy,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryPurple.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.grid_on_rounded,
                  color: AppTheme.accentCyan,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MONTHLY ACTIVITY HEATMAP',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.accentCyan,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      '$monthName ${_focusedMonth.year} Productivity',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textWhite,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Heatmap Grid View
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.1,
            ),
            itemBuilder: (context, index) {
              final dayNum = index + 1;
              final date =
                  DateTime(_focusedMonth.year, _focusedMonth.month, dayNum);
              final count = _getCompletedCountForDate(date);
              final isSelected = _isSameDay(date, _selectedDate);

              Color cellColor = AppTheme.darkBackground;
              if (count == 1) {
                cellColor = AppTheme.primaryPurple.withValues(alpha: 0.35);
              } else if (count == 2) {
                cellColor = AppTheme.accentCyan.withValues(alpha: 0.55);
              } else if (count >= 3) {
                cellColor = AppTheme.accentCyan;
              }

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedDate = date;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: cellColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? Colors.white
                          : (count > 0
                              ? AppTheme.accentCyan.withValues(alpha: 0.4)
                              : Colors.white10),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$dayNum',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: count > 0 || isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: count >= 3
                            ? Colors.black
                            : (count > 0 || isSelected
                                ? Colors.white
                                : AppTheme.textMuted),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),

          // Heatmap Legend Row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                'Less',
                style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
              ),
              const SizedBox(width: 6),
              _buildLegendBox(AppTheme.darkBackground, '0'),
              const SizedBox(width: 4),
              _buildLegendBox(
                  AppTheme.primaryPurple.withValues(alpha: 0.35), '1'),
              const SizedBox(width: 4),
              _buildLegendBox(AppTheme.accentCyan.withValues(alpha: 0.55), '2'),
              const SizedBox(width: 4),
              _buildLegendBox(AppTheme.accentCyan, '3+'),
              const SizedBox(width: 6),
              const Text(
                'More Completed',
                style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendBox(Color color, String label) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white10),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: color == AppTheme.accentCyan ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
