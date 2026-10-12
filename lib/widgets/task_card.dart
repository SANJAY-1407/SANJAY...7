import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/task_item.dart';

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
          onTap: onEditTask,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Interactive Checkbox
                GestureDetector(
                  onTap: onToggleCompleted,
                  behavior: HitTestBehavior.opaque,
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
                            Icons.check_rounded,
                            size: 18,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 14),

                // Category Icon
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(),
                    size: 20,
                    color: AppTheme.accentCyan,
                  ),
                ),
                const SizedBox(width: 14),

                // Title & Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Overdue Indicator Chip
                      if (task.isOverdue) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.urgentRed.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.urgentRed.withValues(alpha: 0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline_rounded, size: 11, color: AppTheme.urgentRed),
                              SizedBox(width: 4),
                              Text(
                                'OVERDUE',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.urgentRed,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: task.isOverdue ? AppTheme.urgentRed : AppTheme.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            task.isToday
                                ? task.formattedTime
                                : '${task.formattedDate} • ${task.formattedTime}',
                            style: TextStyle(
                              fontSize: 12,
                              color: task.isOverdue ? AppTheme.urgentRed : AppTheme.textMuted,
                              fontWeight: task.isOverdue ? FontWeight.w600 : FontWeight.normal,
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

                // Priority Badge & Actions (Edit / Delete)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: priorityColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        task.priority,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: priorityColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          color: AppTheme.textMuted.withValues(alpha: 0.7),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: onEditTask,
                          tooltip: 'Edit Task',
                        ),
                        if (onDeleteTask != null) ...[
                          const SizedBox(width: 10),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18),
                            color: AppTheme.urgentRed.withValues(alpha: 0.8),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: onDeleteTask,
                            tooltip: 'Delete Task',
                          ),
                        ],
                      ],
                    ),
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
