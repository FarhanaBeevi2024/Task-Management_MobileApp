import 'env_resolution.dart';

/// Supabase project keys: `assets/env/app.env` first, then `--dart-define=SUPABASE_*`.
class SupabaseConfig {
  SupabaseConfig._();

  static String get url => resolveEnv(
        'SUPABASE_URL',
        const String.fromEnvironment('SUPABASE_URL'),
      );

  static String get anonKey => resolveEnv(
        'SUPABASE_ANON_KEY',
        const String.fromEnvironment('SUPABASE_ANON_KEY'),
      );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
