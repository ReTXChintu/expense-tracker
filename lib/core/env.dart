import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App configuration from `--dart-define` (release builds) or `.env` (local dev).
abstract final class Env {
  static String get apiBaseUrl {
    const fromDefine = String.fromEnvironment('API_BASE_URL');
    final raw = fromDefine.isNotEmpty
        ? fromDefine
        : dotenv.env['API_BASE_URL']?.trim();
    if (raw == null || raw.isEmpty) {
      throw StateError(
        'API_BASE_URL is missing. Copy .env.example to .env and set your backend URL.',
      );
    }
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  static String get googleServerClientId {
    const fromDefine = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
    if (fromDefine.isNotEmpty) return fromDefine;
    return dotenv.env['GOOGLE_SERVER_CLIENT_ID']?.trim() ?? '';
  }

  static bool get isGoogleConfigured =>
      googleServerClientId.isNotEmpty &&
      !googleServerClientId.startsWith('YOUR_') &&
      googleServerClientId.contains('.apps.googleusercontent.com');
}
