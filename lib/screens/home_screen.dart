import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class TaskItem {
  final String id;
  final String title;
  final String category;
  final String time;
  final String priority;
  bool isCompleted;

  TaskItem({
    required this.id,
    required this.title,
    required this.category,
    required this.time,
    required this.priority,
    this.isCompleted = false,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentBottomNavIndex = 0;

  // In-memory sample tasks for Day 1
  final List<TaskItem> _tasks = [
    TaskItem(
      id: '1',
      title: 'Submit Operating Systems Assignment',
      category: 'College',
      time: '10:00 AM',
      priority: 'High',
      isCompleted: false,
    ),
    TaskItem(
      id: '2',
      title: 'Flutter App Architecture Review',
      category: 'Coding',
      time: '02:30 PM',
      priority: 'High',
      isCompleted: true,
    ),
    TaskItem(
      id: '3',
      title: 'Team Standup & Project Discussion',
      category: 'Work',
      time: '04:00 PM',
      priority: 'Medium',
      isCompleted: false,
    ),
    TaskItem(
      id: '4',
      title: 'Evening Fitness & Gym Workout',
      category: 'Health',
      time: '06:30 PM',
      priority: 'Low',
      isCompleted: false,
    ),
    TaskItem(
      id: '5',
      title: 'Read 15 Pages of Technical Docs',
      category: 'Study',
      time: '09:00 PM',
      priority: 'Low',
      isCompleted: false,
    ),
  ];

  double get _completionPercentage {
    if (_tasks.isEmpty) return 0.0;
    int completedCount = _tasks.where((t) => t.isCompleted).length;
    return completedCount / _tasks.length;
  }

  int get _completedTaskCount => _tasks.where((t) => t.isCompleted).length;

  void _toggleTaskCompletion(int index) {
    setState(() {
      _tasks[index].isCompleted = !_tasks[index].isCompleted;
    });
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return AppTheme.urgentRed;
      case 'Medium':
        return AppTheme.warningOrange;
      case 'Low':
      default:
        return AppTheme.accentCyan;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'College':
        return Icons.school_rounded;
      case 'Coding':
        return Icons.code_rounded;
      case 'Work':
        return Icons.work_rounded;
      case 'Health':
        return Icons.fitness_center_rounded;
      case 'Study':
        return Icons.menu_book_rounded;
      default:
        return Icons.task_alt_rounded;
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
            _buildPlaceholderView('Calendar View', Icons.calendar_month_rounded),
            _buildPlaceholderView('Analytics & Insights', Icons.insights_rounded),
            _buildPlaceholderView('App Settings', Icons.settings_rounded),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white),
                  SizedBox(width: 10),
                  Text('Add Task feature coming in Day 2!'),
                ],
              ),
              backgroundColor: AppTheme.primaryPurple,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
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
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header with App Title & Notification Icon
          Row(
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
                          blurRadius: 10,
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
                    shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
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
          const SizedBox(height: 24),

          // 2. Welcome Heading & Subtitle
          const Text(
            'Hello, IT Student! 👋',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textWhite,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Let\'s accomplish your planned targets today.',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 20),

          // 3. Gradient Daily Progress Card with Circular Indicator
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.cardGradient,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
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
                          color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'DAILY GOAL',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentCyan,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Your Daily Progress',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textWhite,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$_completedTaskCount of ${_tasks.length} tasks completed',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Circular Progress Indicator with Animated Percentage
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: CircularProgressIndicator(
                        value: _completionPercentage,
                        strokeWidth: 8,
                        backgroundColor: AppTheme.darkBackground,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentCyan),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text(
                      '${(_completionPercentage * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textWhite,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 4. Section Heading for Today's Tasks
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Today\'s Tasks',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textWhite,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.cardNavy,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  '${_tasks.length} Tasks',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentCyan,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 5. Today's Task List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _tasks.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final task = _tasks[index];
              return _buildTaskCard(task, index);
            },
          ),
          const SizedBox(height: 80), // Extra padding for Floating Action Button
        ],
      ),
    );
  }

  Widget _buildTaskCard(TaskItem task, int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: task.isCompleted
            ? AppTheme.cardNavy.withValues(alpha: 0.5)
            : AppTheme.cardNavy,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: task.isCompleted
              ? Colors.white10
              : AppTheme.primaryPurple.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          // Checkbox Icon Button with Animation
          GestureDetector(
            onTap: () => _toggleTaskCompletion(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: task.isCompleted ? AppTheme.primaryGradient : null,
                color: task.isCompleted ? null : Colors.transparent,
                border: Border.all(
                  color: task.isCompleted
                      ? Colors.transparent
                      : AppTheme.textMuted,
                  width: 2,
                ),
              ),
              child: task.isCompleted
                  ? const Icon(
                      Icons.check,
                      size: 18,
                      color: Colors.white,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 14),

          // Task Category Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.darkBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getCategoryIcon(task.category),
              size: 20,
              color: AppTheme.accentCyan,
            ),
          ),
          const SizedBox(width: 14),

          // Title & Meta Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: task.isCompleted
                        ? AppTheme.textMuted
                        : AppTheme.textWhite,
                    decoration: task.isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 13,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      task.time,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      task.category,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.accentCyan,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Priority Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getPriorityColor(task.priority).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getPriorityColor(task.priority).withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              task.priority,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: _getPriorityColor(task.priority),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderView(String title, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardNavy,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.3)),
            ),
            child: Icon(
              icon,
              size: 48,
              color: AppTheme.accentCyan,
            ),
          ),
          const SizedBox(height: 16),
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
            'This screen will be implemented in upcoming days!',
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
