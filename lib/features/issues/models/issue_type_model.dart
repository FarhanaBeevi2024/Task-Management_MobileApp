/// Minimal issue type row from `GET /api/jira/issue-types`.
class IssueTypeModel {
  const IssueTypeModel({required this.id, required this.name});

  final String id;
  final String name;

  factory IssueTypeModel.fromJson(Map<String, dynamic> json) {
    return IssueTypeModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Task',
    );
  }
}
