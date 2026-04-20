import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_message.dart';
import '../models/issue_model.dart';
import '../models/issue_status.dart';
import '../providers/issues_providers.dart';
import '../screens/issue_detail_screen.dart';
import '../screens/task_form_screen.dart';
import '../../projects/providers/projects_providers.dart';

/// Modal bottom sheet: view, edit, change status, mark complete.
Future<void> showIssueTaskActionsSheet({
  required BuildContext context,
  required IssueModel issue,
  required String projectId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return _IssueTaskActionsBody(
        parentContext: context,
        issue: issue,
        projectId: projectId,
      );
    },
  );
}

void _invalidateProjectData(ProviderContainer c, String projectId) {
  c.invalidate(projectIssuesProvider);
  if (projectId.isEmpty) return;
  c.invalidate(projectIssueProgressProvider(projectId));
  c.invalidate(issuesForProjectProvider(projectId));
  c.invalidate(workItemsForProjectProvider(projectId));
  c.invalidate(projectMilestonesListProvider(projectId));
}

Future<void> _sheetApplyIssueStatus(
  ProviderContainer c,
  BuildContext messengerContext,
  String projectId,
  IssueModel issue,
  IssueStatus status,
) async {
  final messenger = ScaffoldMessenger.maybeOf(messengerContext);
  try {
    await c.read(issuesApiProvider).updateIssueStatus(
          issueId: issue.id,
          statusApiValue: status.apiValue,
        );
    _invalidateProjectData(c, projectId);
  } catch (e) {
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          friendlyErrorMessage(
            e,
            fallback: 'Could not update task. Please try again.',
          ),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _IssueTaskActionsBody extends ConsumerWidget {
  const _IssueTaskActionsBody({
    required this.parentContext,
    required this.issue,
    required this.projectId,
  });

  final BuildContext parentContext;
  final IssueModel issue;
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // IMPORTANT: this sheet is popped before running async work. Never use
    // [WidgetRef] after `Navigator.pop(context)`; use a stable container instead.
    final container = ProviderScope.containerOf(parentContext, listen: false);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selectedProjectId = ref.watch(selectedProjectIdProvider);
    final projectsAsync = ref.watch(projectsListProvider);
    String? role;
    projectsAsync.whenOrNull(
      data: (list) {
        final id = selectedProjectId;
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
    final moveTargets = isClient
        ? IssueStatus.values.where((s) => s != IssueStatus.inReview).toList(growable: false)
        : IssueStatus.values;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (issue.issueKey != null && issue.issueKey!.isNotEmpty)
                    Text(
                      issue.issueKey!,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    issue.summary,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Status: ${issue.status.label}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.visibility_outlined, color: scheme.primary),
              title: const Text('View details'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(parentContext).push(
                  PageRouteBuilder<void>(
                    pageBuilder: (_, animation, __) => IssueDetailScreen(issue: issue),
                    transitionsBuilder: (_, animation, __, child) {
                      return FadeTransition(
                        opacity: CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.04, 0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          )),
                          child: child,
                        ),
                      );
                    },
                    transitionDuration: const Duration(milliseconds: 320),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.edit_outlined, color: scheme.primary),
              title: const Text('Edit task'),
              onTap: () async {
                Navigator.pop(context);
                final updated = await Navigator.of(parentContext).push<IssueModel>(
                  PageRouteBuilder<IssueModel>(
                    pageBuilder: (_, animation, __) => TaskFormScreen(
                      projectId: projectId,
                      issue: issue,
                    ),
                    transitionsBuilder: (_, animation, __, child) {
                      return FadeTransition(
                        opacity: CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                        child: child,
                      );
                    },
                    transitionDuration: const Duration(milliseconds: 280),
                  ),
                );
                if (updated != null) {
                  _invalidateProjectData(container, projectId);
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Move to',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            ...moveTargets.map((s) {
              final selected = s == issue.status;
              return ListTile(
                selected: selected,
                leading: Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                title: Text(s.label),
                onTap: selected
                    ? null
                    : () async {
                        Navigator.pop(context);
                        await _sheetApplyIssueStatus(container, parentContext, projectId, issue, s);
                      },
              );
            }),
          ],
        ),
      ),
    );
  }
}
