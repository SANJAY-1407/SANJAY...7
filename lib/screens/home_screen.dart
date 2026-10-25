import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import '../models/task_item.dart';
import '../services/alarm_service.dart';
import '../services/database_helper.dart';
import '../widgets/animated_entry.dart';
import '../widgets/empty_state.dart';
import '../widgets/progress_card.dart';
import '../widgets/section_header.dart';
import '../widgets/task_card.dart';
import '../widgets/premium_animations.dart';
import '../widgets/premium_line_graph.dart';
import '../widgets/premium_donut_chart.dart';
import 'calendar_screen.dart';
import 'profile_screen.dart';
import 'task_form_screen.dart';
import 'clock_alarm_list_screen.dart';

enum StatusFilter { all, pending, completed, overdue }

enum SortOption { dateTime, priority, recentlyCreated }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
  int _currentBottomNavIndex = 0;

  List<TaskItem> _tasks = [];
  bool _isLoading = true;

  StatusFilter _statusFilter = StatusFilter.all;
  String _categoryFilter = 'All';
  SortOption _sortOption = SortOption.dateTime;

  final List<String> _categories = [
    'All',
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTasksFromDatabase();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isLoading) {
      _refreshAlarmsAfterReturningFromSettings();
    }
  }

  Future<void> _refreshAlarmsAfterReturningFromSettings() async {
    try {
      // The user may have granted exact alarms or notifications in Android
      // Settings while this process was paused. Refresh the capability state
      // and reconcile persisted tasks with the system alarm manager.
      await AlarmService.instance.refreshPermissionStatus();
      await AlarmService.instance.reconcileAllAlarms(_tasks);
    } catch (e) {
      debugPrint('Alarm refresh after app resume failed: $e');
    }
  }

  String get _timeGreeting {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return 'Good Morning! â˜€ï¸';
    } else if (hour < 17) {
      return 'Good Afternoon! ðŸŒ¤ï¸';
    } else {
      return 'Good Evening! ðŸŒ™';
    }
  }

  Future<void> _loadTasksFromDatabase({bool showLoading = true}) async {
    if (!mounted) return;

    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final loadedTasks = await DatabaseHelper.instance.getAllTasks();

      if (!mounted) return;

      setState(() {
        _tasks = loadedTasks;
        _isLoading = false;
      });

      // Preserve alarm reconciliation safely in background
      try {
        await AlarmService.instance.reconcileAllAlarms(loadedTasks);
      } catch (e) {
        debugPrint('Alarm reconciliation error: $e');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading persistent tasks: $e'),
          backgroundColor: AppTheme.urgentRed,
        ),
      );
    }
  }

  List<TaskItem> get _todayTasks {
    return _tasks.where((task) => task.isToday).toList();
  }

  int get _totalTodayCount => _todayTasks.length;

  int get _completedTodayCount =>
      _todayTasks.where((task) => task.isCompleted).length;

  int get _pendingTodayCount =>
      _todayTasks.where((task) => !task.isCompleted).length;

  List<TaskItem> get _displayedTasks {
    List<TaskItem> list = List.from(_tasks);

    switch (_statusFilter) {
      case StatusFilter.pending:
        list = list.where((task) => !task.isCompleted).toList();
        break;

      case StatusFilter.completed:
        list = list.where((task) => task.isCompleted).toList();
        break;

      case StatusFilter.overdue:
        list = list.where((task) => task.isOverdue).toList();
        break;

      case StatusFilter.all:
        break;
    }

    if (_categoryFilter != 'All') {
      list = list.where((task) => task.category == _categoryFilter).toList();
    }

    switch (_sortOption) {
      case SortOption.priority:
        list.sort(
          (a, b) => b.priorityWeight.compareTo(a.priorityWeight),
        );
        break;

      case SortOption.recentlyCreated:
        list.sort(
          (a, b) => b.createdAt.compareTo(a.createdAt),
        );
        break;

      case SortOption.dateTime:
        list.sort(
          (a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime),
        );
        break;
    }

    return list;
  }

  bool get _hasActiveFilters =>
      _statusFilter != StatusFilter.all || _categoryFilter != 'All';

  void _resetFilters() {
    HapticFeedback.lightImpact();

    setState(() {
      _statusFilter = StatusFilter.all;
      _categoryFilter = 'All';
      _sortOption = SortOption.dateTime;
    });
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

    await _loadTasksFromDatabase(showLoading: false);
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
              Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.urgentRed,
              ),
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
            'Are you sure you want to delete "${task.title}"? '
            'This action cannot be undone.',
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context, false);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textMuted),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.urgentRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteTask(task.id);
      try {
        await AlarmService.instance.cancelTaskAlarm(task.id);
      } catch (e) {
        debugPrint('Alarm cancel error: $e');
      }
      await _loadTasksFromDatabase(showLoading: false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task "${task.title}" deleted.'),
          backgroundColor: AppTheme.urgentRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }
  }

  Future<void> _openAddTaskScreen() async {
    final newTask = await Navigator.push<TaskItem>(
      context,
      MaterialPageRoute(
        builder: (context) => const TaskFormScreen(),
      ),
    );

    if (newTask != null) {
      await DatabaseHelper.instance.insertTask(newTask);
      bool alarmScheduled = false;
      try {
        alarmScheduled = await AlarmService.instance.scheduleTaskAlarm(newTask);
      } catch (e) {
        debugPrint('Alarm scheduling error: $e');
      }
      await _loadTasksFromDatabase(showLoading: false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                alarmScheduled
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  alarmScheduled
                      ? 'Task "${newTask.title}" saved and alarm scheduled!'
                      : 'Task saved, but the alarm could not be scheduled. Check notification permissions.',
                ),
              ),
            ],
          ),
          backgroundColor:
              alarmScheduled ? AppTheme.primaryPurple : AppTheme.warningOrange,
          action: alarmScheduled
              ? null
              : SnackBarAction(
                  label: 'Enable',
                  textColor: Colors.white,
                  onPressed: () {
                    _requestPermissionsAndReschedule(newTask);
                  },
                ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }
  }

  Future<void> _openEditTaskScreen(TaskItem task) async {
    final updatedTask = await Navigator.push<TaskItem>(
      context,
      MaterialPageRoute(
        builder: (context) => TaskFormScreen(initialTask: task),
      ),
    );

    if (updatedTask != null) {
      await DatabaseHelper.instance.updateTask(updatedTask);
      bool alarmScheduled = false;
      try {
        alarmScheduled =
            await AlarmService.instance.scheduleTaskAlarm(updatedTask);
      } catch (e) {
        debugPrint('Alarm scheduling error: $e');
      }
      await _loadTasksFromDatabase(showLoading: false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                alarmScheduled
                    ? Icons.task_alt_rounded
                    : Icons.warning_amber_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  alarmScheduled
                      ? 'Task "${updatedTask.title}" updated and alarm rescheduled!'
                      : 'Task updated, but the alarm could not be scheduled. Check notification permissions.',
                ),
              ),
            ],
          ),
          backgroundColor:
              alarmScheduled ? AppTheme.primaryPurple : AppTheme.warningOrange,
          action: alarmScheduled
              ? null
              : SnackBarAction(
                  label: 'Enable',
                  textColor: Colors.white,
                  onPressed: () {
                    _requestPermissionsAndReschedule(updatedTask);
                  },
                ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }
  }

  Future<void> _requestPermissionsAndReschedule(TaskItem task) async {
    await AlarmService.instance.requestAlarmPermissions();
    final scheduled = await AlarmService.instance.scheduleTaskAlarm(task);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          scheduled
              ? 'Alarm permission enabled and alarm scheduled.'
              : 'Alarm is still not scheduled. Check Android notification and alarm permissions.',
        ),
        backgroundColor:
            scheduled ? AppTheme.primaryPurple : AppTheme.warningOrange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentBottomNavIndex == 4
              ? 3
              : (_currentBottomNavIndex == 3 ? 2 : _currentBottomNavIndex),
          children: [
            _buildDashboardView(),
            CalendarScreen(
              tasks: _tasks,
              onRefreshTasks: _loadTasksFromDatabase,
            ),
            _buildInsightsView(),
            ProfileScreen(
              tasks: _tasks,
              onRefreshTasks: _loadTasksFromDatabase,
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentBottomNavIndex,
        onDestinationSelected: (index) {
          HapticFeedback.selectionClick();
          if (index == 2) {
            _openAddTaskScreen();
            return;
          }
          setState(() => _currentBottomNavIndex = index);
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today_rounded),
              label: 'Calendar'),
          NavigationDestination(
              icon: Icon(Icons.add_rounded),
              selectedIcon: Icon(Icons.add_rounded),
              label: 'New task'),
          NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: 'Insights'),
          NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildDashboardView() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppTheme.accentCyan,
            ),
            SizedBox(height: 16),
            Text(
              'Loading persistent tasks & alarms...',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final displayedList = _displayedTasks;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Branding Header
          AnimatedEntry(
            index: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryPurple.withValues(
                              alpha: 0.4,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.alarm_on_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          AppTheme.primaryGradient.createShader(bounds),
                      child: const Text(
                        'AlertBox',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Clock Alarms',
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ClockAlarmListScreen(),
                          ),
                        );
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.cardNavy,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.accentCyan.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Icon(
                          Icons.alarm_rounded,
                          color: AppTheme.accentCyan,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No new notifications'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.cardNavy,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Icon(
                          Icons.notifications_active_outlined,
                          color: AppTheme.textWhite,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 2. Time-Appropriate Greeting Header
          AnimatedEntry(
            index: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _timeGreeting,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textWhite,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Let\'s organize and accomplish your targets today.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Clock Alarms Quick-Access Card
          AnimatedEntry(
            index: 2,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ClockAlarmListScreen(),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.cardNavy,
                      AppTheme.cardNavy.withValues(alpha: 0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppTheme.accentCyan.withValues(alpha: 0.25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentCyan.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.alarm_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Clock Alarms',
                                style: TextStyle(
                                  color: AppTheme.textWhite,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 12,
                                color: AppTheme.accentCyan,
                              ),
                            ],
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Wake-up alarms, weekday repeats & snooze',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.accentCyan,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Today Statistics + NEW Premium Animated Progress Ring
          AnimatedEntry(
            index: 3,
            child: ProgressCard(
              totalTasks: _totalTodayCount,
              completedTasks: _completedTodayCount,
              pendingTasks: _pendingTodayCount,
            ),
          ),

          const SizedBox(height: 24),

          // 4. Filter & Sorting Controls
          AnimatedEntry(
            index: 3,
            child: _buildFilterAndSortBar(),
          ),

          const SizedBox(height: 20),

          // 5. Tasks Section Header
          AnimatedEntry(
            index: 4,
            child: SectionHeader(
              title:
                  _hasActiveFilters ? 'Filtered Tasks' : 'All Scheduled Tasks',
              badgeText: '${displayedList.length} Items',
              actionLabel: _hasActiveFilters ? 'Clear Filters' : null,
              onActionPressed: _hasActiveFilters ? _resetFilters : null,
            ),
          ),

          const SizedBox(height: 14),

          // 6. Task List or Custom Empty State
          if (_tasks.isEmpty)
            AnimatedEntry(
              index: 5,
              child: EmptyState(
                title: 'No Tasks Found! ðŸ“',
                message:
                    'Your saved task list is empty. Use New Task in the navigation bar when you are ready to begin.',
              ),
            )
          else if (displayedList.isEmpty)
            AnimatedEntry(
              index: 5,
              child: EmptyState(
                title: 'No Matching Tasks ðŸ”',
                message:
                    'No tasks match your selected filter criteria. Try resetting filters.',
                actionLabel: 'Reset Filters',
                onAction: _resetFilters,
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayedList.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final task = displayedList[index];

                return AnimatedEntry(
                  index: index + 5,
                  child: AnimatedTaskCard(
                    child: TaskCard(
                      task: task,
                      onToggleCompleted: () => _toggleTaskCompletion(task),
                      onEditTask: () => _openEditTaskScreen(task),
                      onDeleteTask: () => _confirmDeleteTask(task),
                    ),
                  ),
                );
              },
            ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildFilterAndSortBar() {
    return Container(
      padding: const EdgeInsets.all(14),
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
          // Row 1: Filter Chips & Sort Popup Menu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'FILTERS & SORT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentCyan,
                  letterSpacing: 1,
                ),
              ),
              PopupMenuButton<SortOption>(
                initialValue: _sortOption,
                onSelected: (option) {
                  HapticFeedback.selectionClick();

                  setState(() {
                    _sortOption = option;
                  });
                },
                color: AppTheme.cardNavy,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Colors.white12),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.sort_rounded,
                        size: 16,
                        color: AppTheme.accentCyan,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getSortLabel(_sortOption),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textWhite,
                        ),
                      ),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: SortOption.dateTime,
                    child: Text(
                      'Sort by Date & Time',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const PopupMenuItem(
                    value: SortOption.priority,
                    child: Text(
                      'Sort by Priority',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const PopupMenuItem(
                    value: SortOption.recentlyCreated,
                    child: Text(
                      'Sort by Recently Created',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Row 2: Status Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildStatusFilterChip(StatusFilter.all, 'All'),
                const SizedBox(width: 8),
                _buildStatusFilterChip(StatusFilter.pending, 'Pending'),
                const SizedBox(width: 8),
                _buildStatusFilterChip(
                  StatusFilter.completed,
                  'Completed',
                ),
                const SizedBox(width: 8),
                _buildStatusFilterChip(
                  StatusFilter.overdue,
                  'Overdue âš ï¸',
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Row 3: Category Dropdown
          Row(
            children: [
              const Icon(
                Icons.category_rounded,
                size: 16,
                color: AppTheme.textMuted,
              ),
              const SizedBox(width: 8),
              const Text(
                'Category:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _categoryFilter != 'All'
                          ? AppTheme.accentCyan
                          : Colors.white10,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _categoryFilter,
                      dropdownColor: AppTheme.cardNavy,
                      icon: const Icon(
                        Icons.arrow_drop_down_rounded,
                        color: AppTheme.accentCyan,
                      ),
                      isExpanded: true,
                      style: const TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 13,
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          HapticFeedback.selectionClick();

                          setState(() {
                            _categoryFilter = value;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(
    StatusFilter filter,
    String label,
  ) {
    final isSelected = _statusFilter == filter;
    final isOverdue = filter == StatusFilter.overdue;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          HapticFeedback.selectionClick();

          setState(() {
            _statusFilter = filter;
          });
        }
      },
      selectedColor: isOverdue ? AppTheme.urgentRed : AppTheme.primaryPurple,
      backgroundColor: AppTheme.darkBackground,
      labelStyle: TextStyle(
        fontSize: 12,
        color: isSelected ? Colors.white : AppTheme.textMuted,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? (isOverdue ? AppTheme.urgentRed : AppTheme.accentCyan)
              : Colors.white10,
        ),
      ),
    );
  }

  String _getSortLabel(SortOption option) {
    switch (option) {
      case SortOption.priority:
        return 'Priority';

      case SortOption.recentlyCreated:
        return 'Recent';

      case SortOption.dateTime:
        return 'Date & Time';
    }
  }

  // Premium Productivity Insights Dashboard (Replacing Placeholder)
  Widget _buildInsightsView() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accentCyan),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header
          AnimatedEntry(
            index: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.insights_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Productivity Insights',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textWhite,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Understand your progress and build better habits.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Weekly Productivity Bar Chart
          AnimatedEntry(
            index: 1,
            child: _buildWeeklyProductivityCard(),
          ),
          const SizedBox(height: 20),

          // 3. Animated Task Status Breakdown
          AnimatedEntry(
            index: 2,
            child: PremiumDonutChartCard(tasks: _tasks),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildWeeklyProductivityCard() {
    final now = DateTime.now();
    final currentWeekday = now.weekday; // 1 = Mon, 7 = Sun
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: currentWeekday - 1));

    final dailyCompleted = List<int>.filled(7, 0);

    for (int i = 0; i < 7; i++) {
      final dayDate = monday.add(Duration(days: i));
      final count = _tasks.where((t) {
        if (!t.isCompleted) return false;
        if (t.completedAt != null) {
          return t.completedAt!.year == dayDate.year &&
              t.completedAt!.month == dayDate.month &&
              t.completedAt!.day == dayDate.day;
        }
        return t.scheduledDateTime.year == dayDate.year &&
            t.scheduledDateTime.month == dayDate.month &&
            t.scheduledDateTime.day == dayDate.day;
      }).length;

      dailyCompleted[i] = count;
    }

    final sunday = monday.add(const Duration(days: 6));
    final weekRangeText =
        '${monday.day}/${monday.month} - ${sunday.day}/${sunday.month}';

    return PremiumLineGraph(
      dailyCompleted: dailyCompleted,
      weekRangeText: weekRangeText,
      currentWeekday: currentWeekday,
    );
  }
}
