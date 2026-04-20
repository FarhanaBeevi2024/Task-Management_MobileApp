import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/workspace_bootstrap.dart';
import '../../../core/providers/active_organization_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../../milestones/models/milestone_model.dart';
import '../../projects/providers/projects_providers.dart';
import '../models/issue_activity_log.dart';
import '../models/issue_model.dart';
import '../models/issue_status.dart';
import '../services/issues_api_service.dart';

final issuesApiProvider = Provider<IssuesApiService>((ref) {
  return IssuesApiService(ref.watch(apiClientProvider));
});

/// Fresh task payload (fixes stale list data; includes `parent_issue`, nested milestone, etc.).
final issueDetailProvider = FutureProvider.autoDispose.family<IssueModel, String>(
  (ref, issueId) async {
    if (!hasAuthenticatedApiAccess(ref)) {
      return IssueModel(id: issueId.isEmpty ? '_' : issueId, summary: '');
    }
    await ensureDefaultWorkspace(ref);
    ref.watch(activeOrganizationIdProvider);
    final api = ref.watch(issuesApiProvider);
    return api.fetchIssue(issueId);
  },
);

/// Activity / history for one issue (same source as web IssueDetail "History").
final issueActivityLogsProvider =
    FutureProvider.autoDispose.family<List<IssueActivityLog>, String>(
  (ref, issueId) async {
    await ensureDefaultWorkspace(ref);
    ref.watch(activeOrganizationIdProvider);
    if (issueId.isEmpty) return [];
    final api = ref.watch(issuesApiProvider);
    return api.fetchIssueActivityLogs(issueId);
  },
);

/// Issues for the currently selected project (re-fetches when project id changes).
final projectIssuesProvider = FutureProvider<List<IssueModel>>((ref) async {
  if (!hasAuthenticatedApiAccess(ref)) return [];
  await ensureDefaultWorkspace(ref);
  ref.watch(activeOrganizationIdProvider);
  final projectId = ref.watch(selectedProjectIdProvider);
  if (projectId == null || projectId.isEmpty) {
    return [];
  }
  final api = ref.watch(issuesApiProvider);
  return api.fetchIssues(projectId: projectId);
});

/// Issues for a specific [projectId] (calendar can use first project while board has no selection).
final issuesForProjectProvider =
    FutureProvider.autoDispose.family<List<IssueModel>, String>(
  (ref, projectId) async {
    if (!hasAuthenticatedApiAccess(ref)) return [];
    await ensureDefaultWorkspace(ref);
    ref.watch(activeOrganizationIdProvider);
    if (projectId.isEmpty) return [];
    final api = ref.watch(issuesApiProvider);
    return api.fetchIssues(projectId: projectId);
  },
);

/// Issues assigned to the signed-in user in [projectId] (web **Work items**).
final workItemsForProjectProvider =
    FutureProvider.autoDispose.family<List<IssueModel>, String>(
  (ref, projectId) async {
    if (!hasAuthenticatedApiAccess(ref)) return [];
    await ensureDefaultWorkspace(ref);
    ref.watch(activeOrganizationIdProvider);
    if (projectId.isEmpty) return [];
    final user = await ref.watch(currentUserProvider.future);
    if (user == null || user.id.isEmpty) return [];
    final api = ref.watch(issuesApiProvider);
    return api.fetchIssues(projectId: projectId, assigneeId: user.id);
  },
);

/// Full milestone list for a project (cards + progress).
final projectMilestonesListProvider =
    FutureProvider.autoDispose.family<List<MilestoneModel>, String>(
  (ref, projectId) async {
    if (!hasAuthenticatedApiAccess(ref)) return [];
    await ensureDefaultWorkspace(ref);
    ref.watch(activeOrganizationIdProvider);
    if (projectId.isEmpty) return [];
    final api = ref.watch(issuesApiProvider);
    final raw = await api.fetchMilestonesList(projectId);
    return raw.map(MilestoneModel.fromJson).where((m) => m.id.isNotEmpty).toList();
  },
);

List<IssueModel> issuesInColumn(List<IssueModel> all, IssueStatus column) {
  return all.where((i) => i.status == column).toList();
}

/// Task completion counts for a project (used on project list cards).
class ProjectIssueProgress {
  const ProjectIssueProgress({required this.completed, required this.total});

  final int completed;
  final int total;

  double get fraction => total <= 0 ? 0 : completed / total;

  int get percent => total <= 0 ? 0 : ((completed * 100) ~/ total);
}

/// Fetches issues for [projectId] to compute completed vs total (Kanban `done` status).
final projectIssueProgressProvider =
    FutureProvider.autoDispose.family<ProjectIssueProgress, String>(
  (ref, projectId) async {
    if (!hasAuthenticatedApiAccess(ref)) {
      return const ProjectIssueProgress(completed: 0, total: 0);
    }
    await ensureDefaultWorkspace(ref);
    ref.watch(activeOrganizationIdProvider);
    if (projectId.isEmpty) {
      return const ProjectIssueProgress(completed: 0, total: 0);
    }
    final api = ref.watch(issuesApiProvider);
    final issues = await api.fetchIssues(projectId: projectId);
    final done = issues.where((i) => i.status == IssueStatus.done).length;
    return ProjectIssueProgress(completed: done, total: issues.length);
  },
);

/// Refreshes the board and the matching project card progress strip.
void invalidateProjectTasksData(WidgetRef ref, String projectId) {
  ref.invalidate(projectIssuesProvider);
  if (projectId.isNotEmpty) {
    ref.invalidate(projectIssueProgressProvider(projectId));
    ref.invalidate(issuesForProjectProvider(projectId));
    ref.invalidate(workItemsForProjectProvider(projectId));
    ref.invalidate(projectMilestonesListProvider(projectId));
  }
}
