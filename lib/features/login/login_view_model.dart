import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/database_helper.dart';

class LoginViewModel extends ChangeNotifier {
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  String? _errorMessage;
  // Getters
  bool get isLoading => _isLoading;
  bool get obscurePassword => _obscurePassword;
  bool get rememberMe => _rememberMe;
  String? get errorMessage => _errorMessage;

  // إخفاء أو إظهار كلمة المرور
  void toggleObscurePassword() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  // تذكر تسجيل الدخول
  void setRememberMe(bool value) {
    _rememberMe = value;
    notifyListeners();
  }

  // منطق تسجيل الدخول
  Future<bool> login(String emailOrId, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. تسجيل الدخول باستخدام FirebaseAuth
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: emailOrId, password: password);

      final user = userCredential.user;
      if (user != null) {
        try {
          // 2. جلب بيانات المستخدم من Firestore
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (doc.exists && doc.data() != null) {
            final data = doc.data() as Map<String, dynamic>;

            // 3. حفظ البيانات في SharedPreferences
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('id', data['id']?.toString() ?? user.uid);
            await prefs.setString('name', data['name']?.toString() ?? '');
            await prefs.setString(
              'email',
              data['email']?.toString() ?? user.email ?? '',
            );
            await prefs.setString('role', data['role']?.toString() ?? '');
            await prefs.setString(
              'createAt',
              data['createAt']?.toString() ??
                  data['createdAt']?.toString() ??
                  '',
            );
            await prefs.setString(
              'acceptAt',
              data['acceptAt']?.toString() ??
                  data['acceptedAt']?.toString() ??
                  '',
            );
            await prefs.setBool('is_logged_in', _rememberMe);

            // 4. حفظ البيانات في قاعدة بيانات SQLite المحلية
            await DatabaseHelper.instance.saveUser({
              'id': data['id']?.toString() ?? user.uid,
              'name': data['name']?.toString() ?? '',
              'email': data['email']?.toString() ?? user.email ?? '',
              'role': data['role']?.toString() ?? 'طالب',
              'createAt':
                  data['createAt']?.toString() ??
                  data['createdAt']?.toString() ??
                  '',
              'acceptAt':
                  data['acceptAt']?.toString() ??
                  data['acceptedAt']?.toString() ??
                  '',
            });
          } else {
            // الحساب غير موجود في Firestore (تم حذفه من قبل الإدارة)
            await FirebaseAuth.instance.signOut();
            _isLoading = false;
            _errorMessage = 'هذا الحساب تم حذفه من قبل الإدارة ولم يعد موجوداً.';
            notifyListeners();
            return false;
          }
        } catch (dbError) {
          debugPrint('Error saving user data locally: $dbError');
          // لا نفشل عملية تسجيل الدخول بأكملها إذا فشلت الحماية المحلية الاحتياطية فقط
        }
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'حدث خطأ أثناء تسجيل الدخول';
      notifyListeners();
      return false;
    }
  }
}
