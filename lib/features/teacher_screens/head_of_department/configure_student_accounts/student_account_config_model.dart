class StudentAccountConfigModel {
  final String registrationId; // رقم القيد
  final String studentName; // اسم الطالب
  final String email; // البريد الإلكتروني
  final String department; // التخصص
  final String level; // المستوى
  final String track; // المسار
  final int syncStatus; // حالة المزامنة: 0 للعمل أوفلاين، 1 للمزامنة

  StudentAccountConfigModel({
    required this.registrationId,
    required this.studentName,
    required this.email,
    required this.department,
    required this.level,
    required this.track,
    this.syncStatus = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'registration_id': registrationId,
      'student_name': studentName,
      'email': email,
      'department': department,
      'level': level,
      'track': track,
      'sync': syncStatus,
    };
  }

  factory StudentAccountConfigModel.fromMap(Map<String, dynamic> map) {
    return StudentAccountConfigModel(
      registrationId: map['registration_id'] ?? '',
      studentName: map['student_name'] ?? '',
      email: map['email'] ?? '',
      department: map['department'] ?? '',
      level: map['level'] ?? '',
      track: map['track'] ?? '',
      syncStatus: map['sync'] ?? 0,
    );
  }
}
