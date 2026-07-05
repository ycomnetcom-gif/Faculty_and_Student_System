class HeadAccount {
  final String id; // Represents the Firebase Auth UID
  final String name;
  final String email;
  final String role;
  final String? createAt;

  HeadAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.createAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'createAt': createAt,
    };
  }

  factory HeadAccount.fromMap(Map<String, dynamic> map) {
    return HeadAccount(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: map['role'] as String? ?? 'رئيس قسم',
      createAt: map['createAt'] as String? ?? map['createdAt'] as String?,
    );
  }
}
