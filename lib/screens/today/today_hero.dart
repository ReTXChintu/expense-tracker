import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/analytics.dart';
import '../../core/transaction_kind.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../widgets/stat_chip.dart';

class TodayHero extends StatelessWidget {
  final List<Transaction> transactions;
  final int uncategorizedCount;
  final VoidCallback? onUncategorizedTap;

  const TodayHero({
    super.key,
    required this.transactions,
    required this.uncategorizedCount,
    this.onUncategorizedTap,
  });

  double get _netSpend {
    return transactions
        .where((t) => t.isCategorized && countsInSpendAnalytics(t.kind))
        .fold<double>(0, (sum, t) {
      if (t.kind == TxKind.refund) return sum - t.amount;
      return sum + (t.isDebit ? t.amount : -t.amount);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final netSpend = _netSpend;
    final txCount = transactions.length;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    Widget hero = Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF4361EE), const Color(0xFF5B7AFF)]
              : [const Color(0xFF4361EE), const Color(0xFF738EFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.elevated(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's spend",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          _AnimatedAmount(
            amount: netSpend,
            disableAnimations: disableAnimations,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatChip(
                label: '$txCount transaction${txCount == 1 ? '' : 's'}',
                color: Colors.white,
                icon: Icons.receipt_long_outlined,
              ),
              if (uncategorizedCount > 0)
                StatChip(
                  label: '$uncategorizedCount to categorize',
                  color: AC.uncategorized,
                  icon: Icons.label_off_outlined,
                  onTap: onUncategorizedTap,
                ),
            ],
          ),
        ],
      ),
    );

    if (disableAnimations) return hero;

    return hero
        .animate()
        .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
        .slideY(begin: -0.05, duration: 400.ms, curve: Curves.easeOutCubic);
  }
}

class _AnimatedAmount extends StatelessWidget {
  final double amount;
  final bool disableAnimations;

  const _AnimatedAmount({
    required this.amount,
    required this.disableAnimations,
  });

  @override
  Widget build(BuildContext context) {
    if (disableAnimations) {
      return Text(
        formatInr(amount),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: amount),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (_, value, __) => Text(
        formatInr(value),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
