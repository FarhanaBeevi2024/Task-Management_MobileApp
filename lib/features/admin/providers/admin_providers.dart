import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/workspace_bootstrap.dart';
import '../../../core/permissions/session_permissions.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/workspace_user_model.dart';
import '../services/admin_api_service.dart';

final adminApiProvider = Provider<AdminApiService>((ref) {
  return AdminApiService(ref.watch(apiClientProvider));
});

final workspaceUsersProvider = FutureProvider<List<WorkspaceUserModel>>((ref) async {
  if (!hasAuthenticatedApiAccess(ref)) return [];
  await ensureDefaultWorkspace(ref);
  return ref.watch(adminApiProvider).fetchWorkspaceUsers();
});

final accessConfigPayloadProvider = FutureProvider<AccessConfigPayload>((ref) async {
  if (!hasAuthenticatedApiAccess(ref)) {
    return AccessConfigPayload(roles: {});
  }
  await ensureDefaultWorkspace(ref);
  return ref.watch(adminApiProvider).fetchAccessConfig();
});
