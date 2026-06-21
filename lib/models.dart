import 'package:flutter/material.dart';
import 'core/date_utils.dart';
import 'core/transaction_source_notes.dart';

// ─── User ────────────────────────────────────────────────────────────────────

class User {
  final String id;
  final String name;
  final String email;
  final bool autoMergeSources;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.autoMergeSources = true,
  });

  User copyWith({
    String? name,
    String? email,
    bool? autoMergeSources,
  }) =>
      User(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        autoMergeSources: autoMergeSources ?? this.autoMergeSources,
      );

  factory User.fromJson(Map<String, dynamic> j) => User(
    id: j['_id'] ?? j['id'] ?? '',
    name: j['name'] ?? '',
    email: j['email'] ?? '',
    autoMergeSources: j['autoMergeSources'] as bool? ?? true,
  );
}

// ─── Category ────────────────────────────────────────────────────────────────

class Category {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final bool isDefault;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.isDefault = false,
  });

  factory Category.fromJson(Map<String, dynamic> j) => Category(
    id: j['_id'] ?? j['id'] ?? '',
    name: j['name'] ?? '',
    icon: _icon(j['icon'] ?? ''),
    color: _color(j['color'] ?? '#6366F1'),
    isDefault: j['isDefault'] == true,
  );

  static IconData _icon(String name) => switch (name.toLowerCase()) {
    'restaurant' || 'fastfood' || 'food_bank' => Icons.restaurant,
    'directions_car' || 'commute' || 'local_taxi' => Icons.directions_car,
    'shopping_bag' || 'shopping_cart' || 'local_mall' => Icons.shopping_bag,
    'health_and_safety' ||
    'local_hospital' ||
    'medication' => Icons.health_and_safety,
    'movie' || 'sports_esports' || 'music_note' => Icons.movie,
    'home' || 'house' || 'apartment' => Icons.home,
    'school' || 'book' || 'menu_book' => Icons.school,
    'bolt' || 'water_drop' || 'wifi' => Icons.bolt,
    'flight' || 'hotel' || 'travel_explore' => Icons.flight,
    'local_gas_station' => Icons.local_gas_station,
    'receipt_long' => Icons.receipt_long,
    'trending_up' => Icons.trending_up,
    'pets' => Icons.pets,
    'fitness_center' => Icons.fitness_center,
    'child_care' => Icons.child_care,
    'more_horiz' || 'category' => Icons.category,
    _ => Icons.category,
  };

  static Color _color(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return const Color(0xFF6366F1);
    }
  }
}

// ─── Payment instrument ───────────────────────────────────────────────────────

enum PaymentInstrumentType {
  creditCard,
  debitCard,
  bankAccount,
  upi,
  wallet,
}

class PaymentInstrument {
  final String id;
  final String name;
  final PaymentInstrumentType type;
  final String? issuer;
  final String? last4;
  final Color color;
  final String icon;
  final int? billingCycleDay;
  final List<String> matchHints;

  const PaymentInstrument({
    required this.id,
    required this.name,
    required this.type,
    this.issuer,
    this.last4,
    required this.color,
    required this.icon,
    this.billingCycleDay,
    this.matchHints = const [],
  });

  factory PaymentInstrument.fromJson(Map<String, dynamic> j) =>
      PaymentInstrument(
        id: j['_id'] ?? j['id'] ?? '',
        name: j['name'] ?? '',
        type: switch (j['type']) {
          'debit_card' => PaymentInstrumentType.debitCard,
          'bank_account' => PaymentInstrumentType.bankAccount,
          'upi' => PaymentInstrumentType.upi,
          'wallet' => PaymentInstrumentType.wallet,
          _ => PaymentInstrumentType.creditCard,
        },
        issuer: j['issuer'] as String?,
        last4: j['last4'] as String?,
        color: Category._color(j['color'] ?? '#845EF7'),
        icon: j['icon'] as String? ?? 'credit_card',
        billingCycleDay: (j['billingCycleDay'] as num?)?.toInt(),
        matchHints: (j['matchHints'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': switch (type) {
      PaymentInstrumentType.debitCard => 'debit_card',
      PaymentInstrumentType.bankAccount => 'bank_account',
      PaymentInstrumentType.upi => 'upi',
      PaymentInstrumentType.wallet => 'wallet',
      _ => 'credit_card',
    },
    if (issuer != null) 'issuer': issuer,
    if (last4 != null) 'last4': last4,
    'color': '#${color.toARGB32().toRadixString(16).substring(2)}',
    'icon': icon,
    if (billingCycleDay != null) 'billingCycleDay': billingCycleDay,
    if (matchHints.isNotEmpty) 'matchHints': matchHints,
  };

  String get displayName =>
      last4 != null && last4!.isNotEmpty ? '$name •$last4' : name;
}

// ─── Transaction ─────────────────────────────────────────────────────────────

enum TxSource { sms, gmail, manual }

enum TxKind { purchase, refund, ccBillPayment, selfTransfer, adjustment }

class Transaction {
  final String? id;
  final String merchant;
  final double amount;
  final bool isDebit;
  final DateTime date;
  final String? categoryId;
  final Category? category;
  final TxSource source;
  final TxKind kind;
  final String? linkedTransactionId;
  final String? paymentInstrumentId;
  final String? paymentInstrumentName;
  final String? counterpartyInstrumentId;
  final String? counterpartyInstrumentName;
  final String? account;
  final String? rawText;

