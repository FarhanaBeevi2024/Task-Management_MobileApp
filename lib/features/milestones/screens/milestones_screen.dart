import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/permissions/session_permissions.dart';
import '../../../core/widgets/app_snackbars.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_footer_nav.dart';
import '../../../core/widgets/account_menu_button.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../issues/models/issue_model.dart';
import '../../issues/models/issue_status.dart';
import '../../issues/providers/issues_providers.dart';
import '../../projects/models/project_model.dart';
import '../../projects/providers/projects_providers.dart';
import '../models/milestone_model.dart';

String _milestoneStatusLabel(String raw) {
  switch (raw) {
    case 'planned':
      return 'Planned';
    case 'in_progress':
      return 'In progress';
    case 'released':
      return 'Released';
    default:
      return raw;
  }
}

String _formatPlanned(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  return '${l.day}/${l.month}/${l.year}';
}

/// Release milestones for a project (web **Milestones**). Create/edit/delete requires
/// `canManageMilestones` in Access Control (typically Admin / Team leader).
class MilestonesScreen extends ConsumerWidget {
  const MilestonesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsListProvider);
    final selectedId = ref.watch(selectedProjectIdProvider);
    final permsAsync = ref.watch(sessionPermissionsProvider);

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
          title: const Text('Milestones'),
          actions: [
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: AccountMenuButton(),
            ),
          permsAsync.maybeWhen(
            data: (p) {
              if (!p.project.canManageMilestones) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'New milestone',
                icon: const Icon(Icons.add_rounded),
                onPressed: () async {
                  try {
                    final projects = await ref.read(projectsListProvider.future);
                    if (!context.mounted) return;
                    if (projects.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Create a project first.')),
                      );
                      return;
                    }
                    final sid = ref.read(selectedProjectIdProvider);
                    final effective = sid != null && projects.any((x) => x.id == sid)
                        ? sid
                        : projects.first.id;
                    await _openMilestoneSheet(
                      context,
                      ref,
                      projectId: effective,
                      milestone: null,
                    );
                  } catch (e) {
                    if (context.mounted) {
                      showErrorSnackBar(context, e, fallback: 'Could not open milestone form.');
                    }
                  }
                },
              );
            },
            orElse: () => const SizedBox.shrink(),
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
            return const Center(child: Text('No projects yet.'));
          }
          final sid = selectedId;
          final effectiveId =
              sid != null && projects.any((p) => p.id == sid) ? sid : projects.first.id;

          final milestonesAsync = ref.watch(projectMilestonesListProvider(effectiveId));
          final issuesAsync = ref.watch(issuesForProjectProvider(effectiveId));
          final canManage = permsAsync.maybeWhen(
            data: (p) => p.project.canManageMilestones,
            orElse: () => false,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Release milestones for this project. Assign tasks to milestones when creating or editing issues.',
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
                child: milestonesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('$e', textAlign: TextAlign.center),
                    ),
                  ),
                  data: (milestones) {
                    if (milestones.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'No milestones yet.',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (canManage) ...[
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: () => _openMilestoneSheet(
                                    context,
                                    ref,
                                    projectId: effectiveId,
                                    milestone: null,
                                  ),
                                  child: const Text('Create first milestone'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }
                    final issues = issuesAsync.valueOrNull ?? [];
                    final countsReady = issuesAsync.hasValue || issuesAsync.hasError;
                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(projectMilestonesListProvider(effectiveId));
                        ref.invalidate(issuesForProjectProvider(effectiveId));
                        await Future.wait([
                          ref.read(projectMilestonesListProvider(effectiveId).future),
                          ref.read(issuesForProjectProvider(effectiveId).future),
                        ]);
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: milestones.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final m = milestones[i];
                          final byM = countsReady
                              ? issues.where((x) => x.milestoneId == m.id).toList()
                              : <IssueModel>[];
                          final total = byM.length;
                          final completed =
                              byM.where((x) => x.status == IssueStatus.done).length;
                          final pct = total > 0 ? (completed * 100 / total).round() : 0;
                          return _MilestoneCard(
                            milestone: m,
                            statusLabel: _milestoneStatusLabel(m.status),
                            plannedLabel: m.plannedDate != null
                                ? 'Planned: ${_formatPlanned(m.plannedDate)}'
                                : null,
                            completed: completed,
                            total: total,
                            percent: pct,
                            countsReady: countsReady,
                            issuesLoadFailed: issuesAsync.hasError,
                            canManage: canManage,
                            onEdit: canManage
                                ? () => _openMilestoneSheet(
                                      context,
                                      ref,
                                      projectId: effectiveId,
                                      milestone: m,
                                    )
                                : null,
                            onDelete: canManage
                                ? () => _confirmDelete(context, ref, m)
                                : null,
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

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  MilestoneModel m,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete milestone'),
      content: Text(
        'Delete milestone "${m.version}"?\n\nIssues will be unassigned from this milestone.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    await ref.read(issuesApiProvider).deleteMilestone(m.id);
    ref.invalidate(projectMilestonesListProvider(m.projectId));
    ref.invalidate(issuesForProjectProvider(m.projectId));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Milestone deleted')));
    }
  } catch (e) {
    if (context.mounted) showErrorSnackBar(context, e, fallback: 'Delete failed.');
  }
}

Future<void> _openMilestoneSheet(
  BuildContext context,
  WidgetRef ref, {
  required String projectId,
  required MilestoneModel? milestone,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _MilestoneEditorSheet(
      projectId: projectId,
      milestone: milestone,
      onSaved: () {
        ref.invalidate(projectMilestonesListProvider(projectId));
        ref.invalidate(issuesForProjectProvider(projectId));
      },
    ),
  );
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

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({
    required this.milestone,
    required this.statusLabel,
    required this.plannedLabel,
    required this.completed,
    required this.total,
    required this.percent,
    required this.countsReady,
    required this.issuesLoadFailed,
    required this.canManage,
    this.onEdit,
    this.onDelete,
  });

  final MilestoneModel milestone;
  final String statusLabel;
  final String? plannedLabel;
  final int completed;
  final int total;
  final int percent;
  final bool countsReady;
  final bool issuesLoadFailed;
  final bool canManage;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    milestone.version,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (canManage && (onEdit != null || onDelete != null)) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (onEdit != null)
                    OutlinedButton(
                      onPressed: onEdit,
                      child: const Text('Edit'),
                    ),
                  if (onDelete != null) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: onDelete,
                      style: TextButton.styleFrom(foregroundColor: cs.error),
                      child: const Text('Delete'),
                    ),
                  ],
                ],
              ),
            ],
            if (plannedLabel != null) ...[
              const SizedBox(height: 8),
              Text(plannedLabel!, style: theme.textTheme.bodySmall),
            ],
            if (milestone.description != null && milestone.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                milestone.description!,
                style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: !countsReady
                  ? const LinearProgressIndicator(minHeight: 6)
                  : LinearProgressIndicator(
                      value: issuesLoadFailed ? 0 : (total > 0 ? completed / total : 0),
                      minHeight: 6,
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              !countsReady
                  ? 'Loading task counts…'
                  : issuesLoadFailed
                      ? 'Could not load task counts'
                      : '$completed / $total tasks completed',
              style: theme.textTheme.labelSmall?.copyWith(
                color: issuesLoadFailed ? cs.error : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MilestoneEditorSheet extends ConsumerStatefulWidget {
  const _MilestoneEditorSheet({
    required this.projectId,
    required this.milestone,
    required this.onSaved,
  });

  final String projectId;
  final MilestoneModel? milestone;
  final VoidCallback onSaved;

  @override
  ConsumerState<_MilestoneEditorSheet> createState() => _MilestoneEditorSheetState();
}

class _MilestoneEditorSheetState extends ConsumerState<_MilestoneEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _versionCtrl;
  late final TextEditingController _descCtrl;
  String _status = 'planned';
  DateTime? _planned;
  bool _saving = false;

  bool get _isEdit => widget.milestone != null;

  @override
  void initState() {
    super.initState();
    final m = widget.milestone;
    _versionCtrl = TextEditingController(text: m?.version ?? '');
    _descCtrl = TextEditingController(text: m?.description ?? '');
    final raw = m?.status ?? 'planned';
    const allowed = {'planned', 'in_progress', 'released'};
    _status = allowed.contains(raw) ? raw : 'planned';
    _planned = m?.plannedDate;
  }

  @override
  void dispose() {
    _versionCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _planned ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (d != null) setState(() => _planned = d);
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(issuesApiProvider);
      final plannedStr = _planned == null
          ? null
          : '${_planned!.year}-${_planned!.month.toString().padLeft(2, '0')}-${_planned!.day.toString().padLeft(2, '0')}';
      if (_isEdit) {
        await api.updateMilestone(
          milestoneId: widget.milestone!.id,
          version: _versionCtrl.text,
          plannedDateYyyyMmDd: plannedStr,
          status: _status,
          description: _descCtrl.text,
        );
      } else {
        await api.createMilestone(
          projectId: widget.projectId,
          version: _versionCtrl.text,
          plannedDateYyyyMmDd: plannedStr,
          status: _status,
          description: _descCtrl.text,
        );
      }
      if (!mounted) return;
      widget.onSaved();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEdit ? 'Milestone updated' : 'Milestone created')),
      );
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e, fallback: 'Save failed.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isEdit ? 'Edit milestone' : 'New milestone',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _versionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Version *',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. 1.0.0',
                ),
                validator: (s) {
                  if ((s?.trim() ?? '').isEmpty) return 'Required';
                  return null;
                },
                enabled: !_saving,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Planned date'),
                subtitle: Text(
                  _planned == null ? 'None' : _formatPlanned(_planned),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today_outlined),
                  onPressed: _saving ? null : _pickDate,
                ),
              ),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'planned', child: Text('Planned')),
                  DropdownMenuItem(value: 'in_progress', child: Text('In progress')),
                  DropdownMenuItem(value: 'released', child: Text('Released')),
                ],
                onChanged: _saving
                    ? null
                    : (v) {
                        if (v != null) setState(() => _status = v);
                      },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  hintText: 'Optional',
                ),
                enabled: !_saving,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEdit ? 'Save' : 'Create'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
