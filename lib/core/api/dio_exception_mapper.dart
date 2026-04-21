import 'package:dio/dio.dart';

import 'api_exception.dart';

ApiException mapDioException(
  DioException e, {
  String fallbackMessage = 'Request failed',
}) {
  final statusCode = e.response?.statusCode;
  final data = e.response?.data;

  String message = e.message ?? fallbackMessage;

  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
      message = 'Connection timed out. Check your network and try again.';
      break;
    case DioExceptionType.receiveTimeout:
      // Phone reached API base URL, but server did not finish (often backend → DB).
      message =
          'The server took too long to respond. If Wi‑Fi is fine, the machine running the API may be unable to reach the database (e.g. Supabase) or is overloaded.';
      break;
    case DioExceptionType.connectionError:
      message = 'Could not reach the server. Check your connection and try again.';
      break;
    case DioExceptionType.badCertificate:
      message = 'Secure connection failed (certificate error).';
      break;
    case DioExceptionType.cancel:
      message = 'Request was cancelled.';
      break;
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      if (data is Map) {
        final err = data['error'] ?? data['message'];
        if (err != null && err.toString().trim().isNotEmpty) {
          message = err.toString().trim();
        }
      } else if (data is String && data.trim().isNotEmpty) {
        message = data.trim();
      } else if (statusCode != null) {
        message = 'Request failed (HTTP $statusCode).';
      } else {
        message = fallbackMessage;
      }
      break;
  }

  message = _humanizeBackendErrorMessage(message);

  return ApiException(message, statusCode: statusCode);
}

/// Node/Supabase often surfaces low-level [TypeError: fetch failed] in JSON;
/// replace with something actionable for operators.
String _humanizeBackendErrorMessage(String raw) {
  final lower = raw.toLowerCase();
  if (lower.contains('fetch failed')) {
    return 'The API server could not reach the database (Supabase). On the PC or host running the backend, verify SUPABASE_URL and SUPABASE_SERVICE_KEY, outbound HTTPS access, and that the Supabase project is active (not paused).';
  }
  return raw;
}

