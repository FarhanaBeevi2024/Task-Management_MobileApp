import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api/api_exception.dart';
import '../api/dio_exception_mapper.dart';

String friendlyErrorMessage(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error is ApiException) return error.message;
  if (error is DioException) {
    return mapDioException(error, fallbackMessage: fallback).message;
  }
  if (error is AuthException) return error.message;

  final s = error.toString().trim();
  if (s.isEmpty) return fallback;
  // Avoid showing noisy internal class names when we can.
  if (s.startsWith('ApiException(')) return fallback;
  return s;
}

