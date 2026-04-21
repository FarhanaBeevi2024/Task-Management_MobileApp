import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/permissions/session_permissions.dart';
import '../../../core/widgets/app_snackbars.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../issues/providers/issues_providers.dart';
import '../../issues/models/org_list_user.dart';
import '../models/project_member_model.dart';
import '../models/project_model.dart';
import '../providers/projects_providers.dart';

const _projectRoles = ['admin', 'team_leader', 'team_member', 'client'];

class ProjectOverviewScreen extends ConsumerStatefulWidget {
  const ProjectOverviewScreen({super.key});

  @override
  ConsumerState<ProjectOverviewScreen> createState() => _ProjectOverviewScreenState();
}

class _ProjectOverviewScreenState extends ConsumerState<ProjectOverviewScreen> {
  bool _editing = false;
  bool _savingProject = false;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;

  String _selectedUserId = '';
  String _selectedProjectRole = 'team_member';
  bool _addingMember = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _descCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _syncControllersFrom(ProjectModel p) {
    if (_nameCtrl.text.trim().isEmpty) _nameCtrl.text = p.name;
    if (_descCtrl.text.trim().isEmpty) _descCtrl.text = p.description ?? '';
  }

  Future<void> _saveProject(ProjectModel p) async {
    setState(() => _savingProject = true);
    try {
      final api = ref.read(projectsApiProvider);
      final updated = await api.updateProject(
        projectId: p.id,
        name: _nameCtrl.text,
        description: _descCtrl.text,
      );
      ref.invalidate(projectsListProvider);
      // Keep selection stable; ProjectModel is fetched from list provider.
      if (mounted) {
        setState(() => _editing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project updated')),
        );
      }
      // Ensure controllers reflect saved value if user reopens edit quickly.
      _nameCtrl.text = updated.name;
      _descCtrl.text = updated.description ?? '';
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e, fallback: 'Could not update project.');
    } finally {
      if (mounted) setState(() => _savingProject = false);
    }
  }

  Future<void> _addMember(String projectId) async {
    if (_selectedUserId.trim().isEmpty) return;
    setState(() => _addingMember = true);
    try {
      await ref.read(projectsApiProvider).addProjectMember(
            projectId: projectId,
            userId: _selectedUserId,
            projectRole: _selectedProjectRole,
          );
      ref.invalidate(projectMembersProvider(projectId));
      if (mounted) {
        setState(() {
          _selectedUserId = '';
          _selectedProjectRole = 'team_member';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member added')),
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e, fallback: 'Could not add member.');
    } finally {
      if (mounted) setState(() => _addingMember = false);
    }
  }

  Future<void> _removeMember({
    required String projectId,
    required ProjectMemberModel member,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove member'),
        content: Text('Remove ${member.email} from this project?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(projectsApiProvider).removeProjectMember(
            projectId: projectId,
            userId: member.userId,
          );
      ref.invalidate(projectMembersProvider(projectId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member removed')),
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e, fallback: 'Could not remove member.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final projectId = ref.watch(selectedProjectIdProvider);
    final permsAsync = ref.watch(sessionPermissionsProvider);
    final canManageMembers = permsAsync.maybeWhen(
      data: (p) => p.project.canManageMembers,
      orElse: () => false,
    );

    if (projectId == null || projectId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          title: const Text('Overview'),
        ),
        body: const EmptyStateView(
          title: 'No project selected',
          message: 'Go back and choose a project first.',
          icon: Icons.folder_open_outlined,
        ),
      );
    }

    final projectsAsync = ref.watch(projectsListProvider);
    final membersAsync = ref.watch(projectMembersProvider(projectId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Overview'),
        actions: [
          if (canManageMembers)
            TextButton(
              onPressed: _savingProject
                  ? null
                  : () {
                      setState(() => _editing = !_editing);
                    },
              child: Text(_editing ? 'Cancel' : 'Edit'),
            ),
        ],
      ),
      body: projectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorStateView(error: e, onRetry: () => ref.invalidate(projectsListProvider)),
        data: (projects) {
          final project = projects.firstWhere(
            (p) => p.id == projectId,
            orElse: () => projects.isNotEmpty ? projects.first : const ProjectModel(id: '', name: ''),
          );
          if (project.id.isEmpty) {
            return const EmptyStateView(
              title: 'Project not found',
              message: 'This project is not available in your workspace.',
              icon: Icons.folder_open_outlined,
            );
          }
          _syncControllersFrom(project);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(projectsListProvider);
              ref.invalidate(projectMembersProvider(projectId));
              await Future.wait([
                ref.read(projectsListProvider.future),
                ref.read(projectMembersProvider(projectId).future),
              ]);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Card(
                  elevation: 0,
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                project.key ?? 'PROJECT',
                                style: TextStyle(
                                  color: scheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                project.name,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (_editing) ...[
                          TextField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _descCtrl,
                            minLines: 2,
                            maxLines: 6,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _savingProject ? null : () => _saveProject(project),
                            child: _savingProject
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Save'),
                          ),
                        ] else ...[
                          Text(
                            (project.description ?? '').trim().isEmpty
                                ? 'No description yet.'
                                : project.description!.trim(),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Project members', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                membersAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('$e', style: TextStyle(color: scheme.error)),
                  ),
                  data: (members) {
                    if (members.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          'No members yet.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      );
                    }
                    return Card(
                      elevation: 0,
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
                      child: Column(
                        children: [
                          for (final m in members) ...[
                            ListTile(
                              title: Text(m.email),
                              subtitle: Text(m.projectRole),
                              trailing: canManageMembers
                                  ? TextButton(
                                      onPressed: () => _removeMember(projectId: projectId, member: m),
                                      style: TextButton.styleFrom(foregroundColor: scheme.error),
                                      child: const Text('Remove'),
                                    )
                                  : null,
                            ),
                            if (m != members.last) const Divider(height: 1),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                if (canManageMembers) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Add user to this project',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'The list includes everyone in your current organization. Users already on this project are hidden.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  _AddMemberForm(
                    projectId: projectId,
                    adding: _addingMember,
                    selectedUserId: _selectedUserId,
                    selectedRole: _selectedProjectRole,
                    onUserChanged: (v) => setState(() => _selectedUserId = v),
                    onRoleChanged: (v) => setState(() => _selectedProjectRole = v),
                    onSubmit: () => _addMember(projectId),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AddMemberForm extends ConsumerWidget {
  const _AddMemberForm({
    required this.projectId,
    required this.adding,
    required this.selectedUserId,
    required this.selectedRole,
    required this.onUserChanged,
    required this.onRoleChanged,
    required this.onSubmit,
  });

  final String projectId;
  final bool adding;
  final String selectedUserId;
  final String selectedRole;
  final ValueChanged<String> onUserChanged;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final membersAsync = ref.watch(projectMembersProvider(projectId));
    final usersFuture = ref.read(issuesApiProvider).fetchOrgUsers();

    return FutureBuilder<List<OrgListUser>>(
      future: usersFuture,
      builder: (context, snap) {
        final members = membersAsync.valueOrNull ?? const <ProjectMemberModel>[];
        final memberIds = members.map((m) => m.userId).toSet();

        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final users = (snap.data ?? const <OrgListUser>[])
            .where((u) => u.userId.isNotEmpty && !memberIds.contains(u.userId))
            .toList(growable: false);

        return Card(
          elevation: 0,
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedUserId.isEmpty ? null : selectedUserId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Select user',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('Select user')),
                    ...users.map(
                      (u) => DropdownMenuItem<String>(
                        value: u.userId,
                        child: Text(
                          u.role != null && u.role!.trim().isNotEmpty
                              ? '${u.email} (${u.role})'
                              : u.email,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: adding ? null : (v) => onUserChanged(v ?? ''),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Project role',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _projectRoles
                      .map((r) => DropdownMenuItem<String>(value: r, child: Text(r)))
                      .toList(growable: false),
                  onChanged: adding ? null : (v) => onRoleChanged(v ?? 'team_member'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: adding || selectedUserId.trim().isEmpty ? null : onSubmit,
                  child: adding
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

