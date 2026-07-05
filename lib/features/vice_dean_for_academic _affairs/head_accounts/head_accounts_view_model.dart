import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:student_attendance_system/core/database_helper.dart';
import 'package:student_attendance_system/core/sync_service.dart';
import 'package:student_attendance_system/features/vice_dean_for_academic _affairs/head_accounts/head_account_model.dart';

class HeadAccountsViewModel extends ChangeNotifier {
  List<HeadAccount> _accounts = [];
  bool _isLoading = false;
  bool _isSaving = false;

  List<HeadAccount> get accounts => _accounts;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;

  // جلب الحسابات المخزنة محلياً لرؤساء الأقسام
  Future<void> loadAccounts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final localUsers = await DatabaseHelper.instance.getUsersByRole('رئيس قسم');
      _accounts = localUsers.map((map) => HeadAccount.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error loading head accounts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // إنشاء حساب جديد لرئيس القسم
  Future<String?> createHeadAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    _isSaving = true;
    notifyListeners();

    String? tempAppName;
    FirebaseApp? tempApp;

    try {
      // 1. التحقق من الاتصال بالإنترنت
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnection = connectivityResult.any((result) => result != ConnectivityResult.none);

      if (!hasConnection) {
        return 'عذراً، يجب توفر اتصال بالإنترنت لإنشاء حساب رئيس قسم في نظام التحقق السحابي.';
      }

      // 2. إنشاء الحساب في Firebase Authentication باستخدام تطبيق مؤقت لتجنب تسجيل الخروج للحساب الحالي
      tempAppName = 'temp_head_auth_${DateTime.now().millisecondsSinceEpoch}';
      tempApp = await Firebase.initializeApp(
        name: tempAppName,
        options: Firebase.app().options,
      );

      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      final userCredential = await tempAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final String newUid = userCredential.user!.uid;
      final String isoNow = DateTime.now().toIso8601String();

      // 3. حفظ بيانات المستخدم في Firestore
      await FirebaseFirestore.instance.collection('users').doc(newUid).set({
        'id': newUid,
        'name': name.trim(),
        'email': email.trim(),
        'role': 'رئيس قسم',
        'createdAt': FieldValue.serverTimestamp(),
        'acceptAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 15));

      // 4. حفظ البيانات محلياً في SQLite
      await DatabaseHelper.instance.saveUser({
        'id': newUid,
        'name': name.trim(),
        'email': email.trim(),
        'role': 'رئيس قسم',
        'createAt': isoNow,
        'acceptAt': isoNow,
        'sync': 1,
      });

      // إعادة تحميل القائمة
      await loadAccounts();
      return null; // نجاح العملية
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return 'هذا البريد الإلكتروني مستخدم بالفعل لحساب آخر.';
      } else if (e.code == 'weak-password') {
        return 'كلمة المرور ضعيفة جداً، يرجى كتابة 8 أحرف/أرقام على الأقل.';
      } else if (e.code == 'invalid-email') {
        return 'صيغة البريد الإلكتروني غير صحيحة.';
      }
      return 'خطأ في المصادقة: ${e.message}';
    } catch (e) {
      debugPrint('Error creating head account: $e');
      return 'حدث خطأ غير متوقع أثناء إنشاء الحساب: $e';
    } finally {
      // تنظيف التطبيق المؤقت
      if (tempApp != null) {
        try {
          await tempApp.delete();
        } catch (e) {
          debugPrint('Error deleting temp app: $e');
        }
      }
      _isSaving = false;
      notifyListeners();
    }
  }

  // حذف حساب رئيس قسم
  Future<String?> deleteHeadAccount(String id) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. التحقق من الاتصال بالإنترنت للحذف من السيرفر
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnection = connectivityResult.any((result) => result != ConnectivityResult.none);

      if (!hasConnection) {
        return 'عذراً، يجب توفر اتصال بالإنترنت لحذف الحساب من السيرفر السحابي لمنع تعارض البيانات.';
      }

      // 2. حذف مستند المستخدم من Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(id)
          .delete()
          .timeout(const Duration(seconds: 15));

      // 3. حذف المستخدم من قاعدة البيانات المحلية SQLite
      await DatabaseHelper.instance.deleteUser(id);

      // 4. تحديث القائمة المحلية
      await loadAccounts();
      return null; // نجاح العملية
    } catch (e) {
      debugPrint('Error deleting head account: $e');
      return 'حدث خطأ أثناء محاولة حذف الحساب: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // مزامنة الحسابات من Firestore للتحديث
  Future<void> syncAccountsFromFirestore() async {
    _isLoading = true;
    notifyListeners();

    final connectivityResult = await Connectivity().checkConnectivity();
    final hasConnection = connectivityResult.any((result) => result != ConnectivityResult.none);

    if (!hasConnection) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      // 1. رفع أي تعديلات محلية معلقة (مثل مستخدمين مضافين sync = 0)
      await SyncService.instance.triggerSync();

      // 2. جلب وتحديث الحسابات من السيرفر
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'رئيس قسم')
          .get()
          .timeout(const Duration(seconds: 10));

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final dynamic firestoreCreatedAt = data['createdAt'];
        String? createdAtStr;
        if (firestoreCreatedAt is Timestamp) {
          createdAtStr = firestoreCreatedAt.toDate().toIso8601String();
        }

        await DatabaseHelper.instance.saveUser({
          'id': doc.id,
          'name': data['name'] ?? '',
          'email': data['email'] ?? '',
          'role': 'رئيس قسم',
          'createAt': createdAtStr ?? DateTime.now().toIso8601String(),
          'acceptAt': createdAtStr ?? DateTime.now().toIso8601String(),
          'sync': 1,
        });
      }
      await loadAccounts();
    } catch (e) {
      debugPrint('Error syncing head accounts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
