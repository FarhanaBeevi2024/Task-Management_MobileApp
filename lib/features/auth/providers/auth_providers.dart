import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/workspace_bootstrap.dart';
import '../../../core/providers/active_organization_provider.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/supabase_auth_service.dart';

/// Whether the app can attach a Bearer token to API calls.
///
/// Watches [accessTokenCacheProvider] so providers rebuild as soon as logout
/// clears the cache (avoids 401 spam and noisy Dio errors after sign-out).
bool hasAuthenticatedApiAccess(Ref ref) {
  ref.watch(accessTokenCacheProvider);
  final cached = ref.read(accessTokenCacheProvider)?.trim();
  if (cached != null && cached.isNotEmpty) return true;
  final t = Supabase.instance.client.auth.currentSession?.accessToken.trim() ?? '';
  return t.isNotEmpty;
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(apiClientProvider));
});

final supabaseAuthServiceProvider = Provider<SupabaseAuthService>((ref) {
  return SupabaseAuthService();
});

/// Fast in-memory access token cache used by [SupabaseAuthDioInterceptor].
///
/// We still persist the token in secure storage via auth session listeners,
/// but the interceptor needs a synchronous source.
final accessTokenCacheProvider = StateProvider<String?>((ref) => null);

/// Replace with `StateNotifier` / `AsyncNotifier` when you add login/logout.
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  if (!hasAuthenticatedApiAccess(ref)) return null;
  await ensureDefaultWorkspace(ref);
  ref.watch(activeOrganizationIdProvider);
  final auth = ref.watch(authServiceProvider);
  return auth.fetchCurrentUser();
});
