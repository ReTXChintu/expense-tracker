import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers.dart';
import '../models.dart';
import '../theme.dart';
import '../core/transaction_kind.dart';
import '../core/gmail_reader.dart';
import '../core/date_utils.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/empty_state.dart';
import 'today/merge_helper_sheets.dart';
import 'today/today_hero.dart';
import 'today/section_header.dart';
import 'today/tx_tile.dart';
import 'today/transaction_editor_sheet.dart';
import 'today/transaction_helper_sheets.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  bool _mergeMode = false;
  final Set<String> _selectedIds = {};

  void _toggleMergeMode() {
    setState(() {
      _mergeMode = !_mergeMode;
      _selectedIds.clear();
    });
  }

  void _toggleSelect(Transaction tx) {
    final id = tx.id;
    if (id == null) return;
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else if (_selectedIds.length < 2) {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _runMerge(List<Transaction> all) async {
    if (_selectedIds.length != 2) return;
    final selected = all.where((t) => t.id != null && _selectedIds.contains(t.id)).toList();
    if (selected.length != 2) return;

    final options = await showMergeFlow(context, selected[0], selected[1]);
    if (options == null || !mounted) return;

    try {
      await ref.read(todayProvider.notifier).mergeSaved(selected[0], selected[1], options);
      if (!mounted) return;
      setState(() {
        _mergeMode = false;
        _selectedIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transactions merged')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Merge failed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            await ref
                .read(todayProvider.notifier)
                .createTransaction(
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

    Future<void> pickDate() async {
      final today = normalizeCalendarDate(DateTime.now());
      final picked = await showDatePicker(
        context: context,
        initialDate: normalizeCalendarDate(state.date),
        firstDate: DateTime(2020, 1, 1),
        lastDate: today,
        helpText: 'Jump to date',
        cancelText: 'Cancel',
        confirmText: 'Go',
      );
      if (picked != null) {
        ref.read(todayProvider.notifier).goToDate(picked);
      }
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
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_mergeMode) ...[
            TextButton(
              onPressed: _toggleMergeMode,
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: _selectedIds.length == 2
                  ? () => _runMerge(state.transactions)
                  : null,
              child: Text('Merge (${_selectedIds.length})'),
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.call_merge),
              tooltip: 'Merge transactions',
              onPressed: _toggleMergeMode,
            ),
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Pick date',
            onPressed: pickDate,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous day',
            onPressed: () {
              final prev = normalizeCalendarDate(
                state.date,
              ).subtract(const Duration(days: 1));
              ref.read(todayProvider.notifier).goToDate(prev);
            },
          ),
          if (!isToday(state.date))
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next day',
              onPressed: () {
                final next = normalizeCalendarDate(
                  state.date,
                ).add(const Duration(days: 1));
                ref.read(todayProvider.notifier).goToDate(next);
              },
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
        ],
      ),
      body: (state.loading && state.transactions.isEmpty)
          ? const Center(child: CircularProgressIndicator())
          : categories.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (cats) => _Body(
                state: state,
                categories: cats,
                mergeMode: _mergeMode,
                selectedIds: _selectedIds,
                onToggleSelect: _toggleSelect,
              ),
            ),
    );
  }
}

