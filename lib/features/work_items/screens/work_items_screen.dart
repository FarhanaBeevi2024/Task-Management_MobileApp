import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/app_page_routes.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_footer_nav.dart';
import '../../../core/widgets/account_menu_button.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../issues/models/issue_model.dart';
import '../../issues/providers/issues_providers.dart';
import '../../issues/screens/issue_detail_screen.dart';
import '../../projects/models/project_model.dart';
import '../../projects/providers/projects_providers.dart';

String _formatDue(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  return '${l.day}/${l.month}/${l.year}';
}

/// Tasks assigned to you in the selected project (web **Work items**).
class WorkItemsScreen extends ConsumerWidget {
  const WorkItemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsListProvider);
    final selectedId = ref.watch(selectedProjectIdProvider);

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        bottomNavigationBar: const AppFooterNav(),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          title: const Text('Work items'),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 8),
              child: AccountMenuButton(),
            ),
          ],
        ),
        body: projectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorStateView(
          error: e,
          onRetry: () => ref.invalidate(projectsListProvider),
        ),
        data: (projects) {
          if (projects.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No projects yet. Create a project from the Projects tab.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }
          final sid = selectedId;
          final effectiveId =
              sid != null && projects.any((p) => p.id == sid) ? sid : projects.first.id;
          final project = projects.firstWhere(
            (p) => p.id == effectiveId,
            orElse: () => projects.first,
          );
          final isProjectClient = project.currentUserProjectRole?.toLowerCase() == 'client';

          if (isProjectClient) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Work items are not available when your role on this project is Client.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }

          final issuesAsync = ref.watch(workItemsForProjectProvider(effectiveId));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Tasks and issues assigned to you.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ProjectDropdown(
                  projects: projects,
                  value: effectiveId,
                  onChanged: (id) {
                    ref.read(selectedProjectIdProvider.notifier).state = id;
                  },
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: issuesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                  data: (issues) {
                    if (issues.isEmpty) {
                      return Center(
                        child: Text(
                          'No work items with this filter.',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(workItemsForProjectProvider(effectiveId));
                        await ref.read(workItemsForProjectProvider(effectiveId).future);
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: issues.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final issue = issues[i];
                          return _WorkItemCard(
                            issue: issue,
                            projectKey: project.key,
                            onTap: () {
                              Navigator.of(context).push(
                                AppPageRoutes.fade(IssueDetailScreen(issue: issue)),
                              );
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        ),
      ),
    );
  }
}

class _ProjectDropdown extends StatelessWidget {
  const _ProjectDropdown({
    required this.projects,
    required this.value,
    required this.onChanged,
  });

  final List<ProjectModel> projects;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Project',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: projects.any((p) => p.id == value) ? value : projects.first.id,
          items: projects
              .map(
                (p) => DropdownMenuItem(
                  value: p.id,
                  child: Text(
                    p.key != null && p.key!.trim().isNotEmpty ? '${p.name} (${p.key})' : p.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _WorkItemCard extends StatelessWidget {
  const _WorkItemCard({
    required this.issue,
    required this.projectKey,
    required this.onTap,
  });

  final IssueModel issue;
  final String? projectKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      issue.issueKey ?? '—',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    projectKey ?? '—',
                    style: theme.textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                issue.summary.isEmpty ? '(Untitled)' : issue.summary,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _MetaChip(label: 'Status', value: issue.status.apiValue),
                  _MetaChip(
                    label: 'Assignee',
                    value: issue.assigneeEmail ?? '—',
                  ),
                  _MetaChip(label: 'Due', value: _formatDue(issue.dueDate)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
            text: value,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
