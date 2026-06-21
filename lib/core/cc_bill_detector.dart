import '../models.dart';

final _ccBillHints = [
  RegExp(r'credit\s+card\s+(?:bill|payment|bill\s+payment)', caseSensitive: false),
  RegExp(
    r'(?:payment|paid)\s+(?:received\s+)?(?:towards|to)\s+(?:your\s+)?(?:credit\s+card|card\s+ending)',
    caseSensitive: false,
  ),
  RegExp(r'card\s+ending\s+\d{4}', caseSensitive: false),
  RegExp(r'(?:cc|card)\s+bill\s+(?:paid|payment)', caseSensitive: false),
];

bool detectCcBillPayment(String rawText) =>
    _ccBillHints.any((re) => re.hasMatch(rawText));

TxKind? suggestedKindFromRawText(String rawText) {
  if (detectCcBillPayment(rawText)) return TxKind.ccBillPayment;
  if (RegExp(r'self\s+transfer|transfer\s+to\s+self', caseSensitive: false)
      .hasMatch(rawText)) {
    return TxKind.selfTransfer;
  }
  if (RegExp(r'refund|reversal|reversed', caseSensitive: false)
      .hasMatch(rawText)) {
    return TxKind.refund;
  }
  return null;
}

Transaction applySuggestedKind(Transaction tx) {
  final text = tx.rawText ?? '';
  if (text.isEmpty || tx.kind != TxKind.purchase) return tx;
  final kind = suggestedKindFromRawText(text);
  if (kind == null) return tx;
  return tx.withKind(kind);
}
