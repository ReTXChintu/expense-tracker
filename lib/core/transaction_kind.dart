import '../models.dart';

const excludedSpendKinds = {'cc_bill_payment', 'self_transfer'};

const kindLabels = {
  TxKind.purchase: 'Purchase',
  TxKind.refund: 'Refund',
  TxKind.ccBillPayment: 'CC bill payment',
  TxKind.selfTransfer: 'Self transfer',
  TxKind.adjustment: 'Adjustment',
};

bool countsInSpendAnalytics(TxKind kind) {
  if (kind == TxKind.purchase || kind == TxKind.adjustment || kind == TxKind.refund) {
    return true;
  }
  return !excludedSpendKinds.contains(txKindToApi(kind));
}

double effectiveSpendAmount(Transaction tx) {
  if (!countsInSpendAnalytics(tx.kind)) return 0;
  if (tx.kind == TxKind.refund) return -tx.amount;
  if (tx.isDebit) return tx.amount;
  return 0;
}

double sumNetSpend(Iterable<Transaction> txs) {
  var total = 0.0;
  for (final t in txs) {
    total += effectiveSpendAmount(t);
  }
  return total < 0 ? 0 : total;
}

TxKind parseTxKind(String? value) {
  return switch (value) {
    'refund' => TxKind.refund,
    'cc_bill_payment' => TxKind.ccBillPayment,
    'self_transfer' => TxKind.selfTransfer,
    'adjustment' => TxKind.adjustment,
    _ => TxKind.purchase,
  };
}

String txKindToApi(TxKind kind) => switch (kind) {
  TxKind.ccBillPayment => 'cc_bill_payment',
  TxKind.selfTransfer => 'self_transfer',
  _ => kind.name,
};
