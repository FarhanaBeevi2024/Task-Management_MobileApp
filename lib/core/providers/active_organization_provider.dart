import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Active workspace org id, sent as `X-Organization-Id` (same as the React app).
/// Set after login via [ensureDefaultWorkspace] or a future org-picker UI.
final activeOrganizationIdProvider = StateProvider<String?>((ref) => null);

/// Supabase user id used for the current [activeOrganizationIdProvider] (clear org on account switch).
final orgBootstrapUserIdProvider = StateProvider<String?>((ref) => null);
