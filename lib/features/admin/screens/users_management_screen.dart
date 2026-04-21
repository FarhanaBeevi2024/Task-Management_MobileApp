import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/permissions/session_permissions.dart';
import '../../../core/widgets/app_snackbars.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_footer_nav.dart';
import '../../../core/widgets/account_menu_button.dart';
import '../../auth/providers/auth_providers.dart';
import '../../projects/models/project_model.dart';
import '../../projects/providers/projects_providers.dart';
import '../models/workspace_user_model.dart';
import '../providers/admin_providers.dart';

/// Lists workspace members and invites users (parity with web **Users** page).
class UsersManagementScreen extends ConsumerStatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  ConsumerState<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends ConsumerState<UsersManagementScreen> {
  final _emailCtrl = TextEditingController();
  String _inviteRole = 'user';
  bool _inviting = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitInvite() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address.')),
      );
      return;
    }
    setState(() => _inviting = true);
    try {
      final res = await ref.read(adminApiProvider).inviteUser(email: email, role: _inviteRole);
      if (!mounted) return;
      if (res['added_existing_user'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'That email already has an account — they were added to this workspace.',
            ),
          ),
        );
        _emailCtrl.clear();
      } else {
        final url = res['signup_url']?.toString() ?? '';
        final err = res['email_send_error']?.toString();
        if (url.isNotEmpty) {
          await Clipboard.setData(ClipboardData(text: url));
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                err != null && err.isNotEmpty
                    ? 'Invite link copied. Email may have failed: $err'
                    : 'Invite link copied to clipboard.',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invitation created.')),
          );
        }
        _emailCtrl.clear();
      }
      ref.invalidate(workspaceUsersProvider);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e, fallback: 'Could not send invite.');
    } finally {
      if (mounted) setState(() => _inviting = false);
    }
  }

  Future<void> _openCreateUser(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => _CreateUserSheet(
        onDone: () {
          ref.invalidate(workspaceUsersProvider);
          ref.invalidate(projectsListProvider);
        },
      ),
    );
  }

  Future<void> _openEdit(WorkspaceUserModel u) async {
    final me = await ref.read(currentUserProvider.future);
    if (!mounted) return;
    final isSelf = me?.id == u.userId;
    String role = u.role == 'admin' ? 'admin' : 'user';
    bool active = u.active;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Edit member', style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(u.email, style: Theme.of(ctx).textTheme.bodySmall),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: role,
                    decoration: const InputDecoration(
                      labelText: 'Workspace role',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      DropdownMenuItem(value: 'user', child: Text('User')),
                    ],
                    onChanged: isSelf && role == 'admin'
                        ? null
                        : (v) {
                            if (v != null) setModal(() => role = v);
                          },
                  ),
                  if (isSelf && role == 'admin')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'You cannot change your own role from Admin to User here.',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Active'),
                    value: active,
                    onChanged: (v) => setModal(() => active = v),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      try {
                        await ref.read(adminApiProvider).updateWorkspaceUser(
                              userId: u.userId,
                              role: role != u.role ? role : null,
                              active: active != u.active ? active : null,
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                        ref.invalidate(workspaceUsersProvider);
                        ref.invalidate(currentUserProvider);
                        ref.invalidate(sessionPermissionsProvider);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('User updated')),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          showErrorSnackBar(ctx, e, fallback: 'Update failed.');
                        }
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(workspaceUsersProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        bottomNavigationBar: const AppFooterNav(),
        appBar: AppBar(
          title: const Text('Users'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          actions: [
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: AccountMenuButton(),
            ),
            TextButton.icon(
              onPressed: () => _openCreateUser(context),
              icon: const Icon(Icons.person_add_outlined, size: 20),
              label: const Text('Add user'),
            ),
          ],
        ),
        body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: cs.error),
                const SizedBox(height: 12),
                Text('$e', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(workspaceUsersProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (users) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(workspaceUsersProvider);
              await ref.read(workspaceUsersProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Text(
                  'Workspace roles are Admin or User. Use Add user for a password account here, or invite by email for a signup link.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Invite user', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          enabled: !_inviting,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _inviteRole,
                          decoration: const InputDecoration(
                            labelText: 'Role',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'user', child: Text('User')),
                            DropdownMenuItem(value: 'admin', child: Text('Admin')),
                          ],
                          onChanged: _inviting
                              ? null
                              : (v) {
                                  if (v != null) setState(() => _inviteRole = v);
                                },
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _inviting ? null : _submitInvite,
                          child: _inviting
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Create invite link'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Members', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                ...users.map((u) => _UserTile(user: u, onEdit: () => _openEdit(u))),
              ],
            ),
          );
        },
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.onEdit});

  final WorkspaceUserModel user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(user.email),
        subtitle: Text(
          user.pendingOrgMembership ? 'Pending workspace' : user.displayRole,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (user.active)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Active',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              Text('Inactive', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
              tooltip: 'Edit',
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateUserSheet extends ConsumerStatefulWidget {
  const _CreateUserSheet({required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<_CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends ConsumerState<_CreateUserSheet> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _workspaceRole = 'user';
  bool _selectAllProjects = true;
  final Set<String> _selectedProjectIds = {};
  bool _projectsInitScheduled = false;
  bool _projectsInited = false;
  bool _submitting = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _scheduleInitFromProjects(List<ProjectModel> list) {
    if (_projectsInited || _projectsInitScheduled) return;
    _projectsInitScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        if (list.isEmpty) {
          _selectedProjectIds.clear();
        } else {
          _selectedProjectIds
            ..clear()
            ..addAll(list.map((e) => e.id));
        }
        _selectAllProjects = true;
        _projectsInited = true;
        _projectsInitScheduled = false;
      });
    });
  }

  void _onSelectAll(bool? checked) {
    final list = ref.read(projectsListProvider).valueOrNull ?? [];
    final all = list.map((e) => e.id).toSet();
    setState(() {
      if (checked == true) {
        _selectAllProjects = true;
        _selectedProjectIds
          ..clear()
          ..addAll(all);
      } else {
        _selectAllProjects = false;
        _selectedProjectIds.clear();
      }
    });
  }

  void _toggleProject(String id, bool? checked) {
    final list = ref.read(projectsListProvider).valueOrNull ?? [];
    final allIds = list.map((e) => e.id).toSet();
    setState(() {
      if (checked == true) {
        _selectedProjectIds.add(id);
      } else {
        _selectedProjectIds.remove(id);
      }
      _selectAllProjects =
          allIds.isNotEmpty && _selectedProjectIds.length == allIds.length;
    });
  }

  String? _requiredName(String? s, String label) {
    if ((s?.trim() ?? '').isEmpty) return 'Enter $label';
    return null;
  }

  String? _emailValidator(String? s) {
    final t = s?.trim() ?? '';
    if (t.isEmpty) return 'Enter email';
    if (!t.contains('@')) return 'Invalid email';
    return null;
  }

  String? _passwordValidator(String? s) {
    if ((s ?? '').length < 6) return 'At least 6 characters';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final api = ref.read(adminApiProvider);
      final res = await api.createUser(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
        firstName: _firstNameCtrl.text,
        lastName: _lastNameCtrl.text,
        role: _workspaceRole,
      );
      final uid = res['user_id']?.toString() ?? '';
      if (uid.isEmpty) {
        throw StateError('Server did not return user_id');
      }
      if (!_selectAllProjects) {
        await api.setUserProjectAssociations(
          userId: uid,
          projectIds: _selectedProjectIds.toList(),
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      widget.onDone();
      messenger?.showSnackBar(const SnackBar(content: Text('User created')));
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e, fallback: 'Could not create user.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projectsAsync = ref.watch(projectsListProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    projectsAsync.whenData((list) {
      if (!_projectsInited && !_projectsInitScheduled) {
        _scheduleInitFromProjects(list);
      }
    });

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Create user', style: theme.textTheme.titleLarge),
              Text(
                'Set up profile and credentials like signup.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _firstNameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'First name',
                  border: OutlineInputBorder(),
                ),
                validator: (s) => _requiredName(s, 'first name'),
                enabled: !_submitting,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lastNameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Last name',
                  border: OutlineInputBorder(),
                ),
                validator: (s) => _requiredName(s, 'last name'),
                enabled: !_submitting,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: _emailValidator,
                enabled: !_submitting,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter password',
                  border: OutlineInputBorder(),
                ),
                validator: _passwordValidator,
                enabled: !_submitting,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _workspaceRole,
                decoration: const InputDecoration(
                  labelText: 'Workspace role',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('User')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: _submitting
                    ? null
                    : (v) {
                        if (v != null) setState(() => _workspaceRole = v);
                      },
              ),
              const SizedBox(height: 20),
              Text('Project access', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              projectsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('$e', style: TextStyle(color: theme.colorScheme.error)),
                data: (list) {
                  if (list.isEmpty) {
                    return Text(
                      'No projects yet — the user will have workspace access when projects exist.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    );
                  }
                  if (!_projectsInited) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final allIds = list.map((e) => e.id).toSet();
                  final allSelected =
                      allIds.isNotEmpty && _selectedProjectIds.length == allIds.length;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CheckboxListTile(
                        value: allSelected && _selectAllProjects,
                        onChanged: _submitting ? null : _onSelectAll,
                        title: const Text('Select all'),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      ...list.map(
                        (p) {
                          final subtitle = (p.key != null && p.key!.trim().isNotEmpty)
                              ? '${p.name} (${p.key})'
                              : p.name;
                          return CheckboxListTile(
                            value: _selectedProjectIds.contains(p.id),
                            onChanged: _submitting
                                ? null
                                : (v) => _toggleProject(p.id, v),
                            title: Text(subtitle),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _submitting ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create user'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
