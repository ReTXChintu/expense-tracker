import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models.dart';

class SmsReader {
  // Match any rupee amount
  static final _amountRe = RegExp(
    r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d+)?)',
    caseSensitive: false,
  );

  // Explicit credit keywords
  static final _creditRe = RegExp(
    r'\b(?:credited|received|deposited|added|refunded|reversed|cashback)\b',
    caseSensitive: false,
  );

  // Any word that signals a financial transaction happened (broad)
  static final _txSignalRe = RegExp(
    r'\b(?:debited|deducted|spent|used|charged|withdrawn|paid|sent|transferred|'
    r'purchase|payment|transaction|upi|neft|imps|atm|pos)\b',
    caseSensitive: false,
  );

  // Extract merchant name after common prepositions
  static final _merchantRe = RegExp(
    r'(?:\bat\b|\btowards\b|\bto\b|\bfor\b)\s+([A-Za-z0-9][A-Za-z0-9 \-\.\/]{2,35}?)(?=\s+on\b|\s+dated\b|\s+ref\b|\s+upi\b|\s*[,\.]\s|\s+\d|$)',
    caseSensitive: false,
  );

  // UPI merchant from "VPA abc@bank" or "UPI/P2M/MerchantName/"
  static final _upiMerchantRe = RegExp(
    r'(?:UPI\/[A-Z0-9]+\/([A-Za-z0-9 \-\.]{3,30})\/|VPA\s+([A-Za-z0-9.\-]+@[A-Za-z0-9]+))',
    caseSensitive: false,
  );

  static Future<List<Transaction>> fetchForDate(DateTime date) async {
    final status = await Permission.sms.request();
    if (!status.isGranted) return [];

    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final messages = await SmsQuery().querySms(
      kinds: [SmsQueryKind.inbox],
      count: 500,
    );

    final result = <Transaction>[];
    for (final msg in messages) {
      final msgDate = msg.date;
      if (msgDate == null) continue;
      if (msgDate.isBefore(dayStart) || !msgDate.isBefore(dayEnd)) continue;
      final tx = _parse(msg.body ?? '', msgDate);
      if (tx != null) result.add(tx);
    }
    return result;
  }

  static Transaction? _parse(String text, DateTime date) {
    final amountMatch = _amountRe.firstMatch(text);
    if (amountMatch == null) return null;

    final amountStr = amountMatch.group(1)!.replaceAll(',', '');
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) return null;

    // Must have at least one transaction signal word or UPI/NEFT/IMPS keyword
    final hasSignal = _txSignalRe.hasMatch(text);
    if (!hasSignal) return null;

    final isCredit = _creditRe.hasMatch(text);

    // Extract merchant
    String merchant = 'Unknown';
    final upiMatch = _upiMerchantRe.firstMatch(text);
    if (upiMatch != null) {
      merchant = (upiMatch.group(1) ?? upiMatch.group(2) ?? '').trim();
    }
    if (merchant == 'Unknown' || merchant.isEmpty) {
      final m = _merchantRe.firstMatch(text);
      if (m != null) merchant = _clean(m.group(1)?.trim() ?? '');
    }
    if (merchant.isEmpty) merchant = 'Unknown';

    return Transaction(
      merchant: merchant,
      amount: amount,
      isDebit: !isCredit,
      date: date,
      source: TxSource.sms,
      rawText: text, // full message stored
    );
  }

  static String _clean(String s) => s
      .replaceAll(
        RegExp(r'\b(?:a\/c|ac|acct|account|bank|card|upi|p2m|p2p|ref|no\.?)\b',
            caseSensitive: false),
        '',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
