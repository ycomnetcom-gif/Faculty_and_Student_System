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
  Future<bool> login(String emailOrId, String password, {required String userType}) async {
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
          Map<String, dynamic>? data;

          if (userType == 'faculty') {
            // جلب البيانات من كولكشن أعضاء هيئة التدريس
            final facultyDoc = await FirebaseFirestore.instance
                .collection('faculty_users')
                .doc(user.uid)
                .get();
            if (facultyDoc.exists && facultyDoc.data() != null) {
              data = facultyDoc.data() as Map<String, dynamic>;
            } else {
              _errorMessage = 'عذراً، لم يتم العثور على حسابك في كولكشن أعضاء هيئة التدريس.';
            }
          } else {
            // جلب البيانات من كولكشن المستخدمين العام
            final doc = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
            if (doc.exists && doc.data() != null) {
              data = doc.data() as Map<String, dynamic>;
            } else {
              _errorMessage = 'عذراً، لم يتم العثور على حسابك في كولكشن المستخدمين العام.';
            }
          }

          if (data != null) {
            // 3. حفظ البيانات في SharedPreferences
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('id', data['id']?.toString() ?? user.uid);
            await prefs.setString('name', data['name']?.toString() ?? '');
            await prefs.setString(
              'email',
              data['email']?.toString() ?? user.email ?? '',
            );
            await prefs.setString('role', data['role']?.toString() ?? '');
            await prefs.setString('user_type', userType);
            await prefs.setString(
              'department',
              data['department']?.toString() ?? 'غير محدد',
            );
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

            // 4. حفظ البيانات في قاعدة بيانات SQLite المحلية حسب الدور
            final role = data['role']?.toString() ?? 'طالب';
            if (role == 'عضو هيئة تدريس' || role == 'رئيس قسم') {
              await DatabaseHelper.instance.saveFacultyUser({
                'id': data['id']?.toString() ?? user.uid,
                'name': data['name']?.toString() ?? '',
                'email': data['email']?.toString() ?? user.email ?? '',
                'role': role,
                'createAt': data['createAt']?.toString() ?? data['createdAt']?.toString() ?? '',
                'acceptAt': data['acceptAt']?.toString() ?? data['acceptedAt']?.toString() ?? '',
                'department': data['department']?.toString() ?? 'غير محدد',
                'sync': 1,
              });
            } else {
              await DatabaseHelper.instance.saveUser({
                'id': data['id']?.toString() ?? user.uid,
                'name': data['name']?.toString() ?? '',
                'email': data['email']?.toString() ?? user.email ?? '',
                'role': role,
                'createAt': data['createAt']?.toString() ?? data['createdAt']?.toString() ?? '',
                'acceptAt': data['acceptAt']?.toString() ?? data['acceptedAt']?.toString() ?? '',
                'sync': 1,
              });
            }
          } else {
            // الحساب غير موجود في الكولكشن المحددة
            await FirebaseAuth.instance.signOut();
            _isLoading = false;
            _errorMessage ??= 'هذا الحساب غير متوفر للدور المحدد.';
            notifyListeners();
            return false;
          }
        } catch (dbError) {
          debugPrint('Error saving user data locally: $dbError');
        }
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      if (e.code == 'user-not-found') {
        _errorMessage = 'البريد الإلكتروني غير مسجل.';
      } else if (e.code == 'wrong-password') {
        _errorMessage = 'كلمة المرور غير صحيحة.';
      } else {
        _errorMessage = 'فشل تسجيل الدخول: ${e.message}';
      }
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'حدث خطأ أثناء تسجيل الدخول: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
}
