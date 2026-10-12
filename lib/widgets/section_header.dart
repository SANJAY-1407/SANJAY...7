import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? badgeText;
  final VoidCallback? onActionPressed;
  final String? actionLabel;

  const SectionHeader({
    super.key,
    required this.title,
    this.badgeText,
    this.onActionPressed,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textWhite,
              ),
            ),
            if (badgeText != null) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.cardNavy,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  badgeText!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentCyan,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (actionLabel != null && onActionPressed != null)
          TextButton(
            onPressed: onActionPressed,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.accentCyan,
              ),
            ),
          ),
      ],
    );
  }
}
