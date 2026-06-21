import 'package:flutter/material.dart';
import '../theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? accentColor;
  final VoidCallback? onTap;
  final bool muted;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.accentColor,
    this.onTap,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color ?? Colors.white;
    final innerPadding = padding ?? const EdgeInsets.all(14);

    Widget inner = accentColor != null
        ? IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ColoredBox(color: accentColor!, child: const SizedBox(width: 4)),
                Expanded(
                  child: Padding(padding: innerPadding, child: child),
                ),
              ],
            ),
          )
        : Padding(padding: innerPadding, child: child);

    Widget content = Container(
      margin: margin ??
          const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
      decoration: BoxDecoration(
        color: muted ? cardColor.withValues(alpha: isDark ? 0.6 : 0.85) : cardColor,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card(isDark),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: inner,
      ),
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: content,
        ),
      );
    }

    return content;
  }
}
