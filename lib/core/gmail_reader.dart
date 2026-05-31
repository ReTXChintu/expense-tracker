import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;
import '../models.dart';
import 'google_config.dart';

/// Thrown when Gmail connect or fetch fails with a user-visible reason.
class GmailReaderException implements Exception {
  final String message;
  const GmailReaderException(this.message);

  @override
  String toString() => message;
}

GoogleSignIn _createSignIn() => GoogleSignIn(
      scopes: const ['https://www.googleapis.com/auth/gmail.readonly'],
      serverClientId:
          GoogleConfig.isConfigured ? GoogleConfig.serverClientId : null,
    );

class GmailReader {
  static final GoogleSignIn _signIn = _createSignIn();

  static bool get isConfigured => GoogleConfig.isConfigured;

  static Future<bool> isSignedIn() async {
    if (!isConfigured) return false;
    return _signIn.isSignedIn();
  }

  static Future<GoogleSignInAccount?> signIn() async {
    if (!isConfigured) {
      throw const GmailReaderException(GoogleConfig.setupHint);
    }

    try {
      final account = await _signIn.signIn();
      if (account == null) return null;

      final granted = await _signIn.requestScopes(
        const ['https://www.googleapis.com/auth/gmail.readonly'],
      );
      if (!granted) {
        await _signIn.signOut();
        throw const GmailReaderException(
          'Gmail permission was not granted. Try Connect again and allow access.',
        );
      }
      return account;
    } on GmailReaderException {
      rethrow;
    } catch (e) {
      debugPrint('[Gmail] signIn error: $e');
      throw GmailReaderException(_friendlySignInError(e));
    }
  }

  static String _friendlySignInError(Object e) {
    final s = e.toString();
    if (s.contains('ApiException: 10') || s.contains('sign_in_failed')) {
      return 'Google Sign-In is misconfigured (error 10). Register your app '
          'package com.example.expense_tracker and debug SHA-1 in Google Cloud '
          'Console, and set googleServerClientId — see GOOGLE_SETUP.md';
    }
    if (s.contains('network_error')) {
      return 'Network error during sign-in. Check your connection and retry.';
    }
    return 'Gmail sign-in failed. See GOOGLE_SETUP.md or try again.';
  }

  static Future<void> signOut() => _signIn.signOut();

  static Future<List<Transaction>> fetchForDate(DateTime date) async {
    if (!isConfigured) return [];

    final account = await _signIn.signInSilently();
    if (account == null) {
      debugPrint('[Gmail] not signed in');
      return [];
    }

    final auth = await account.authentication;
    final accessToken = auth.accessToken;
    if (accessToken == null) {
      throw const GmailReaderException(
        'Could not get Gmail access token. Disconnect and reconnect Gmail in Profile.',
      );
    }

    debugPrint('[Gmail] fetching messages for $date');
    final client = _BearerClient(accessToken);
    try {
      final api = gmail.GmailApi(client);

      final q = _gmailQueryForDay(date);
      debugPrint('[Gmail] query: $q');
      final list = await api.users.messages.list('me', q: q, maxResults: 100);
      final messageCount = list.messages?.length ?? 0;
      debugPrint('[Gmail] found $messageCount messages for $date');

      final txs = <Transaction>[];
      var skippedSubject = 0;
      var skippedParse = 0;
      for (final stub in list.messages ?? []) {
        if (stub.id == null) continue;
        final msg = await api.users.messages.get('me', stub.id!,
            format: 'full',
            $fields:
                'id,internalDate,snippet,payload(headers,body/data,parts(mimeType,body/data,parts(mimeType,body/data)))');

        final subject = _header(msg, 'Subject');

        if (_rejectSubjectRe.hasMatch(subject)) {
          skippedSubject++;
          debugPrint('[Gmail] skip subject: $subject');
          continue;
        }

        final body = _extractBody(msg);
        final strippedBody = _stripHtml(body);

        final shortBody = strippedBody.length > 800
            ? strippedBody.substring(0, 800)
            : strippedBody;
        final parseText = '$subject\n$shortBody'.trim();

        final rawText = '$subject\n$body'.trim();
        final msgDate = _messageDate(msg, date);

        final tx = _parse(parseText, msgDate, rawText: rawText);
        if (tx != null) {
          txs.add(tx);
        } else {
          skippedParse++;
          debugPrint(
              '[Gmail] no parse: $subject | ${parseText.substring(0, parseText.length.clamp(0, 80))}');
        }
      }

      client.close();
      debugPrint(
          '[Gmail] parsed ${txs.length} txs ($skippedSubject skipped subject, $skippedParse no parse)',
      );
      return txs;
    } catch (e) {
      client.close();
      debugPrint('[Gmail] fetch error: $e');
      if (e is GmailReaderException) rethrow;
      throw GmailReaderException('Failed to fetch Gmail: $e');
    }
  }

