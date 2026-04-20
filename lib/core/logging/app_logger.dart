import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// App-wide logging. Uses [debugPrint] under the hood via [Logger] so output
/// appears in `flutter run`, Xcode, and Android Studio.
///
/// For API traffic, prefer [DioLoggingInterceptor] (structured request/response).
class AppLogger {
  AppLogger._();

  static final Logger _default = Logger(
    level: kDebugMode ? Level.trace : Level.warning,
    filter: _ReleaseWarningFilter(),
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 12,
      lineLength: 110,
      colors: true,
      printEmojis: true,
    ),
    output: _FlutterLogOutput(),
  );

  static void d(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _default.d(message, error: error, stackTrace: stackTrace);
  }

  static void i(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _default.i(message, error: error, stackTrace: stackTrace);
  }

  static void w(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _default.w(message, error: error, stackTrace: stackTrace);
  }

  static void e(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _default.e(message, error: error, stackTrace: stackTrace);
  }
}

class _ReleaseWarningFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    if (kDebugMode) return true;
    return event.level.index >= Level.warning.index;
  }
}

/// Routes [Logger] output to [debugPrint] (throttled, debugger-friendly).
class _FlutterLogOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    for (final line in event.lines) {
      debugPrint(line);
    }
  }
}
