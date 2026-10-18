import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/task_item.dart';

class PremiumDonutChartCard extends StatefulWidget {
  final List<TaskItem> tasks;

  const PremiumDonutChartCard({
    super.key,
    required this.tasks,
  });

  @override
  State<PremiumDonutChartCard> createState() => _PremiumDonutChartCardState();
}

class _PremiumDonutChartCardState extends State<PremiumDonutChartCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _chartAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _chartAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant PremiumDonutChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tasks.length != widget.tasks.length ||
        oldWidget.tasks != widget.tasks) {
      _animController.reset();
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.tasks.length;
    final completed = widget.tasks.where((t) => t.isCompleted).length;
    final overdue = widget.tasks.where((t) => t.isOverdue).length;
    final pending = widget.tasks.where((t) => !t.isCompleted && !t.isOverdue).length;

    final completedPct = total == 0 ? 0 : ((completed / total) * 100).round();
    final pendingPct = total == 0 ? 0 : ((pending / total) * 100).round();
    final overduePct = total == 0 ? 0 : ((overdue / total) * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardNavy,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.primaryPurple.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.donut_large_rounded,
                  color: AppTheme.accentCyan,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Task Status Breakdown',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textWhite,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Animated Donut Chart with Center Statistics
          Center(
            child: SizedBox(
              width: 180,
              height: 180,
              child: AnimatedBuilder(
                animation: _chartAnimation,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(180, 180),
                        painter: _DonutChartPainter(
                          completed: completed,
                          pending: pending,
                          overdue: overdue,
                          total: total,
                          progress: _chartAnimation.value,
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$total',
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textWhite,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Total Tasks',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accentCyan.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.accentCyan.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              '$completedPct% Done',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentCyan,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Status Summary Cards Row
          Row(
            children: [
              Expanded(
                child: _buildStatusCard(
                  label: 'Completed',
                  count: completed,
                  percentage: completedPct,
                  icon: Icons.check_circle_rounded,
                  color: AppTheme.successGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusCard(
                  label: 'Pending',
                  count: pending,
                  percentage: pendingPct,
                  icon: Icons.pending_actions_rounded,
                  color: AppTheme.warningOrange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusCard(
                  label: 'Overdue',
                  count: overdue,
                  percentage: overduePct,
                  icon: Icons.error_outline_rounded,
                  color: AppTheme.urgentRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard({
    required String label,
    required int count,
    required int percentage,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$percentage%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final int completed;
  final int pending;
  final int overdue;
  final int total;
  final double progress;

  _DonutChartPainter({
    required this.completed,
    required this.pending,
    required this.overdue,
    required this.total,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 24) / 2;
    const strokeWidth = 16.0;

    // Draw Background Track Ring
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    if (total == 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);

    final completedRatio = (completed / total);
    final pendingRatio = (pending / total);
    final overdueRatio = (overdue / total);

    const double gapAngle = 0.08; // Small gap between segments
    double startAngle = -math.pi / 2;

    void drawSegment(double ratio, Color color) {
      if (ratio <= 0) return;

      final sweepAngle = (ratio * 2 * math.pi - gapAngle) * progress;
      if (sweepAngle <= 0) return;

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startAngle + (gapAngle / 2), sweepAngle, false, paint);
      startAngle += (ratio * 2 * math.pi) * progress;
    }

    // Draw Completed Arc (Turquoise / Green)
    drawSegment(completedRatio, AppTheme.successGreen);

    // Draw Pending Arc (Amber / Orange)
    drawSegment(pendingRatio, AppTheme.warningOrange);

    // Draw Overdue Arc (Coral / Red)
    drawSegment(overdueRatio, AppTheme.urgentRed);
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.completed != completed ||
        oldDelegate.pending != pending ||
        oldDelegate.overdue != overdue ||
        oldDelegate.total != total;
  }
}
