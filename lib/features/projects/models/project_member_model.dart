/// Row from `GET /api/jira/projects/:id/members`.
class ProjectMemberModel {
  const ProjectMemberModel({
    required this.projectId,
    required this.userId,
    required this.email,
    required this.projectRole,
    this.workspaceRole,
    this.firstName,
    this.lastName,
    this.displayName,
  });

  final String projectId;
  final String userId;
  final String email;
  final String projectRole;
  final String? workspaceRole;
  final String? firstName;
  final String? lastName;
  final String? displayName;

  /// Primary label for lists: name from profile, else email local-part, else email.
  String get memberLabel {
    final fromApi = displayName?.trim();
    if (fromApi != null && fromApi.isNotEmpty) return fromApi;
    final fn = firstName?.trim() ?? '';
    final ln = lastName?.trim() ?? '';
    final combined = '$fn $ln'.trim();
    if (combined.isNotEmpty) return combined;
    final e = email.trim();
    if (e.contains('@')) return e.split('@').first;
    return e.isEmpty ? 'Unknown' : e;
  }

  factory ProjectMemberModel.fromJson(Map<String, dynamic> json) {
    final email = json['email']?.toString() ?? 'Unknown';
    return ProjectMemberModel(
      projectId: json['project_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      email: email,
      projectRole: json['project_role']?.toString() ?? 'team_member',
      workspaceRole: json['workspace_role']?.toString(),
      firstName: json['first_name']?.toString(),
      lastName: json['last_name']?.toString(),
      displayName: json['display_name']?.toString(),
    );
  }
}
