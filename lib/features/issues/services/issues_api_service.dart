import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/dio_exception_mapper.dart';
import '../models/id_label_option.dart';
import '../models/issue_activity_log.dart';
import '../models/issue_model.dart';
import '../models/issue_type_model.dart';
import '../models/org_list_user.dart';

class IssuesApiService {
  IssuesApiService(this._dio);

  final Dio _dio;

  Future<List<IssueModel>> fetchIssues({
    required String projectId,
    String? sprintId,
    String? milestoneId,
    /// When set, returns issues assigned to this user (web **Work items**).
    String? assigneeId,
    /// When set, returns subtasks for the given parent issue.
    /// Use `'null'` (string) if you ever need top-level only (backend supports it),
    /// but the app currently uses it for specific parents.
    String? parentIssueId,
  }) async {
    try {
      final query = <String, dynamic>{'project_id': projectId};
      if (sprintId != null) query['sprint_id'] = sprintId;
      if (milestoneId != null) query['milestone_id'] = milestoneId;
      if (assigneeId != null && assigneeId.isNotEmpty) query['assignee_id'] = assigneeId;
      if (parentIssueId != null && parentIssueId.isNotEmpty) {
        query['parent_issue_id'] = parentIssueId;
      }

      final res = await _dio.get<List<dynamic>>(
        '/api/jira/issues',
        queryParameters: query,
      );
      final list = res.data ?? [];
      return list
          .map((e) => IssueModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, fallbackMessage: 'Failed to load tasks');
    }
  }

