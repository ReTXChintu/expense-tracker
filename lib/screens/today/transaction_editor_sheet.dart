import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/transaction_kind.dart';
import '../../core/transaction_source_notes.dart';
import '../../models.dart';
import '../../providers.dart';
import '../../theme.dart';
import 'merge_helper_sheets.dart';
import 'transaction_helper_sheets.dart';

/// Full transaction editor — single save for all fields.
class TransactionEditorSheet extends ConsumerStatefulWidget {
  final Transaction transaction;
  final List<Category> categories;

  const TransactionEditorSheet({
    super.key,
    required this.transaction,
    required this.categories,
  });

  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    required Transaction transaction,
    required List<Category> categories,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TransactionEditorSheet(
        transaction: transaction,
        categories: categories,
      ),
    );
  }

  @override
  ConsumerState<TransactionEditorSheet> createState() => _TransactionEditorSheetState();
}

class _TransactionEditorSheetState extends ConsumerState<TransactionEditorSheet> {
  late final TextEditingController _merchantCtrl;
  late final TextEditingController _amountCtrl;
  late bool _isDebit;
  late TxKind _kind;
  String? _categoryId;
  String? _paymentInstrumentId;
  String? _counterpartyInstrumentId;
  String? _linkedTransactionId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    _merchantCtrl = TextEditingController(text: tx.merchant);
    _amountCtrl = TextEditingController(text: tx.amount.toStringAsFixed(0));
    _isDebit = tx.isDebit;
    _kind = tx.kind;
    _categoryId = tx.categoryId;
    _paymentInstrumentId = tx.paymentInstrumentId;
    _counterpartyInstrumentId = tx.counterpartyInstrumentId;
    _linkedTransactionId = tx.linkedTransactionId;
  }

  @override
  void dispose() {
    _merchantCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  List<PaymentInstrument> get _instruments =>
      ref.read(paymentInstrumentsProvider).valueOrNull ?? [];

  Category? get _selectedCat => _categoryId != null
      ? widget.categories.where((c) => c.id == _categoryId).firstOrNull
      : null;

  List<({TxSource source, String text})> get _sourceBlocks {
    return TransactionSourceNotes.parseParts(
      widget.transaction.rawText,
      primary: widget.transaction.source,
    )
        .map((p) {
          final plain = TransactionSourceNotes.plainPreview(p.text);
          return plain == null ? null : (source: p.source, text: plain);
        })
        .whereType<({TxSource source, String text})>()
        .toList();
  }

  Future<void> _unmerge() async {
    if (!widget.transaction.hasMultipleSources || widget.transaction.id == null) return;
    final ok = await confirmUnmerge(context);
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(todayProvider.notifier).unmergeSaved(widget.transaction);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unmerge failed');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickCategory() async {
    final result = await showCategoryPickerSheet(context);
    if (result != null) setState(() => _categoryId = result.id);
  }

  Future<void> _pickInstrument() async {
    final selected = await showAssignInstrumentSheet(
      context,
      instruments: _instruments,
      selectedId: _paymentInstrumentId,
    );
    if (selected != null || _paymentInstrumentId != null) {
      setState(() => _paymentInstrumentId = selected);
    }
  }

  Future<void> _pickCcCard() async {
    final cards = _instruments.where((i) => i.type == PaymentInstrumentType.creditCard).toList();
    final cardId = await showAssignInstrumentSheet(
      context,
      instruments: cards,
      selectedId: _paymentInstrumentId,
      title: 'Which credit card bill is this?',
    );
    if (cardId != null) setState(() => _paymentInstrumentId = cardId);
  }

  Future<void> _pickSelfTransfer() async {
    final pair = await showSelfTransferSheet(
      context,
      instruments: _instruments,
      fromId: _paymentInstrumentId,
      toId: _counterpartyInstrumentId,
    );
    if (pair != null) {
      setState(() {
        _paymentInstrumentId = pair.$1;
        _counterpartyInstrumentId = pair.$2;
      });
    }
  }

  Future<void> _linkRefund() async {
    final purchaseId = await showLinkRefundSheet(context, widget.transaction);
    if (purchaseId != null) setState(() => _linkedTransactionId = purchaseId);
  }

  Future<void> _save() async {
    final merchant = _merchantCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '').trim());
    if (merchant.isEmpty) {
      setState(() => _error = 'Enter a payee / merchant name');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    if (_kind == TxKind.selfTransfer &&
        (_paymentInstrumentId == null || _counterpartyInstrumentId == null)) {
      setState(() => _error = 'Select from and to accounts');
      return;
    }
    if (_kind == TxKind.ccBillPayment && _paymentInstrumentId == null) {
      setState(() => _error = 'Select a credit card');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final txId = widget.transaction.id!;
      final wasCcBill = widget.transaction.kind == TxKind.ccBillPayment;
      final isNewCcBill = _kind == TxKind.ccBillPayment && !wasCcBill;

      await ref.read(todayProvider.notifier).updateSaved(
            txId,
            merchant: merchant,
            amount: amount,
            isDebit: _isDebit,
            categoryId: _categoryId,
            kind: _kind,
            linkedTransactionId: _linkedTransactionId,
            clearLinkedTransactionId: _kind != TxKind.refund &&
                widget.transaction.linkedTransactionId != null &&
                _linkedTransactionId == null,
            paymentInstrumentId: _paymentInstrumentId,
            clearPaymentInstrumentId: widget.transaction.paymentInstrumentId != null &&
                _paymentInstrumentId == null,
            counterpartyInstrumentId: _counterpartyInstrumentId,
            clearCounterpartyInstrumentId: _kind != TxKind.selfTransfer &&
                widget.transaction.counterpartyInstrumentId != null &&
                _counterpartyInstrumentId == null,
          );

      if (!mounted) return;
      Navigator.pop(context);

      if (isNewCcBill && _paymentInstrumentId != null) {
        final reconciled = await showReconcileBillSheet(
          context,
          billTransactionId: txId,
          instrumentId: _paymentInstrumentId!,
          amount: amount,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                reconciled == true ? 'Bill reconciled' : 'Saved as CC bill payment',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete transaction?'),
            content: const Text('This cannot be undone.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirm || !mounted) return;
    await ref.read(todayProvider.notifier).deleteSaved(widget.transaction.id!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final sourceBlocks = _sourceBlocks;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
            const SizedBox(height: 16),
            Text('Edit transaction', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),

            Row(
              children: [
                _TypeChip(
                  label: 'Debit',
                  selected: _isDebit,
                  color: AC.debit,
                  onTap: () => setState(() => _isDebit = true),
                ),
                const SizedBox(width: 8),
                _TypeChip(
                  label: 'Credit',
                  selected: !_isDebit,
                  color: AC.credit,
                  onTap: () => setState(() => _isDebit = false),
                ),
              ],
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _merchantCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Payee / Merchant',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '₹  ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),

            Text('Category', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            _PickerRow(
              icon: _selectedCat?.icon ?? Icons.category_outlined,
              iconColor: _selectedCat?.color,
              label: _selectedCat?.name ?? 'Select category',
              hint: _selectedCat == null,
              onTap: _pickCategory,
            ),
            const SizedBox(height: 14),

            Text('Type', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            DropdownButtonFormField<TxKind>(
              initialValue: _kind,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
              items: TxKind.values
                  .map(
                    (k) => DropdownMenuItem(
                      value: k,
                      child: Text(kindLabels[k]!),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _kind = v);
              },
            ),

            if (_kind == TxKind.refund) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _linkRefund,
                icon: const Icon(Icons.link, size: 18),
                label: Text(
                  _linkedTransactionId != null ? 'Linked to purchase' : 'Link to purchase',
                ),
              ),
            ],

            if (_kind == TxKind.selfTransfer) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _pickSelfTransfer,
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Set from / to accounts'),
              ),
            ],

            if (_kind == TxKind.ccBillPayment) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _pickCcCard,
                icon: const Icon(Icons.credit_card, size: 18),
                label: Text(
                  _paymentInstrumentId != null ? 'Credit card selected' : 'Select credit card',
                ),
              ),
            ],

            const SizedBox(height: 14),
            Text('Instrument', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            _PickerRow(
              icon: Icons.credit_card_outlined,
              label: _paymentInstrumentId != null
                  ? (_instruments
                          .where((i) => i.id == _paymentInstrumentId)
                          .firstOrNull
                          ?.displayName ??
                      'Assigned')
                  : 'None / unassigned',
              hint: _paymentInstrumentId == null,
              onTap: _pickInstrument,
            ),

            if (sourceBlocks.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Source', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              ...sourceBlocks.map((block) {
                final label = switch (block.source) {
                  TxSource.sms => 'SMS',
                  TxSource.gmail => 'Email',
                  TxSource.manual => 'Manual',
                };
                final color = switch (block.source) {
                  TxSource.sms => AC.smsColor,
                  TxSource.gmail => AC.gmailColor,
                  TxSource.manual => Colors.grey,
                };
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              block.source == TxSource.gmail
                                  ? Icons.mail_outline
                                  : block.source == TxSource.sms
                                      ? Icons.sms_outlined
                                      : Icons.touch_app_outlined,
                              size: 16,
                              color: color,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(block.text, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                );
              }),
              if (widget.transaction.hasMultipleSources) ...[
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _unmerge,
                  icon: const Icon(Icons.call_split, size: 18),
                  label: const Text('Unmerge'),
                ),
              ],
            ],

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
              ),
            ],

            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AC.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _delete,
              icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
              label: Text(
                'Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final bool hint;
  final VoidCallback onTap;

  const _PickerRow({
    required this.icon,
    this.iconColor,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: iconColor ?? Theme.of(context).hintColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: hint ? Theme.of(context).hintColor : null,
                  fontWeight: hint ? FontWeight.normal : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: Theme.of(context).hintColor),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(color: selected ? color : Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : Theme.of(context).hintColor,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
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
