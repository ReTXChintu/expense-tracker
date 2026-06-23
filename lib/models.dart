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

enum TxKind {
  purchase,
  refund,
  ccBillPayment,
  selfTransfer,
  adjustment,
  emi,
  emiRepayment,
  split,
  splitSettlement,
}

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
  final String? emiPlanId;
  final String? splitBillId;
  final String? splitParticipantId;
  final double? ownerShareAmount;
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
    this.emiPlanId,
    this.splitBillId,
    this.splitParticipantId,
    this.ownerShareAmount,
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
      emiPlanId: a.emiPlanId ?? b.emiPlanId,
      splitBillId: a.splitBillId ?? b.splitBillId,
      splitParticipantId: a.splitParticipantId ?? b.splitParticipantId,
      ownerShareAmount: a.ownerShareAmount ?? b.ownerShareAmount,
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
    emiPlanId: emiPlanId,
    splitBillId: splitBillId,
    splitParticipantId: splitParticipantId,
    ownerShareAmount: ownerShareAmount,
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
    emiPlanId: emiPlanId,
    splitBillId: splitBillId,
    splitParticipantId: splitParticipantId,
    ownerShareAmount: ownerShareAmount,
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
    emiPlanId: emiPlanId,
    splitBillId: splitBillId,
    splitParticipantId: splitParticipantId,
    ownerShareAmount: ownerShareAmount,
    paymentInstrumentId: paymentInstrumentId,
    paymentInstrumentName: paymentInstrumentName,
    counterpartyInstrumentId: counterpartyInstrumentId,
    counterpartyInstrumentName: counterpartyInstrumentName,
    account: account,
    rawText: rawText,
  );

  Transaction withKind(
    TxKind newKind, {
    String? linkedId,
    String? emiPlan,
    String? splitBill,
    String? splitParticipant,
  }) => Transaction(
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
    emiPlanId: newKind == TxKind.emi || newKind == TxKind.emiRepayment
        ? emiPlan ?? emiPlanId
        : null,
    splitBillId: newKind == TxKind.split || newKind == TxKind.splitSettlement
        ? splitBill ?? splitBillId
        : null,
    splitParticipantId:
        newKind == TxKind.splitSettlement ? splitParticipant ?? splitParticipantId : null,
    ownerShareAmount: newKind == TxKind.split ? ownerShareAmount : null,
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
    emiPlanId: emiPlanId,
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
        'emi' => TxKind.emi,
        'emi_repayment' => TxKind.emiRepayment,
        'split' => TxKind.split,
        'split_settlement' => TxKind.splitSettlement,
        _ => TxKind.purchase,
      },
      linkedTransactionId: j['linkedTransactionId'] as String?,
      emiPlanId: j['emiPlanId'] as String?,
      splitBillId: j['splitBillId'] as String?,
      splitParticipantId: j['splitParticipantId'] as String?,
      ownerShareAmount: (j['ownerShareAmount'] as num?)?.toDouble(),
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
      TxKind.emiRepayment => 'emi_repayment',
      TxKind.splitSettlement => 'split_settlement',
      _ => kind.name,
    },
    if (linkedTransactionId != null) 'linkedTransactionId': linkedTransactionId,
    if (emiPlanId != null) 'emiPlanId': emiPlanId,
    if (splitBillId != null) 'splitBillId': splitBillId,
    if (splitParticipantId != null) 'splitParticipantId': splitParticipantId,
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

// ─── EMI plan ────────────────────────────────────────────────────────────────

class EmiPlan {
  final String id;
  final String originTransactionId;
  final String merchant;
  final double principalAmount;
  final int tenureMonths;
  final DateTime startDate;
  final String? paymentInstrumentId;
  final String status;
  final int paidInstallments;
  final int pendingInstallments;
  final double expectedMonthly;
  final double repaidAmount;
  final DateTime estimatedCompletion;
  final List<EmiRepayment> repayments;

  const EmiPlan({
    required this.id,
    required this.originTransactionId,
    required this.merchant,
    required this.principalAmount,
    required this.tenureMonths,
    required this.startDate,
    this.paymentInstrumentId,
    required this.status,
    required this.paidInstallments,
    required this.pendingInstallments,
    required this.expectedMonthly,
    required this.repaidAmount,
    required this.estimatedCompletion,
    this.repayments = const [],
  });

