import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logging/app_logger.dart';
import '../providers/active_organization_provider.dart';
import 'api_client.dart';

/// Parses `GET /api/me/organizations` — backend returns `{ organizations: [...], is_superadmin }`
/// (same shape as React [OrganizationContext]), not a bare array.
List<Map<String, dynamic>> _organizationsFromResponse(dynamic data) {
  if (data is Map) {
    final raw = data['organizations'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
  }
  if (data is List) {
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  return [];
}

void _setProviderState(dynamic ref, void Function() write) {
  // [WidgetRef]: synchronous writes are OK from post-frame / async callbacks.
  //
  // [Ref] (e.g. `FutureProvider` bodies): deferring with [Future.microtask] caused
  // `ensureDefaultWorkspace` to return before `activeOrganizationIdProvider` was
  // updated, so callers like [projectsListProvider] ran `fetchProjects` without
  // `X-Organization-Id` and could hang or error (seen as endless loading after
  // re-login on routes such as `/milestones`). Writes after `await` in async
  // providers are not in a synchronous provider build — apply immediately.
  if (ref is WidgetRef) {
    write();
  } else {
    write();
  }
}

/// [WidgetRef] is implemented by [ConsumerStatefulElement], which has no
/// public `container` getter — use [ProviderScope.containerOf] on [WidgetRef.context].
ProviderContainer _providerContainer(dynamic ref) {
  if (ref is WidgetRef) {
    return ProviderScope.containerOf(ref.context, listen: false);
  }
  if (ref is Ref) {
    return ref.container;
  }
  throw ArgumentError(
    'ensureDefaultWorkspace: expected WidgetRef or Ref, got ${ref.runtimeType}',
  );
}

/// If the user is signed in and no org is selected, pick the first from `GET /api/me/organizations`.
///
/// Uses `dynamic` for [ref] so it can be called both from providers
/// (which receive `Ref` / `FutureProviderRef`) and from widgets
/// (which receive `WidgetRef`), as long as they support `read(...)`.
Future<void> ensureDefaultWorkspace(dynamic ref) async {
  // Never use [WidgetRef] after an await: sign-in can navigate away and dispose
  // the login screen while this still runs. [ProviderContainer] stays valid.
  final c = _providerContainer(ref);

  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) {
    _setProviderState(ref, () {
      c.read(activeOrganizationIdProvider.notifier).state = null;
      c.read(orgBootstrapUserIdProvider.notifier).state = null;
    });
    return;
  }

  final uid = session.user.id;
  if (c.read(orgBootstrapUserIdProvider) != uid) {
    _setProviderState(ref, () {
      c.read(activeOrganizationIdProvider.notifier).state = null;
      c.read(orgBootstrapUserIdProvider.notifier).state = uid;
    });
  }
  if (c.read(activeOrganizationIdProvider) != null) return;

  try {
    final dio = c.read(apiClientProvider);
    final res = await dio.get<dynamic>('/api/me/organizations');
    final body = res.data;

    if (body is Map && body['is_superadmin'] == true) {
      AppLogger.i('ensureDefaultWorkspace: superadmin — no org header (matches web)');
      return;
    }

    final orgs = _organizationsFromResponse(body);
    if (orgs.isEmpty) {
      AppLogger.w('ensureDefaultWorkspace: organizations list empty');
      return;
    }

    final id = orgs.first['id']?.toString();
    if (id != null && id.isNotEmpty) {
      _setProviderState(ref, () {
        c.read(activeOrganizationIdProvider.notifier).state = id;
      });
      AppLogger.i('ensureDefaultWorkspace: active org set to $id');
    }
  } on DioException catch (e, st) {
    AppLogger.w('ensureDefaultWorkspace failed: ${e.message}', e, st);
  } catch (e, st) {
    AppLogger.w('ensureDefaultWorkspace failed: $e', e, st);
  }
}
