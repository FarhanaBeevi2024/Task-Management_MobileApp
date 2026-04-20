import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/workspace_bootstrap.dart';
import '../providers/active_organization_provider.dart';
import '../../features/auth/providers/auth_providers.dart';

/// Global flags from `GET /api/access-config` → `roles[role].global` (web Access Control).
class AccessGlobalPermissions {
  const AccessGlobalPermissions({
    required this.canManageUsers,
    required this.canViewAllUsers,
    required this.canCreateProjects,
    required this.canViewAllProjects,
  });

  final bool canManageUsers;
  final bool canViewAllUsers;
  final bool canCreateProjects;
  final bool canViewAllProjects;

  factory AccessGlobalPermissions.fromJson(Map<String, dynamic>? json) {
    final m = json ?? const {};
    bool b(String k) => m[k] == true || m[k] == 1 || m[k] == 'true';
    return AccessGlobalPermissions(
      canManageUsers: b('canManageUsers'),
      canViewAllUsers: b('canViewAllUsers'),
      canCreateProjects: b('canCreateProjects'),
      canViewAllProjects: b('canViewAllProjects'),
    );
  }

  static AccessGlobalPermissions none() => const AccessGlobalPermissions(
        canManageUsers: false,
        canViewAllUsers: false,
        canCreateProjects: false,
        canViewAllProjects: false,
      );

  /// For `PUT /api/admin/role-access`.
  Map<String, dynamic> toJson() => {
        'canManageUsers': canManageUsers,
        'canViewAllUsers': canViewAllUsers,
        'canCreateProjects': canCreateProjects,
        'canViewAllProjects': canViewAllProjects,
      };

  AccessGlobalPermissions copyWith({
    bool? canManageUsers,
    bool? canViewAllUsers,
    bool? canCreateProjects,
    bool? canViewAllProjects,
  }) {
    return AccessGlobalPermissions(
      canManageUsers: canManageUsers ?? this.canManageUsers,
      canViewAllUsers: canViewAllUsers ?? this.canViewAllUsers,
      canCreateProjects: canCreateProjects ?? this.canCreateProjects,
      canViewAllProjects: canViewAllProjects ?? this.canViewAllProjects,
    );
  }
}

/// Project-scoped flags from `roles[role].project`.
class AccessProjectPermissions {
  const AccessProjectPermissions({
    required this.autoMemberOnCreate,
    required this.canManageMembers,
    required this.canCreateIssues,
    required this.canAssignIssuesToOthers,
    required this.canManageMilestones,
  });

  final bool autoMemberOnCreate;
  final bool canManageMembers;
  final bool canCreateIssues;
  final bool canAssignIssuesToOthers;
  final bool canManageMilestones;

  factory AccessProjectPermissions.fromJson(Map<String, dynamic>? json) {
    final m = json ?? const {};
    bool b(String k) => m[k] == true || m[k] == 1 || m[k] == 'true';
    return AccessProjectPermissions(
      autoMemberOnCreate: b('autoMemberOnCreate'),
      canManageMembers: b('canManageMembers'),
      canCreateIssues: b('canCreateIssues'),
      canAssignIssuesToOthers: b('canAssignIssuesToOthers'),
      canManageMilestones: b('canManageMilestones'),
    );
  }

  static AccessProjectPermissions none() => const AccessProjectPermissions(
        autoMemberOnCreate: false,
        canManageMembers: false,
        canCreateIssues: false,
        canAssignIssuesToOthers: false,
        canManageMilestones: false,
      );

  Map<String, dynamic> toJson() => {
        'autoMemberOnCreate': autoMemberOnCreate,
        'canManageMembers': canManageMembers,
        'canCreateIssues': canCreateIssues,
        'canAssignIssuesToOthers': canAssignIssuesToOthers,
        'canManageMilestones': canManageMilestones,
      };

