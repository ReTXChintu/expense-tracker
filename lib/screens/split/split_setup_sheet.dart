import 'package:flutter/material.dart';

class SplitParticipantDraft {
  final String name;
  final double shareAmount;

  const SplitParticipantDraft({required this.name, required this.shareAmount});

  Map<String, dynamic> toJson() => {
    'name': name,
    'shareAmount': shareAmount,
  };
}

class _ParticipantRow {
  final TextEditingController nameCtrl;
  final TextEditingController amountCtrl;

  _ParticipantRow({String name = '', String amount = ''})
      : nameCtrl = TextEditingController(text: name),
        amountCtrl = TextEditingController(text: amount);

  void dispose() {
    nameCtrl.dispose();
    amountCtrl.dispose();
  }
}

Future<List<SplitParticipantDraft>?> showSplitSetupSheet(
  BuildContext context, {
  required double totalAmount,
  List<SplitParticipantDraft>? initial,
}) {
  return showModalBottomSheet<List<SplitParticipantDraft>>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SplitSetupSheet(totalAmount: totalAmount, initial: initial),
  );
}

class _SplitSetupSheet extends StatefulWidget {
  final double totalAmount;
  final List<SplitParticipantDraft>? initial;

  const _SplitSetupSheet({required this.totalAmount, this.initial});

  @override
  State<_SplitSetupSheet> createState() => _SplitSetupSheetState();
}

class _SplitSetupSheetState extends State<_SplitSetupSheet> {
  final List<_ParticipantRow> _rows = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null && initial.isNotEmpty) {
      for (final p in initial) {
        _rows.add(
          _ParticipantRow(
            name: p.name,
            amount: p.shareAmount.toStringAsFixed(0),
          ),
        );
      }
    } else {
      _rows.add(_ParticipantRow());
    }
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  double get _assigned {
    var sum = 0.0;
    for (final r in _rows) {
      sum += double.tryParse(r.amountCtrl.text.replaceAll(',', '').trim()) ?? 0;
    }
    return sum;
  }

  double get _ownerShare => widget.totalAmount - _assigned;

  void _addRow() => setState(() => _rows.add(_ParticipantRow()));

  void _removeRow(int i) {
    if (_rows.length <= 1) return;
    setState(() {
      _rows[i].dispose();
      _rows.removeAt(i);
    });
  }

  void _save() {
    final drafts = <SplitParticipantDraft>[];
    for (final r in _rows) {
      final name = r.nameCtrl.text.trim();
      final amount = double.tryParse(r.amountCtrl.text.replaceAll(',', '').trim());
      if (name.isEmpty || amount == null || amount <= 0) {
        setState(() => _error = 'Enter a name and valid amount for each person');
        return;
      }
      drafts.add(SplitParticipantDraft(name: name, shareAmount: amount));
    }
    if (_ownerShare < 0) {
      setState(() => _error = 'Shares exceed the total amount');
      return;
    }
    if ((drafts.fold<double>(0, (s, p) => s + p.shareAmount) + _ownerShare - widget.totalAmount).abs() > 1) {
      setState(() => _error = 'Shares must add up to the expense total');
      return;
    }
    Navigator.pop(context, drafts);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Split expense', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Total ₹${widget.totalAmount.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              ...List.generate(_rows.length, (i) {
                final row = _rows[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: row.nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: row.amountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Owes ₹',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _removeRow(i),
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ],
                  ),
                );
              }),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  label: const Text('Add person'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your share: ₹${_ownerShare.clamp(0, widget.totalAmount).toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 16),
              FilledButton(onPressed: _save, child: const Text('Save split')),
            ],
          ),
        ),
      ),
    );
  }
}
