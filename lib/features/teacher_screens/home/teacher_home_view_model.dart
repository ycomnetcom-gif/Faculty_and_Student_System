import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_attendance_system/core/database_helper.dart';

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

  // جلب بيانات المستخدم المسجل دخوله من SharedPreferences مع وجود خط دفاع ثاني (الشبكة/Firestore) عند فقدان البيانات
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
      final prefs = await SharedPreferences.getInstance();
      String id = prefs.getString('id') ?? '';
      String name = prefs.getString('name') ?? '';
      String email = prefs.getString('email') ?? '';
      String role = prefs.getString('role') ?? '';
      String department = prefs.getString('department') ?? '';
      final userType = prefs.getString('user_type') ?? 'general';

      // إذا كانت البيانات الأساسية فارغة، نقوم بجلبها من Firestore وحفظها محلياً
      if (name.isEmpty || role.isEmpty || email.isEmpty) {
        debugPrint('SharedPreferences data is incomplete, loading from Firestore for type: $userType...');
        
        Map<String, dynamic>? data;
        if (userType == 'faculty') {
          final facultyDoc = await _firestore.collection('faculty_users').doc(currentUser.uid).get();
          if (facultyDoc.exists && facultyDoc.data() != null) {
            data = facultyDoc.data() as Map<String, dynamic>;
          }
        } else {
          final doc = await _firestore.collection('users').doc(currentUser.uid).get();
          if (doc.exists && doc.data() != null) {
            data = doc.data() as Map<String, dynamic>;
          }
        }

        if (data != null) {
          id = data['id']?.toString() ?? currentUser.uid;
          name = data['name']?.toString() ?? '';
          email = data['email']?.toString() ?? currentUser.email ?? '';
          role = data['role']?.toString() ?? '';
          department = data['department']?.toString() ?? 'غير محدد';

          await prefs.setString('id', id);
          await prefs.setString('name', name);
          await prefs.setString('email', email);
          await prefs.setString('role', role);
          await prefs.setString('department', department);
        }
      }

      if (id.isEmpty) id = currentUser.uid;
      if (name.isEmpty) name = currentUser.displayName ?? 'مستخدم غير معروف';
      if (email.isEmpty) email = currentUser.email ?? 'غير معروف';
      if (role.isEmpty) role = 'غير معروف';
      if (department.isEmpty) department = 'غير محدد';

      _profile = TeacherProfile(
        uid: id,
        name: name,
        email: email,
        department: department,
        academicTitle: role,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'حدث خطأ أثناء جلب بيانات المستخدم: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  // التحقق من وجود بيانات غير متزامنة في جميع الجداول قبل تسجيل الخروج
  Future<bool> hasUnsyncedData() async {
    try {
      final unsynced = await DatabaseHelper.instance.getUnsyncedUsers();
      if (unsynced.isNotEmpty) return true;
      final unsyncedFacultyUsers = await DatabaseHelper.instance.getUnsyncedFacultyUsers();
      if (unsyncedFacultyUsers.isNotEmpty) return true;
      final unsyncedFacultyAccounts = await DatabaseHelper.instance.getUnsyncedFacultyAccounts();
      if (unsyncedFacultyAccounts.isNotEmpty) return true;
      final unsyncedDepts = await DatabaseHelper.instance.getUnsyncedDepartments();
      if (unsyncedDepts.isNotEmpty) return true;
      final deletedDepts = await DatabaseHelper.instance.getDeletedDepartments();
      if (deletedDepts.isNotEmpty) return true;
      return false;
    } catch (e) {
      debugPrint('Error checking unsynced data: $e');
      return false;
    }
  }

  // تسجيل الخروج
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
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