  const Transaction({
    this.id,
    required this.merchant,
    required this.amount,
    required this.isDebit,
    required this.date,
    this.categoryId,
    this.category,
    required this.source,
    this.kind = TxKind.purchase,
    this.linkedTransactionId,
    this.paymentInstrumentId,
    this.paymentInstrumentName,
    this.counterpartyInstrumentId,
    this.counterpartyInstrumentName,
    this.account,
    this.rawText,
  });

  bool get isSaved => id != null;
  bool get isCategorized => categoryId != null;

  Map<TxSource, String> get sourceTexts =>
      TransactionSourceNotes.parse(rawText, primary: source);

  List<TxSource> get sources =>
      TransactionSourceNotes.orderedSourcesFromParts(
        TransactionSourceNotes.parseParts(rawText, primary: source),
      );

  bool get hasMultipleSources =>
      TransactionSourceNotes.isSplittable(rawText, primary: source);

  String? textForSource(TxSource s) => sourceTexts[s];

  /// Merge two rows for the same payment (SMS + email) into one.
  static Transaction merge(
    Transaction a,
    Transaction b, {
    double? amount,
    DateTime? date,
    String? merchant,
    String? rawTextOverride,
  }) {
    final partsMap = <TxSource, String>{...a.sourceTexts, ...b.sourceTexts};
    final mergedParts = TransactionSourceNotes.mergeParts(
      TransactionSourceNotes.parseParts(a.rawText, primary: a.source),
      TransactionSourceNotes.parseParts(b.rawText, primary: b.source),
    );
    final encoded = rawTextOverride ?? TransactionSourceNotes.encodeParts(mergedParts);
    final pickedMerchant = merchant ?? _pickMerchant(a.merchant, b.merchant);
    return Transaction(
      id: a.id ?? b.id,
      merchant: pickedMerchant,
      amount: amount ?? a.amount,
      isDebit: a.isDebit,
      date: date ?? (a.date.isAfter(b.date) ? a.date : b.date),
      categoryId: a.categoryId ?? b.categoryId,
      category: a.category ?? b.category,
      source: partsMap.containsKey(TxSource.sms)
          ? TxSource.sms
          : (partsMap.containsKey(TxSource.gmail) ? TxSource.gmail : a.source),
      kind: a.kind,
      linkedTransactionId: a.linkedTransactionId ?? b.linkedTransactionId,
      paymentInstrumentId: a.paymentInstrumentId ?? b.paymentInstrumentId,
      paymentInstrumentName: a.paymentInstrumentName ?? b.paymentInstrumentName,
      counterpartyInstrumentId: a.counterpartyInstrumentId ?? b.counterpartyInstrumentId,
      counterpartyInstrumentName: a.counterpartyInstrumentName ?? b.counterpartyInstrumentName,
      account: a.account ?? b.account,
      rawText: encoded.isEmpty ? null : encoded,
    );
  }

  static String _pickMerchant(String a, String b) {
    bool ok(String m) =>
        m.trim().isNotEmpty && m.trim().toLowerCase() != 'unknown';
    if (ok(a) && !ok(b)) return a;
    if (ok(b) && !ok(a)) return b;
    if (ok(a) && ok(b)) return a.length >= b.length ? a : b;
    return a;
  }

  String? get noteForApi {
    if (rawText == null) return null;
    final parts = TransactionSourceNotes.parseParts(rawText, primary: source);
    final plain = parts
        .map((p) => SourceNotePart(
              marker: p.marker,
              source: p.source,
              text: TransactionSourceNotes.stripHtmlToPlain(p.text),
            ))
        .where((p) => p.text.isNotEmpty && !TransactionSourceNotes.isPlaceholder(p.text))
        .toList();
    if (plain.isEmpty) return null;
    return TransactionSourceNotes.encodeParts(plain);
  }

