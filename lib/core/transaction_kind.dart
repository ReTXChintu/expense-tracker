import '../models.dart';

const excludedSpendKinds = {
  'cc_bill_payment',
  'self_transfer',
  'emi',
  'emi_repayment',
  'split_settlement',
};

const kindLabels = {
  TxKind.purchase: 'Purchase',
  TxKind.refund: 'Refund',
  TxKind.ccBillPayment: 'CC bill payment',
  TxKind.selfTransfer: 'Self transfer',
  TxKind.adjustment: 'Adjustment',
  TxKind.emi: 'EMI',
  TxKind.emiRepayment: 'EMI repayment',
  TxKind.split: 'Split',
  TxKind.splitSettlement: 'Split settlement',
};

bool countsInSpendAnalytics(TxKind kind) {
  if (kind == TxKind.purchase || kind == TxKind.adjustment || kind == TxKind.refund) {
    return true;
  }
  if (kind == TxKind.split) return true;
  return !excludedSpendKinds.contains(txKindToApi(kind));
}

double effectiveSpendAmount(Transaction tx) {
  if (tx.kind == TxKind.split) return tx.ownerShareAmount ?? 0;
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
    'emi' => TxKind.emi,
    'emi_repayment' => TxKind.emiRepayment,
    'split' => TxKind.split,
    'split_settlement' => TxKind.splitSettlement,
    _ => TxKind.purchase,
  };
}

String txKindToApi(TxKind kind) => switch (kind) {
  TxKind.ccBillPayment => 'cc_bill_payment',
  TxKind.selfTransfer => 'self_transfer',
  TxKind.emiRepayment => 'emi_repayment',
  TxKind.splitSettlement => 'split_settlement',
  _ => kind.name,
};
