import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/transaction_kind.dart';
import '../../core/transaction_source_notes.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../widgets/source_indicators.dart';

class TxTile extends StatelessWidget {
  final Transaction tx;
  final List<Category> categories;
  final VoidCallback onTap;
  final bool selectionMode;
  final bool selected;

  const TxTile({
    super.key,
    required this.tx,
    required this.categories,
    required this.onTap,
    this.selectionMode = false,
    this.selected = false,
  });

  static String? _previewFor(Transaction tx) {
    final parts = TransactionSourceNotes.parseParts(tx.rawText, primary: tx.source);
    for (final p in parts) {
      final preview = TransactionSourceNotes.plainPreview(p.text);
      if (preview != null) return preview;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cat = tx.categoryId != null
        ? categories.where((c) => c.id == tx.categoryId).firstOrNull
        : null;
    final excluded = !countsInSpendAnalytics(tx.kind);
    final isRefund = tx.kind == TxKind.refund;
    final uncategorized = !tx.isCategorized;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final preview = _previewFor(tx);

    final amountColor = isRefund
        ? AC.credit
        : excluded
            ? Theme.of(context).disabledColor
            : tx.isDebit
                ? AC.debit
                : AC.credit;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: uncategorized
                    ? AC.uncategorized.withValues(alpha: 0.55)
                    : Theme.of(context).dividerColor,
                width: uncategorized ? 1.5 : 1,
              ),
              boxShadow: AppShadows.card(isDark),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 8),
                    child: Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                      color: selected ? AC.accent : Theme.of(context).disabledColor,
                      size: 22,
                    ),
                  ),
                SourceIndicators(sources: tx.sources),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tx.merchant,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            DateFormat('h:mm a').format(tx.date.toLocal()),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                      if (preview != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          preview,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (cat != null)
                            _MetaChip(
                              label: cat.name,
                              color: cat.color,
                              icon: cat.icon,
                            )
                          else
                            const _MetaChip(
                              label: 'Categorize',
                              color: AC.uncategorized,
                              icon: Icons.label_off_outlined,
                            ),
                          if (tx.kind != TxKind.purchase)
                            _MetaChip(
                              label: kindLabels[tx.kind]!,
                              color: _kindColor(tx.kind),
                            ),
                          if (tx.paymentInstrumentName != null)
                            _MetaChip(
                              label: tx.paymentInstrumentName!,
                              color: Colors.purple,
                              icon: Icons.credit_card_outlined,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${isRefund ? '+' : tx.isDebit ? '-' : '+'}₹${tx.amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: amountColor,
                    decoration: excluded ? TextDecoration.lineThrough : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Color _kindColor(TxKind kind) => switch (kind) {
        TxKind.refund => AC.credit,
        TxKind.ccBillPayment => Colors.purple,
        TxKind.selfTransfer => Colors.blue,
        TxKind.adjustment => Colors.orange,
        TxKind.emi => Colors.teal,
        TxKind.emiRepayment => Colors.indigo,
        TxKind.split => Colors.deepOrange,
        TxKind.splitSettlement => Colors.cyan,
        _ => Colors.grey,
      };
}

class _MetaChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _MetaChip({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
