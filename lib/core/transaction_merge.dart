import '../models.dart';
import 'transaction_source_notes.dart';

class MergeOptions {
  final double? amount;
  final DateTime? date;
  final String? merchant;

  const MergeOptions({this.amount, this.date, this.merchant});
}

abstract final class TransactionMerge {
  static bool canMergeTypes(Transaction a, Transaction b) => a.isDebit == b.isDebit;

  static bool amountsDiffer(Transaction a, Transaction b) =>
      (a.amount - b.amount).abs() > 0.001;

  static bool timesDiffer(Transaction a, Transaction b) =>
      a.date.difference(b.date).inMinutes.abs() > 0;

  static List<SourceNotePart> _partsWithFallback(Transaction tx) {
    return TransactionSourceNotes.parseParts(tx.rawText, primary: tx.source);
  }

  static Transaction merge(
    Transaction a,
    Transaction b, {
    MergeOptions? options,
  }) {
    final mergedParts = TransactionSourceNotes.mergeParts(
      _partsWithFallback(a),
      _partsWithFallback(b),
    );
    final encoded = TransactionSourceNotes.encodeParts(mergedParts);
    return Transaction.merge(
      a,
      b,
      amount: options?.amount,
      date: options?.date,
      merchant: options?.merchant,
      rawTextOverride: encoded.isEmpty ? null : encoded,
    );
  }

  /// Split a merged transaction into separate draft rows (no ids).
  static List<Transaction> split(Transaction tx) {
    final parts = TransactionSourceNotes.parseParts(tx.rawText, primary: tx.source);
    if (parts.length < 2) return [tx];

    return parts.map((part) {
      final note = TransactionSourceNotes.encodeParts([part]);
      return Transaction(
        merchant: tx.merchant,
        amount: tx.amount,
        isDebit: tx.isDebit,
        date: tx.date,
        categoryId: tx.categoryId,
        category: tx.category,
        source: part.source,
        kind: tx.kind,
        linkedTransactionId: tx.linkedTransactionId,
        paymentInstrumentId: tx.paymentInstrumentId,
        paymentInstrumentName: tx.paymentInstrumentName,
        counterpartyInstrumentId: tx.counterpartyInstrumentId,
        counterpartyInstrumentName: tx.counterpartyInstrumentName,
        account: tx.account,
        rawText: note.isEmpty ? null : note,
      );
    }).toList();
  }
}
