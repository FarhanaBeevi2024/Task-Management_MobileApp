import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/permissions/session_permissions.dart';
import '../../../core/widgets/app_snackbars.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/loading_skeletons.dart';
import '../../issues/providers/issues_providers.dart';
import '../models/project_model.dart';
import '../providers/projects_providers.dart';
import '../widgets/project_tile.dart';

/// [MainShellScreen] uses `extendBody` + a floating [NavigationBar], so list
/// content draws under the bar unless we pad by this much.
double projectsTabListBottomPadding(BuildContext context) {
  const material3NavigationBarHeight = 80.0;
  const shellBarOuterBottom = 14.0;
  const breathingRoom = 8.0;
  return MediaQuery.viewPaddingOf(context).bottom +
      material3NavigationBarHeight +
      shellBarOuterBottom +
      breathingRoom;
}

class ProjectsListScreen extends ConsumerWidget {
  const ProjectsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(projectsListProvider);
    final canDelete = ref.watch(sessionPermissionsProvider).maybeWhen(
      data: (p) => p.project.canManageMembers,
      orElse: () => false,
    );
    final canCreate = ref.watch(sessionPermissionsProvider).maybeWhen(
      data: (p) => p.global.canCreateProjects,
      orElse: () => false,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canCreate)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => showCreateProjectDialog(context, ref),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create project'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ),
        if (canCreate) const SizedBox(height: 8),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 340),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: async.when(
              loading: () => KeyedSubtree(
              key: const ValueKey('projects-loading'),
                child: LoadingSkeletons.projectList(
                  context,
                  bottomScrollPadding: projectsTabListBottomPadding(context),
                ),
              ),
              error: (e, _) => KeyedSubtree(
              key: ValueKey('projects-error-$e'),
                child: ErrorStateView(
                  error: e,
                  onRetry: () => ref.invalidate(projectsListProvider),
                ),
              ),
              data: (projects) {
                if (projects.isEmpty) {
                  return KeyedSubtree(
                    key: const ValueKey('projects-empty'),
                    child: EmptyStateView(
                      title: 'No projects yet',
                      message: ref.watch(sessionPermissionsProvider).maybeWhen(
                            data: (p) => p.global.canCreateProjects,
                            orElse: () => false,
                          )
                          ? 'Create a project with the button above, or pull to refresh.'
                          : 'When a project is created for your workspace, it will appear here.',
                      actionLabel: 'Refresh',
                      onAction: () => ref.invalidate(projectsListProvider),
                    ),
                  );
                }
                return KeyedSubtree(
                  key: ValueKey('projects-data-${projects.length}'),
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(projectsListProvider);
                      ref.invalidate(sessionPermissionsProvider);
                      await ref.read(projectsListProvider.future);
                    },
                    child: ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        4,
                        16,
                        projectsTabListBottomPadding(context),
                      ),
                      itemCount: projects.length,
                      itemBuilder: (context, i) {
                        final p = projects[i];
                        return ProjectTile(
                          project: p,
                          onTap: () {
                            ref.read(selectedProjectIdProvider.notifier).state = p.id;
                            context.push('/board');
                          },
                          onDelete: canDelete
                              ? () => _confirmDeleteProject(context, ref, p)
                              : null,
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Opens the create-project dialog (used from the projects list action row).
///
/// Controllers live on a [ConsumerStatefulWidget] so they are disposed only after
/// the dialog route has torn down (avoids `_dependents.isEmpty` crashes).
Future<void> showCreateProjectDialog(BuildContext context, WidgetRef ref) async {
  final created = await showDialog<bool>(
    context: context,
    builder: (_) => const _CreateProjectDialog(),
  );

  if (created != true || !context.mounted) return;

  ref.invalidate(projectsListProvider);
  await ref.read(projectsListProvider.future);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Project created')),
    );
  }
}

class _CreateProjectDialog extends ConsumerStatefulWidget {
  const _CreateProjectDialog();

  @override
  ConsumerState<_CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends ConsumerState<_CreateProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _keyCtrl;
  late final TextEditingController _descCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _keyCtrl = TextEditingController();
    _descCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _keyCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _saving = true);
    try {
      await ref.read(projectsApiProvider).createProject(
            key: _keyCtrl.text.trim(),
            name: _nameCtrl.text.trim(),
            description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e, fallback: 'Could not create project.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create project'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter a name';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _keyCtrl,
                textCapitalization: TextCapitalization.characters,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Project code',
                  hintText: 'e.g. CHEMP',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter a project code';
                  final t = v.trim();
                  if (t.length < 2) return 'At least 2 characters';
                  if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(t)) {
                    return 'Letters, numbers, hyphen, underscore only';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'Creating…' : 'Create'),
        ),
      ],
    );
  }
}

Future<void> _confirmDeleteProject(
  BuildContext context,
  WidgetRef ref,
  ProjectModel project,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete project?'),
      content: Text(
        'This will remove "${project.name}" and its tasks from the workspace. This cannot be undone.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
            foregroundColor: Theme.of(ctx).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;

  try {
    await ref.read(projectsApiProvider).deleteProject(project.id);
    ref.invalidate(projectsListProvider);
    ref.invalidate(projectIssueProgressProvider(project.id));
    if (ref.read(selectedProjectIdProvider) == project.id) {
      ref.read(selectedProjectIdProvider.notifier).state = null;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project deleted')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      showErrorSnackBar(context, e, fallback: 'Could not delete project.');
    }
  }
}
