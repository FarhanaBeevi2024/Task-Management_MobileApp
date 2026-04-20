import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/active_organization_provider.dart';
import '../../features/auth/providers/auth_providers.dart';

/// Attaches Supabase `Authorization` and workspace `X-Organization-Id` before each request.
///
/// Reads [GoTrueClient.currentSession] (there is no async `getSession()` on the Dart client).
/// Retries once on 401 after [refreshSession].
class SupabaseAuthDioInterceptor extends Interceptor {
  SupabaseAuthDioInterceptor({required this.ref, required this.dio});

  final Ref ref;
  final Dio dio;

  static const _retryKey = 'supabase_auth_retry';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final auth = Supabase.instance.client.auth;
    final cached = ref.read(accessTokenCacheProvider)?.trim();
    final token = (cached != null && cached.isNotEmpty)
        ? cached
        : auth.currentSession?.accessToken.trim();

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    } else {
      options.headers.remove('Authorization');
    }

    final orgId = ref.read(activeOrganizationIdProvider)?.trim();
    if (orgId != null && orgId.isNotEmpty) {
      options.headers['X-Organization-Id'] = orgId;
    } else {
      options.headers.remove('X-Organization-Id');
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }
    if (err.requestOptions.extra[_retryKey] == true) {
      handler.next(err);
      return;
    }

    final session = Supabase.instance.client.auth.currentSession;
    final refresh = session?.refreshToken?.trim();
    if (session == null || refresh == null || refresh.isEmpty) {
      handler.next(err);
      return;
    }

    Supabase.instance.client.auth.refreshSession().then((authResponse) {
      final opts = err.requestOptions;
      opts.extra[_retryKey] = true;

      final token = (authResponse.session?.accessToken ??
              Supabase.instance.client.auth.currentSession?.accessToken)
          ?.trim();
      if (token != null && token.isNotEmpty) {
        ref.read(accessTokenCacheProvider.notifier).state = token;
        opts.headers['Authorization'] = 'Bearer $token';
      }

      return dio.fetch(opts);
    }).then((response) {
      handler.resolve(response);
    }).catchError((Object _) {
      handler.next(err);
    });
  }
}
