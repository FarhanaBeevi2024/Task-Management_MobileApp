import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/widgets/app_snackbars.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/task_model.dart';
import '../providers/tasks_notifier.dart';
import '../providers/tasks_providers.dart';

class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({
    super.key,
    this.task,
  });

  final Task? task;

  bool get isEditing => task != null;

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _dueDateController; // YYYY-MM-DD

  String _priority = 'medium';
  String _status = 'pending';
  String _assignedTo = '';

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _titleController = TextEditingController(text: t?.title ?? '');
    _descriptionController = TextEditingController(text: t?.description ?? '');
    _priority = (t?.priority ?? 'medium').trim().isEmpty ? 'medium' : (t!.priority);
    _status = (t?.status ?? 'pending').trim().isEmpty ? 'pending' : (t!.status);
    _assignedTo = (t?.assigned_to ?? '').trim();

    final due = (t?.due_date ?? '').trim();
    final normalized = due.isEmpty ? '' : due.substring(0, due.length >= 10 ? 10 : due.length);
    _dueDateController = TextEditingController(text: normalized);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  String? _validateTitle(String? value) {
    final t = (value ?? '').trim();
    if (t.isEmpty) return 'Title is required';
    return null;
  }

  Future<void> _pickDueDate() async {
    if (_saving) return;
    DateTime? initial;
    final txt = _dueDateController.text.trim();
    if (txt.isNotEmpty) {
      initial = DateTime.tryParse(txt);
    }
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (!mounted) return;
    if (picked == null) return;
    final yyyy = picked.year.toString().padLeft(4, '0');
    final mm = picked.month.toString().padLeft(2, '0');
    final dd = picked.day.toString().padLeft(2, '0');
    setState(() => _dueDateController.text = '$yyyy-$mm-$dd');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final title = _titleController.text.trim();
    final description = _descriptionController.text;
    final dueDate = _dueDateController.text.trim();
    final assignedTo = _assignedTo.trim();

    try {
      final api = ref.read(tasksApiServiceProvider);
      if (widget.isEditing) {
        await api.updateTask(
          taskId: widget.task!.id,
          title: title,
          // React sends description always (can be empty string).
          description: description,
          priority: _priority,
          status: _status,
          // React sends null to clear.
          dueDate: dueDate.isEmpty ? null : dueDate,
          assignedTo: assignedTo.isEmpty ? null : assignedTo,
        );
      } else {
        await api.createTask(
          title: title,
          description: description,
          priority: _priority,
          status: _status,
          dueDate: dueDate.isEmpty ? null : dueDate,
          assignedTo: assignedTo.isEmpty ? null : assignedTo,
        );
      }

      // Web refreshes list after mutations; do the same.
      ref.invalidate(tasksNotifierProvider);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e, fallback: 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final currentUserAsync = ref.watch(currentUserProvider);

    final userRole = currentUserAsync.valueOrNull?.role ?? 'user';
    final isTeamLeader = userRole == 'team_leader';

    final usersAsync = isTeamLeader ? ref.watch(_usersProvider) : const AsyncValue.data(<_UserOption>[]);
    final isBusy = _saving || usersAsync.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Task' : 'Create New Task'),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  TextFormField(
                    controller: _titleController,
                    enabled: !isBusy,
                    decoration: const InputDecoration(
                      labelText: 'Title *',
                      hintText: 'Enter task title',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateTitle,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    enabled: !isBusy,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Enter task description',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    minLines: 4,
                    maxLines: 6,
                    textInputAction: TextInputAction.newline,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _priority,
                          decoration: const InputDecoration(
                            labelText: 'Priority',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'low', child: Text('Low')),
                            DropdownMenuItem(value: 'medium', child: Text('Medium')),
                            DropdownMenuItem(value: 'high', child: Text('High')),
                          ],
                          onChanged: isBusy ? null : (v) => setState(() => _priority = v ?? 'medium'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _status,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'pending', child: Text('Pending')),
                            DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                            DropdownMenuItem(value: 'completed', child: Text('Completed')),
                            DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                          ],
                          onChanged: isBusy ? null : (v) => setState(() => _status = v ?? 'pending'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _dueDateController,
                    enabled: !isBusy,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Due Date',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: isBusy ? null : _pickDueDate,
                        icon: const Icon(Icons.calendar_month_outlined),
                      ),
                    ),
                    onTap: isBusy ? null : _pickDueDate,
                  ),
                  const SizedBox(height: 16),
                  if (isTeamLeader) ...[
                    usersAsync.when(
                      loading: () => const Center(child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: CircularProgressIndicator(),
                      )),
                      error: (e, _) => Text(
                        'Could not load users for assignment: $e',
                        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error),
                      ),
                      data: (users) {
                        final items = [
                          const DropdownMenuItem(value: '', child: Text('Unassigned')),
                          ...users.map(
                            (u) => DropdownMenuItem(
                              value: u.id,
                              child: Text(u.label),
                            ),
                          ),
                        ];
                        return DropdownButtonFormField<String>(
                          value: _assignedTo,
                          decoration: const InputDecoration(
                            labelText: 'Assign To',
                            border: OutlineInputBorder(),
                          ),
                          items: items,
                          onChanged: isBusy ? null : (v) => setState(() => _assignedTo = v ?? ''),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            Material(
              elevation: 10,
              shadowColor: Colors.black26,
              color: scheme.surface,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: isBusy ? null : _save,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _saving
                          ? SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: scheme.onPrimary,
                              ),
                            )
                          : Text(widget.isEditing ? 'Update Task' : 'Create Task'),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserOption {
  const _UserOption({required this.id, required this.label});

  final String id;
  final String label;
}

/// Mirrors the React form behavior: team leaders can fetch `/api/users` for assignment.
final _usersProvider = FutureProvider<List<_UserOption>>((ref) async {
  final dio = ref.watch(apiClientProvider);
  final res = await dio.get<List<dynamic>>('/api/users');
  final list = res.data ?? [];
  return list
      .map((e) => Map<String, dynamic>.from(e as Map))
      .map((m) {
        final id = (m['user_id'] ?? m['id'] ?? '').toString();
        final email = (m['email'] ?? '').toString();
        return _UserOption(id: id, label: email.isNotEmpty ? email : id);
      })
      .where((u) => u.id.isNotEmpty)
      .toList(growable: false);
});

