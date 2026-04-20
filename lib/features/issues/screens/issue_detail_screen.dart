import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../projects/providers/projects_providers.dart';
import '../../../core/permissions/session_permissions.dart';
import '../models/issue_activity_log.dart';
import '../models/issue_model.dart';
import '../providers/issues_providers.dart';
import 'task_form_screen.dart';

class IssueDetailScreen extends ConsumerStatefulWidget {
  const IssueDetailScreen({super.key, required this.issue});

  final IssueModel issue;

  @override
  ConsumerState<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends ConsumerState<IssueDetailScreen> {
  static String _formatDueDate(DateTime d) {
    const months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  static String _assigneeLine(IssueModel i) {
    final e = i.assigneeEmail?.trim();
    if (e != null && e.isNotEmpty) return e;
    final id = i.assigneeId?.trim();
    if (id != null && id.isNotEmpty) return 'Assigned';
    return 'Unassigned';
  }

  static String? _parentLine(IssueModel i) {
    final key = i.parentIssueKey?.trim();
    final sum = i.parentSummary?.trim();
    if (key != null && key.isNotEmpty) {
      if (sum != null && sum.isNotEmpty) return '$key · $sum';
      return key;
    }
    final pid = i.parentIssueId?.trim();
    if (pid != null && pid.isNotEmpty) return 'Subtask of another task';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final seed = widget.issue;
    final detailAsync = ref.watch(issueDetailProvider(seed.id));
    final display = detailAsync.asData?.value ?? seed;
    final projectId = ref.watch(selectedProjectIdProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final theme = Theme.of(context);
    final activityAsync = ref.watch(issueActivityLogsProvider(seed.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(display.issueKey ?? 'Issue'),
        actions: [
          if (projectId != null && projectId.isNotEmpty)
            ref.watch(sessionPermissionsProvider).maybeWhen(
                  data: (p) => p.project.canCreateIssues
                      ? IconButton(
                          icon: const Icon(Icons.subdirectory_arrow_right_rounded),
                          tooltip: 'Add subtask',
                          onPressed: () async {
                            final created = await Navigator.of(context).push<IssueModel>(
                              MaterialPageRoute(
                                builder: (_) => TaskFormScreen(
                                  projectId: projectId,
                                  initialParentIssueId: display.id,
                                ),
                              ),
                            );
                            if (created != null && context.mounted) {
                              final pid = ref.read(selectedProjectIdProvider);
                              if (pid != null && pid.isNotEmpty) {
                                invalidateProjectTasksData(ref, pid);
                              }
                            }
                          },
                        )
                      : const SizedBox.shrink(),
                  orElse: () => const SizedBox.shrink(),
                ),
          if (projectId != null && projectId.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit task',
              onPressed: () async {
                final updated = await Navigator.of(context).push<IssueModel>(
                  MaterialPageRoute(
                    builder: (_) => TaskFormScreen(
                      projectId: projectId,
                      issue: display,
                    ),
                  ),
                );
                if (updated != null && context.mounted) {
                  ref.invalidate(issueActivityLogsProvider(updated.id));
                  ref.invalidate(issueDetailProvider(updated.id));
                  final pid = ref.read(selectedProjectIdProvider);
                  if (pid != null && pid.isNotEmpty) {
                    invalidateProjectTasksData(ref, pid);
                  }
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => IssueDetailScreen(issue: updated),
                    ),
                  );
                }
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(issueActivityLogsProvider(seed.id));
          ref.invalidate(issueDetailProvider(seed.id));
          await Future.wait([
            ref.read(issueActivityLogsProvider(seed.id).future),
            ref.read(issueDetailProvider(seed.id).future),
          ]);
          final pid = ref.read(selectedProjectIdProvider);
          if (pid != null && pid.isNotEmpty) {
            invalidateProjectTasksData(ref, pid);
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            if (detailAsync.isLoading && detailAsync.asData == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(minHeight: 3),
                ),
              ),
            if (display.issueKey != null && display.issueKey!.trim().isNotEmpty) ...[
              Text(
                display.issueKey!.trim(),
                style: textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              'Summary',
              style: textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              display.summary.isEmpty ? '—' : display.summary,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(display.status.label),
                  visualDensity: VisualDensity.compact,
                ),
                if (display.internalPriority != null && display.internalPriority!.trim().isNotEmpty)
                  Chip(
                    label: Text('Internal: ${display.internalPriority!.trim()}'),
                    visualDensity: VisualDensity.compact,
                  ),
                if (display.clientPriority != null && display.clientPriority!.trim().isNotEmpty)
                  Chip(
                    label: Text('Client: ${display.clientPriority!.trim()}'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              'Details',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _DetailRow(
              label: 'Task type',
              value: display.issueTypeName,
              theme: theme,
            ),
            if (display.workflowStatus != null && display.workflowStatus!.trim().isNotEmpty)
              _DetailRow(
                label: 'Workflow',
                value: display.workflowStatus,
                theme: theme,
              ),
            _DetailRow(
              label: 'Assigned to',
              value: _assigneeLine(display),
              theme: theme,
            ),
            _DetailRow(
              label: 'Due date',
              value: display.dueDate != null ? _formatDueDate(display.dueDate!.toLocal()) : null,
              theme: theme,
            ),
            _DetailRow(
              label: 'Story points',
              value: display.storyPoints != null ? '${display.storyPoints}' : null,
              theme: theme,
            ),
            _DetailRow(
              label: 'Planned (days)',
              value: display.estimatedDays != null ? '${display.estimatedDays}' : null,
              theme: theme,
            ),
            _DetailRow(
              label: 'Actual (days)',
              value: display.actualDays != null ? '${display.actualDays}' : null,
              theme: theme,
            ),
            _DetailRow(
              label: 'Exposed to client',
              value: display.exposedToClient ? 'Yes' : 'No',
              theme: theme,
            ),
            _DetailRow(
              label: 'Milestone',
              value: display.milestoneDisplay,
              theme: theme,
            ),
            if (display.releaseId != null && display.releaseId!.trim().isNotEmpty)
              _DetailRow(
                label: 'Release',
                value: 'Linked',
                theme: theme,
              ),
            if (_parentLine(display) != null)
              _DetailRow(
                label: 'Parent task',
                value: _parentLine(display),
                theme: theme,
              ),
            if (display.reporterEmail != null && display.reporterEmail!.trim().isNotEmpty)
              _DetailRow(
                label: 'Reporter',
                value: display.reporterEmail,
                theme: theme,
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Labels',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (display.labels.isEmpty)
                    Text(
                      '—',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurface,
                        height: 1.35,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: display.labels
                          .map(
                            (l) => Chip(
                              label: Text(l),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
            if (display.description != null && display.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Description',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                display.description!.trim(),
                style: textTheme.bodyLarge?.copyWith(height: 1.45),
              ),
            ],
            const SizedBox(height: 20),
            Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 20),
            Text(
              'History',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            activityAsync.when(
              data: (logs) {
                if (logs.isEmpty) {
                  return Text(
                    'No activity recorded yet.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  );
                }
                return Column(
                  children: logs.map((log) => _ActivityTile(log: log)).toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(
                e.toString(),
                style: textTheme.bodyMedium?.copyWith(color: scheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.theme,
  });

  final String label;
  final String? value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final trimmed = value?.trim();
    final v = (trimmed == null || trimmed.isEmpty) ? '—' : trimmed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            v,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurface,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.log});

  final IssueActivityLog log;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final email = log.performedByEmail;
    final initial = (email != null && email.isNotEmpty) ? email[0].toUpperCase() : '?';
    final dateSuffix = log.displayDateSuffix;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
            child: Text(
              initial,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                  height: 1.35,
                ),
                children: [
                  TextSpan(text: log.displayMessage),
                  if (dateSuffix.isNotEmpty)
                    TextSpan(
                      text: ' – $dateSuffix',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