  static String _p(int n) => n.toString().padLeft(2, '0');

  /// Gmail `after`/`before` use YYYY/MM/DD; [day] must roll month/year correctly.
  static String _gmailQueryForDay(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final nextDay = dayStart.add(const Duration(days: 1));
    // Date-only window (no keyword filter) — Indian bank mails use many phrasings.
    return 'after:${dayStart.year}/${_p(dayStart.month)}/${_p(dayStart.day)} '
        'before:${nextDay.year}/${_p(nextDay.month)}/${_p(nextDay.day)}';
  }

  static DateTime _messageDate(gmail.Message msg, DateTime fallback) {
    final raw = msg.internalDate;
    if (raw != null) {
      final ms = int.tryParse(raw);
      if (ms != null) {
        return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
      }
    }
    return fallback;
  }

  static final _amountRe = RegExp(
    r'(?:'
    r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d+)?)|'
    r'spent\s+(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d+)?)|'
    r'(?:debited|credited|paid)\s+(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d+)?)'
    r')',
    caseSensitive: false,
  );

  static final _creditRe = RegExp(
      r'\b(?:credited|received|refunded|reversed|cashback)\b',
      caseSensitive: false);

  static final _txSignalRe = RegExp(
    r'\b(?:debited|deducted|spent|charged|used|paid|sent|transferred|'
    r'withdrawn|purchase|payment|transaction|upi|neft|imps|atm|pos|alert)\b',
    caseSensitive: false,
  );

  static final _rejectSubjectRe = RegExp(
    r'\b(?:portfolio|mutual\s+fund|nav\b|statement|digest|newsletter|'
    r'holdings?|returns?|investment\s+(?:report|summary)|'
    r'weekly\s+(?:report|summary|digest)|monthly\s+(?:report|summary|digest)|'
    r'account\s+summary|e-?statement|passbook)\b',
    caseSensitive: false,
  );

  static final _merchantRe = RegExp(
    r'(?:\bat\b|\btowards\b|\bto\b|\bfor\b|\bpaid\s+to\b)\s+'
    r'([A-Za-z0-9][A-Za-z0-9 \-\.\/]{2,35}?)(?=\s+on\b|\s+dated\b|\s+upi\b|\s*[,\.]\s|\s+\d|$)',
    caseSensitive: false,
  );

  static final _upiMerchantRe = RegExp(
    r'(?:UPI\/[A-Z0-9]+\/([A-Za-z0-9 \-\.]{3,30})\/|VPA\s+([A-Za-z0-9.\-]+@[A-Za-z0-9]+))',
    caseSensitive: false,
  );

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
          RegExp(r'<style[^>]*>.*?</style>', dotAll: true, caseSensitive: false),
          '')
      .replaceAll(
          RegExp(r'<script[^>]*>.*?</script>', dotAll: true, caseSensitive: false),
          '')
      .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static double? _parseAmount(RegExpMatch match) {
    for (var i = 1; i <= match.groupCount; i++) {
      final g = match.group(i);
      if (g != null && g.isNotEmpty) {
        return double.tryParse(g.replaceAll(',', ''));
      }
    }
    return null;
  }

  static String _parseMerchant(String text) {
    final upi = _upiMerchantRe.firstMatch(text);
    if (upi != null) {
      final name = (upi.group(1) ?? upi.group(2) ?? '').trim();
      if (name.isNotEmpty) return _cleanMerchant(name);
    }
    final m = _merchantRe.firstMatch(text);
    if (m != null) {
      final name = m.group(1)?.trim() ?? '';
      if (name.isNotEmpty) return _cleanMerchant(name);
    }
    return 'Unknown';
  }

  static String _cleanMerchant(String s) => s
      .replaceAll(
        RegExp(
          r'\b(?:a\/c|ac|acct|account|bank|card|upi|p2m|p2p|ref|no\.?)\b',
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static Transaction? _parse(String text, DateTime date, {String? rawText}) {
    final amountMatch = _amountRe.firstMatch(text);
    if (amountMatch == null) return null;
    final amount = _parseAmount(amountMatch);
    if (amount == null || amount <= 0) return null;
    if (!_txSignalRe.hasMatch(text)) return null;

    final isCredit = _creditRe.hasMatch(text);
    final merchant = _parseMerchant(text);

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
