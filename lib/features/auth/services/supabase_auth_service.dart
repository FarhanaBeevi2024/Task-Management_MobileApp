import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';

/// Wraps Supabase Auth for the login screen. Safe to inject in tests with a fake.
class SupabaseAuthService {
  SupabaseClient get _client => Supabase.instance.client;

  /// Throws [StateError] if Supabase was not initialized in [main].
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw StateError(
        'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY in '
        'assets/env/app.env (or pass --dart-define).',
      );
    }

    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Optional: same flow as web “forgot password” (magic link / recovery).
  Future<void> sendPasswordResetEmail(String email) async {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase is not configured.');
    }
    await _client.auth.resetPasswordForEmail(email.trim());
  }
}
