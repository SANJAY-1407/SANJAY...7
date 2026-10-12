import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/task_item.dart';
import '../services/database_helper.dart';
import '../widgets/animated_entry.dart';
import '../widgets/empty_state.dart';
import '../widgets/progress_card.dart';
import '../widgets/section_header.dart';
import '../widgets/task_card.dart';
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

  // In-memory task collection loaded from SQLite
  List<TaskItem> _tasks = [];
  bool _isLoading = true;

  // Day 4 & Day 5 Filter and Sort States
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

  /// Retrieve persistent tasks from SQLite database
  Future<void> _loadTasksFromDatabase() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await DatabaseHelper.instance.seedInitialTasksIfEmpty();
      final loadedTasks = await DatabaseHelper.instance.getAllTasks();

      if (mounted) {
        setState(() {
          _tasks = loadedTasks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
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
  }

  // Statistics calculated ONLY from Today's calendar date tasks
  List<TaskItem> get _todayTasks {
    return _tasks.where((t) => t.isToday).toList();
  }

  int get _totalTodayCount => _todayTasks.length;
  int get _completedTodayCount => _todayTasks.where((t) => t.isCompleted).length;
  int get _pendingTodayCount => _todayTasks.where((t) => !t.isCompleted).length;

  // Filtered and Sorted task list for UI view
  List<TaskItem> get _displayedTasks {
    List<TaskItem> list = List.from(_tasks);

    // 1. Status Filter
    switch (_statusFilter) {
      case StatusFilter.pending:
        list = list.where((t) => !t.isCompleted).toList();
        break;
      case StatusFilter.completed:
        list = list.where((t) => t.isCompleted).toList();
        break;
      case StatusFilter.overdue:
        list = list.where((t) => t.isOverdue).toList();
        break;
      case StatusFilter.all:
        break;
    }

    // 2. Category Filter
    if (_categoryFilter != 'All') {
      list = list.where((t) => t.category == _categoryFilter).toList();
    }

    // 3. Sorting
    switch (_sortOption) {
      case SortOption.priority:
        list.sort((a, b) => b.priorityWeight.compareTo(a.priorityWeight));
        break;
      case SortOption.recentlyCreated:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.dateTime:
        list.sort((a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime));
        break;
    }

    return list;
  }

  bool get _hasActiveFilters =>
      _statusFilter != StatusFilter.all || _categoryFilter != 'All';

  void _resetFilters() {
    setState(() {
      _statusFilter = StatusFilter.all;
      _categoryFilter = 'All';
      _sortOption = SortOption.dateTime;
    });
  }

  /// Persist completion status toggle to SQLite
  Future<void> _toggleTaskCompletion(TaskItem task) async {
    setState(() {
      task.isCompleted = !task.isCompleted;
    });
    await DatabaseHelper.instance.updateTask(task);
  }

  /// Delete a task by ID from SQLite after confirmation
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
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textMuted),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
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

  /// Persist new task to SQLite
  Future<void> _openAddTaskScreen() async {
    final newTask = await Navigator.push<TaskItem>(
      context,
      MaterialPageRoute(
        builder: (context) => const TaskFormScreen(),
      ),
    );

    if (newTask != null) {
      await DatabaseHelper.instance.insertTask(newTask);
      await _loadTasksFromDatabase();

      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Task "${newTask.title}" saved to database!'),
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

  /// Persist updated task to SQLite
  Future<void> _openEditTaskScreen(TaskItem task) async {
    final updatedTask = await Navigator.push<TaskItem>(
      context,
      MaterialPageRoute(
        builder: (context) => TaskFormScreen(initialTask: task),
      ),
    );

    if (updatedTask != null) {
      await DatabaseHelper.instance.updateTask(updatedTask);
      await _loadTasksFromDatabase();

      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.task_alt_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Task "${updatedTask.title}" updated in database!'),
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
            _buildPlaceholderView('Calendar Schedule', Icons.calendar_month_rounded),
            _buildPlaceholderView('Productivity Insights', Icons.insights_rounded),
            _buildPlaceholderView('App Settings', Icons.settings_rounded),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTaskScreen,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New Task',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentBottomNavIndex,
        onTap: (index) {
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
            icon: Icon(Icons.calendar_today_rounded),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Insights',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
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
            CircularProgressIndicator(color: AppTheme.accentCyan),
            SizedBox(height: 16),
            Text(
              'Loading persistent tasks...',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    final displayedList = _displayedTasks;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                            color: AppTheme.primaryPurple.withValues(alpha: 0.4),
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

          // 2. Greeting Header
          const AnimatedEntry(
            index: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome Back! 👋',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textWhite,
                  ),
                ),
                SizedBox(height: 4),
                Text(
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

          // 3. Dynamic Today Statistics Card
          AnimatedEntry(
            index: 2,
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
              title: _hasActiveFilters ? 'Filtered Tasks' : 'All Scheduled Tasks',
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
                message: 'Your task database is empty. Tap below to create your first persistent task.',
                onAction: _openAddTaskScreen,
              ),
            )
          else if (displayedList.isEmpty)
            AnimatedEntry(
              index: 5,
              child: EmptyState(
                title: 'No Matching Tasks 🔍',
                message: 'No tasks match your selected filter criteria. Try resetting filters.',
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
                  child: TaskCard(
                    task: task,
                    onToggleCompleted: () => _toggleTaskCompletion(task),
                    onEditTask: () => _openEditTaskScreen(task),
                    onDeleteTask: () => _confirmDeleteTask(task),
                  ),
                );
              },
            ),

          const SizedBox(height: 80), // FAB Bottom Spacing
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
          // Row 1: Status Filter Chips & Sort Popup Menu
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sort_rounded, size: 16, color: AppTheme.accentCyan),
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
                    child: Text('Sort by Date & Time', style: TextStyle(color: Colors.white)),
                  ),
                  const PopupMenuItem(
                    value: SortOption.priority,
                    child: Text('Sort by Priority', style: TextStyle(color: Colors.white)),
                  ),
                  const PopupMenuItem(
                    value: SortOption.recentlyCreated,
                    child: Text('Sort by Recently Created', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 2: Status Filter Segmented Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildStatusFilterChip(StatusFilter.all, 'All'),
                const SizedBox(width: 8),
                _buildStatusFilterChip(StatusFilter.pending, 'Pending'),
                const SizedBox(width: 8),
                _buildStatusFilterChip(StatusFilter.completed, 'Completed'),
                const SizedBox(width: 8),
                _buildStatusFilterChip(StatusFilter.overdue, 'Overdue ⚠️'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Row 3: Category Dropdown Selector
          Row(
            children: [
              const Icon(Icons.category_rounded, size: 16, color: AppTheme.textMuted),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
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
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.accentCyan),
                      isExpanded: true,
                      style: const TextStyle(color: AppTheme.textWhite, fontSize: 13),
                      items: _categories.map((cat) {
                        return DropdownMenuItem<String>(
                          value: cat,
                          child: Text(cat),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
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

  Widget _buildStatusFilterChip(StatusFilter filter, String label) {
    final isSelected = _statusFilter == filter;
    final isOverdue = filter == StatusFilter.overdue;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
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

  Widget _buildPlaceholderView(String title, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppTheme.cardNavy,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primaryPurple.withValues(alpha: 0.35),
              ),
            ),
            child: Icon(
              icon,
              size: 48,
              color: AppTheme.accentCyan,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textWhite,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This screen will be expanded in upcoming days!',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
