import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/permissions/session_permissions.dart';
import '../../../core/widgets/app_snackbars.dart';
import '../providers/admin_providers.dart';

/// Parity with web **Access Control** — organization vs project permission matrix.
class AccessControlScreen extends ConsumerStatefulWidget {
  const AccessControlScreen({super.key});

  @override
  ConsumerState<AccessControlScreen> createState() => _AccessControlScreenState();
}

class _AccessControlScreenState extends ConsumerState<AccessControlScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  AccessConfigPayload? _draft;
  AccessConfigPayload? _baseline;
  bool _inited = false;
  bool _saving = false;

  static const _globalRoleKeys = ['admin', 'user'];
  static const _projectRoleKeys = ['admin', 'team_leader', 'team_member', 'client'];

  static const _roleLabels = {
    'admin': 'Admin',
    'team_leader': 'Team leader',
    'team_member': 'Team member',
    'client': 'Client',
    'user': 'User (default)',
  };

  static const _globalPerms = [
    ('canManageUsers', 'Manage users & assign global roles'),
    ('canViewAllUsers', 'View all users (assignment lists, directory)'),
    ('canCreateProjects', 'Create projects'),
    ('canViewAllProjects', 'View all projects (not only member projects)'),
  ];

  static const _projectPerms = [
    ('autoMemberOnCreate', 'Auto-add self as project member when creating a project'),
    ('canManageMembers', 'Manage project members'),
    ('canCreateIssues', 'Create issues / tasks'),
    ('canAssignIssuesToOthers', 'Assign issues to other users'),
    ('canManageMilestones', 'Manage milestones'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _applyGlobalToggle(String roleKey, String permKey, bool value) {
    final d = _draft!;
    final entry = d.roles[roleKey];
    if (entry == null) return;
    final g = _globalWith(entry.global, permKey, value);
    final next = Map<String, RoleAccessEntry>.from(d.roles);
    next[roleKey] = entry.copyWith(global: g);
    setState(() => _draft = AccessConfigPayload(roles: next));
  }

  void _applyProjectToggle(String roleKey, String permKey, bool value) {
    final d = _draft!;
    final entry = d.roles[roleKey];
    if (entry == null) return;
    final p = _projectWith(entry.project, permKey, value);
    final next = Map<String, RoleAccessEntry>.from(d.roles);
    next[roleKey] = entry.copyWith(project: p);
    setState(() => _draft = AccessConfigPayload(roles: next));
  }

  AccessGlobalPermissions _globalWith(AccessGlobalPermissions g, String key, bool v) {
    switch (key) {
      case 'canManageUsers':
        return g.copyWith(canManageUsers: v);
      case 'canViewAllUsers':
        return g.copyWith(canViewAllUsers: v);
      case 'canCreateProjects':
        return g.copyWith(canCreateProjects: v);
      case 'canViewAllProjects':
        return g.copyWith(canViewAllProjects: v);
      default:
        return g;
    }
  }

  AccessProjectPermissions _projectWith(AccessProjectPermissions p, String key, bool v) {
    switch (key) {
      case 'autoMemberOnCreate':
        return p.copyWith(autoMemberOnCreate: v);
      case 'canManageMembers':
        return p.copyWith(canManageMembers: v);
      case 'canCreateIssues':
        return p.copyWith(canCreateIssues: v);
      case 'canAssignIssuesToOthers':
        return p.copyWith(canAssignIssuesToOthers: v);
      case 'canManageMilestones':
        return p.copyWith(canManageMilestones: v);
      default:
        return p;
    }
  }

  bool _globalBool(RoleAccessEntry? e, String key) {
    if (e == null) return false;
    final g = e.global;
    switch (key) {
      case 'canManageUsers':
        return g.canManageUsers;
      case 'canViewAllUsers':
        return g.canViewAllUsers;
      case 'canCreateProjects':
        return g.canCreateProjects;
      case 'canViewAllProjects':
        return g.canViewAllProjects;
      default:
        return false;
    }
  }

  bool _projectBool(RoleAccessEntry? e, String key) {
    if (e == null) return false;
    final p = e.project;
    switch (key) {
      case 'autoMemberOnCreate':
        return p.autoMemberOnCreate;
      case 'canManageMembers':
        return p.canManageMembers;
      case 'canCreateIssues':
        return p.canCreateIssues;
      case 'canAssignIssuesToOthers':
        return p.canAssignIssuesToOthers;
      case 'canManageMilestones':
        return p.canManageMilestones;
      default:
        return false;
    }
  }

  Future<void> _save() async {
    if (_draft == null) return;
    setState(() => _saving = true);
    try {
      final saved = await ref.read(adminApiProvider).saveRoleAccess(_draft!);
      if (!mounted) return;
      setState(() {
        _draft = saved.clone();
        _baseline = saved.clone();
      });
      ref.invalidate(sessionPermissionsProvider);
      ref.invalidate(accessConfigPayloadProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Role access saved. Changes apply immediately.')),
      );
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e, fallback: 'Save failed.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _reset() {
    if (_baseline != null) {
      setState(() => _draft = _baseline!.clone());
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(accessConfigPayloadProvider);
    final canManage = ref.watch(sessionPermissionsProvider).maybeWhen(
          data: (p) => p.global.canManageUsers,
          orElse: () => false,
        );

    if (!canManage) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          title: const Text('Access Control'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('You do not have permission to configure role access.'),
          ),
        ),
      );
    }

    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          title: const Text('Access Control'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          title: const Text('Access Control'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$e', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(accessConfigPayloadProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (data) {
        if (!_inited) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _draft = data.clone();
              _baseline = data.clone();
              _inited = true;
            });
          });
        }
        if (!_inited || _draft == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              ),
              title: const Text('Access Control'),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        final d = _draft!;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            ),
            title: const Text('Access Control'),
            actions: [
              TextButton(
                onPressed: _saving ? null : _reset,
                child: const Text('Reset'),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Organization'),
                Tab(text: 'Project'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _roleGrid(
                context,
                keys: _globalRoleKeys,
                d: d,
                isGlobal: true,
                cs: cs,
              ),
              _roleGrid(
                context,
                keys: _projectRoleKeys,
                d: d,
                isGlobal: false,
                cs: cs,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _roleGrid(
    BuildContext context, {
    required List<String> keys,
    required AccessConfigPayload d,
    required bool isGlobal,
    required ColorScheme cs,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          isGlobal
              ? 'Permissions for workspace roles (Admin and User).'
              : 'Permissions for project roles (Admin, Team leader, Team member, Client).',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        ...keys.map((roleKey) {
          final entry = d.roles[roleKey];
          final title = _roleLabels[roleKey] ?? roleKey;
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    roleKey,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                  ),
                  const SizedBox(height: 12),
                  if (isGlobal)
                    ..._globalPerms.map((pair) {
                      final key = pair.$1;
                      final label = pair.$2;
                      return CheckboxListTile(
                        value: _globalBool(entry, key),
                        onChanged: (v) {
                          if (v != null) _applyGlobalToggle(roleKey, key, v);
                        },
                        title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    })
                  else
                    ..._projectPerms.map((pair) {
                      final key = pair.$1;
                      final label = pair.$2;
                      return CheckboxListTile(
                        value: _projectBool(entry, key),
                        onChanged: (v) {
                          if (v != null) _applyProjectToggle(roleKey, key, v);
                        },
                        title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    }),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
