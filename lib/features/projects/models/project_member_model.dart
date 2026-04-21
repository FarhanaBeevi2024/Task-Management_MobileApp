/// Row from `GET /api/jira/projects/:id/members`.
class ProjectMemberModel {
  const ProjectMemberModel({
    required this.projectId,
    required this.userId,
    required this.email,
    required this.projectRole,
    this.workspaceRole,
  });

  final String projectId;
  final String userId;
  final String email;
  final String projectRole;
  final String? workspaceRole;

  factory ProjectMemberModel.fromJson(Map<String, dynamic> json) {
    return ProjectMemberModel(
      projectId: json['project_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      email: json['email']?.toString() ?? 'Unknown',
      projectRole: json['project_role']?.toString() ?? 'team_member',
      workspaceRole: json['workspace_role']?.toString(),
    );
  }
}

