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
    case DioExceptionType.receiveTimeout:
      message = 'Connection timed out. Check your network and try again.';
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

  return ApiException(message, statusCode: statusCode);
}

