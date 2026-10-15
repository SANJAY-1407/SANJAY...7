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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textWhite,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badgeText != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.cardNavy,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    badgeText!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accentCyan,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null && onActionPressed != null) ...[
          const SizedBox(width: 8),
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
      ],
    );
  }
}
