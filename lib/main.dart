import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final rawEnvAsset = await rootBundle.loadString('assets/env/app.env');
  final rawBaseUrlLine = rawEnvAsset
      .split('\n')
      .map((l) => l.trim())
      .firstWhere(
        (l) => l.startsWith('API_BASE_URL='),
        orElse: () => '<missing API_BASE_URL>',
      );
  debugPrint('asset(app.env) $rawBaseUrlLine');

  await dotenv.load(fileName: 'assets/env/app.env');
  debugPrint('dotenv[API_BASE_URL] = ${dotenv.env['API_BASE_URL']}');
  debugPrint('AppConfig.apiBaseUrl = ${AppConfig.apiBaseUrl}');

  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
    // Initialize uses setInitialSession from storage but does not await recoverSession(),
    // so a persisted session can still have an expired JWT on the first API call. Refresh
    // here when needed so Dio always sees a valid access token.
    final auth = Supabase.instance.client.auth;
    final session = auth.currentSession;
    if (session != null && session.isExpired) {
      try {
        await auth.refreshSession();
      } catch (_) {
        // Revoked refresh token or network failure; user may need to sign in again.
      }
    }
  }

  runApp(const ProviderScope(child: TaskManagementApp()));
}
