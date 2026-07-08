import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:student_attendance_system/core/database_helper.dart';

class FacultySignupViewModel extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSuccess = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isSuccess => _isSuccess;

  void resetState() {
    _isLoading = false;
    _errorMessage = null;
    _isSuccess = false;
    notifyListeners();
  }

  // تسجيل حساب عضو هيئة التدريس الفعلي
  Future<bool> registerFaculty({
    required String name,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _isSuccess = false;
    notifyListeners();

    try {
      // 1. التحقق من اتصال الإنترنت
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnection = connectivityResult.any((result) => result != ConnectivityResult.none);
      if (!hasConnection) {
        _errorMessage = 'عذراً، يجب توفر اتصال بالإنترنت لإكمال عملية التسجيل.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final formattedEmail = email.trim().toLowerCase();

      // 2. التحقق مما إذا كان البريد الإلكتروني مسجلاً مسبقاً في كولكشن faculty_accounts (مضاف من قبل النائب)
      final accountSnapshot = await FirebaseFirestore.instance
          .collection('faculty_accounts')
          .where('email', isEqualTo: formattedEmail)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 15));

      if (accountSnapshot.docs.isEmpty) {
        _errorMessage = 'عذراً، هذا البريد الإلكتروني غير مصرح له بالتسجيل كعضو هيئة تدريس. يرجى التواصل مع نائب العميد لإضافتك أولاً.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final accountDoc = accountSnapshot.docs.first;
      final accountData = accountDoc.data();
      final String department = accountData['department'] ?? 'غير محدد';
      final String role = accountData['role'] ?? 'عضو هيئة تدريس';

      // 3. التحقق مما إذا كان قد قام بالتسجيل مسبقاً في faculty_users
      final userSnapshot = await FirebaseFirestore.instance
          .collection('faculty_users')
          .where('email', isEqualTo: formattedEmail)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 15));

      if (userSnapshot.docs.isNotEmpty) {
        _errorMessage = 'هذا البريد الإلكتروني مسجل بالفعل كعضو هيئة تدريس نشط. يمكنك تسجيل الدخول مباشرة.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 4. إنشاء الحساب في Firebase Authentication
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: formattedEmail,
        password: password,
      );

      final String uid = userCredential.user!.uid;
      final String isoNow = DateTime.now().toIso8601String();

      // 5. حفظ البيانات في كولكشن faculty_users السحابية
      await FirebaseFirestore.instance.collection('faculty_users').doc(uid).set({
        'id': uid,
        'name': name.trim(),
        'email': formattedEmail,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
        'department': department,
      }).timeout(const Duration(seconds: 15));

      // 6. حفظ البيانات محلياً في SQLite بقاعدة بيانات التطبيق
      await DatabaseHelper.instance.saveFacultyUser({
        'id': uid,
        'name': name.trim(),
        'email': formattedEmail,
        'role': role,
        'createAt': isoNow,
        'acceptAt': isoNow,
        'department': department,
        'sync': 1,
      });

      _isLoading = false;
      _isSuccess = true;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      if (e.code == 'email-already-in-use') {
        _errorMessage = 'البريد الإلكتروني مستخدم بالفعل لحساب آخر.';
      } else if (e.code == 'weak-password') {
        _errorMessage = 'كلمة المرور ضعيفة جداً، يرجى إدخال 8 خانات على الأقل.';
      } else if (e.code == 'invalid-email') {
        _errorMessage = 'صيغة البريد الإلكتروني غير صحيحة.';
      } else {
        _errorMessage = 'خطأ في المصادقة: ${e.message}';
      }
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'حدث خطأ غير متوقع أثناء التسجيل: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
}
