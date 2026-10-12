import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class ProgressCard extends StatelessWidget {
  final int completedTasks;
  final int totalTasks;

  const ProgressCard({
    super.key,
    required this.completedTasks,
    required this.totalTasks,
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
      padding: const EdgeInsets.all(22),
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
      child: Row(
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
                    'DAILY PROGRESS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.accentCyan,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your Task Target',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textWhite,
                  ),
                ),
                const SizedBox(height: 6),
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
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: targetPercentage),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              final int displayPercent = (value * 100).round();
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 76,
                    height: 76,
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
                      fontSize: 17,
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
    );
  }
}
