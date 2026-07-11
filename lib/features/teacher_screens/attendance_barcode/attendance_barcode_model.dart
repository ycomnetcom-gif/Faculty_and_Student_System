import 'dart:convert';

/// نموذج بيانات المادة الدراسية المرتبطة بمعلم لاستخدامها في شاشة باركود التحضير.
class AttendanceCourseModel {
  /// معرف التعيين من جدول course_assignments
  final String id;

  /// اسم المادة الدراسية
  final String subjectName;

  /// قائمة المجموعات الطلابية المسندة لهذه المادة
  final List<String> studentGroups;

  const AttendanceCourseModel({
    required this.id,
    required this.subjectName,
    required this.studentGroups,
  });

  /// إنشاء نموذج من صف SQLite
  factory AttendanceCourseModel.fromSqliteRow(Map<String, dynamic> row) {
    List<String> groups = [];
    final dynamic rawGroups = row['student_groups'];
    if (rawGroups is String && rawGroups.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawGroups);
        if (decoded is List) {
          groups = decoded.cast<String>();
        }
      } catch (_) {}
    }
    return AttendanceCourseModel(
      id: row['id'] as String? ?? '',
      subjectName: row['subject_name'] as String? ?? 'مادة غير معروفة',
      studentGroups: groups,
    );
  }

  @override
  String toString() =>
      'AttendanceCourseModel(id: $id, subject: $subjectName, groups: $studentGroups)';
}

/// نموذج بيانات الحمولة (Payload) المشفرة داخل رمز QR.
/// يحتوي على كل ما يلزم للتحقق من صحة تسجيل الحضور.
class QrPayloadModel {
  /// معرف التعيين (course_assignments.id)
  final String courseId;

  /// اسم المادة الدراسية
  final String subjectName;

  /// المجموعة الطلابية المحددة
  final String group;

  /// معرف المعلم (firebase uid)
  final String teacherId;

  /// الوقت الذي تم فيه توليد الباركود (millisecondsSinceEpoch)
  final int timestamp;

  /// خط العرض (GPS) للمعلم وقت توليد الباركود
  final double latitude;

  /// خط الطول (GPS) للمعلم وقت توليد الباركود
  final double longitude;

  /// دقة الموقع الجغرافي بالمتر
  final double locationAccuracy;

  /// اسم جهاز بلوتوث المعلم — يستخدمه الطالب للتحقق من قربه
  final String btDeviceName;

  const QrPayloadModel({
    required this.courseId,
    required this.subjectName,
    required this.group,
    required this.teacherId,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.locationAccuracy,
    required this.btDeviceName,
  });

  /// تحويل إلى Map للتشفير لاحقاً
  Map<String, dynamic> toMap() => {
        'course_id': courseId,
        'subject': subjectName,
        'group': group,
        'teacher_id': teacherId,
        'time': timestamp,
        'lat': latitude,
        'lng': longitude,
        'acc': locationAccuracy,
        'bt': btDeviceName,
      };

  /// تحويل إلى JSON String جاهز للتشفير
  String toJson() => jsonEncode(toMap());

  /// إنشاء من Map (لفك التشفير لاحقاً عند مسح الباركود)
  factory QrPayloadModel.fromMap(Map<String, dynamic> map) {
    return QrPayloadModel(
      courseId: map['course_id'] as String? ?? '',
      subjectName: map['subject'] as String? ?? '',
      group: map['group'] as String? ?? '',
      teacherId: map['teacher_id'] as String? ?? '',
      timestamp: map['time'] as int? ?? 0,
      latitude: (map['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['lng'] as num?)?.toDouble() ?? 0.0,
      locationAccuracy: (map['acc'] as num?)?.toDouble() ?? 0.0,
      btDeviceName: map['bt'] as String? ?? '',
    );
  }

  @override
  String toString() =>
      'QrPayloadModel(course: $courseId, group: $group, teacher: $teacherId, time: $timestamp, lat: $latitude, lng: $longitude, bt: $btDeviceName)';
}

