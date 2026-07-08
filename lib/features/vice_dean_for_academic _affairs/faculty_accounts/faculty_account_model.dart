class FacultyAccount {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? createAt;
  final int sync;

  FacultyAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.createAt,
    this.sync = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'createAt': createAt,
      'sync': sync,
    };
  }

  factory FacultyAccount.fromMap(Map<String, dynamic> map) {
    return FacultyAccount(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: map['role'] as String? ?? 'عضو هيئة تدريس',
      createAt: map['createAt'] as String? ?? map['createdAt'] as String?,
      sync: map['sync'] as int? ?? 1,
    );
  }
}
