import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../widgets/animated_entry.dart';
import '../widgets/empty_state.dart';
import '../widgets/progress_card.dart';
import '../widgets/section_header.dart';
import '../widgets/task_card.dart';

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

  // In-memory sample tasks for Day 2
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

  int get _completedTaskCount => _tasks.where((t) => t.isCompleted).length;

  void _toggleTaskCompletion(int index) {
    setState(() {
      _tasks[index].isCompleted = !_tasks[index].isCompleted;
    });
  }

  void _showAddTaskPlaceholder() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.add_task_rounded, color: Colors.white),
            SizedBox(width: 12),
            Text(
              'Add Task modal coming in Day 3!',
              style: TextStyle(fontWeight: FontWeight.w600),
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
        onPressed: _showAddTaskPlaceholder,
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
          // 1. Header with TaskAlert Branding & Notification Icon
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
          const SizedBox(height: 24),

          // 2. Welcome Greeting & Motivational Subtitle
          const AnimatedEntry(
            index: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, IT Student! 👋',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textWhite,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Let\'s accomplish your planned targets today.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Reusable Progress Card with Animated Counter
          AnimatedEntry(
            index: 2,
            child: ProgressCard(
              completedTasks: _completedTaskCount,
              totalTasks: _tasks.length,
            ),
          ),
          const SizedBox(height: 28),

          // 4. Section Header for Today's Tasks
          AnimatedEntry(
            index: 3,
            child: SectionHeader(
              title: 'Today\'s Tasks',
              badgeText: '${_tasks.length} Tasks',
            ),
          ),
          const SizedBox(height: 16),

          // 5. Today's Task List or Empty State
          if (_tasks.isEmpty)
            AnimatedEntry(
              index: 4,
              child: EmptyState(
                onAction: _showAddTaskPlaceholder,
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _tasks.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final task = _tasks[index];
                return AnimatedEntry(
                  index: index + 4,
                  child: TaskCard(
                    title: task.title,
                    category: task.category,
                    time: task.time,
                    priority: task.priority,
                    isCompleted: task.isCompleted,
                    onToggle: () => _toggleTaskCompletion(index),
                  ),
                );
              },
            ),
          const SizedBox(height: 80), // Extra bottom spacing for FAB
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
