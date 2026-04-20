import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../logging/app_logger.dart';

/// Logs every Dio request/response/error when [AppConfig.enableApiLogging] is true.
///
/// - Redacts [Authorization] and shortens [X-Organization-Id] for safer console output.
/// - Truncates large bodies so logs stay readable (copy full payload from backend if needed).
class DioLoggingInterceptor extends Interceptor {
  DioLoggingInterceptor({this.maxBodyLength = 2500});

  final int maxBodyLength;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!AppConfig.enableApiLogging) {
      return handler.next(options);
    }

    final buf = StringBuffer()
      ..writeln('┌── HTTP ${options.method} ${options.uri}')
      ..writeln('│ baseUrl: ${options.baseUrl}')
      ..writeln('│ headers: ${_sanitizeHeaders(options.headers)}');

    final data = options.data;
    if (data != null) {
      buf.writeln('│ body: ${_stringifyData(data)}');
    }
    buf.write('└────────────────────────────────────────');
    AppLogger.i(buf.toString());

    return handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    if (!AppConfig.enableApiLogging) {
      return handler.next(response);
    }

    final req = response.requestOptions;
    final buf = StringBuffer()
      ..writeln('┌── RESPONSE ${response.statusCode} ${req.method} ${req.uri}')
      ..writeln('│ ${_truncate(_stringifyData(response.data))}')
      ..write('└────────────────────────────────────────');
    AppLogger.i(buf.toString());

    return handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (AppConfig.enableApiLogging) {
      final req = err.requestOptions;
      final status = err.response?.statusCode;
      final buf = StringBuffer()
        ..writeln('┌── ERROR ${req.method} ${req.uri}')
        ..writeln('│ type: ${err.type}')
        ..writeln('│ message: ${err.message}')
        ..writeln('│ statusCode: $status');

      if (status == 401) {
        buf.writeln(
          '│ hint: 401 Unauthorized — missing/invalid Bearer token or expired session. '
          'Attach Supabase access_token in api_client interceptor after sign-in.',
        );
      }

      final data = err.response?.data;
      if (data != null) {
        buf.writeln('│ responseBody: ${_truncate(_stringifyData(data))}');
      }
      buf.write('└────────────────────────────────────────');
      AppLogger.e(buf.toString(), err, err.stackTrace);
    }

    return handler.next(err);
  }

  static Map<String, dynamic> _sanitizeHeaders(Map<String, dynamic> headers) {
    final out = Map<String, dynamic>.from(headers);
    final auth = out['Authorization'] ?? out['authorization'];
    if (auth != null) {
      final s = auth.toString();
      if (s.toLowerCase().startsWith('bearer ') && s.length > 12) {
        out['Authorization'] = 'Bearer <redacted len=${s.length - 7}>';
      } else {
        out['Authorization'] = '<redacted>';
      }
    }
    final org = out['X-Organization-Id'] ?? out['x-organization-id'];
    if (org != null) {
      final id = org.toString();
      out['X-Organization-Id'] = id.length <= 8 ? '***' : '${id.substring(0, 4)}…${id.substring(id.length - 4)}';
    }
    return out;
  }

  static String _stringifyData(dynamic data) {
    if (data == null) return 'null';
    if (data is FormData) {
      return 'FormData(fields: ${data.fields.length}, files: ${data.files.length})';
    }
    return data.toString();
  }

  String _truncate(String s) {
    if (s.length <= maxBodyLength) return s;
    return '${s.substring(0, maxBodyLength)}… [truncated ${s.length - maxBodyLength} chars]';
  }
}
