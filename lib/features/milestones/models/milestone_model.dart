/// Row from `GET /api/jira/projects/:id/milestones`.
class MilestoneModel {
  const MilestoneModel({
    required this.id,
    required this.projectId,
    required this.version,
    this.plannedDate,
    this.status = 'planned',
    this.description,
  });

  final String id;
  final String projectId;
  final String version;
  final DateTime? plannedDate;
  final String status;
  final String? description;

  factory MilestoneModel.fromJson(Map<String, dynamic> json) {
    final plannedRaw = json['planned_date']?.toString();
    DateTime? planned;
    if (plannedRaw != null && plannedRaw.isNotEmpty) {
      planned = DateTime.tryParse(plannedRaw);
    }
    return MilestoneModel(
      id: json['id']?.toString() ?? '',
      projectId: json['project_id']?.toString() ?? '',
      version: json['version']?.toString() ?? '',
      plannedDate: planned,
      status: json['status']?.toString() ?? 'planned',
      description: json['description']?.toString(),
    );
  }
}
