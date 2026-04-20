import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'dio_logging_interceptor.dart';
import 'supabase_auth_dio_interceptor.dart';

/// Shared Dio instance: base URL, timeouts, interceptors (auth token, org header).
final apiClientProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(
    SupabaseAuthDioInterceptor(ref: ref, dio: dio),
  );

  // After auth so logs show final headers (redacted).
  dio.interceptors.add(DioLoggingInterceptor());

  return dio;
});
