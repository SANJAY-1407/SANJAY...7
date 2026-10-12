import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class EmptyState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onAction;
  final String? actionLabel;

  const EmptyState({
    super.key,
    this.title = 'All Caught Up! 🎉',
    this.message = 'No tasks scheduled for today. Take a break or add a new task to get started.',
    this.onAction,
    this.actionLabel = 'Add New Task',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: AppTheme.cardNavy.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.task_alt_rounded,
              size: 44,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textWhite,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textMuted,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(actionLabel!),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: AppTheme.textWhite,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
