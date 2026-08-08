import 'package:flutter/foundation.dart';

/// Centralized application configuration.
///
/// Supabase credentials are read from `--dart-define` flags at build time:
///   flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=your-anon-key
///
/// The fallback values below are for local development only and MUST NOT be
/// used in production builds.
class AppConfig {
  static const String _envSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _envSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get supabaseUrl =>
      _envSupabaseUrl.isNotEmpty ? _envSupabaseUrl : _fallbackSupabaseUrl;

  static String get supabaseAnonKey =>
      _envSupabaseAnonKey.isNotEmpty ? _envSupabaseAnonKey : _fallbackSupabaseAnonKey;

  static const String _fallbackSupabaseUrl = 'https://rytkmzxmesjymyezpxmk.supabase.co';
  static const String _fallbackSupabaseAnonKey = 'sb_publishable_7XLhqMboA3mXLwSiR3BBdA_oO78Zt2e';

  /// Whether the app is running with production credentials injected.
  static bool get isProductionConfigured =>
      _envSupabaseUrl.isNotEmpty && _envSupabaseAnonKey.isNotEmpty;

  /// Logs a warning in debug mode when fallback credentials are in use.
  static void validateConfig() {
    if (kDebugMode && !isProductionConfigured) {
      debugPrint(
        '⚠️  WARNING: Using fallback Supabase credentials. '
        'Pass --dart-define=SUPABASE_URL and --dart-define=SUPABASE_ANON_KEY '
        'for production builds.',
      );
    }
  }
}