// â”€â”€â”€ Body â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _Body extends ConsumerStatefulWidget {
  final TodayState state;
  final List<Category> categories;
  final bool mergeMode;
  final Set<String> selectedIds;
  final ValueChanged<Transaction> onToggleSelect;

  const _Body({
    required this.state,
    required this.categories,
    this.mergeMode = false,
    this.selectedIds = const {},
    required this.onToggleSelect,
  });

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _gmailConnected = false;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _checkGmail();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkGmail() async {
    final connected = await GmailReader.isSignedIn();
    if (mounted) setState(() => _gmailConnected = connected);
  }

  Future<void> _connectGmail() async {
    try {
      final account = await GmailReader.signIn();
      if (account != null) {
        setState(() => _gmailConnected = true);
        if (mounted) {
          await ref.read(todayProvider.notifier).onGmailConnected();
        }
      }
    } on GmailReaderException catch (e) {
      if (mounted) _showGmailSnackBar(context, e.message);
    }
  }

  void _showGmailSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
    );
  }

  void _openEditor(Transaction tx) {
    if (widget.mergeMode) {
      widget.onToggleSelect(tx);
      return;
    }
    TransactionEditorSheet.show(
      context,
      ref,
      transaction: tx,
      categories: widget.categories,
    );
  }

  void _onSwipeDelete(Transaction tx) {
    final id = tx.id;
    if (id == null) return;
    ref.read(todayProvider.notifier).stageDelete(tx);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Transaction deleted'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => ref.read(todayProvider.notifier).undoDelete(id),
        ),
      ),
    );
  }

  Widget _buildTile(Transaction tx, List<Category> cats) {
    final id = tx.id;
    final selected = id != null && widget.selectedIds.contains(id);
    final tile = TxTile(
      tx: tx,
      categories: cats,
      selectionMode: widget.mergeMode,
      selected: selected,
      onTap: () {
        HapticFeedback.lightImpact();
        _openEditor(tx);
      },
    );
    if (widget.mergeMode) return tile;
    return _Deletable(
      key: ValueKey('d_${tx.id}'),
      onDelete: () => _onSwipeDelete(tx),
      child: tile,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final cats = widget.categories;

    final uncategorized = state.transactions
        .where((t) => !t.isCategorized)
        .toList();
    final categorized = state.transactions
        .where((t) => t.isCategorized)
        .toList();

    final debitTotal = sumNetSpend(categorized);

    return RefreshIndicator(
      onRefresh: () => ref
          .read(todayProvider.notifier)
          .load(state.date, forceRescan: true),
      child: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
        // Gmail connect banner
        if (!_gmailConnected)
          SliverToBoxAdapter(
            child: _GmailBanner(
              onConnect: _connectGmail,
              notConfigured: !GmailReader.isConfigured,
            ),
          ),

        SliverToBoxAdapter(
          child: TodayHero(
            transactions: state.transactions,
            uncategorizedCount: uncategorized.length,
            onUncategorizedTap: uncategorized.isNotEmpty
                ? () {
                    if (_scrollCtrl.hasClients) {
                      _scrollCtrl.animateTo(
                        180,
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  }
                : null,
          ),
        ),

        // Scanning banner
        if (state.scanning)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  Text(
                    'Scanning messages and Gmail…',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
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
                color: Theme.of(
                  context,
                ).colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                state.error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ),
          ),

        if (uncategorized.isNotEmpty) ...[
          SectionHeader(
            title: 'To Categorize  •  ${uncategorized.length}',
            subtitle: widget.mergeMode
                ? 'Select 2 transactions to merge'
                : 'Tap a transaction to edit',
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((ctx, i) {
              final tx = uncategorized[i];
              return AnimatedListItem(
                index: i,
                child: _buildTile(tx, cats),
              );
            }, childCount: uncategorized.length),
          ),
        ],

        // â”€â”€ Categorized â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        if (categorized.isNotEmpty) ...[
          SectionHeader(
            title: 'Done  •  ${categorized.length}',
            subtitle: debitTotal > 0
                ? '₹${debitTotal.toStringAsFixed(0)} spent'
                : 'All categorized',
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((ctx, i) {
              final tx = categorized[i];
              return AnimatedListItem(
                index: i,
                child: _buildTile(tx, cats),
              );
            }, childCount: categorized.length),
          ),
        ],

        // Empty state
        if (state.transactions.isEmpty && !state.scanning)
          const SliverFillRemaining(
            child: Center(
              child: EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No transactions for this day',
                subtitle: 'Tap + to add one manually',
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
      ),
    );
  }
}

// â”€â”€â”€ Deletable wrapper â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

// â”€â”€â”€ Gmail banner â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _GmailBanner extends StatelessWidget {
  final VoidCallback onConnect;
  final bool notConfigured;
  const _GmailBanner({required this.onConnect, this.notConfigured = false});

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
          Expanded(
            child: Text(
              notConfigured
                  ? 'Gmail setup required — add OAuth client ID (see GOOGLE_SETUP.md)'
                  : 'Connect Gmail to fetch transactions from emails',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: onConnect,
            style: TextButton.styleFrom(
              foregroundColor: AC.gmailColor,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
            child: Text(notConfigured ? 'Info' : 'Connect'),
          ),
        ],
      ),
    );
  }
}


// --- Create transaction sheet (FAB add only) ---

class _TransactionSheet extends StatefulWidget {
  final List<Category> categories;
  final DateTime date;
  final Future<void> Function(
    String merchant,
    double amount,
    bool isDebit,
    String? categoryId,
  )
  onSave;

  const _TransactionSheet({
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
    _merchantCtrl = TextEditingController();
    _amountCtrl = TextEditingController();
    _isDebit = true;
  }

  @override
  void dispose() {
    _merchantCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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
            'Add Transaction',
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
                borderRadius: BorderRadius.circular(10),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),

          // Amount
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '₹  ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),

          // Category
          GestureDetector(
            onTap: () async {
              final result = await showCategoryPickerSheet(context);
              if (result != null) setState(() => _categoryId = result.id);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  if (selectedCat != null) ...[
                    Icon(selectedCat.icon, size: 16, color: selectedCat.color),
                    const SizedBox(width: 8),
                    Text(
                      selectedCat.name,
                      style: TextStyle(
                        color: selectedCat.color,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ] else ...[
                    Icon(
                      Icons.category_outlined,
                      size: 16,
                      color: Theme.of(context).hintColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Category (optional)',
                      style: TextStyle(
                        color: Theme.of(context).hintColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Theme.of(context).hintColor,
                  ),
                ],
              ),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
              ),
            ),
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
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Add Transaction',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€ Debit / Credit chip â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
          border: Border.all(
            color: selected ? color : Theme.of(context).dividerColor,
          ),
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

