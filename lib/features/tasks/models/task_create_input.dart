/// Payload for creating a task via [TasksNotifier.addTask].
class TaskCreateInput {
  const TaskCreateInput({
    required this.title,
    this.description,
    this.priority = 'medium',
    this.status = 'pending',
    this.dueDate,
    this.assignedTo,
  });

  final String title;
  final String? description;
  final String priority;
  final String status;
  final String? dueDate;
  final String? assignedTo;
}
