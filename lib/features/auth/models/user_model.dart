/// Mirrors `GET /api/user` (adjust fields to match your backend JSON).
class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    this.role = 'user',
    this.firstName,
    this.lastName,
  });

  final String id;
  final String email;
  final String role;
  final String? firstName;
  final String? lastName;

  /// Full name when first/last exist; otherwise falls back to [email].
  String get displayName {
    final fn = firstName?.trim() ?? '';
    final ln = lastName?.trim() ?? '';
    if (fn.isEmpty && ln.isEmpty) return email;
    if (fn.isEmpty) return ln;
    if (ln.isEmpty) return fn;
    return '$fn $ln';
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'user',
      firstName: json['first_name']?.toString(),
      lastName: json['last_name']?.toString(),
    );
  }
}
