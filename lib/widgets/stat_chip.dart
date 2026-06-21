import 'package:flutter/material.dart';
import '../theme.dart';

class StatChip extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;
  final VoidCallback? onTap;

  const StatChip({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AC.accent;
    final bg = chipColor.withValues(alpha: 0.12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(color: chipColor.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: chipColor),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: chipColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