  AccessProjectPermissions copyWith({
    bool? autoMemberOnCreate,
    bool? canManageMembers,
    bool? canCreateIssues,
    bool? canAssignIssuesToOthers,
    bool? canManageMilestones,
  }) {
    return AccessProjectPermissions(
      autoMemberOnCreate: autoMemberOnCreate ?? this.autoMemberOnCreate,
      canManageMembers: canManageMembers ?? this.canManageMembers,
      canCreateIssues: canCreateIssues ?? this.canCreateIssues,
      canAssignIssuesToOthers: canAssignIssuesToOthers ?? this.canAssignIssuesToOthers,
      canManageMilestones: canManageMilestones ?? this.canManageMilestones,
    );
  }
}

class RoleAccessEntry {
  const RoleAccessEntry({
    required this.global,
    required this.project,
  });

  final AccessGlobalPermissions global;
  final AccessProjectPermissions project;

  factory RoleAccessEntry.fromJson(Map<String, dynamic> json) {
    return RoleAccessEntry(
      global: AccessGlobalPermissions.fromJson(
        json['global'] is Map ? Map<String, dynamic>.from(json['global'] as Map) : null,
      ),
      project: AccessProjectPermissions.fromJson(
        json['project'] is Map ? Map<String, dynamic>.from(json['project'] as Map) : null,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'global': global.toJson(),
        'project': project.toJson(),
      };

  RoleAccessEntry copyWith({
    AccessGlobalPermissions? global,
    AccessProjectPermissions? project,
  }) {
    return RoleAccessEntry(
      global: global ?? this.global,
      project: project ?? this.project,
    );
  }
}

/// Full payload from `GET /api/access-config`.
class AccessConfigPayload {
  AccessConfigPayload({required this.roles});

  final Map<String, RoleAccessEntry> roles;

  factory AccessConfigPayload.fromJson(Map<String, dynamic> json) {
    final raw = json['roles'];
    final out = <String, RoleAccessEntry>{};
    if (raw is Map) {
      for (final e in raw.entries) {
        final k = e.key.toString().toLowerCase().trim();
        if (e.value is Map) {
          out[k] = RoleAccessEntry.fromJson(Map<String, dynamic>.from(e.value as Map));
        }
      }
    }
    return AccessConfigPayload(roles: out);
  }

  RoleAccessEntry resolve(String globalRole) {
    final r = globalRole.toLowerCase().trim();
    final direct = roles[r];
    if (direct != null) return direct;
    final userEntry = roles['user'];
    if (userEntry != null) return userEntry;
    return RoleAccessEntry(
      global: AccessGlobalPermissions.none(),
      project: AccessProjectPermissions.none(),
    );
  }

  /// Deep copy for Access Control editor drafts.
  AccessConfigPayload clone() {
    final m = <String, RoleAccessEntry>{};
    for (final e in roles.entries) {
      final g = e.value.global;
      final p = e.value.project;
      m[e.key] = RoleAccessEntry(
        global: AccessGlobalPermissions(
          canManageUsers: g.canManageUsers,
          canViewAllUsers: g.canViewAllUsers,
          canCreateProjects: g.canCreateProjects,
          canViewAllProjects: g.canViewAllProjects,
        ),
        project: AccessProjectPermissions(
          autoMemberOnCreate: p.autoMemberOnCreate,
          canManageMembers: p.canManageMembers,
          canCreateIssues: p.canCreateIssues,
          canAssignIssuesToOthers: p.canAssignIssuesToOthers,
          canManageMilestones: p.canManageMilestones,
        ),
      );
    }
    return AccessConfigPayload(roles: m);
  }

  /// Body for `PUT /api/admin/role-access` (`{ roles: { ... } }`).
  Map<String, dynamic> toRoleAccessRequestBody() {
    return {
      'roles': {
        for (final e in roles.entries) e.key: e.value.toJson(),
      },
    };
  }
}

/// Effective permissions for the signed-in user (matches web `useAccessConfig` + `userRole`).
class SessionPermissions {
  const SessionPermissions({
    required this.globalRole,
    required this.global,
    required this.project,
  });

  final String globalRole;
  final AccessGlobalPermissions global;
  final AccessProjectPermissions project;

  static SessionPermissions guest() => SessionPermissions(
        globalRole: 'user',
        global: AccessGlobalPermissions.none(),
        project: AccessProjectPermissions.none(),
      );

  /// Used when `/api/access-config` fails; mirrors backend `DEFAULT_ROLE_ACCESS` (subset).
  factory SessionPermissions.builtinForRole(String rawRole) {
    final r = rawRole.toLowerCase().trim();
    switch (r) {
      case 'superadmin':
      case 'admin':
        return SessionPermissions(
          globalRole: r,
          global: const AccessGlobalPermissions(
            canManageUsers: true,
            canViewAllUsers: true,
            canCreateProjects: true,
            canViewAllProjects: true,
          ),
          project: const AccessProjectPermissions(
            autoMemberOnCreate: true,
            canManageMembers: true,
            canCreateIssues: true,
            canAssignIssuesToOthers: true,
            canManageMilestones: true,
          ),
        );
      case 'team_leader':
        return SessionPermissions(
          globalRole: r,
          global: const AccessGlobalPermissions(
            canManageUsers: true,
            canViewAllUsers: true,
            canCreateProjects: true,
            canViewAllProjects: false,
          ),
          project: const AccessProjectPermissions(
            autoMemberOnCreate: true,
            canManageMembers: true,
            canCreateIssues: true,
            canAssignIssuesToOthers: true,
            canManageMilestones: true,
          ),
        );
      case 'team_member':
        return SessionPermissions(
          globalRole: r,
          global: AccessGlobalPermissions.none(),
          project: const AccessProjectPermissions(
            autoMemberOnCreate: false,
            canManageMembers: false,
            canCreateIssues: true,
            canAssignIssuesToOthers: false,
            canManageMilestones: false,
          ),
        );
      case 'client':
        return SessionPermissions(
          globalRole: r,
          global: AccessGlobalPermissions.none(),
          project: AccessProjectPermissions.none(),
        );
      default:
        return SessionPermissions(
          globalRole: 'user',
          global: AccessGlobalPermissions.none(),
          project: const AccessProjectPermissions(
            autoMemberOnCreate: false,
            canManageMembers: false,
            canCreateIssues: true,
            canAssignIssuesToOthers: false,
            canManageMilestones: false,
          ),
        );
    }
  }

  factory SessionPermissions.fromPayload(String rawRole, AccessConfigPayload payload) {
    final r = rawRole.toLowerCase().trim();
    final entry = payload.resolve(r);
    return SessionPermissions(globalRole: r, global: entry.global, project: entry.project);
  }
}

extension SessionPermissionsMilestoneNav on SessionPermissions {
  /// Web `canShowMilestonesNav` when project role is not yet chosen (e.g. **More** tab).
  bool get showMilestonesMenuLink {
    if (project.canManageMilestones) return true;
    final r = globalRole.toLowerCase();
    return r != 'client' && r != 'representative';
  }
}

/// Loads `/api/access-config` and merges with `GET /api/user` role (same as web `AccessConfigProvider`).
final sessionPermissionsProvider = FutureProvider<SessionPermissions>((ref) async {
  if (!hasAuthenticatedApiAccess(ref)) return SessionPermissions.guest();
  await ensureDefaultWorkspace(ref);
  ref.watch(activeOrganizationIdProvider);
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return SessionPermissions.guest();

  final dio = ref.watch(apiClientProvider);
  try {
    final res = await dio.get<Map<String, dynamic>>('/api/access-config');
    final body = res.data;
    if (body == null) {
      return SessionPermissions.builtinForRole(user.role);
    }
    final payload = AccessConfigPayload.fromJson(body);
    return SessionPermissions.fromPayload(user.role, payload);
  } on DioException {
    return SessionPermissions.builtinForRole(user.role);
  }
});
