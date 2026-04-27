import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Resolves config: **`--dart-define`** first, then **bundled env file**, then [fallback].
///
/// Call only after [dotenv.load] in [main].
String resolveEnv(
  String key,
  String fromDefine, {
  String fallback = '',
}) {
  final fromCompiler = fromDefine.trim();
  if (fromCompiler.isNotEmpty) return fromCompiler;

  final fromDot = dotenv.env[key]?.trim();
  if (fromDot != null && fromDot.isNotEmpty) return fromDot;

  return fallback;
}
