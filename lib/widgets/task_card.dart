import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/task_item.dart';

class TaskCard extends StatelessWidget {
  final TaskItem task;
  final VoidCallback onToggleCompleted;
  final VoidCallback onEditTask;
  final VoidCallback? onDeleteTask;

  const TaskCard(
      {super.key,
      required this.task,
      required this.onToggleCompleted,
      required this.onEditTask,
      this.onDeleteTask});

  Color _priorityColor() {
    switch (task.priority.toLowerCase()) {
      case 'high':
        return AppTheme.urgentRed;
      case 'medium':
        return AppTheme.warningOrange;
      default:
        return AppTheme.accentCyan;
    }
  }

  Color _categoryColor() {
    switch (task.category.toLowerCase()) {
      case 'work':
        return AppTheme.categoryWork;
      case 'study':
        return AppTheme.categoryStudy;
      case 'health':
      case 'fitness':
        return AppTheme.categoryHealth;
      case 'shopping':
        return AppTheme.categoryShopping;
      case 'bills':
        return AppTheme.categoryBills;
      case 'family':
        return AppTheme.categoryFamily;
      default:
        return AppTheme.categoryPersonal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = _priorityColor();
    final categoryColor = _categoryColor();
    final progress = task.isCompleted ? 1.0 : (task.isOverdue ? 0.18 : 0.62);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEditTask,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 13),
          decoration: BoxDecoration(
            color: task.isCompleted
                ? AppTheme.cardNavy.withValues(alpha: .72)
                : AppTheme.cardNavy,
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
            border: Border.all(
                color: task.isOverdue
                    ? AppTheme.urgentRed.withValues(alpha: .55)
                    : Colors.white.withValues(alpha: .06)),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Text(task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: task.isCompleted
                              ? AppTheme.textMuted
                              : AppTheme.textWhite,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null))),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.more_horiz_rounded,
                    color: AppTheme.textMuted, size: 20),
                color: AppTheme.surfaceLight,
                onSelected: (value) {
                  if (value == 'edit') onEditTask();
                  if (value == 'delete') onDeleteTask?.call();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit task')),
                  if (onDeleteTask != null)
                    const PopupMenuItem(
                        value: 'delete', child: Text('Delete task'))
                ],
              ),
            ]),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(task.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            Row(children: [
              _pill(task.priority, priorityColor),
              const SizedBox(width: 7),
              _pill(task.category, categoryColor),
              const Spacer(),
              InkResponse(
                  onTap: onToggleCompleted,
                  radius: 18,
                  child: Icon(
                      task.isCompleted
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: task.isCompleted
                          ? AppTheme.successGreen
                          : AppTheme.textMuted,
                      size: 21)),
            ]),
            const SizedBox(height: 12),
            ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                    minHeight: 3,
                    value: progress,
                    backgroundColor: Colors.white.withValues(alpha: .08),
                    valueColor: AlwaysStoppedAnimation(task.isCompleted
                        ? AppTheme.successGreen
                        : AppTheme.accentCyan))),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.schedule_rounded,
                  size: 13,
                  color:
                      task.isOverdue ? AppTheme.urgentRed : AppTheme.textMuted),
              const SizedBox(width: 5),
              Text(
                  task.isToday
                      ? task.formattedTime
                      : '${task.formattedDate} • ${task.formattedTime}',
                  style: TextStyle(
                      color: task.isOverdue
                          ? AppTheme.urgentRed
                          : AppTheme.textMuted,
                      fontSize: 11)),
              const Spacer(),
              Text(
                  task.isCompleted
                      ? 'Complete'
                      : (task.isOverdue
                          ? 'Overdue'
                          : '${(progress * 100).round()}%'),
                  style: TextStyle(
                      color: task.isCompleted
                          ? AppTheme.successGreen
                          : AppTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _pill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      );
}
