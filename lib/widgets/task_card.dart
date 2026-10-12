import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class TaskCard extends StatelessWidget {
  final String title;
  final String category;
  final String time;
  final String priority;
  final bool isCompleted;
  final VoidCallback onToggle;
  final VoidCallback? onTap;

  const TaskCard({
    super.key,
    required this.title,
    required this.category,
    required this.time,
    required this.priority,
    required this.isCompleted,
    required this.onToggle,
    this.onTap,
  });

  Color _getPriorityColor() {
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

  IconData _getCategoryIcon() {
    switch (category.toLowerCase()) {
      case 'college':
      case 'study':
        return Icons.school_rounded;
      case 'coding':
      case 'dev':
        return Icons.code_rounded;
      case 'work':
        return Icons.work_rounded;
      case 'health':
      case 'fitness':
        return Icons.fitness_center_rounded;
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
        color: isCompleted
            ? AppTheme.cardNavy.withValues(alpha: 0.45)
            : AppTheme.cardNavy,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted
              ? Colors.white.withValues(alpha: 0.05)
              : AppTheme.primaryPurple.withValues(alpha: 0.25),
        ),
        boxShadow: [
          if (!isCompleted)
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
          onTap: onTap ?? onToggle,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onToggle,
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isCompleted ? AppTheme.primaryGradient : null,
                      color: isCompleted ? null : Colors.transparent,
                      border: Border.all(
                        color: isCompleted
                            ? Colors.transparent
                            : AppTheme.textMuted,
                        width: 2,
                      ),
                    ),
                    child: isCompleted
                        ? const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 14),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isCompleted
                              ? AppTheme.textMuted
                              : AppTheme.textWhite,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationColor: AppTheme.textMuted,
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
                            time,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            category,
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
                    priority,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: priorityColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
