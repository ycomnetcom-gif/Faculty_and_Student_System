class Department {
  final int? id;
  final String? firestoreId;
  final String name;
  final String headId;
  final String headName;
  final int sync;
  final String? createdAt; // ISO-8601 creation timestamp

  Department({
    this.id,
    this.firestoreId,
    required this.name,
    required this.headId,
    required this.headName,
    required this.sync,
    this.createdAt,
  });

  // تحويل الكائن إلى Map لتخزينه في SQLite
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (firestoreId != null) 'firestore_id': firestoreId,
      'name': name,
      'head_id': headId,
      'head_name': headName,
      'sync': sync,
      if (createdAt != null) 'created_at': createdAt,
    };
  }

  // إنشاء كائن من Map مسترجع من SQLite
  factory Department.fromMap(Map<String, dynamic> map) {
    return Department(
      id: map['id'] as int?,
      firestoreId: map['firestore_id'] as String?,
      name: map['name'] as String? ?? '',
      headId: map['head_id'] as String? ?? '',
      headName: map['head_name'] as String? ?? '',
      sync: map['sync'] as int? ?? 0,
      createdAt: map['created_at'] as String?,
    );
  }
}
