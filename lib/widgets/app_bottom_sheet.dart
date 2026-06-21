import 'package:flutter/material.dart';
import '../theme.dart';

class AppBottomSheet extends StatelessWidget {
  final String? title;
  final Widget child;

  const AppBottomSheet({
    super.key,
    this.title,
    required this.child,
  });

  static Future<T?> show<T>(
    BuildContext context, {
    String? title,
    required Widget child,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: AppBottomSheet(title: title, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardTheme.color ?? Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md + 4,
        AppSpacing.md,
        AppSpacing.md + 4,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (title != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              title!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
          ] else
            const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}
