/// Row from `GET /api/users` (org-scoped user directory).
class WorkspaceUserModel {
  const WorkspaceUserModel({
    required this.userId,
    required this.email,
    required this.role,
    required this.active,
    required this.pendingOrgMembership,
    this.firstName = '',
    this.lastName = '',
  });

  final String userId;
  final String email;
  /// Workspace role: `admin` or `user` (and possibly others from backend).
  final String role;
  final bool active;
  final bool pendingOrgMembership;
  final String firstName;
  final String lastName;

  factory WorkspaceUserModel.fromJson(Map<String, dynamic> json) {
    return WorkspaceUserModel(
      userId: json['user_id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString().toLowerCase().trim() ?? 'user',
      active: json['active'] != false,
      pendingOrgMembership: json['pending_org_membership'] == true,
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
    );
  }

  String get displayRole {
    if (role.isEmpty) return 'User';
    return '${role[0].toUpperCase()}${role.length > 1 ? role.substring(1) : ''}';
  }
}
