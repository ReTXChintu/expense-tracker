import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models.dart';
import '../../providers.dart';
import '../../theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/shimmer_box.dart';

class EmiPlansScreen extends ConsumerWidget {
  const EmiPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(emiPlansProvider);
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final monthFmt = DateFormat('MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text('EMIs', style: Theme.of(context).textTheme.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(emiPlansProvider),
          ),
        ],
      ),
      body: plans.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: ShimmerBox(height: 120, borderRadius: AppRadius.card),
        ),
        error: (e, _) => Center(child: Text('Failed to load EMIs\n$e')),
        data: (all) {
          final active = all.where((p) => p.isActive).toList();
          final completed = all.where((p) => p.status == 'completed').toList();

          if (all.isEmpty) {
            return const EmptyState(
              icon: Icons.account_balance_outlined,
              title: 'No EMIs yet',
              subtitle: 'Mark a purchase as EMI from the transaction editor',
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (active.isNotEmpty) ...[
                Text('Running', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...active.map(
                  (p) => _EmiPlanCard(
                    plan: p,
                    currency: currency,
                    monthFmt: monthFmt,
                    onTap: () => _showDetail(context, ref, p.id),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (completed.isNotEmpty) ...[
                Text('Completed', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...completed.map(
                  (p) => _EmiPlanCard(
                    plan: p,
                    currency: currency,
                    monthFmt: monthFmt,
                    onTap: () => _showDetail(context, ref, p.id),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _showDetail(BuildContext context, WidgetRef ref, String id) async {
    final api = ref.read(apiProvider);
    try {
      final res = await api.get('/emi-plans/$id') as Map<String, dynamic>;
      final plan = EmiPlan.fromJson(res);
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => _EmiDetailSheet(plan: plan),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _EmiPlanCard extends StatelessWidget {
  final EmiPlan plan;
  final NumberFormat currency;
  final DateFormat monthFmt;
  final VoidCallback onTap;

  const _EmiPlanCard({
    required this.plan,
    required this.currency,
    required this.monthFmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = plan.tenureMonths > 0
        ? plan.paidInstallments / plan.tenureMonths
        : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.merchant,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  currency.format(plan.principalAmount),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0, 1),
                minHeight: 6,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${plan.paidInstallments}/${plan.tenureMonths} paid · '
              '${plan.pendingInstallments} remaining',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (plan.isActive) ...[
              const SizedBox(height: 4),
              Text(
                'Est. complete ${monthFmt.format(plan.estimatedCompletion)} · '
                '≈ ${currency.format(plan.expectedMonthly)}/mo',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmiDetailSheet extends StatelessWidget {
  final EmiPlan plan;

  const _EmiDetailSheet({required this.plan});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final dateFmt = DateFormat('d MMM yyyy');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan.merchant, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${currency.format(plan.principalAmount)} · ${plan.tenureMonths} months',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text('Repayments', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (plan.repayments.isEmpty)
              Text('No repayments recorded yet', style: Theme.of(context).textTheme.bodySmall)
            else
              ...plan.repayments.map(
                (r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(currency.format(r.amount)),
                  subtitle: Text(
                    '${dateFmt.format(r.date)}'
                    '${r.paymentInstrumentName != null ? ' · ${r.paymentInstrumentName}' : ''}',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
