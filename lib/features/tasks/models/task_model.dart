/// Task entity aligned with the legacy web `Dashboard` (`/api/tasks`) contract.
///
/// This matches the React app field names/types exactly:
/// - `title`, `description`, `priority`, `status`, `due_date`, `assigned_to`
/// - server-managed: `id`, `created_by`, `created_at`, `updated_at`
///
/// Status values (web + backend): `pending`, `in_progress`, `completed`, `cancelled`.
/// Priority values (web): `low`, `medium`, `high`.
class Task {
  const Task({
    required this.id,
    required this.title,
    this.description,
    required this.priority,
    required this.status,
    this.due_date,
    required this.assigned_to,
    required this.created_by,
    required this.created_at,
    required this.updated_at,
  });

  final String id;
  final String title;
  final String? description;

  /// `low` | `medium` | `high`
  final String priority;

  /// `pending` | `in_progress` | `completed` | `cancelled`
  final String status;

  /// ISO string date/datetime or null (web sends YYYY-MM-DD, backend may store timestamp).
  final String? due_date;

  /// User id (nullable in UI, but backend defaults it to current user on create).
  final String? assigned_to;

  /// Creator user id.
  final String? created_by;

  /// ISO strings as returned by Supabase (`created_at`, `updated_at`).
  final String? created_at;
  final String? updated_at;

  factory Task.fromJson(Map<String, dynamic> json) {
    String? readNullableString(Object? v) {
      final s = v?.toString();
      if (s == null) return null;
      final t = s.trim();
      return t.isEmpty ? null : t;
    }

    String readString(Object? v, {String fallback = ''}) {
      final s = v?.toString();
      if (s == null) return fallback;
      final t = s.trim();
      return t.isEmpty ? fallback : t;
    }

    return Task(
      id: readString(json['id']),
      title: readString(json['title']),
      description: readNullableString(json['description']),
      priority: readString(json['priority'], fallback: 'medium'),
      status: readString(json['status'], fallback: 'pending'),
      due_date: readNullableString(json['due_date'] ?? json['dueDate']),
      assigned_to: readNullableString(json['assigned_to'] ?? json['assignedTo']),
      created_by: readNullableString(json['created_by'] ?? json['createdBy']),
      created_at: readNullableString(json['created_at'] ?? json['createdAt']),
      updated_at: readNullableString(json['updated_at'] ?? json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'priority': priority,
      'status': status,
      'due_date': due_date,
      'assigned_to': assigned_to,
      'created_by': created_by,
      'created_at': created_at,
      'updated_at': updated_at,
    };
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    String? priority,
    String? status,
    String? due_date,
    String? assigned_to,
    String? created_by,
    String? created_at,
    String? updated_at,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      due_date: due_date ?? this.due_date,
      assigned_to: assigned_to ?? this.assigned_to,
      created_by: created_by ?? this.created_by,
      created_at: created_at ?? this.created_at,
      updated_at: updated_at ?? this.updated_at,
    );
  }
}