  /// Single issue with nested `issue_type`, `milestone`, `parent_issue`, etc.
  Future<IssueModel> fetchIssue(String issueId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/jira/issues/$issueId');
      final data = res.data;
      if (data == null) {
        throw ApiException('Empty response', statusCode: res.statusCode);
      }
      return IssueModel.fromJson(data);
    } on DioException catch (e) {
      throw mapDioException(e, fallbackMessage: 'Failed to load task');
    }
  }

  Future<List<IssueTypeModel>> fetchIssueTypes() async {
    try {
      final res = await _dio.get<List<dynamic>>('/api/jira/issue-types');
      final list = res.data ?? [];
      return list
          .map(
            (e) => IssueTypeModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .where((t) => t.id.isNotEmpty)
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, fallbackMessage: 'Failed to load issue types');
    }
  }

  /// Org users for assignee dropdown (`GET /api/users`). Empty on 403.
  Future<List<OrgListUser>> fetchOrgUsers() async {
    try {
      final res = await _dio.get<List<dynamic>>('/api/users');
      final list = res.data ?? [];
      return list
          .map((e) => OrgListUser.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((u) => u.userId.isNotEmpty)
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) return [];
      throw mapDioException(e, fallbackMessage: 'Failed to load users');
    }
  }

  Future<List<IdLabelOption>> fetchActiveReleases(String projectId) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        '/api/jira/releases',
        queryParameters: {'project_id': projectId, 'is_active': 'true'},
      );
      final list = res.data ?? [];
      return list.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        final id = m['id']?.toString() ?? '';
        final name = m['name']?.toString() ?? 'Release';
        final ver = m['version']?.toString();
        final label = ver != null && ver.isNotEmpty ? '$name ($ver)' : name;
        return IdLabelOption(id: id, label: label);
      }).where((o) => o.id.isNotEmpty).toList();
    } on DioException catch (e) {
      throw mapDioException(e, fallbackMessage: 'Failed to load releases');
    }
  }

  Future<List<IdLabelOption>> fetchProjectMilestones(String projectId) async {
    try {
      final res = await _dio.get<List<dynamic>>('/api/jira/projects/$projectId/milestones');
      final list = res.data ?? [];
      return list.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        final id = m['id']?.toString() ?? '';
        final version = m['version']?.toString() ?? 'Milestone';
        final planned = m['planned_date']?.toString();
        String? shortPlanned;
        if (planned != null && planned.isNotEmpty) {
          final d = DateTime.tryParse(planned);
          shortPlanned = d != null ? '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}' : planned;
        }
        final label = shortPlanned != null ? '$version ($shortPlanned)' : version;
        return IdLabelOption(id: id, label: label);
      }).where((o) => o.id.isNotEmpty).toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) return [];
      throw mapDioException(e, fallbackMessage: 'Failed to load milestones');
    }
  }

  Future<IssueModel> createIssue({
    required String projectId,
    required String issueTypeId,
    required String summary,
    String? description,
    String status = 'to_do',
    String internalPriority = 'P3',
    String? clientPriority,
    String? assigneeId,
    String? releaseId,
    String? milestoneId,
    String? parentIssueId,
    int? storyPoints,
    List<String>? labels,
    int? estimatedDays,
    int? actualDays,
    bool exposedToClient = false,
    String? dueDateYyyyMmDd,
    String? workflowStatus,
  }) async {
    try {
      final body = <String, dynamic>{
        'project_id': projectId,
        'issue_type_id': issueTypeId,
        'summary': summary,
        'title': summary,
        'status': status,
        'internal_priority': internalPriority,
        'client_priority': (clientPriority == null || clientPriority.isEmpty) ? null : clientPriority,
        'labels': labels ?? <String>[],
        'exposed_to_client': exposedToClient,
        if (description != null && description.isNotEmpty) 'description': description,
        if (assigneeId != null && assigneeId.isNotEmpty) 'assignee_id': assigneeId,
        if (releaseId != null && releaseId.isNotEmpty) 'release_id': releaseId,
        if (milestoneId != null && milestoneId.isNotEmpty) 'milestone_id': milestoneId,
        if (parentIssueId != null && parentIssueId.isNotEmpty) 'parent_issue_id': parentIssueId,
        if (storyPoints != null) 'story_points': storyPoints,
        if (estimatedDays != null) 'estimated_days': estimatedDays,
        if (actualDays != null) 'actual_days': actualDays,
        if (dueDateYyyyMmDd != null && dueDateYyyyMmDd.isNotEmpty) 'due_date': dueDateYyyyMmDd,
        if (workflowStatus != null && workflowStatus.isNotEmpty) 'workflow_status': workflowStatus,
      };

      final res = await _dio.post<Map<String, dynamic>>(
        '/api/jira/issues',
        data: body,
      );
      final data = res.data;
      if (data == null) {
        throw ApiException('Empty response', statusCode: res.statusCode);
      }
      return IssueModel.fromJson(data);
    } on DioException catch (e) {
      throw mapDioException(e, fallbackMessage: 'Failed to create task');
    }
  }

  /// Audit trail for a task (`GET /api/jira/issues/:id/activity-logs`).
  Future<List<IssueActivityLog>> fetchIssueActivityLogs(String issueId) async {
    try {
      final res = await _dio.get<List<dynamic>>('/api/jira/issues/$issueId/activity-logs');
      final list = res.data ?? [];
      return list
          .map((e) => IssueActivityLog.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((log) => log.id.isNotEmpty)
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, fallbackMessage: 'Failed to load activity');
    }
  }

  Future<void> updateIssueStatus({
    required String issueId,
    required String statusApiValue,
  }) async {
    try {
      await _dio.put<void>(
        '/api/jira/issues/$issueId',
        data: {'status': statusApiValue},
      );
    } on DioException catch (e) {
      throw mapDioException(e, fallbackMessage: 'Failed to update status');
    }
  }

  /// Full update aligned with web `IssueDetail` save payload.
  Future<IssueModel> updateIssue({
    required String issueId,
    required String summary,
    String? description,
    required String statusApiValue,
    required String internalPriority,
    String? clientPriority,
    int? storyPoints,
    List<String>? labels,
    String? dueDateYyyyMmDd,
    int? estimatedDays,
    int? actualDays,
    required bool exposedToClient,
    String? assigneeId,
    String? milestoneId,
    String? workflowStatus,
  }) async {
    try {
      final data = <String, dynamic>{
        'summary': summary,
        'title': summary,
        'description': description ?? '',
        'status': statusApiValue,
        'internal_priority': internalPriority.isEmpty ? 'P3' : internalPriority,
        'client_priority': (clientPriority == null || clientPriority.isEmpty) ? null : clientPriority,
        'story_points': storyPoints,
        'labels': labels ?? <String>[],
        'due_date': (dueDateYyyyMmDd == null || dueDateYyyyMmDd.isEmpty) ? null : dueDateYyyyMmDd,
        'estimated_days': estimatedDays,
        'actual_days': actualDays,
        'assignee_id': (assigneeId == null || assigneeId.isEmpty) ? null : assigneeId,
        'milestone_id': (milestoneId == null || milestoneId.isEmpty) ? null : milestoneId,
        'exposed_to_client': exposedToClient,
        if (workflowStatus != null && workflowStatus.isNotEmpty) 'workflow_status': workflowStatus,
      };

      final res = await _dio.put<Map<String, dynamic>>(
        '/api/jira/issues/$issueId',
        data: data,
      );
      final out = res.data;
      if (out == null) {
        throw ApiException('Empty response', statusCode: res.statusCode);
      }
      return IssueModel.fromJson(out);
    } on DioException catch (e) {
      throw mapDioException(e, fallbackMessage: 'Failed to update task');
    }
  }

  /// Full milestone rows for a project (`GET /api/jira/projects/:id/milestones`).
  Future<List<Map<String, dynamic>>> fetchMilestonesList(String projectId) async {
    try {
      final res = await _dio.get<List<dynamic>>('/api/jira/projects/$projectId/milestones');
      final list = res.data ?? [];
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on DioException catch (e) {
      throw mapDioException(e, fallbackMessage: 'Failed to load milestones');
    }
  }

  Future<Map<String, dynamic>> createMilestone({
    required String projectId,
    required String version,
    String? plannedDateYyyyMmDd,
    String status = 'planned',
    String? description,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/jira/projects/$projectId/milestones',
        data: {
          'version': version.trim(),
          'planned_date': (plannedDateYyyyMmDd == null || plannedDateYyyyMmDd.isEmpty)
              ? null
              : plannedDateYyyyMmDd,
          'status': status,
          'description': (description == null || description.trim().isEmpty) ? null : description.trim(),
        },
      );
      final data = res.data;
      if (data == null) {
        throw ApiException('Empty response', statusCode: res.statusCode);
      }
      return data;
    } on DioException catch (e) {
      throw mapDioException(e, fallbackMessage: 'Failed to create milestone');
    }
  }

  Future<Map<String, dynamic>> updateMilestone({
    required String milestoneId,
    required String version,
    String? plannedDateYyyyMmDd,
    required String status,
    String? description,
  }) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/api/jira/milestones/$milestoneId',
        data: {
          'version': version.trim(),
          'planned_date': (plannedDateYyyyMmDd == null || plannedDateYyyyMmDd.isEmpty)
              ? null
              : plannedDateYyyyMmDd,
          'status': status,
          'description': (description == null || description.trim().isEmpty) ? null : description.trim(),
        },
      );
      final data = res.data;
      if (data == null) {
        throw ApiException('Empty response', statusCode: res.statusCode);
      }
      return data;
    } on DioException catch (e) {
      throw mapDioException(e, fallbackMessage: 'Failed to update milestone');
    }
  }

  Future<void> deleteMilestone(String milestoneId) async {
    try {
      await _dio.delete<void>('/api/jira/milestones/$milestoneId');
    } on DioException catch (e) {
      throw mapDioException(e, fallbackMessage: 'Failed to delete milestone');
    }
  }
}
