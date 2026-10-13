import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class ProgressCard extends StatelessWidget {
  final int totalTasks;
  final int completedTasks;
  final int pendingTasks;

  const ProgressCard({
    super.key,
    required this.totalTasks,
    required this.completedTasks,
    required this.pendingTasks,
  });

  double get completionRatio {
    if (totalTasks == 0) return 0.0;
    return (completedTasks / totalTasks).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final double targetPercentage = completionRatio;

    return Container(
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
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
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
                        'TODAY\'S PROGRESS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accentCyan,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Daily Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textWhite,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$completedTasks of $totalTasks tasks completed',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Animated Radial Progress Ring
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: targetPercentage),
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  final int displayPercent = (value * 100).round();
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: CircularProgressIndicator(
                          value: value,
                          strokeWidth: 8,
                          backgroundColor: AppTheme.darkBackground,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentCyan),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Text(
                        '$displayPercent%',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textWhite,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 14),

          // 3 Animated Stat Counters: Total Today, Completed, Pending
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatMetric(
                label: 'Total Today',
                targetValue: totalTasks,
                color: AppTheme.textWhite,
              ),
              Container(width: 1, height: 28, color: Colors.white10),
              _buildStatMetric(
                label: 'Completed',
                targetValue: completedTasks,
                color: AppTheme.successGreen,
              ),
              Container(width: 1, height: 28, color: Colors.white10),
              _buildStatMetric(
                label: 'Pending',
                targetValue: pendingTasks,
                color: AppTheme.warningOrange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatMetric({
    required String label,
    required int targetValue,
    required Color color,
  }) {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: targetValue.toDouble()),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          builder: (context, val, child) {
            return Text(
              '${val.round()}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            );
          },
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
