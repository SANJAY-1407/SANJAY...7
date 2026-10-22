import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/task_item.dart';

/// Task status visualization backed entirely by the persisted task list.
/// The public widget name is retained so existing screen wiring stays stable.
class PremiumDonutChartCard extends StatelessWidget {
  final List<TaskItem> tasks;

  const PremiumDonutChartCard({super.key, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final completed = tasks.where((task) => task.isCompleted).length;
    final overdue = tasks.where((task) => task.isOverdue).length;
    final pending = tasks
        .where((task) => !task.isCompleted && !task.isOverdue)
        .length;
    final total = tasks.length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardNavy,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.accentCyan.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bar_chart_rounded,
                    color: AppTheme.accentCyan, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Task Status Breakdown',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textWhite)),
              const Spacer(),
              Text('$total total',
                  style:
                      const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Your current task distribution',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final completedWidth =
                  total == 0 ? 0.0 : maxWidth * completed / total;
              final pendingWidth =
                  total == 0 ? 0.0 : maxWidth * pending / total;
              final overdueWidth =
                  total == 0 ? 0.0 : maxWidth * overdue / total;
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 12,
                  color: Colors.white.withValues(alpha: .07),
                  child: Row(
                    children: [
                      _segment(completedWidth, AppTheme.successGreen),
                      _segment(pendingWidth, AppTheme.warningOrange),
                      _segment(overdueWidth, AppTheme.urgentRed),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child: _statusCard(
                      'Completed',
                      completed,
                      total,
                      AppTheme.successGreen,
                      Icons.check_circle_outline_rounded)),
              const SizedBox(width: 8),
              Expanded(
                  child: _statusCard('Pending', pending, total,
                      AppTheme.warningOrange, Icons.pending_actions_rounded)),
              const SizedBox(width: 8),
              Expanded(
                  child: _statusCard('Overdue', overdue, total,
                      AppTheme.urgentRed, Icons.error_outline_rounded)),
            ],
          ),
          if (total == 0) ...[
            const SizedBox(height: 12),
            const Text('No saved tasks to analyze yet.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _segment(double width, Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      width: width,
      height: 12,
      color: color,
    );
  }

  Widget _statusCard(
      String label, int count, int total, Color color, IconData icon) {
    final percentage = total == 0 ? 0 : ((count / total) * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(height: 7),
          Text('$count',
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.w800)),
          Text('$percentage%',
              style: TextStyle(
                  color: color.withValues(alpha: .8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
        ],
      ),
    );
  }
}
