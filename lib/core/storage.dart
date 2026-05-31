import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

class AppStorage {
  static const _keyToken = 'access_token';
  static const _keyScanned = 'scanned_dates'; // comma-separated yyyy-MM-dd

  static Future<void> saveToken(String token) =>
      _storage.write(key: _keyToken, value: token);

  static Future<String?> getToken() => _storage.read(key: _keyToken);

  static Future<bool> hasToken() async =>
      (await _storage.read(key: _keyToken)) != null;

  static Future<void> clearToken() => _storage.delete(key: _keyToken);

  // ── Scanned dates — past calendar days only (today is never marked) ───────

  static Future<bool> isDateScanned(DateTime date) async {
    final val = await _storage.read(key: _keyScanned);
    if (val == null || val.isEmpty) return false;
    return val.split(',').contains(_fmt(date));
  }

  static Future<void> markDateScanned(DateTime date) async {
    final val = await _storage.read(key: _keyScanned) ?? '';
    final dates = val.isEmpty ? <String>{} : val.split(',').toSet();
    dates.add(_fmt(date));
    await _storage.write(key: _keyScanned, value: dates.join(','));
  }

  static Future<void> clearScannedDate(DateTime date) async {
    final val = await _storage.read(key: _keyScanned) ?? '';
    final dates = val.isEmpty ? <String>{} : val.split(',').toSet();
    dates.remove(_fmt(date));
    await _storage.write(key: _keyScanned, value: dates.join(','));
  }

  /// After Gmail is linked, re-scan past days that were SMS-only.
  static Future<void> clearAllScannedDates() async {
    await _storage.delete(key: _keyScanned);
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
