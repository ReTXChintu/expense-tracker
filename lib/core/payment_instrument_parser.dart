import '../models.dart';

class ParsedPaymentInstrumentHints {
  final String? rawAccountLabel;
  final String? last4;
  final String? issuer;

  const ParsedPaymentInstrumentHints({
    this.rawAccountLabel,
    this.last4,
    this.issuer,
  });
}

final _issuerPatterns = <(RegExp, String)>[
  (RegExp(r'\bHDFC\b', caseSensitive: false), 'HDFC'),
  (RegExp(r'\bICICI\b', caseSensitive: false), 'ICICI'),
  (RegExp(r'\bSBI\b|\bState Bank\b', caseSensitive: false), 'SBI'),
  (RegExp(r'\bAxis\b', caseSensitive: false), 'Axis'),
  (RegExp(r'\bKotak\b', caseSensitive: false), 'Kotak'),
  (RegExp(r'\bYes Bank\b|\bYESBANK\b', caseSensitive: false), 'Yes Bank'),
  (RegExp(r'\bIndusInd\b', caseSensitive: false), 'IndusInd'),
  (RegExp(r'\bIDFC\b', caseSensitive: false), 'IDFC'),
  (RegExp(r'\bPaytm\b', caseSensitive: false), 'Paytm'),
  (RegExp(r'\bPhonePe\b', caseSensitive: false), 'PhonePe'),
];

final _last4Patterns = [
  RegExp(
    r'(?:card|a\/c|ac|account)\s*(?:no\.?|number|#)?\s*(?:XX|\*+|x+|X+)?(\d{4})',
    caseSensitive: false,
  ),
  RegExp(
    r'(?:ending|ends)\s*(?:with|in)?\s*(?:XX|\*+|x+|X+)?(\d{4})',
    caseSensitive: false,
  ),
  RegExp(r'(?:XX|\*+|x+|X+)(\d{4})'),
];

ParsedPaymentInstrumentHints parsePaymentInstrumentHints(String text) {
  String? last4;
  for (final pattern in _last4Patterns) {
    final match = pattern.firstMatch(text);
    if (match != null && match.groupCount >= 1) {
      last4 = match.group(1);
      break;
    }
  }

  String? issuer;
  for (final (regex, name) in _issuerPatterns) {
    if (regex.hasMatch(text)) {
      issuer = name;
      break;
    }
  }

  String? rawAccountLabel;
  if (issuer != null || last4 != null) {
    rawAccountLabel = [issuer, last4 != null ? 'XX$last4' : null]
        .whereType<String>()
        .join(' ');
  }

  return ParsedPaymentInstrumentHints(
    rawAccountLabel: rawAccountLabel,
    last4: last4,
    issuer: issuer,
  );
}

bool _issuerMatches(String? a, String? b) {
  if (a == null || b == null) return false;
  final la = a.toLowerCase();
  final lb = b.toLowerCase();
  return la.contains(lb) || lb.contains(la);
}

({String? paymentInstrumentId, String? account}) matchPaymentInstrument(
  ParsedPaymentInstrumentHints hints,
  List<PaymentInstrument> instruments,
) {
  if (hints.last4 != null && hints.issuer != null) {
    for (final inst in instruments) {
      if (inst.last4 == hints.last4 && _issuerMatches(inst.issuer, hints.issuer)) {
        return (paymentInstrumentId: inst.id, account: hints.rawAccountLabel);
      }
    }
  }

  if (hints.last4 != null) {
    final matches = instruments.where((i) => i.last4 == hints.last4).toList();
    if (matches.length == 1) {
      return (paymentInstrumentId: matches.first.id, account: hints.rawAccountLabel);
    }
  }

  if (hints.rawAccountLabel != null) {
    final lower = hints.rawAccountLabel!.toLowerCase();
    for (final inst in instruments) {
      if (inst.matchHints.any((h) => lower.contains(h.toLowerCase()))) {
        return (paymentInstrumentId: inst.id, account: hints.rawAccountLabel);
      }
    }
  }

  return (paymentInstrumentId: null, account: hints.rawAccountLabel);
}

Transaction applyInstrumentMatch(Transaction tx, List<PaymentInstrument> instruments) {
  final hints = parsePaymentInstrumentHints(tx.rawText ?? '');
  final matched = matchPaymentInstrument(hints, instruments);
  if (matched.paymentInstrumentId == null && matched.account == null) return tx;
  final inst = instruments.where((i) => i.id == matched.paymentInstrumentId).firstOrNull;
  return tx.withPaymentInstrument(
    matched.paymentInstrumentId,
    name: inst?.displayName,
  ).copyWithAccount(matched.account);
}

extension on Transaction {
  Transaction copyWithAccount(String? acct) => Transaction(
    id: id,
    merchant: merchant,
    amount: amount,
    isDebit: isDebit,
    date: date,
    categoryId: categoryId,
    category: category,
    source: source,
    kind: kind,
    linkedTransactionId: linkedTransactionId,
    paymentInstrumentId: paymentInstrumentId,
    paymentInstrumentName: paymentInstrumentName,
    account: acct ?? account,
    rawText: rawText,
  );
}
