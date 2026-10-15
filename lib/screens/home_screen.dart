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
import 'calendar_screen.dart';
import 'profile_screen.dart';
import 'task_form_screen.dart';

enum StatusFilter { all, pending, completed, overdue }

enum SortOption { dateTime, priority, recentlyCreated }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
    _loadTasksFromDatabase();
  }

  String get _timeGreeting {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return 'Good Morning! ☀️';
    } else if (hour < 17) {
      return 'Good Afternoon! 🌤️';
    } else {
      return 'Good Evening! 🌙';
    }
  }

  Future<void> _loadTasksFromDatabase() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await DatabaseHelper.instance.seedInitialTasksIfEmpty();

      final loadedTasks =
      await DatabaseHelper.instance.getAllTasks();

      // Preserve the existing alarm reconciliation.
      await AlarmService.instance.reconcileAllAlarms(loadedTasks);

      if (!mounted) return;

      setState(() {
        _tasks = loadedTasks;
        _isLoading = false;
      });
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
      list = list
          .where((task) => task.category == _categoryFilter)
          .toList();
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
              (a, b) =>
              a.scheduledDateTime.compareTo(b.scheduledDateTime),
        );
        break;
    }

    return list;
  }

  bool get _hasActiveFilters =>
      _statusFilter != StatusFilter.all ||
          _categoryFilter != 'All';

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
    });

    await DatabaseHelper.instance.updateTask(task);

    // Keep the existing alarm scheduling behavior.
    await AlarmService.instance.scheduleTaskAlarm(task);
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
      await AlarmService.instance.cancelTaskAlarm(task.id);
      await _loadTasksFromDatabase();

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
      await AlarmService.instance.scheduleTaskAlarm(newTask);
      await _loadTasksFromDatabase();

      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Task "${newTask.title}" saved and alarm scheduled!',
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.primaryPurple,
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
      await AlarmService.instance.scheduleTaskAlarm(updatedTask);
      await _loadTasksFromDatabase();

      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.task_alt_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Task "${updatedTask.title}" updated and alarm rescheduled!',
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.primaryPurple,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentBottomNavIndex,
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

      floatingActionButton: _currentBottomNavIndex == 0
          ? PremiumAddButton(
        onPressed: _openAddTaskScreen,
        label: 'New Task',
      )
          : null,

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentBottomNavIndex,
        onTap: (index) {
          HapticFeedback.selectionClick();

          setState(() {
            _currentBottomNavIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_rounded),
            activeIcon: Icon(Icons.calendar_month_rounded),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Insights',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
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
                        'TaskAlert',
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

          // 3. Today Statistics + NEW Premium Animated Progress Ring
          AnimatedEntry(
            index: 2,
            child: Column(
              children: [
                ProgressCard(
                  totalTasks: _totalTodayCount,
                  completedTasks: _completedTodayCount,
                  pendingTasks: _pendingTodayCount,
                ),
                const SizedBox(height: 18),
                Center(
                  child: PremiumProgressRing(
                    progress: _totalTodayCount == 0
                        ? 0.0
                        : _completedTodayCount / _totalTodayCount,
                    size: 110,
                  ),
                ),
              ],
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
              title: _hasActiveFilters
                  ? 'Filtered Tasks'
                  : 'All Scheduled Tasks',
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
                title: 'No Tasks Found! 📝',
                message:
                'Your task database is empty. Tap below to create your first alarm task.',
                onAction: _openAddTaskScreen,
              ),
            )
          else if (displayedList.isEmpty)
            AnimatedEntry(
              index: 5,
              child: EmptyState(
                title: 'No Matching Tasks 🔍',
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
              separatorBuilder: (context, index) =>
              const SizedBox(height: 12),
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
                  'Overdue ⚠️',
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
      selectedColor:
      isOverdue ? AppTheme.urgentRed : AppTheme.primaryPurple,
      backgroundColor: AppTheme.darkBackground,
      labelStyle: TextStyle(
        fontSize: 12,
        color: isSelected ? Colors.white : AppTheme.textMuted,
        fontWeight:
        isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? (isOverdue
              ? AppTheme.urgentRed
              : AppTheme.accentCyan)
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

    final totalCount = _tasks.length;
    final completedCount = _tasks.where((t) => t.isCompleted).length;
    final pendingCount = _tasks.where((t) => !t.isCompleted).length;
    final overdueCount = _tasks.where((t) => t.isOverdue).length;
    final completionRate = totalCount == 0
        ? 0
        : ((completedCount / totalCount) * 100).round();

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

          // 2. Productivity Overview Cards (Feature 1)
          AnimatedEntry(
            index: 1,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildInsightStatCard(
                        label: 'Total Tasks',
                        value: '$totalCount',
                        icon: Icons.assignment_outlined,
                        color: AppTheme.accentCyan,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInsightStatCard(
                        label: 'Completed Tasks',
                        value: '$completedCount',
                        icon: Icons.check_circle_outline_rounded,
                        color: AppTheme.successGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInsightStatCard(
                        label: 'Pending Tasks',
                        value: '$pendingCount',
                        icon: Icons.pending_actions_rounded,
                        color: AppTheme.warningOrange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInsightStatCard(
                        label: 'Completion Rate',
                        value: '$completionRate%',
                        icon: Icons.speed_rounded,
                        color: AppTheme.primaryPurple,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Animated Progress Ring Card (Feature 2)
          AnimatedEntry(
            index: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppTheme.cardGradient,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryPurple.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.primaryPurple.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Text(
                            'OVERALL ACCUMULATION',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.accentCyan,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Task Completion Ratio',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textWhite,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$completedCount of $totalCount total tasks completed',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0.0,
                      end: totalCount == 0 ? 0.0 : (completedCount / totalCount).clamp(0.0, 1.0),
                    ),
                    duration: const Duration(milliseconds: 750),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      final percent = (value * 100).round();
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 76,
                            height: 76,
                            child: CircularProgressIndicator(
                              value: value,
                              strokeWidth: 8,
                              backgroundColor: AppTheme.darkBackground,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentCyan),
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Text(
                            '$percent%',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textWhite,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 4. Weekly Productivity Bar Chart (Feature 3)
          AnimatedEntry(
            index: 3,
            child: _buildWeeklyProductivityCard(),
          ),
          const SizedBox(height: 20),

          // 5. Task Status Breakdown
          AnimatedEntry(
            index: 4,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.cardNavy,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Task Status Breakdown',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textWhite,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 12,
                      child: Row(
                        children: [
                          if (completedCount > 0)
                            Expanded(
                              flex: completedCount,
                              child: Container(color: AppTheme.successGreen),
                            ),
                          if (pendingCount > 0)
                            Expanded(
                              flex: pendingCount,
                              child: Container(color: AppTheme.warningOrange),
                            ),
                          if (overdueCount > 0)
                            Expanded(
                              flex: overdueCount,
                              child: Container(color: AppTheme.urgentRed),
                            ),
                          if (totalCount == 0)
                            Expanded(
                              child: Container(color: Colors.white10),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildBreakdownLegendItem(
                        label: 'Completed',
                        count: completedCount,
                        percentage: totalCount == 0 ? 0 : ((completedCount / totalCount) * 100).round(),
                        color: AppTheme.successGreen,
                      ),
                      _buildBreakdownLegendItem(
                        label: 'Pending',
                        count: pendingCount,
                        percentage: totalCount == 0 ? 0 : ((pendingCount / totalCount) * 100).round(),
                        color: AppTheme.warningOrange,
                      ),
                      _buildBreakdownLegendItem(
                        label: 'Overdue',
                        count: overdueCount,
                        percentage: totalCount == 0 ? 0 : ((overdueCount / totalCount) * 100).round(),
                        color: AppTheme.urgentRed,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 6. Empty State or Motivational Insight
          if (totalCount == 0)
            AnimatedEntry(
              index: 5,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.cardNavy,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.insights_rounded, size: 48, color: AppTheme.accentCyan),
                    SizedBox(height: 12),
                    Text(
                      'No Tasks Found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textWhite,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Add tasks to generate full analytics and track your weekly progress.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            )
          else
            AnimatedEntry(
              index: 5,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryPurple.withValues(alpha: 0.25),
                      AppTheme.cardNavy,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppTheme.accentCyan.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentCyan.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        completionRate == 100
                            ? Icons.emoji_events_rounded
                            : (completionRate >= 50
                                ? Icons.auto_awesome_rounded
                                : Icons.rocket_launch_rounded),
                        size: 28,
                        color: AppTheme.accentCyan,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            completionRate == 100
                                ? 'Target Accomplished! 🎉'
                                : (completionRate >= 50 ? 'Great Progress!' : 'Build Momentum!'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textWhite,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            completionRate == 100
                                ? 'You have completed all scheduled tasks. Excellent work!'
                                : (completionRate >= 50
                                    ? 'You\'re on a roll with $completionRate% completed. Keep it up!'
                                    : 'Complete your pending tasks to boost your daily productivity score.'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildInsightStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardNavy,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
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
              Icon(icon, size: 22, color: color),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyProductivityCard() {
    final now = DateTime.now();
    final currentWeekday = now.weekday; // 1 = Mon, 7 = Sun
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: currentWeekday - 1));

    final weekdaysLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dailyCompleted = List<int>.filled(7, 0);

    for (int i = 0; i < 7; i++) {
      final dayDate = monday.add(Duration(days: i));
      final dayTasks = _tasks.where((t) {
        return t.scheduledDateTime.year == dayDate.year &&
            t.scheduledDateTime.month == dayDate.month &&
            t.scheduledDateTime.day == dayDate.day;
      }).toList();

      dailyCompleted[i] = dayTasks.where((t) => t.isCompleted).length;
    }

    final weeklyCompletedTotal = dailyCompleted.fold(0, (a, b) => a + b);

    int maxInDay = 5;
    for (int val in dailyCompleted) {
      if (val > maxInDay) maxInDay = val;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardNavy,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.primaryPurple.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Weekly Productivity',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textWhite,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'This Week: $weeklyCompletedTotal completed tasks',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.accentCyan,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  '${monday.day}/${monday.month} - ${monday.add(const Duration(days: 6)).day}/${monday.add(const Duration(days: 6)).month}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 130,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final count = dailyCompleted[index];
                final isToday = (index + 1) == currentWeekday;
                final double fillRatio = (count / maxInDay).clamp(0.0, 1.0);

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: count > 0
                            ? (isToday ? AppTheme.accentCyan : Colors.white)
                            : AppTheme.textMuted.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 22,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.darkBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        width: 22,
                        height: 80 * fillRatio,
                        decoration: BoxDecoration(
                          gradient: isToday
                              ? AppTheme.primaryGradient
                              : (count > 0
                                  ? const LinearGradient(
                                      colors: [
                                        AppTheme.accentCyan,
                                        AppTheme.primaryPurple,
                                      ],
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                    )
                                  : null),
                          color: count == 0 ? Colors.white10 : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      weekdaysLabels[index],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        color: isToday ? AppTheme.accentCyan : AppTheme.textMuted,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownLegendItem({
    required String label,
    required int count,
    required int percentage,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$count ($percentage%)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
