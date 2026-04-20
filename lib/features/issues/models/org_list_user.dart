/// Row from `GET /api/users` (assignee picker).
class OrgListUser {
  const OrgListUser({
    required this.userId,
    required this.email,
    this.role,
  });

  final String userId;
  final String email;
  final String? role;

  factory OrgListUser.fromJson(Map<String, dynamic> json) {
    return OrgListUser(
      userId: json['user_id']?.toString() ?? '',
      email: json['email']?.toString() ?? 'Unknown',
      role: json['role']?.toString(),
    );
  }
}
