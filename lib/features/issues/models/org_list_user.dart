/// Row from `GET /api/users` (assignee picker, add-member dropdown).
class OrgListUser {
  const OrgListUser({
    required this.userId,
    required this.email,
    this.role,
    this.firstName,
    this.lastName,
  });

  final String userId;
  final String email;
  final String? role;
  final String? firstName;
  final String? lastName;

  /// Shown in pickers: full name when set, else part before @ in email.
  String get displayLabel {
    final fn = firstName?.trim() ?? '';
    final ln = lastName?.trim() ?? '';
    final full = '$fn $ln'.trim();
    if (full.isNotEmpty) return full;
    final e = email.trim();
    if (e.contains('@')) return e.split('@').first;
    return e.isEmpty ? 'Unknown' : e;
  }

  factory OrgListUser.fromJson(Map<String, dynamic> json) {
    return OrgListUser(
      userId: json['user_id']?.toString() ?? '',
      email: json['email']?.toString() ?? 'Unknown',
      role: json['role']?.toString(),
      firstName: json['first_name']?.toString(),
      lastName: json['last_name']?.toString(),
    );
  }
}
