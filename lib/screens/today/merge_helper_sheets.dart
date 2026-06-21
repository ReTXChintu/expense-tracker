import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/transaction_merge.dart';
import '../../models.dart';
import '../../theme.dart';

class MergeFieldChoices {
  final bool useAmountFromA;
  final bool useTimeFromA;

  const MergeFieldChoices({
    required this.useAmountFromA,
    required this.useTimeFromA,
  });

  MergeOptions toOptions(Transaction a, Transaction b, {required bool amountDiff, required bool timeDiff}) =>
      MergeOptions(
        amount: amountDiff ? (useAmountFromA ? a.amount : b.amount) : null,
        date: timeDiff ? (useTimeFromA ? a.date : b.date) : null,
      );
}

/// Runs merge confirmation + field pickers. Returns null if cancelled or invalid.
Future<MergeOptions?> showMergeFlow(
  BuildContext context,
  Transaction a,
  Transaction b,
) async {
  if (!TransactionMerge.canMergeTypes(a, b)) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cannot merge'),
        content: const Text(
          'Only transactions of the same type (both debit or both credit) can be merged.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
    return null;
  }

  final amountDiff = TransactionMerge.amountsDiffer(a, b);
  final timeDiff = TransactionMerge.timesDiffer(a, b);

  if (amountDiff || timeDiff) {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Merge anyway?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (amountDiff)
              Text('Amounts: ₹${a.amount.toStringAsFixed(0)} vs ₹${b.amount.toStringAsFixed(0)}'),
            if (timeDiff) ...[
              if (amountDiff) const SizedBox(height: 8),
              Text(
                'Times: ${DateFormat.jm().format(a.date.toLocal())} vs ${DateFormat.jm().format(b.date.toLocal())}',
              ),
            ],
            const SizedBox(height: 12),
            const Text('These transactions will be combined into one row.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Merge anyway'),
          ),
        ],
      ),
    );
    if (proceed != true) return null;
  }

  if (!context.mounted) return null;

  if (!amountDiff && !timeDiff) {
    return const MergeOptions();
  }

  final choices = await showModalBottomSheet<MergeFieldChoices>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _MergePickerSheet(a: a, b: b, amountDiff: amountDiff, timeDiff: timeDiff),
  );
  return choices?.toOptions(a, b, amountDiff: amountDiff, timeDiff: timeDiff);
}

class _MergePickerSheet extends StatefulWidget {
  final Transaction a;
  final Transaction b;
  final bool amountDiff;
  final bool timeDiff;

  const _MergePickerSheet({
    required this.a,
    required this.b,
    required this.amountDiff,
    required this.timeDiff,
  });

  @override
  State<_MergePickerSheet> createState() => _MergePickerSheetState();
}

class _MergePickerSheetState extends State<_MergePickerSheet> {
  late bool _useAmountFromA;
  late bool _useTimeFromA;

  @override
  void initState() {
    super.initState();
    _useAmountFromA = true;
    _useTimeFromA = true;
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.a;
    final b = widget.b;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Choose values to keep', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          if (widget.amountDiff) ...[
            Text('Amount', style: Theme.of(context).textTheme.labelLarge),
            RadioGroup<bool>(
              groupValue: _useAmountFromA,
              onChanged: (v) {
                if (v != null) setState(() => _useAmountFromA = v);
              },
              child: Column(
                children: [
                  RadioListTile<bool>(
                    title: Text('${a.merchant} — ₹${a.amount.toStringAsFixed(0)}'),
                    value: true,
                  ),
                  RadioListTile<bool>(
                    title: Text('${b.merchant} — ₹${b.amount.toStringAsFixed(0)}'),
                    value: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (widget.timeDiff) ...[
            Text('Time', style: Theme.of(context).textTheme.labelLarge),
            RadioGroup<bool>(
              groupValue: _useTimeFromA,
              onChanged: (v) {
                if (v != null) setState(() => _useTimeFromA = v);
              },
              child: Column(
                children: [
                  RadioListTile<bool>(
                    title: Text('${a.merchant} — ${DateFormat.jm().format(a.date.toLocal())}'),
                    value: true,
                  ),
                  RadioListTile<bool>(
                    title: Text('${b.merchant} — ${DateFormat.jm().format(b.date.toLocal())}'),
                    value: false,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              MergeFieldChoices(useAmountFromA: _useAmountFromA, useTimeFromA: _useTimeFromA),
            ),
            style: FilledButton.styleFrom(backgroundColor: AC.accent),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

Future<bool> confirmUnmerge(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Unmerge transactions?'),
          content: const Text(
            'Split this into separate rows. Both will use the merged amount and time.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Unmerge')),
          ],
        ),
      ) ??
      false;
}
