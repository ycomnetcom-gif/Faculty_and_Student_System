import 'dart:convert';

/// نموذج بيانات تعيين مادة دراسية بمعلمها ومجموعاتها الطلابية والقاعة الدراسية.
/// يستخدم حقل [syncStatus] لتتبع حالة المزامنة مع Firestore:
///   0 = غير مزامن (محلي فقط)
///   1 = مزامن
class CourseAssignmentModel {
  /// معرف فريد من نوع UUID
  final String id;

  /// اسم المادة الدراسية كما وردت في ملف CSV
  final String subjectName;

  /// معرف المعلم المسؤول عن المادة (uid من جدول faculty_users)
  final String teacherUid;

  /// قائمة المجموعات الطلابية المرتبطة بالمادة
  final List<String> studentGroups;

  /// القاعة الدراسية
  final String room;

  /// حالة المزامنة: 0 = معلق، 1 = مزامن
  final int syncStatus;

  const CourseAssignmentModel({
    required this.id,
    required this.subjectName,
    required this.teacherUid,
    required this.studentGroups,
    required this.room,
    this.syncStatus = 0,
  });

  // ---------------------------------------------------------------------------
  // SQLite serialisation
  // ---------------------------------------------------------------------------

  /// تحويل النموذج إلى Map قابل للحفظ في SQLite.
  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'subject_name': subjectName,
      'teacher_uid': teacherUid,
      'student_groups': jsonEncode(studentGroups),
      'room': room,
      'sync_status': syncStatus,
    };
  }

  /// إنشاء نموذج من Map مسترجع من SQLite مع فك تشفير JSON لقائمة المجموعات.
  factory CourseAssignmentModel.fromSqliteMap(Map<String, dynamic> map) {
    List<String> groups = [];
    final dynamic raw = map['student_groups'];
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          groups = decoded.cast<String>();
        }
      } catch (_) {}
    }

    return CourseAssignmentModel(
      id: map['id'] as String? ?? '',
      subjectName: map['subject_name'] as String? ?? '',
      teacherUid: map['teacher_uid'] as String? ?? '',
      studentGroups: groups,
      room: map['room'] as String? ?? '',
      syncStatus: map['sync_status'] as int? ?? 0,
    );
  }

  // ---------------------------------------------------------------------------
  // Firestore serialisation
  // ---------------------------------------------------------------------------

  /// تحويل النموذج إلى Map لرفعه إلى Firestore.
  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'subject_name': subjectName,
      'teacher_uid': teacherUid,
      'student_groups': studentGroups,
      'room': room,
    };
  }

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------

  CourseAssignmentModel copyWith({
    String? id,
    String? subjectName,
    String? teacherUid,
    List<String>? studentGroups,
    String? room,
    int? syncStatus,
  }) {
    return CourseAssignmentModel(
      id: id ?? this.id,
      subjectName: subjectName ?? this.subjectName,
      teacherUid: teacherUid ?? this.teacherUid,
      studentGroups: studentGroups ?? this.studentGroups,
      room: room ?? this.room,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  String toString() =>
      'CourseAssignmentModel(id: $id, subject: $subjectName, teacher: $teacherUid, groups: $studentGroups, room: $room, sync: $syncStatus)';
}
