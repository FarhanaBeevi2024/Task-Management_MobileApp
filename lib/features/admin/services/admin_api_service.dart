import 'package:dio/dio.dart';

import '../../../core/permissions/session_permissions.dart';
import '../models/workspace_user_model.dart';

class AdminApiService {
  AdminApiService(this._dio);

  final Dio _dio;

  Future<List<WorkspaceUserModel>> fetchWorkspaceUsers() async {
    final res = await _dio.get<dynamic>(
      '/api/users',
      queryParameters: {'include_pending_signups': '1'},
    );
    final data = res.data;
    if (data is! List) return [];
    return data
        .map((e) => WorkspaceUserModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Returns server JSON (includes `signup_url`, `added_existing_user`, etc.).
  Future<Map<String, dynamic>> inviteUser({
    required String email,
    required String role,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/organization/invitations',
      data: {'email': email.trim().toLowerCase(), 'role': role},
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<AccessConfigPayload> fetchAccessConfig() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/access-config');
    return AccessConfigPayload.fromJson(Map<String, dynamic>.from(res.data ?? {}));
  }

  Future<AccessConfigPayload> saveRoleAccess(AccessConfigPayload payload) async {
    final res = await _dio.put<Map<String, dynamic>>(
      '/api/admin/role-access',
      data: payload.toRoleAccessRequestBody(),
    );
    return AccessConfigPayload.fromJson(Map<String, dynamic>.from(res.data ?? {}));
  }

  Future<void> updateWorkspaceUser({
    required String userId,
    String? role,
    bool? active,
  }) async {
    final body = <String, dynamic>{};
    if (role != null) body['role'] = role;
    if (active != null) body['active'] = active;
    if (body.isEmpty) return;
    await _dio.put<void>('/api/admin/users/$userId', data: body);
  }

  /// Direct signup-style user creation (parity with web **Create user**).
  Future<Map<String, dynamic>> createUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/admin/users/create',
      data: {
        'email': email.trim().toLowerCase(),
        'password': password,
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'role': role,
      },
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  /// Restricts user to listed projects; omit call (or empty with no prior rows) for “all projects”.
  Future<void> setUserProjectAssociations({
    required String userId,
    required List<String> projectIds,
  }) async {
    await _dio.put<void>(
      '/api/admin/users/$userId/project-associations',
      data: {'project_ids': projectIds},
    );
  }
}
