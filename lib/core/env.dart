import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App configuration loaded from `.env` at startup (see `.env.example`).
abstract final class Env {
  static String get apiBaseUrl {
    final raw = dotenv.env['API_BASE_URL']?.trim();
    if (raw == null || raw.isEmpty) {
      throw StateError(
        'API_BASE_URL is missing. Copy .env.example to .env and set your backend URL.',
      );
    }
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  static String get googleServerClientId =>
      dotenv.env['GOOGLE_SERVER_CLIENT_ID']?.trim() ?? '';

  static bool get isGoogleConfigured =>
      googleServerClientId.isNotEmpty &&
      !googleServerClientId.startsWith('YOUR_') &&
      googleServerClientId.contains('.apps.googleusercontent.com');
}
