import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(
    encryptedSharedPreferences: true,
    resetOnError: true,
  ),
);

class AppStorage {
  static const _keyToken = 'access_token';

  static String? _cachedToken;
  static Future<String?>? _tokenReadInFlight;

  /// Warms the in-memory token cache (call once at startup when logged in).
  static Future<String?> warmTokenCache() => getToken();

  /// Reads a value, recovering gracefully when Android Keystore data is corrupt.
  static Future<String?> _safeRead(String key) async {
    try {
      return await _storage.read(key: key);
    } on PlatformException catch (e, st) {
      debugPrint('Secure storage read failed for $key: $e');
      debugPrint('$st');
      return null;
    } catch (e, st) {
      debugPrint('Secure storage read failed for $key: $e');
      debugPrint('$st');
      return null;
    }
  }

  static Future<void> _purgeCorruptedStorage() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      debugPrint('Secure storage purge failed: $e');
    }
  }

  static Future<void> saveToken(String token) async {
    _cachedToken = token;
    try {
      await _storage.write(key: _keyToken, value: token);
    } on PlatformException catch (e, st) {
      debugPrint('Secure storage write failed for token: $e');
      debugPrint('$st');
      await _purgeCorruptedStorage();
      await _storage.write(key: _keyToken, value: token);
    }
  }

  static Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    if (_tokenReadInFlight != null) return _tokenReadInFlight;

    _tokenReadInFlight = _loadTokenFromStorage();
    try {
      return await _tokenReadInFlight;
    } finally {
      _tokenReadInFlight = null;
    }
  }

  static Future<String?> _loadTokenFromStorage() async {
    final token = await _safeRead(_keyToken);
    _cachedToken = token;
    return token;
  }

  static Future<bool> hasToken() async => (await getToken()) != null;

  static Future<void> clearToken() async {
    _cachedToken = null;
    try {
      await _storage.delete(key: _keyToken);
    } on PlatformException catch (e) {
      debugPrint('Secure storage delete failed for token: $e');
      await _purgeCorruptedStorage();
    }
  }
}
