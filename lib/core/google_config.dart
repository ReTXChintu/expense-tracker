import 'env.dart';

/// Google OAuth configuration for Gmail (Sign-In + gmail.readonly).
abstract final class GoogleConfig {
  static String get serverClientId => Env.googleServerClientId;

  static bool get isConfigured => Env.isGoogleConfigured;

  static const String setupHint =
      'Gmail is not configured. Set GOOGLE_SERVER_CLIENT_ID in .env — see GOOGLE_SETUP.md';
}
