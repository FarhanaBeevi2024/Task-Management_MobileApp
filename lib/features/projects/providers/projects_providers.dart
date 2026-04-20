import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/workspace_bootstrap.dart';
import '../../../core/providers/active_organization_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/project_model.dart';
import '../services/projects_api_service.dart';

final projectsApiProvider = Provider<ProjectsApiService>((ref) {
  return ProjectsApiService(ref.watch(apiClientProvider));
});

final projectsListProvider = FutureProvider<List<ProjectModel>>((ref) async {
  if (!hasAuthenticatedApiAccess(ref)) return [];
  await ensureDefaultWorkspace(ref);
  ref.watch(activeOrganizationIdProvider);
  final api = ref.watch(projectsApiProvider);
  return api.fetchProjects();
});

/// Which project is active for board / issues (lift to `AsyncNotifier` if you persist it).
final selectedProjectIdProvider = StateProvider<String?>((ref) => null);
