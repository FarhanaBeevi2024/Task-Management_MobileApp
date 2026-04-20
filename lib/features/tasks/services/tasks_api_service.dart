import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/dio_exception_mapper.dart';
import '../models/task_model.dart';

/// Legacy `/api/tasks` client (same routes as React `Dashboard.jsx`).
class TasksApiService {
  TasksApiService(this._dio);

  final Dio _dio;
  static const Object _noChange = Object();

  /// `GET /api/tasks`
  Future<List<Task>> fetchTasks() async {
    try {
      final response = await _dio.get<List<dynamic>>('/api/tasks');
      final raw = response.data ?? [];
      return raw
          .map((e) => Task.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, fallbackMessage: 'Failed to load tasks');
    }
  }

  /// `POST /api/tasks` — matches React payload (`title`, `description`, `priority`, `status`, `due_date`, `assigned_to`).
  Future<Task> createTask({
    required String title,
    String? description,
    String priority = 'medium',
    String status = 'pending',
    String? dueDate,
    String? assignedTo,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/tasks',
        data: <String, dynamic>{
          'title': title,
          if (description != null) 'description': description,
          'priority': priority,
          'status': status,
          if (dueDate != null) 'due_date': dueDate,
          if (assignedTo != null) 'assigned_to': assignedTo,
        },
      );
      final data = response.data;
      if (data == null) {
        throw ApiException(
          'Empty response from server',
          statusCode: response.statusCode,
        );
      }
      return Task.fromJson(data);
    } on DioException catch (e) {
      throw mapDioException(e, fallbackMessage: 'Failed to create task');
    }
  }

  /// `PUT /api/tasks/:id` — matches React `api.put(`/api/tasks/${taskId}`, updates)`.
  ///
  /// The backend expects any subset of these fields:
  /// `title`, `description`, `priority`, `status`, `due_date`, `assigned_to`.
  Future<Task> updateTask({
    required String taskId,
    String? title,
    String? description,
    String? priority,
    String? status,
    Object? dueDate = _noChange,
    Object? assignedTo = _noChange,
  }) async {
    try {
      final data = <String, dynamic>{
        if (title != null) 'title': title,
        // React sends description always (can be empty string); allow null to mean "omit".
        if (description != null) 'description': description,
        if (priority != null) 'priority': priority,
        if (status != null) 'status': status,
        // React sends null to clear; allow explicit null by using a sentinel.
        if (dueDate != _noChange) 'due_date': dueDate,
        if (assignedTo != _noChange) 'assigned_to': assignedTo,
      };
      if (data.isEmpty) {
        throw ApiException('No updates provided');
      }
      final response = await _dio.put<Map<String, dynamic>>(
        '/api/tasks/$taskId',
        data: data,
      );
      final body = response.data;
      if (body == null) {
        throw ApiException(
          'Empty response from server',
          statusCode: response.statusCode,
        );
      }
      return Task.fromJson(body);
    } on DioException catch (e) {
      throw mapDioException(e, fallbackMessage: 'Failed to update task');
    }
  }

  /// Convenience wrapper for status-only updates (used by older UI).
  Future<Task> updateTaskStatus({
    required String taskId,
    required String status,
  }) {
    return updateTask(taskId: taskId, status: status);
  }

  /// `DELETE /api/tasks/:id`
  Future<void> deleteTask(String taskId) async {
    try {
      await _dio.delete<void>('/api/tasks/$taskId');
    } on DioException catch (e) {
      throw mapDioException(e, fallbackMessage: 'Failed to delete task');
    }
  }
}
