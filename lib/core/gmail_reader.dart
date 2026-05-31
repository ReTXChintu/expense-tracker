import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;
import '../models.dart';

final _signIn = GoogleSignIn(
  scopes: ['https://www.googleapis.com/auth/gmail.readonly'],
);

class GmailReader {
  static Future<bool> isSignedIn() => _signIn.isSignedIn();

  static Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await _signIn.signIn();
      if (account == null) return null;
      final granted = await _signIn.requestScopes(
          ['https://www.googleapis.com/auth/gmail.readonly']);
      if (!granted) {
        await _signIn.signOut();
        return null;
      }
      return account;
    } catch (e) {
      debugPrint('[Gmail] signIn error: $e');
      return null;
    }
  }

  static Future<void> signOut() => _signIn.signOut();

  static Future<List<Transaction>> fetchForDate(DateTime date) async {
    final account = await _signIn.signInSilently();
    if (account == null) {
      debugPrint('[Gmail] not signed in');
      return [];
    }

    final auth = await account.authentication;
    final accessToken = auth.accessToken;
    if (accessToken == null) {
      throw Exception(
          'Could not get Gmail access token. Please disconnect and reconnect Gmail in your profile.');
    }

    debugPrint('[Gmail] fetching messages for $date');
    final client = _BearerClient(accessToken);
    try {
      final api = gmail.GmailApi(client);

      final q = 'after:${date.year}/${_p(date.month)}/${_p(date.day)} '
          'before:${date.year}/${_p(date.month)}/${_p(date.day + 1)} '
          '(debited OR credited OR transaction OR spent OR payment OR UPI OR NEFT OR IMPS)';

      debugPrint('[Gmail] query: $q');
      final list = await api.users.messages.list('me', q: q, maxResults: 50);
      debugPrint('[Gmail] found ${list.messages?.length ?? 0} messages');

      final txs = <Transaction>[];
      for (final stub in list.messages ?? []) {
        if (stub.id == null) continue;
        final msg = await api.users.messages.get('me', stub.id!,
            format: 'full',
            $fields:
                'id,snippet,payload(headers,body/data,parts(mimeType,body/data,parts(mimeType,body/data)))');

        final subject = _header(msg, 'Subject');

        // Skip emails that are clearly portfolio/newsletter/summary emails
        if (_rejectSubjectRe.hasMatch(subject)) {
          debugPrint('[Gmail] skipping non-transaction email: $subject');
          continue;
        }

        final body = _extractBody(msg);
        final strippedBody = _stripHtml(body);

        // Limit parse text to subject + first 500 chars of body.
        // This avoids legal disclaimers at the bottom which cause bad merchant matches.
        final shortBody = strippedBody.length > 500
            ? strippedBody.substring(0, 500)
            : strippedBody;
        final parseText = '$subject\n$shortBody'.trim();

        // rawText keeps the original (may be HTML) for the bottom-sheet viewer.
        final rawText = '$subject\n$body'.trim();

        debugPrint(
            '[Gmail] subject: $subject | parse snippet: ${parseText.substring(0, parseText.length.clamp(0, 100))}');

        final tx = _parse(parseText, date, rawText: rawText);
        if (tx != null) txs.add(tx);
      }

      client.close();
      debugPrint('[Gmail] parsed ${txs.length} transactions');
      return txs;
    } catch (e) {
      client.close();
      debugPrint('[Gmail] fetch error: $e');
      rethrow;
    }
  }

  // ── Regexes ────────────────────────────────────────────────────────────────

  static String _p(int n) => n.toString().padLeft(2, '0');

  static final _amountRe =
      RegExp(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d+)?)', caseSensitive: false);

  static final _creditRe = RegExp(
      r'\b(?:credited|received|refunded|reversed|cashback)\b',
      caseSensitive: false);

  static final _txSignalRe = RegExp(
    r'\b(?:debited|deducted|spent|charged|used|paid|sent|transferred|'
    r'purchase|payment|transaction|upi|neft|imps|atm)\b',
    caseSensitive: false,
  );

  // Reject emails by subject — not transaction alerts
  static final _rejectSubjectRe = RegExp(
    r'\b(?:portfolio|mutual\s+fund|nav\b|statement|digest|newsletter|'
    r'holdings?|returns?|investment\s+(?:report|summary)|'
    r'weekly\s+(?:report|summary|digest)|monthly\s+(?:report|summary|digest)|'
    r'account\s+summary|e-?statement|passbook)\b',
    caseSensitive: false,
  );

  // Stricter merchant pattern:
  //  - Only after "paid to", "towards", "at" (removed bare "to" and "for"
  //    which match too much prose)
  //  - No $ end-of-string anchor (must end before a date/digit/punctuation)
  //  - Max 25 chars
  static final _merchantRe = RegExp(
    r'(?:\bpaid\s+to\b|\btowards\b|\bat\b)\s+'
    r'([A-Za-z0-9][A-Za-z0-9 &\-\.]{1,24}?)'
    r'(?=\s+on\b|\s*[,\.]\s|\s+\d)',
    caseSensitive: false,
  );

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _header(gmail.Message msg, String name) =>
      msg.payload?.headers
          ?.where((h) => h.name == name)
          .map((h) => h.value ?? '')
          .firstOrNull ??
      '';

  static String _decodeBody(String encoded) {
    try {
      final normalized = encoded.replaceAll('-', '+').replaceAll('_', '/');
      return utf8.decode(base64.decode(normalized));
    } catch (_) {
      return '';
    }
  }

  static String _extractBody(gmail.Message msg) {
    String? plain;
    String? html;

    void walk(gmail.MessagePart? part) {
      if (part == null) return;
      if (part.body?.data != null) {
        if (part.mimeType == 'text/plain') {
          plain ??= _decodeBody(part.body!.data!);
        } else if (part.mimeType == 'text/html') {
          html ??= _decodeBody(part.body!.data!);
        }
      }
      for (final sub in part.parts ?? []) {
        walk(sub);
      }
    }

    walk(msg.payload);
    return plain ?? html ?? (msg.snippet ?? '');
  }

  static String _stripHtml(String text) => text
      .replaceAll(
          RegExp(r'<style[^>]*>.*?</style>', dotAll: true, caseSensitive: false), '')
      .replaceAll(
          RegExp(r'<script[^>]*>.*?</script>', dotAll: true, caseSensitive: false), '')
      .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static Transaction? _parse(String text, DateTime date, {String? rawText}) {
    final amountMatch = _amountRe.firstMatch(text);
    if (amountMatch == null) return null;
    final amount =
        double.tryParse(amountMatch.group(1)!.replaceAll(',', ''));
    if (amount == null || amount <= 0) return null;
    if (!_txSignalRe.hasMatch(text)) return null;

    final isCredit = _creditRe.hasMatch(text);
    final merchantMatch = _merchantRe.firstMatch(text);
    final merchant =
        merchantMatch?.group(1)?.trim().replaceAll(RegExp(r'\s+'), ' ') ??
            'Unknown';

    return Transaction(
      merchant: merchant,
      amount: amount,
      isDebit: !isCredit,
      date: date,
      source: TxSource.gmail,
      rawText: rawText ?? text,
    );
  }
}

class _BearerClient extends http.BaseClient {
  final String _token;
  final _inner = http.Client();
  _BearerClient(this._token);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
