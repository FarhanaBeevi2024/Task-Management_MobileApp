import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../models/user_model.dart';

/// Auth + session helpers. Wire to Supabase or your backend token storage.
class AuthService {
  AuthService(this._dio);

  final Dio _dio;

  Future<UserModel?> fetchCurrentUser() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/user');
      final data = res.data;
      if (data == null) return null;
      return UserModel.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return null;
      throw ApiException(
        e.message ?? 'Request failed',
        statusCode: e.response?.statusCode,
      );
    }
  }
}
