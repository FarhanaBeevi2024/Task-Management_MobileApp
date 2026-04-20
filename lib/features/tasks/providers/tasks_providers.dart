import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../services/tasks_api_service.dart';

/// Injectable API client for tasks (used by [TasksNotifier] and tests).
final tasksApiServiceProvider = Provider<TasksApiService>((ref) {
  return TasksApiService(ref.watch(apiClientProvider));
});
