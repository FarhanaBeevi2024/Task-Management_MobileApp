import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Resolves config: **bundled env file** first, then **`--dart-define`**, then [fallback].
///
/// Call only after [dotenv.load] in [main].
String resolveEnv(
  String key,
  String fromDefine, {
  String fallback = '',
}) {
  final fromDot = dotenv.env[key]?.trim();
  if (fromDot != null && fromDot.isNotEmpty) return fromDot;

  final fromCompiler = fromDefine.trim();
  if (fromCompiler.isNotEmpty) return fromCompiler;

  return fallback;
}
