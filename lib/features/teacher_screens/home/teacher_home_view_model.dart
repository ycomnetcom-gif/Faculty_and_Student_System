import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TeacherProfile {
  final String uid;
  final String name;
  final String email;
  final String department;
  final String academicTitle;

  TeacherProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.department,
    required this.academicTitle,
  });

  factory TeacherProfile.fromMap(
    Map<String, dynamic> map,
    String uid,
    String defaultEmail,
  ) {
    return TeacherProfile(
      uid: uid,
      name: map['name'] ?? 'مستخدم غير معروف',
      email: map['email'] ?? defaultEmail,
      department: map['department'] ?? 'غير محدد',
      academicTitle: map['academicTitle'] ?? map['role'] ?? 'غير معروف',
    );
  }
}

class TeacherHomeViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String? _errorMessage;
  TeacherProfile? _profile;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  TeacherProfile? get profile => _profile;

  // جلب بيانات المستخدم المسجل دخوله
  Future<void> fetchTeacherProfile() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _errorMessage = 'لم يتم العثور على مستخدم نشط';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. جلب مستند المستخدم مباشرة من كولكشن users بناءً على الـ uid الخاص بالحساب
      final doc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        _profile = TeacherProfile.fromMap(
          doc.data() as Map<String, dynamic>,
          currentUser.uid,
          currentUser.email ?? '',
        );
      } else {
        // 3. في حال عدم وجود مستند للمستخدم في الكولكشنز، يتم توليد بروفايل مؤقت بالبيانات الأساسية للحساب
        _profile = TeacherProfile(
          uid: currentUser.uid,
          name: currentUser.displayName ?? 'غير معروف',
          email: currentUser.email ?? 'غير معروف',
          department: 'غير معروف',
          academicTitle: 'غير معروف',
        );
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'حدث خطأ أثناء جلب بيانات المستخدم: ${e.toString()}';
      // تعيين بروفايل افتراضي حتى لا تتعطل الواجهة للمستخدم
      _profile = TeacherProfile(
        uid: currentUser.uid,
        name: currentUser.displayName ?? 'غير معروف',
        email: currentUser.email ?? 'غير معروف',
        department: 'غير معروف',
        academicTitle: 'غير معروف',
      );
      _isLoading = false;
      notifyListeners();
    }
  }

  // تسجيل الخروج
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _auth.signOut();
      _profile = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'حدث خطأ أثناء تسجيل الخروج';
      notifyListeners();
    }
  }
}
