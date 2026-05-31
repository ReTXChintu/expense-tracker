import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:intl/intl.dart';
import '../providers.dart';
import '../models.dart';
import '../theme.dart';
import '../core/gmail_reader.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(todayProvider);
    final categories = ref.watch(categoriesProvider);

    void openCreateSheet() {
      final cats = categories.valueOrNull;
      if (cats == null) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _TransactionSheet(
          categories: cats,
          date: state.date,
          onSave: (merchant, amount, isDebit, categoryId) async {
            await ref.read(todayProvider.notifier).createTransaction(
              merchant: merchant,
              amount: amount,
              isDebit: isDebit,
              categoryId: categoryId,
              date: state.date,
            );
          },
        ),
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_create',
        onPressed: openCreateSheet,
        backgroundColor: AC.accent,
        foregroundColor: Colors.white,
        tooltip: 'Add transaction',
        child: const Icon(Icons.add),
      ),
      appBar: AppBar(
        title: Text(
          DateFormat('EEEE, d MMM').format(state.date),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous day',
            onPressed: () => ref.read(todayProvider.notifier).goToDate(
                  state.date.subtract(const Duration(days: 1)),
                ),
          ),
          if (!_isToday(state.date))
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next day',
              onPressed: () => ref.read(todayProvider.notifier).goToDate(
                    state.date.add(const Duration(days: 1)),
                  ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh & rescan',
            onPressed: (state.loading || state.scanning)
                ? null
                : () => ref
                    .read(todayProvider.notifier)
                    .load(state.date, forceRescan: true),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => const _ProfileSheet(),
              ),
              child: CircleAvatar(
                radius: 16,
                backgroundColor:
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                child: Icon(Icons.person_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ),
        ],
      ),
      body: (state.loading && !state.scanning)
          ? const Center(child: CircularProgressIndicator())
          : categories.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (cats) => _Body(state: state, categories: cats),
            ),
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _Body extends ConsumerStatefulWidget {
  final TodayState state;
  final List<Category> categories;
  const _Body({required this.state, required this.categories});

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _gmailConnected = false;

  @override
  void initState() {
    super.initState();
    _checkGmail();
  }

  Future<void> _checkGmail() async {
    final connected = await GmailReader.isSignedIn();
    if (mounted) setState(() => _gmailConnected = connected);
  }

  Future<void> _connectGmail() async {
    final account = await GmailReader.signIn();
    if (account != null) {
      setState(() => _gmailConnected = true);
      if (mounted) {
        ref
            .read(todayProvider.notifier)
            .load(widget.state.date, forceRescan: true);
      }
    }
  }

  void _openSheet({Transaction? existing, bool isSaved = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TransactionSheet(
        existing: existing,
        categories: widget.categories,
        date: widget.state.date,
        onSave: (merchant, amount, isDebit, categoryId) async {
          if (existing != null) {
            await ref.read(todayProvider.notifier).updateSaved(
              existing.id!,
              merchant: merchant,
              amount: amount,
              isDebit: isDebit,
              categoryId: categoryId,
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final cats = widget.categories;

    final uncategorized =
        state.transactions.where((t) => !t.isCategorized).toList();
    final categorized =
        state.transactions.where((t) => t.isCategorized).toList();

    final debitTotal = categorized
        .where((t) => t.isDebit)
        .fold<double>(0, (s, t) => s + t.amount);

    return CustomScrollView(
      slivers: [
        // Gmail connect banner
        if (!_gmailConnected)
          SliverToBoxAdapter(child: _GmailBanner(onConnect: _connectGmail)),

        // Scanning banner
        if (state.scanning)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AC.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AC.accent.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text('Scanning messages and Gmail…',
                      style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.primary)),
                ],
              ),
            ),
          ),

        // Error banner
        if (state.error != null)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .error
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(state.error!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13)),
            ),
          ),

        // ── To categorize ───────────────────────────────────────────────────
        if (uncategorized.isNotEmpty) ...[
          _SectionHeader(
            title: 'To Categorize  •  ${uncategorized.length}',
            subtitle: 'Tap the chip to assign a category',
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final tx = uncategorized[i];
                return _Deletable(
                  key: ValueKey('u_${tx.id}'),
                  onDelete: () =>
                      ref.read(todayProvider.notifier).deleteSaved(tx.id!),
                  child: _TxTile(
                    tx: tx,
                    categories: cats,
                    onCategory: (catId) => ref
                        .read(todayProvider.notifier)
                        .updateSaved(tx.id!, categoryId: catId),
                    onEdit: () => _openSheet(existing: tx, isSaved: true),
                  ),
                );
              },
              childCount: uncategorized.length,
            ),
          ),
        ],

        // ── Categorized ─────────────────────────────────────────────────────
        if (categorized.isNotEmpty) ...[
          _SectionHeader(
            title: 'Done  •  ${categorized.length}',
            subtitle: debitTotal > 0
                ? '₹${debitTotal.toStringAsFixed(0)} spent'
                : 'All categorized',
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final tx = categorized[i];
                return _Deletable(
                  key: ValueKey('c_${tx.id}'),
                  onDelete: () =>
                      ref.read(todayProvider.notifier).deleteSaved(tx.id!),
                  child: _TxTile(
                    tx: tx,
                    categories: cats,
                    onCategory: (catId) => ref
                        .read(todayProvider.notifier)
                        .updateSaved(tx.id!, categoryId: catId),
                    onEdit: () => _openSheet(existing: tx, isSaved: true),
                  ),
                );
              },
              childCount: categorized.length,
            ),
          ),
        ],

        // Empty state
        if (state.transactions.isEmpty && !state.scanning)
          const SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 56, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No transactions for this day',
                      style: TextStyle(fontSize: 15)),
                  SizedBox(height: 4),
                  Text('Tap + to add one manually',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

// ─── Deletable wrapper ────────────────────────────────────────────────────────

class _Deletable extends StatelessWidget {
  final Widget child;
  final VoidCallback onDelete;
  const _Deletable({super.key, required this.child, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: key!,
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      child: child,
    );
  }
}

// ─── Gmail banner ─────────────────────────────────────────────────────────────

class _GmailBanner extends StatelessWidget {
  final VoidCallback onConnect;
  const _GmailBanner({required this.onConnect});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AC.gmailColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AC.gmailColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.mail_outline, color: AC.gmailColor, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Connect Gmail to fetch transactions from emails',
                style: TextStyle(fontSize: 13)),
          ),
          TextButton(
            onPressed: onConnect,
            style: TextButton.styleFrom(
                foregroundColor: AC.gmailColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Row(
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontSize: 14)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Transaction tile ─────────────────────────────────────────────────────────

class _TxTile extends StatelessWidget {
  final Transaction tx;
  final List<Category> categories;
  final void Function(String)? onCategory;
  final VoidCallback? onEdit;

  const _TxTile({
    required this.tx,
    required this.categories,
    this.onCategory,
    this.onEdit,
  });

  static bool _isHtml(String text) =>
      text.contains('<html') ||
      text.contains('<body') ||
      text.contains('<div') ||
      text.contains('<p>') ||
      text.contains('<br') ||
      text.contains('<table') ||
      text.contains('<span');

  static String _plainPreview(String text) => text
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  @override
  Widget build(BuildContext context) {
    final cat = tx.categoryId != null
        ? categories.where((c) => c.id == tx.categoryId).firstOrNull
        : null;

    return GestureDetector(
      onTap: tx.rawText != null ? () => _showRawMessage(context) : null,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SourceDot(source: tx.source),
              const SizedBox(width: 12),

              // Merchant + preview + category picker
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tx.merchant,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (tx.rawText != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _plainPreview(tx.rawText!),
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    _CategoryPicker(
                      categories: categories,
                      selected: cat,
                      onSelect: onCategory,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Amount + edit icon
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (onEdit != null)
                    GestureDetector(
                      onTap: onEdit,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Icon(Icons.edit_outlined,
                            size: 14,
                            color:
                                Theme.of(context).textTheme.bodySmall?.color),
                      ),
                    ),
                  Text(
                    '${tx.isDebit ? '-' : '+'}₹${tx.amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: tx.isDebit ? AC.debit : AC.credit,
                    ),
                  ),
                  Text(
                    DateFormat('h:mm a').format(tx.date),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRawMessage(BuildContext context) {
    final raw = tx.rawText ?? '';
    final isHtml = _isHtml(raw);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Icon(
                    tx.source == TxSource.sms
                        ? Icons.sms_outlined
                        : Icons.mail_outline,
                    size: 18,
                    color: tx.source == TxSource.sms
                        ? AC.smsColor
                        : AC.gmailColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tx.source == TxSource.sms ? 'SMS Message' : 'Email',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: isHtml
                    ? HtmlWidget(
                        raw,
                        textStyle: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(height: 1.5),
                      )
                    : Text(
                        raw,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(height: 1.5),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Source dot ───────────────────────────────────────────────────────────────

class _SourceDot extends StatelessWidget {
  final TxSource source;
  const _SourceDot({required this.source});

  @override
  Widget build(BuildContext context) {
    final color = switch (source) {
      TxSource.sms => AC.smsColor,
      TxSource.gmail => AC.gmailColor,
      TxSource.manual => AC.manualColor,
    };
    final icon = switch (source) {
      TxSource.sms => Icons.sms_outlined,
      TxSource.gmail => Icons.mail_outline,
      TxSource.manual => Icons.edit_outlined,
    };
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}

// ─── Category picker chip ─────────────────────────────────────────────────────

class _CategoryPicker extends StatelessWidget {
  final List<Category> categories;
  final Category? selected;
  final void Function(String)? onSelect;

  const _CategoryPicker(
      {required this.categories, this.selected, this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect != null ? () => _showPicker(context) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected != null
              ? selected!.color.withValues(alpha: 0.10)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected != null
                ? selected!.color.withValues(alpha: 0.30)
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected != null) ...[
              Icon(selected!.icon, size: 12, color: selected!.color),
              const SizedBox(width: 4),
              Text(selected!.name,
                  style: TextStyle(
                      fontSize: 12,
                      color: selected!.color,
                      fontWeight: FontWeight.w500)),
            ] else ...[
              Icon(Icons.add,
                  size: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color),
              const SizedBox(width: 4),
              Text('Add category',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final result = await showModalBottomSheet<Category>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CategorySheet(categories: categories),
    );
    if (result != null) onSelect?.call(result.id);
  }
}

// ─── Category grid sheet ──────────────────────────────────────────────────────

class _CategorySheet extends StatelessWidget {
  final List<Category> categories;
  const _CategorySheet({required this.categories});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
        const SizedBox(height: 16),
        Text('Select Category',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Flexible(
          child: GridView.builder(
            shrinkWrap: true,
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
                    Text(cat.name,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Create / Edit transaction sheet ─────────────────────────────────────────

class _TransactionSheet extends StatefulWidget {
  final Transaction? existing;
  final List<Category> categories;
  final DateTime date;
  final Future<void> Function(
          String merchant, double amount, bool isDebit, String? categoryId)
      onSave;

  const _TransactionSheet({
    this.existing,
    required this.categories,
    required this.date,
    required this.onSave,
  });

  @override
  State<_TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends State<_TransactionSheet> {
  late final TextEditingController _merchantCtrl;
  late final TextEditingController _amountCtrl;
  late bool _isDebit;
  String? _categoryId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _merchantCtrl = TextEditingController(text: e?.merchant ?? '');
    _amountCtrl = TextEditingController(
        text: e != null ? e.amount.toStringAsFixed(0) : '');
    _isDebit = e?.isDebit ?? true;
    _categoryId = e?.categoryId;
  }

  @override
  void dispose() {
    _merchantCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final merchant = _merchantCtrl.text.trim();
    final amount =
        double.tryParse(_amountCtrl.text.replaceAll(',', '').trim());
    if (merchant.isEmpty) {
      setState(() => _error = 'Enter a payee / merchant name');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(merchant, amount, _isDebit, _categoryId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCreate = widget.existing == null;
    final selectedCat = _categoryId != null
        ? widget.categories.where((c) => c.id == _categoryId).firstOrNull
        : null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Text(
            isCreate ? 'Add Transaction' : 'Edit Transaction',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 20),

          // Debit / Credit
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

          // Merchant
          TextField(
            controller: _merchantCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Payee / Merchant',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),

          // Amount
          TextField(
            controller: _amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '₹  ',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),

          // Category
          GestureDetector(
            onTap: () async {
              final result = await showModalBottomSheet<Category>(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) =>
                    _CategorySheet(categories: widget.categories),
              );
              if (result != null) setState(() => _categoryId = result.id);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  if (selectedCat != null) ...[
                    Icon(selectedCat.icon,
                        size: 16, color: selectedCat.color),
                    const SizedBox(width: 8),
                    Text(selectedCat.name,
                        style: TextStyle(
                            color: selectedCat.color,
                            fontWeight: FontWeight.w500,
                            fontSize: 14)),
                  ] else ...[
                    Icon(Icons.category_outlined,
                        size: 16, color: Theme.of(context).hintColor),
                    const SizedBox(width: 8),
                    Text('Category (optional)',
                        style: TextStyle(
                            color: Theme.of(context).hintColor,
                            fontSize: 14)),
                  ],
                  const Spacer(),
                  Icon(Icons.chevron_right,
                      size: 18, color: Theme.of(context).hintColor),
                ],
              ),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13)),
          ],

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AC.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(
                      isCreate ? 'Add Transaction' : 'Save Changes',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Debit / Credit chip ──────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _TypeChip(
      {required this.label,
      required this.selected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border.all(
              color: selected ? color : Theme.of(context).dividerColor),
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

// ─── Profile sheet ────────────────────────────────────────────────────────────

class _ProfileSheet extends ConsumerStatefulWidget {
  const _ProfileSheet();

  @override
  ConsumerState<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends ConsumerState<_ProfileSheet> {
  bool? _gmailConnected;

  @override
  void initState() {
    super.initState();
    GmailReader.isSignedIn().then((v) {
      if (mounted) setState(() => _gmailConnected = v);
    });
  }

  Future<void> _toggleGmail() async {
    if (_gmailConnected == true) {
      await GmailReader.signOut();
      setState(() => _gmailConnected = false);
    } else {
      final account = await GmailReader.signIn();
      setState(() => _gmailConnected = account != null);
      if (account != null && mounted) {
        Navigator.pop(context);
        ref
            .read(todayProvider.notifier)
            .load(ref.read(todayProvider).date, forceRescan: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 32,
            backgroundColor: cs.primary.withValues(alpha: 0.12),
            child: Icon(Icons.person, size: 36, color: cs.primary),
          ),
          const SizedBox(height: 12),
          if (user != null) ...[
            Text(user.name,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(user.email,
                style: Theme.of(context).textTheme.bodyMedium),
          ] else
            Text('Profile',
                style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AC.gmailColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.mail_outline,
                  color: AC.gmailColor, size: 20),
            ),
            title: const Text('Gmail'),
            subtitle: Text(
              _gmailConnected == null
                  ? 'Checking…'
                  : _gmailConnected!
                      ? 'Connected'
                      : 'Not connected',
              style: TextStyle(
                color: _gmailConnected == true
                    ? AC.credit
                    : Theme.of(context).textTheme.bodySmall?.color,
                fontSize: 13,
              ),
            ),
            trailing: _gmailConnected == null
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : TextButton(
                    onPressed: _toggleGmail,
                    style: TextButton.styleFrom(
                      foregroundColor: _gmailConnected!
                          ? Theme.of(context).colorScheme.error
                          : cs.primary,
                    ),
                    child:
                        Text(_gmailConnected! ? 'Disconnect' : 'Connect'),
                  ),
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .error
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.logout,
                  color: Theme.of(context).colorScheme.error, size: 20),
            ),
            title: Text('Logout',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error)),
            onTap: () async {
              Navigator.pop(context);
              await ref.read(authProvider.notifier).logout();
            },
          ),
        ],
      ),
    );
  }
}
