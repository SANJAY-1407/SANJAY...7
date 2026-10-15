import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';
import '../models/task_item.dart';
import 'premium_animations.dart';

class TaskCard extends StatelessWidget {
  final TaskItem task;
  final VoidCallback onToggleCompleted;
  final VoidCallback onEditTask;
  final VoidCallback? onDeleteTask;

  const TaskCard({
    super.key,
    required this.task,
    required this.onToggleCompleted,
    required this.onEditTask,
    this.onDeleteTask,
  });

  Color _getPriorityColor() {
    switch (task.priority.toLowerCase()) {
      case 'high':
        return AppTheme.urgentRed;
      case 'medium':
        return AppTheme.warningOrange;
      case 'low':
      default:
        return AppTheme.accentCyan;
    }
  }

  Color _getCategoryColor() {
    switch (task.category.toLowerCase()) {
      case 'personal':
        return const Color(0xFFA855F7); // Purple
      case 'work':
        return const Color(0xFF3B82F6); // Blue
      case 'study':
      case 'college':
        return const Color(0xFF10B981); // Emerald
      case 'health':
      case 'fitness':
        return const Color(0xFFEC4899); // Pink
      case 'shopping':
        return const Color(0xFFF59E0B); // Amber
      case 'meetings':
        return const Color(0xFF06B6D4); // Cyan
      case 'bills':
        return const Color(0xFFEF4444); // Red
      case 'family':
        return const Color(0xFF6366F1); // Indigo
      case 'coding':
        return const Color(0xFF14B8A6); // Teal
      case 'other':
      default:
        return AppTheme.accentCyan;
    }
  }

  IconData _getCategoryIcon() {
    switch (task.category.toLowerCase()) {
      case 'personal':
        return Icons.person_rounded;
      case 'work':
        return Icons.work_rounded;
      case 'study':
      case 'college':
        return Icons.school_rounded;
      case 'health':
        return Icons.favorite_rounded;
      case 'fitness':
        return Icons.fitness_center_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'meetings':
        return Icons.groups_rounded;
      case 'bills':
        return Icons.receipt_long_rounded;
      case 'family':
        return Icons.family_restroom_rounded;
      case 'coding':
        return Icons.code_rounded;
      case 'other':
      default:
        return Icons.task_alt_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = _getPriorityColor();
    final categoryColor = _getCategoryColor();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: task.isCompleted
            ? AppTheme.cardNavy.withValues(alpha: 0.45)
            : AppTheme.cardNavy,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: task.isOverdue
              ? AppTheme.urgentRed.withValues(alpha: 0.6)
              : (task.isCompleted
                  ? Colors.white.withValues(alpha: 0.05)
                  : AppTheme.primaryPurple.withValues(alpha: 0.25)),
          width: task.isOverdue ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (!task.isCompleted)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onEditTask();
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Premium Animated Checkbox
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: PremiumTaskCheckbox(
                    value: task.isCompleted,
                    onChanged: (_) {
                      HapticFeedback.lightImpact();
                      onToggleCompleted();
                    },
                  ),
                ),
                const SizedBox(width: 10),

                // Category Icon
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: categoryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(
                      _getCategoryIcon(),
                      size: 18,
                      color: categoryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Main details column (Expanded & Flexible to prevent overflow)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status & Priority Badge Row (Wrapped to adapt cleanly)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (task.isOverdue)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.urgentRed.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.urgentRed.withValues(alpha: 0.5)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.error_outline_rounded, size: 10, color: AppTheme.urgentRed),
                                  SizedBox(width: 3),
                                  Text(
                                    'OVERDUE',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.urgentRed,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: priorityColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: priorityColor.withValues(alpha: 0.4),
                              ),
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
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Task Title
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: task.isCompleted
                              ? AppTheme.textMuted
                              : AppTheme.textWhite,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationColor: AppTheme.textMuted,
                        ),
                      ),

                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          task.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted.withValues(alpha: 0.8),
                          ),
                        ),
                      ],

                      const SizedBox(height: 8),

                      // Time & Category Metadata Row (Wrapped to avoid spill)
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 12,
                                color: task.isOverdue ? AppTheme.urgentRed : AppTheme.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                task.isToday
                                    ? task.formattedTime
                                    : '${task.formattedDate} • ${task.formattedTime}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: task.isOverdue ? AppTheme.urgentRed : AppTheme.textMuted,
                                  fontWeight: task.isOverdue ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              task.category,
                              style: TextStyle(
                                fontSize: 11,
                                color: categoryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Edit / Delete Action Column
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      color: AppTheme.textMuted.withValues(alpha: 0.8),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        onEditTask();
                      },
                      tooltip: 'Edit Task',
                    ),
                    if (onDeleteTask != null) ...[
                      const SizedBox(height: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        color: AppTheme.urgentRed.withValues(alpha: 0.8),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          onDeleteTask!();
                        },
                        tooltip: 'Delete Task',
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
