import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models.dart';
import '../../providers.dart';

/// Pick a payment instrument (or none).
Future<String?> showAssignInstrumentSheet(
  BuildContext context, {
  required List<PaymentInstrument> instruments,
  String? selectedId,
  String title = 'Assign account/card',
}) {
  return showModalBottomSheet<String?>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _AssignInstrumentSheet(
      instruments: instruments,
      selectedId: selectedId,
      title: title,
    ),
  );
}

class _AssignInstrumentSheet extends StatelessWidget {
  final List<PaymentInstrument> instruments;
  final String? selectedId;
  final String title;

  const _AssignInstrumentSheet({
    required this.instruments,
    this.selectedId,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('None / unassigned'),
            onTap: () => Navigator.pop(context, null),
          ),
          ...instruments.map(
            (inst) => ListTile(
              title: Text(inst.displayName),
              subtitle: Text(inst.issuer ?? inst.type.name),
              trailing: selectedId == inst.id ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, inst.id),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Link a refund transaction to a purchase.
Future<String?> showLinkRefundSheet(BuildContext context, Transaction refund) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => LinkRefundSheet(refund: refund),
  );
}

class LinkRefundSheet extends ConsumerStatefulWidget {
  final Transaction refund;
  const LinkRefundSheet({super.key, required this.refund});

  @override
  ConsumerState<LinkRefundSheet> createState() => _LinkRefundSheetState();
}

class _LinkRefundSheetState extends ConsumerState<LinkRefundSheet> {
  final _searchCtrl = TextEditingController();
  List<Transaction> _results = [];
  List<Map<String, dynamic>> _suggestions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
    _search('');
  }

  Future<void> _loadSuggestions() async {
    try {
      final api = ref.read(apiProvider);
      final res = await api.get('/transactions/${widget.refund.id}/suggestions')
          as Map<String, dynamic>;
      final matches = (res['refundMatches'] as List<dynamic>?) ?? [];
      if (mounted) setState(() => _suggestions = matches.cast<Map<String, dynamic>>());
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final end = widget.refund.date;
      final start = end.subtract(const Duration(days: 90));
      final api = ref.read(apiProvider);
      final res = await api.get(
        '/transactions',
        query: {
          'kind': 'purchase',
          'limit': '30',
          'startDate': start.toUtc().toIso8601String(),
          'endDate': end.toUtc().toIso8601String(),
          if (q.trim().isNotEmpty) 'search': q.trim(),
        },
      );
      final list = (res as List<dynamic>)
          .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
          .where((t) => t.id != widget.refund.id)
          .toList();
      if (mounted) setState(() => _results = list);
    } catch (_) {
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Link refund to purchase',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Refund ₹${widget.refund.amount.toStringAsFixed(0)} — last 90 days',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search merchant…',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
              onChanged: _search,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty && _suggestions.isEmpty
                    ? Center(
                        child: Text(
                          'No matching purchases',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: _buildRows().length,
                        itemBuilder: (_, i) => _buildRows()[i],
                      ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRows() {
    final suggestedIds = _suggestions.map((s) => s['transactionId'] as String).toSet();
    final rows = <Widget>[];
    final suggestedTxs = _results.where((t) => suggestedIds.contains(t.id)).toList();
    final rest = _results.where((t) => !suggestedIds.contains(t.id)).toList();

    if (suggestedTxs.isNotEmpty) {
      rows.add(Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(
          'Suggested matches',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.green),
        ),
      ));
      for (final tx in suggestedTxs) {
        final hint = _suggestions.firstWhere(
          (s) => s['transactionId'] == tx.id,
          orElse: () => {},
        );
        rows.add(_purchaseTile(tx, hint: hint['reason'] as String?));
      }
      rows.add(Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text('All purchases', style: Theme.of(context).textTheme.labelSmall),
      ));
    }
    for (final tx in suggestedTxs.isEmpty ? _results : rest) {
      rows.add(_purchaseTile(tx));
    }
    return rows;
  }

  Widget _purchaseTile(Transaction tx, {String? hint}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(tx.merchant),
      subtitle: Text(
        '${DateFormat('d MMM').format(tx.date.toLocal())} · ₹${tx.amount.toStringAsFixed(0)}'
        '${hint != null ? ' · $hint' : ''}',
      ),
      onTap: () => Navigator.pop(context, tx.id),
    );
  }
}

/// CC bill reconciliation after marking as bill payment.
Future<bool?> showReconcileBillSheet(
  BuildContext context, {
  required String billTransactionId,
  required String instrumentId,
  required double amount,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => ReconcileBillSheet(
      billTransactionId: billTransactionId,
      instrumentId: instrumentId,
      amount: amount,
    ),
  );
}

