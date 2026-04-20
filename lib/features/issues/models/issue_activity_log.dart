/// One row from `GET /api/jira/issues/:id/activity-logs` (web `IssueDetail` history).
class IssueActivityLog {
  const IssueActivityLog({
    required this.id,
    required this.actionType,
    this.fieldName,
    this.oldValue,
    this.newValue,
    this.performedAt,
    this.performedByEmail,
  });

  final String id;
  final String actionType;
  final String? fieldName;
  final String? oldValue;
  final String? newValue;
  final DateTime? performedAt;
  final String? performedByEmail;

  factory IssueActivityLog.fromJson(Map<String, dynamic> json) {
    DateTime? at;
    final rawAt = json['performed_at'];
    if (rawAt != null) {
      at = DateTime.tryParse(rawAt.toString());
    }
    return IssueActivityLog(
      id: json['id']?.toString() ?? '',
      actionType: json['action_type']?.toString() ?? 'UPDATE',
      fieldName: json['field_name'] as String?,
      oldValue: json['old_value']?.toString(),
      newValue: json['new_value']?.toString(),
      performedAt: at,
      performedByEmail: json['performed_by_email'] as String?,
    );
  }

  /// Human-readable line (matches web `formatActivityMessage`).
  String get displayMessage {
    final email = performedByEmail;
    final name = (email != null && email.isNotEmpty) ? email.split('@').first : 'Someone';

    String cap(String? s) {
      if (s == null || s.isEmpty) return '—';
      final t = s.replaceAll('_', ' ');
      return t[0].toUpperCase() + t.substring(1);
    }

    String fmt(String? v) {
      if (v == null || v.isEmpty) return '—';
      return v;
    }

    switch (actionType) {
      case 'CREATE':
        return '$name created this issue';
      case 'STATUS_CHANGE':
        return "$name changed status from '${cap(oldValue)}' to '${cap(newValue)}'";
      case 'PRIORITY_CHANGE':
        final which = fieldName == 'client_priority' ? 'client priority' : 'priority';
        return "$name changed $which from '${fmt(oldValue)}' to '${fmt(newValue)}'";
      case 'ASSIGNMENT_CHANGE':
        return '$name changed assignee';
      case 'DUE_DATE_CHANGE':
        return "$name changed due date from '${fmt(oldValue)}' to '${fmt(newValue)}'";
      case 'MILESTONE_CHANGE':
        return '$name changed milestone';
      case 'SUMMARY_CHANGE':
        return '$name updated summary';
      case 'DESCRIPTION_CHANGE':
        return '$name updated description';
      case 'UPDATE':
        if (fieldName == 'workflow_status') {
          return "$name changed workflow status from '${fmt(oldValue)}' to '${fmt(newValue)}'";
        }
        return "$name updated ${fieldName ?? 'field'} from '${fmt(oldValue)}' to '${fmt(newValue)}'";
      case 'COMMENT_ADDED':
        return '$name added a comment';
      case 'DELETE':
        return '$name deleted this issue';
      default:
        return "$name updated ${fieldName ?? 'field'} from '${fmt(oldValue)}' to '${fmt(newValue)}'";
    }
  }

  /// Matches web `formatActivityDate` (local clock).
  String get displayDateSuffix {
    final d = performedAt;
    if (d == null) return '';
    final local = d.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final day = local.day.toString().padLeft(2, '0');
    final month = months[local.month - 1];
    final year = local.year;
    var hours = local.hour;
    final mins = local.minute.toString().padLeft(2, '0');
    final ampm = hours >= 12 ? 'PM' : 'AM';
    hours = hours % 12;
    if (hours == 0) hours = 12;
    return '$day $month $year, $hours:$mins $ampm';
  }
}
