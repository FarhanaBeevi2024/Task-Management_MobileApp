import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../issues/models/issue_status.dart';
import '../../projects/providers/projects_providers.dart';

/// Board keyword search (summary, description, key, workflow, assignee, priorities, labels).
final boardSearchQueryProvider = StateProvider<String>((ref) => '');

/// Status filter for the Board list. Defaults to `to_do` (matches the reference UI tiles).
///
/// Values must match [IssueStatus.apiValue].
final boardStatusFilterProvider = StateProvider<String>((ref) => 'to_do');

/// Mobile-only: selected tab index for the board status tabs.
final boardSelectedTabIndexProvider = StateProvider<int>((ref) => 0);

/// Columns shown in the board.
///
/// Matches web JiraBoard:
/// - Standard columns: To Do, In Progress, In Review, Completed
/// - Client project role: hides `In Review`
final visibleBoardColumnsProvider = Provider<List<IssueStatus>>((ref) {
  final projectId = ref.watch(selectedProjectIdProvider);
  final projectsAsync = ref.watch(projectsListProvider);

  String? role;
  projectsAsync.whenOrNull(
    data: (list) {
      final id = projectId;
      if (id == null || id.isEmpty) return;
      for (final p in list) {
        if (p.id == id) {
          role = p.currentUserProjectRole?.toLowerCase().trim();
          return;
        }
      }
    },
  );

  final isClient = role == 'client';
  if (!isClient) return IssueStatus.values;

  return IssueStatus.values.where((s) => s != IssueStatus.inReview).toList(growable: false);
});