class ReconcileBillSheet extends ConsumerStatefulWidget {
  final String billTransactionId;
  final String instrumentId;
  final double amount;

  const ReconcileBillSheet({
    super.key,
    required this.billTransactionId,
    required this.instrumentId,
    required this.amount,
  });

  @override
  ConsumerState<ReconcileBillSheet> createState() => _ReconcileBillSheetState();
}

class _ReconcileBillSheetState extends ConsumerState<ReconcileBillSheet> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _settle = true;
  bool _createAdjustment = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiProvider);
      final res = await api.get(
        '/payment-instruments/${widget.instrumentId}/reconciliation',
        query: {'billTransactionId': widget.billTransactionId},
      ) as Map<String, dynamic>;
      if (mounted) setState(() => _data = res);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirm() async {
    setState(() => _submitting = true);
    try {
      final api = ref.read(apiProvider);
      await api.post(
        '/payment-instruments/${widget.instrumentId}/reconciliation',
        data: {
          'billTransactionId': widget.billTransactionId,
          'settlePurchases': _settle,
          'createAdjustment': _createAdjustment,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (_, __) => Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reconcile bill', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Payment ₹${widget.amount.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_data != null) ...[
                    const SizedBox(height: 16),
                    Text('Expected: ₹${(_data!['expectedBill'] as num).toStringAsFixed(0)}'),
                    Text('Purchases: ${_data!['purchaseCount']}'),
                    if (_data!['difference'] != null)
                      Text('Difference: ₹${(_data!['difference'] as num).toStringAsFixed(0)}'),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Mark purchases as settled'),
                      value: _settle,
                      onChanged: (v) => setState(() => _settle = v ?? true),
                    ),
                    if (_data!['difference'] != null &&
                        (_data!['difference'] as num).abs() > 1)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Create adjustment for difference'),
                        value: _createAdjustment,
                        onChanged: (v) => setState(() => _createAdjustment = v ?? false),
                      ),
                  ],
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submitting ? null : _confirm,
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Confirm reconciliation'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Pick from / to instruments for self transfer.
Future<(String, String)?> showSelfTransferSheet(
  BuildContext context, {
  required List<PaymentInstrument> instruments,
  String? fromId,
  String? toId,
}) {
  return showModalBottomSheet<(String, String)>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SelfTransferSheet(
      instruments: instruments,
      fromId: fromId,
      toId: toId,
    ),
  );
}

class SelfTransferSheet extends StatefulWidget {
  final List<PaymentInstrument> instruments;
  final String? fromId;
  final String? toId;

  const SelfTransferSheet({
    super.key,
    required this.instruments,
    this.fromId,
    this.toId,
  });

  @override
  State<SelfTransferSheet> createState() => _SelfTransferSheetState();
}

class _SelfTransferSheetState extends State<SelfTransferSheet> {
  String? _from;
  String? _to;

  @override
  void initState() {
    super.initState();
    _from = widget.fromId;
    _to = widget.toId;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (_, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 12),
          Text('Self transfer', style: Theme.of(context).textTheme.titleMedium),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(16),
              children: [
                Text('From', style: Theme.of(context).textTheme.labelLarge),
                RadioGroup<String>(
                  groupValue: _from,
                  onChanged: (v) => setState(() => _from = v),
                  child: Column(
                    children: [
                      for (final inst in widget.instruments.where((i) => i.id != _to))
                        RadioListTile<String>(
                          title: Text(inst.displayName),
                          value: inst.id,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text('To', style: Theme.of(context).textTheme.labelLarge),
                RadioGroup<String>(
                  groupValue: _to,
                  onChanged: (v) => setState(() => _to = v),
                  child: Column(
                    children: [
                      for (final inst in widget.instruments.where((i) => i.id != _from))
                        RadioListTile<String>(
                          title: Text(inst.displayName),
                          value: inst.id,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _from != null && _to != null && _from != _to
                    ? () => Navigator.pop(context, (_from!, _to!))
                    : null,
                child: const Text('Save transfer'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Category grid picker — returns selected [Category].
Future<Category?> showCategoryPickerSheet(BuildContext context) {
  return showModalBottomSheet<Category>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const CategoryPickerSheet(),
  );
}

class CategoryPickerSheet extends ConsumerWidget {
  const CategoryPickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return categoriesAsync.when(
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SizedBox(height: 120, child: Center(child: Text('Error: $e'))),
      data: (categories) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Select Category',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: GridView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: categories.length,
                itemBuilder: (ctx, i) {
                  final cat = categories[i];
                  return GestureDetector(
                    onTap: () => Navigator.pop(ctx, cat),
                    child: Column(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: cat.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(cat.icon, color: cat.color, size: 26),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          cat.name,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
