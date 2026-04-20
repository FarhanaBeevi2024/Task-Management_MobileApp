import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../../features/auth/services/secure_token_store.dart';
import '../providers/active_organization_provider.dart';

/// Notifies [GoRouter] when Supabase auth session changes (sign-in / sign-out / refresh).
class AuthRefreshListenable extends ChangeNotifier {
  AuthRefreshListenable({required this.ref}) {
    _syncFromCurrentSession();

    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      _syncFromCurrentSession();
      notifyListeners();
    });
  }

  final Ref ref;
  final SecureTokenStore _tokenStore = const SecureTokenStore();

  late final StreamSubscription<AuthState> _sub;

  void _setProviderState(void Function() write) {
    // Riverpod asserts if a provider synchronously modifies another provider
    // during its own initialization/build. Since this listenable is created
    // inside `appRouterProvider`, defer provider writes.
    Future.microtask(write);
  }

  void _syncFromCurrentSession() {
    final session = Supabase.instance.client.auth.currentSession;
    final tokenTrimmed = session?.accessToken.trim() ?? '';

    // Keep token cache available synchronously for Dio interceptors.
    _setProviderState(() {
      ref.read(accessTokenCacheProvider.notifier).state =
          tokenTrimmed.isEmpty ? null : tokenTrimmed;
    });

    // Persist token securely for “store token securely” parity with the web.
    // Also clear org selection if the user is signed out.
    if (tokenTrimmed.isEmpty) {
      _setProviderState(() {
        ref.read(activeOrganizationIdProvider.notifier).state = null;
        ref.read(orgBootstrapUserIdProvider.notifier).state = null;
      });
    }

    // Fire-and-forget; listeners may run often and we don't want to block routing.
    unawaited(
      _tokenStore.setAccessToken(tokenTrimmed.isEmpty ? null : tokenTrimmed),
    );
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
