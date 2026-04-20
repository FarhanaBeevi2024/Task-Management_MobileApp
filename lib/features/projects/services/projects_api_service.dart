import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/dio_exception_mapper.dart';
import '../models/project_model.dart';

class ProjectsApiService {
  ProjectsApiService(this._dio);

  final Dio _dio;

  Future<List<ProjectModel>> fetchProjects() async {
    try {
      final res = await _dio.get<List<dynamic>>('/api/jira/projects');
      final list = res.data ?? [];
      return list
          .map((e) => ProjectModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      String msg = _messageFromDioResponse(e) ??
          e.message ??
          'Failed to load projects';
      throw ApiException(msg, statusCode: e.response?.statusCode);
    }
  }

  Future<ProjectModel> createProject({
    required String key,
    required String name,
    String? description,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/jira/projects',
        data: {
          'key': key.trim().toUpperCase(),
          'name': name.trim(),
          if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
        },
      );
      final data = res.data;
      if (data == null) {
        throw ApiException('Empty response', statusCode: res.statusCode);
      }
      return ProjectModel.fromJson(data);
    } on DioException catch (e) {
      throw mapDioException(e, fallbackMessage: 'Failed to create project');
    }
  }

  Future<void> deleteProject(String projectId) async {
    try {
      await _dio.delete<void>('/api/jira/projects/$projectId');
    } on DioException catch (e) {
      throw mapDioException(e, fallbackMessage: 'Failed to delete project');
    }
  }

  static String? _messageFromDioResponse(DioException e) {
    dynamic body = e.response?.data;
    if (body is String && body.trim().isNotEmpty) {
      try {
        body = jsonDecode(body) as Object?;
      } catch (_) {
        return body.trim();
      }
    }
    if (body is Map && body['error'] != null) {
      return body['error'].toString();
    }
    return null;
  }
}