  bool get isActive => status == 'active';

  factory EmiPlan.fromJson(Map<String, dynamic> j) {
    final reps = (j['repayments'] as List<dynamic>?) ?? [];
    return EmiPlan(
      id: j['id'] as String,
      originTransactionId: j['originTransactionId'] as String,
      merchant: j['merchant'] as String,
      principalAmount: (j['principalAmount'] as num).toDouble(),
      tenureMonths: j['tenureMonths'] as int,
      startDate: parseApiDateTime(j['startDate']),
      paymentInstrumentId: j['paymentInstrumentId'] as String?,
      status: j['status'] as String,
      paidInstallments: j['paidInstallments'] as int? ?? 0,
      pendingInstallments: j['pendingInstallments'] as int? ?? 0,
      expectedMonthly: (j['expectedMonthly'] as num?)?.toDouble() ?? 0,
      repaidAmount: (j['repaidAmount'] as num?)?.toDouble() ?? 0,
      estimatedCompletion: parseApiDateTime(j['estimatedCompletion']),
      repayments: reps
          .map((r) => EmiRepayment.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

class EmiRepayment {
  final String id;
  final String merchant;
  final double amount;
  final DateTime date;
  final String? paymentInstrumentName;

  const EmiRepayment({
    required this.id,
    required this.merchant,
    required this.amount,
    required this.date,
    this.paymentInstrumentName,
  });

  factory EmiRepayment.fromJson(Map<String, dynamic> j) => EmiRepayment(
    id: j['id'] as String,
    merchant: j['merchant'] as String,
    amount: (j['amount'] as num).toDouble(),
    date: parseApiDateTime(j['date']),
    paymentInstrumentName: j['paymentInstrumentName'] as String?,
  );
}

// ─── Split bill ─────────────────────────────────────────────────────────────

class SplitParticipant {
  final String id;
  final String name;
  final double shareAmount;
  final bool isPaid;
  final String? settlementTransactionId;
  final DateTime? paidAt;

  const SplitParticipant({
    required this.id,
    required this.name,
    required this.shareAmount,
    required this.isPaid,
    this.settlementTransactionId,
    this.paidAt,
  });

  factory SplitParticipant.fromJson(Map<String, dynamic> j) => SplitParticipant(
    id: j['id'] as String,
    name: j['name'] as String,
    shareAmount: (j['shareAmount'] as num).toDouble(),
    isPaid: j['isPaid'] as bool? ?? false,
    settlementTransactionId: j['settlementTransactionId'] as String?,
    paidAt: j['paidAt'] != null ? parseApiDateTime(j['paidAt']) : null,
  );
}

class SplitBill {
  final String id;
  final String originTransactionId;
  final String merchant;
  final double totalAmount;
  final double ownerShareAmount;
  final DateTime date;
  final String status;
  final int paidCount;
  final int pendingCount;
  final double pendingAmount;
  final int participantCount;
  final List<SplitParticipant> participants;

  const SplitBill({
    required this.id,
    required this.originTransactionId,
    required this.merchant,
    required this.totalAmount,
    required this.ownerShareAmount,
    required this.date,
    required this.status,
    required this.paidCount,
    required this.pendingCount,
    required this.pendingAmount,
    required this.participantCount,
    this.participants = const [],
  });

  bool get isActive => status == 'active';

  factory SplitBill.fromJson(Map<String, dynamic> j) {
    final parts = (j['participants'] as List<dynamic>?) ?? [];
    return SplitBill(
      id: j['id'] as String,
      originTransactionId: j['originTransactionId'] as String,
      merchant: j['merchant'] as String,
      totalAmount: (j['totalAmount'] as num).toDouble(),
      ownerShareAmount: (j['ownerShareAmount'] as num).toDouble(),
      date: parseApiDateTime(j['date']),
      status: j['status'] as String,
      paidCount: j['paidCount'] as int? ?? 0,
      pendingCount: j['pendingCount'] as int? ?? 0,
      pendingAmount: (j['pendingAmount'] as num?)?.toDouble() ?? 0,
      participantCount: j['participantCount'] as int? ?? parts.length,
      participants: parts
          .map((p) => SplitParticipant.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}
