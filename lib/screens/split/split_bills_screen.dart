import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models.dart';
import '../../providers.dart';
import '../../theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/shimmer_box.dart';

class SplitBillsScreen extends ConsumerWidget {
  const SplitBillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bills = ref.watch(splitBillsProvider);
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: Text('Splits', style: Theme.of(context).textTheme.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(splitBillsProvider),
          ),
        ],
      ),
      body: bills.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: ShimmerBox(height: 120, borderRadius: AppRadius.card),
        ),
        error: (e, _) => Center(child: Text('Failed to load splits\n$e')),
        data: (all) {
          final active = all.where((b) => b.isActive).toList();
          final completed = all.where((b) => b.status == 'completed').toList();

          if (all.isEmpty) {
            return const EmptyState(
              icon: Icons.people_outline,
              title: 'No splits yet',
              subtitle: 'Mark an expense as Split from the transaction editor',
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (active.isNotEmpty) ...[
                Text('Active', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...active.map(
                  (b) => _SplitBillCard(
                    bill: b,
                    currency: currency,
                    onTap: () => _showDetail(context, ref, b.id),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (completed.isNotEmpty) ...[
                Text('Completed', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...completed.map(
                  (b) => _SplitBillCard(
                    bill: b,
                    currency: currency,
                    onTap: () => _showDetail(context, ref, b.id),
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
      final res = await api.get('/split-bills/$id') as Map<String, dynamic>;
      final bill = SplitBill.fromJson(res);
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => _SplitDetailSheet(bill: bill),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _SplitBillCard extends StatelessWidget {
  final SplitBill bill;
  final NumberFormat currency;
  final VoidCallback onTap;

  const _SplitBillCard({
    required this.bill,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = bill.participantCount > 0 ? bill.paidCount / bill.participantCount : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(bill.merchant, style: Theme.of(context).textTheme.titleSmall)),
                Text(currency.format(bill.totalAmount), style: Theme.of(context).textTheme.titleSmall),
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
              '${bill.paidCount}/${bill.participantCount} paid · '
              '${currency.format(bill.pendingAmount)} pending',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (bill.isActive) ...[
              const SizedBox(height: 4),
              Text(
                'Your share: ${currency.format(bill.ownerShareAmount)}',
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

class _SplitDetailSheet extends StatelessWidget {
  final SplitBill bill;

  const _SplitDetailSheet({required this.bill});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(bill.merchant, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${currency.format(bill.totalAmount)} · your share ${currency.format(bill.ownerShareAmount)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text('People', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...bill.participants.map(
              (p) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(p.name),
                subtitle: Text(currency.format(p.shareAmount)),
                trailing: Icon(
                  p.isPaid ? Icons.check_circle : Icons.schedule,
                  color: p.isPaid ? Colors.green : Colors.orange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
