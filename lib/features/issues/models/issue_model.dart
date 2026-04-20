import 'issue_status.dart';

/// Jira-style issue fields — aligned with web `IssueForm` / `IssueDetail` + API.
class IssueModel {
  const IssueModel({
    required this.id,
    required this.summary,
    this.issueKey,
    this.description,
    this.status = IssueStatus.toDo,
    this.workflowStatus,
    this.assigneeId,
    this.assigneeEmail,
    this.internalPriority,
    this.dueDate,
    this.clientPriority,
    this.storyPoints,
    this.labels = const [],
    this.estimatedDays,
    this.actualDays,
    this.exposedToClient = false,
    this.milestoneId,
    this.releaseId,
    this.parentIssueId,
    this.issueTypeId,
    this.issueTypeName,
    this.milestoneDisplay,
    this.parentIssueKey,
    this.parentSummary,
    this.reporterEmail,
  });

  final String id;
  final String summary;
  final String? issueKey;
  final String? description;
  final IssueStatus status;
  final String? workflowStatus;
  final String? assigneeId;
  final String? assigneeEmail;
  final String? internalPriority;
  final DateTime? dueDate;
  final String? clientPriority;
  final int? storyPoints;
  final List<String> labels;
  final int? estimatedDays;
  final int? actualDays;
  final bool exposedToClient;
  final String? milestoneId;
  final String? releaseId;
  final String? parentIssueId;
  final String? issueTypeId;
  /// From nested `issue_type` on list/detail API responses.
  final String? issueTypeName;
  /// Human-readable milestone line from nested `milestone`.
  final String? milestoneDisplay;
  /// When `parent_issue` is embedded (detail fetch).
  final String? parentIssueKey;
  final String? parentSummary;
  /// From nested `reporter` when API attaches profile.
  final String? reporterEmail;

  static String _readString(dynamic v) => v == null ? '' : v.toString();

  static String? _readNullableString(dynamic v) {
    final s = v?.toString();
    if (s == null) return null;
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  static int? _readInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim());
  }

  static List<String> _readLabels(dynamic v) {
    if (v == null) return const [];
    if (v is List) {
      return v.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList(growable: false);
    }
    final s = v.toString().trim();
    if (s.isEmpty) return const [];
    return s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
  }

  factory IssueModel.fromJson(Map<String, dynamic> json) {
    final fieldsMap = switch (json['fields']) {
      final Map m => Map<String, dynamic>.from(m),
      _ => const <String, dynamic>{},
    };

    final assignee = json['assignee'];
    String? email;
    if (assignee is Map) {
      email = assignee['email']?.toString();
    }

    final statusValue = json['status'];
    final statusString = switch (statusValue) {
      String s => s,
      Map m => (m['api_value'] ?? m['value'] ?? m['name'] ?? m['id'])?.toString(),
      _ => null,
    };

    final summary = _readString(
      json['summary'] ??
          json['title'] ??
          json['name'] ??
          fieldsMap['summary'] ??
          fieldsMap['title'],
    ).trim();

    String? issueTypeName;
    final issueType = json['issue_type'];
    if (issueType is Map) {
      issueTypeName = _readNullableString(issueType['name']);
    }

    String? reporterEmail;
    final reporter = json['reporter'];
    if (reporter is Map) {
      reporterEmail = _readNullableString(reporter['email']);
    }

    String? parentIssueKey;
    String? parentSummary;
    final parentIssue = json['parent_issue'];
    if (parentIssue is Map) {
      parentIssueKey = _readNullableString(parentIssue['issue_key']);
      parentSummary = _readNullableString(parentIssue['summary']);
    }

    return IssueModel(
      id: json['id']?.toString() ?? '',
      summary: summary,
      issueKey: _readNullableString(json['issue_key'] ?? json['key']),
      description: _readNullableString(json['description'] ?? fieldsMap['description']),
      status: IssueStatus.fromApi(statusString),
      workflowStatus: _readNullableString(json['workflow_status'] ?? json['workflowStatus']),
      assigneeId: json['assignee_id']?.toString(),
      assigneeEmail: email,
      internalPriority: json['internal_priority']?.toString() ?? json['priority']?.toString(),
      dueDate: _parseDate(json['due_date'] ?? fieldsMap['due_date'] ?? fieldsMap['duedate']),
      clientPriority: _readNullableString(json['client_priority']),
      storyPoints: _readInt(json['story_points']),
      labels: _readLabels(json['labels']),
      estimatedDays: _readInt(json['estimated_days']),
      actualDays: _readInt(json['actual_days']),
      exposedToClient: json['exposed_to_client'] == true ||
          json['exposed_to_client'] == 'true' ||
          json['exposed_to_client'] == 1,
      milestoneId: _readNullableString(json['milestone_id']),
      releaseId: _readNullableString(json['release_id']),
      parentIssueId: _readNullableString(json['parent_issue_id']),
      issueTypeId: _readNullableString(json['issue_type_id']),
      issueTypeName: issueTypeName,
      milestoneDisplay: _milestoneDisplayFromJson(json['milestone']),
      parentIssueKey: parentIssueKey,
      parentSummary: parentSummary,
      reporterEmail: reporterEmail,
    );
  }

  static String? _milestoneDisplayFromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    if (m['id'] == null) return null;
    final version = (m['version']?.toString() ?? 'Milestone').trim();
    final plannedRaw = m['planned_date'];
    if (plannedRaw == null || plannedRaw.toString().trim().isEmpty) {
      return version;
    }
    final d = _parseDate(plannedRaw);
    if (d == null) return version;
    final y = d.year;
    final mo = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$version ($y-$mo-$day)';
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    final dt = DateTime.tryParse(s);
    if (dt == null) return null;
    return dt;
  }
}
