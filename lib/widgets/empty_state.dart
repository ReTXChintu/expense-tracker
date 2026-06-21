import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 56, color: Theme.of(context).hintColor),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );

    if (disableAnimations) return content;

    return content
        .animate()
        .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.06, duration: 400.ms, curve: Curves.easeOutCubic);
  }
}
