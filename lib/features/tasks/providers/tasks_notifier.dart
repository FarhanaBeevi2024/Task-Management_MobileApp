import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task_create_input.dart';
import '../models/task_model.dart';
import 'tasks_providers.dart';

/// Task list + mutations (fetch, add, update status, delete).
final tasksNotifierProvider =
    AsyncNotifierProvider<TasksNotifier, List<Task>>(TasksNotifier.new);

class TasksNotifier extends AsyncNotifier<List<Task>> {
  @override
  Future<List<Task>> build() async {
    final api = ref.watch(tasksApiServiceProvider);
    return api.fetchTasks();
  }

  /// Reload tasks from the server (pull-to-refresh, retry).
  Future<void> refresh() async {
    final previous = state;
    state = await AsyncValue.guard(() {
      return ref.read(tasksApiServiceProvider).fetchTasks();
    });
    if (state.hasError && previous.hasValue) {
      state = previous;
    }
  }

  /// `POST /api/tasks` then reloads the list.
  Future<void> addTask(TaskCreateInput input) async {
    await _mutate(() async {
      final api = ref.read(tasksApiServiceProvider);
      await api.createTask(
        title: input.title,
        description: input.description,
        priority: input.priority,
        status: input.status,
        dueDate: input.dueDate,
        assignedTo: input.assignedTo,
      );
      return api.fetchTasks();
    });
  }

  /// `PUT /api/tasks/:id` with `{ status }` then reloads the list.
  Future<void> updateTaskStatus({
    required String taskId,
    required String status,
  }) async {
    await _mutate(() async {
      final api = ref.read(tasksApiServiceProvider);
      await api.updateTaskStatus(taskId: taskId, status: status);
      return api.fetchTasks();
    });
  }

  /// `DELETE /api/tasks/:id` then reloads the list.
  Future<void> deleteTask(String taskId) async {
    await _mutate(() async {
      final api = ref.read(tasksApiServiceProvider);
      await api.deleteTask(taskId);
      return api.fetchTasks();
    });
  }

  /// Runs [run], sets data from returned list; on failure restores prior [AsyncValue] if it had data.
  Future<void> _mutate(Future<List<Task>> Function() run) async {
    final previous = state;
    try {
      final next = await run();
      state = AsyncValue.data(next);
    } catch (e, st) {
      if (previous.hasValue) {
        state = previous;
      } else {
        state = AsyncValue.error(e, st);
      }
      rethrow;
    }
  }
}
