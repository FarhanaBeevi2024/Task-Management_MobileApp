class ProjectModel {
  const ProjectModel({
    required this.id,
    required this.name,
    this.description,
    this.key,
    this.currentUserProjectRole,
  });

  final String id;
  final String name;
  final String? description;
  /// Jira-style project code (e.g. `SP3`).
  final String? key;

  /// e.g. `client`, `member` — from backend when available.
  final String? currentUserProjectRole;

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      key: json['key']?.toString(),
      currentUserProjectRole: json['current_user_project_role']?.toString(),
    );
  }
}