  Transaction withCategory(String catId) => Transaction(
    id: id,
    merchant: merchant,
    amount: amount,
    isDebit: isDebit,
    date: date,
    categoryId: catId,
    category: category,
    source: source,
    kind: kind,
    linkedTransactionId: linkedTransactionId,
    paymentInstrumentId: paymentInstrumentId,
    paymentInstrumentName: paymentInstrumentName,
    counterpartyInstrumentId: counterpartyInstrumentId,
    counterpartyInstrumentName: counterpartyInstrumentName,
    account: account,
    rawText: rawText,
  );

  Transaction withTransferInstruments({
    String? fromId,
    String? fromName,
    String? toId,
    String? toName,
  }) => Transaction(
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
    paymentInstrumentId: fromId ?? paymentInstrumentId,
    paymentInstrumentName: fromName ?? paymentInstrumentName,
    counterpartyInstrumentId: toId ?? counterpartyInstrumentId,
    counterpartyInstrumentName: toName ?? counterpartyInstrumentName,
    account: account,
    rawText: rawText,
  );

  Transaction withId(String newId) => Transaction(
    id: newId,
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
    counterpartyInstrumentId: counterpartyInstrumentId,
    counterpartyInstrumentName: counterpartyInstrumentName,
    account: account,
    rawText: rawText,
  );

  Transaction withKind(TxKind newKind, {String? linkedId}) => Transaction(
    id: id,
    merchant: merchant,
    amount: amount,
    isDebit: isDebit,
    date: date,
    categoryId: categoryId,
    category: category,
    source: source,
    kind: newKind,
    linkedTransactionId: newKind == TxKind.refund ? linkedId : null,
    paymentInstrumentId: paymentInstrumentId,
    paymentInstrumentName: paymentInstrumentName,
    counterpartyInstrumentId: counterpartyInstrumentId,
    counterpartyInstrumentName: counterpartyInstrumentName,
    account: account,
    rawText: rawText,
  );

  Transaction withPaymentInstrument(String? instId, {String? name}) => Transaction(
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
    paymentInstrumentId: instId,
    paymentInstrumentName: name,
    counterpartyInstrumentId: counterpartyInstrumentId,
    counterpartyInstrumentName: counterpartyInstrumentName,
    account: account,
    rawText: rawText,
  );

  factory Transaction.fromJson(Map<String, dynamic> j) {
    final cat = j['category'];
    return Transaction(
      id: j['_id'] ?? j['id'] ?? '',
      merchant: j['merchant'] ?? j['title'] ?? 'Unknown',
      amount: (j['amount'] as num?)?.toDouble() ?? 0.0,
      isDebit: (j['type'] ?? 'debit') == 'debit',
      date: parseApiDateTime(j['date']),
      categoryId: cat is Map ? cat['_id'] ?? cat['id'] : j['categoryId'],
      category: cat is Map
          ? Category.fromJson(cat as Map<String, dynamic>)
          : null,
      source: switch (j['source']) {
        'sms' => TxSource.sms,
        'gmail' || 'email' => TxSource.gmail,
        _ => TxSource.manual,
      },
      kind: switch (j['kind']) {
        'refund' => TxKind.refund,
        'cc_bill_payment' => TxKind.ccBillPayment,
        'self_transfer' => TxKind.selfTransfer,
        'adjustment' => TxKind.adjustment,
        _ => TxKind.purchase,
      },
      linkedTransactionId: j['linkedTransactionId'] as String?,
      paymentInstrumentId: j['paymentInstrumentId'] as String?,
      paymentInstrumentName: j['paymentInstrumentName'] as String?,
      counterpartyInstrumentId: j['counterpartyInstrumentId'] as String?,
      counterpartyInstrumentName: j['counterpartyInstrumentName'] as String?,
      account: j['account'] as String?,
      rawText: j['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'merchant': merchant,
    'amount': amount,
    'type': isDebit ? 'debit' : 'credit',
    // Always UTC+Z — some validators reject dates without a timezone
    'date': DateTime.fromMillisecondsSinceEpoch(
      date.millisecondsSinceEpoch,
      isUtc: true,
    ).toIso8601String(),
    'source': _apiSource(source),
    'kind': switch (kind) {
      TxKind.ccBillPayment => 'cc_bill_payment',
      TxKind.selfTransfer => 'self_transfer',
      _ => kind.name,
    },
    if (linkedTransactionId != null) 'linkedTransactionId': linkedTransactionId,
    if (paymentInstrumentId != null) 'paymentInstrumentId': paymentInstrumentId,
    if (counterpartyInstrumentId != null)
      'counterpartyInstrumentId': counterpartyInstrumentId,
    if (account != null) 'account': account,
    if (categoryId != null) 'categoryId': categoryId,
    if (rawText != null) 'note': noteForApi,
  };

  static String _apiSource(TxSource s) => switch (s) {
    TxSource.gmail => 'email',
    _ => s.name,
  };
}
