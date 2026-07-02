import 'package:cloud_firestore/cloud_firestore.dart';

class RegistrationRequestModel {
  final String id; // رقم القيد أو الرقم الأكاديمي
  final String name; // الاسم الكامل
  final String email; // البريد الإلكتروني
  final String password; // كلمة المرور
  final String role; // الدور (طالب افتراضياً)
  final String state; // حالة الطلب
  final DateTime createdAt; // وقت إرسال الطلب
  final Map<String, dynamic>? stuInfo; // معلومات الطالب الإضافية (التخصص، المستوى، المسار)

  RegistrationRequestModel({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    required this.state,
    required this.createdAt,
    this.stuInfo,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'password': password,
      'role': role,
      'state': state,
      'createAt': Timestamp.fromDate(createdAt),
      'stu_info': stuInfo,
    };
  }

  factory RegistrationRequestModel.fromMap(Map<String, dynamic> map) {
    return RegistrationRequestModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      role: map['role'] ?? 'طالب',
      state: map['state'] ?? 'قيد المراجعة',
      createdAt: (map['createAt'] as Timestamp?)?.toDate() ??
          (map['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      stuInfo: map['stu_info'] != null
          ? Map<String, dynamic>.from(map['stu_info'])
          : null,
    );
  }
}
