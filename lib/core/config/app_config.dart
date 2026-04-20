import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'env_resolution.dart';

/// Backend and app-wide settings.
///
/// Values come from `assets/env/app.env` (flutter_dotenv), then `--dart-define`.
class AppConfig {
  AppConfig._();

  /// Same `/api` base as the React Vite proxy.
  static String get apiBaseUrl {
    final raw = resolveEnv(
      'API_BASE_URL',
      const String.fromEnvironment('API_BASE_URL', defaultValue: ''),
      fallback: 'http://localhost:3003',
    );
    return _maybeMapLocalhostForAndroidEmulator(raw);
  }

  /// When developing on Android **emulator**, you can keep `API_BASE_URL=http://localhost:3003`
  /// and enable mapping so it becomes `http://10.0.2.2:3003`.
  ///
  /// This is **disabled by default** because it breaks physical devices (where you should use
  /// either your Mac LAN IP, or `adb reverse` + `http://127.0.0.1:3003`).
  static bool get enableAndroidEmulatorLocalhostMapping {
    final flag = dotenv.env['ANDROID_EMULATOR_LOCALHOST']?.toLowerCase().trim();
    return flag == 'true' || flag == '1' || flag == 'yes';
  }

  /// Defaults to 10.0.2.2 (Android emulator "host loopback").
  static String get androidEmulatorHostLoopback {
    final raw = dotenv.env['ANDROID_EMULATOR_HOST_LOOPBACK']?.trim();
    return (raw == null || raw.isEmpty) ? '10.0.2.2' : raw;
  }

  static String _maybeMapLocalhostForAndroidEmulator(String url) {
    if (kIsWeb) return url;
    if (defaultTargetPlatform != TargetPlatform.android) return url;
    if (!enableAndroidEmulatorLocalhostMapping) return url;

    final host = androidEmulatorHostLoopback;
    return url.replaceAll('127.0.0.1', host).replaceAll('localhost', host);
  }

  /// Verbose Dio request/response logging (console via [AppLogger]).
  ///
  /// - **Debug builds:** on by default; set `API_DEBUG_LOG=false` in `assets/env/app.env` to disable.
  /// - **Release/profile:** off unless `API_DEBUG_LOG=true` in app.env or `--dart-define=API_DEBUG_LOG=true`.
  static bool get enableApiLogging {
    const fromDefine = bool.fromEnvironment('API_DEBUG_LOG', defaultValue: false);
    final flag = dotenv.env['API_DEBUG_LOG']?.toLowerCase().trim();
    if (flag == 'false' || flag == '0' || flag == 'no') return false;
    if (flag == 'true' || flag == '1' || flag == 'yes' || fromDefine) return true;
    return kDebugMode;
  }
}
