import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:student_attendance_system/core/database_helper.dart';
import 'package:student_attendance_system/core/sync_service.dart';
import 'package:student_attendance_system/features/vice_dean_for_academic _affairs/faculty_accounts/faculty_account_model.dart';

class FacultyAccountsViewModel extends ChangeNotifier {
  List<FacultyAccount> _accounts = [];
  bool _isLoading = false;
  bool _isSaving = false;

  List<FacultyAccount> get accounts => _accounts;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;

  // جلب الحسابات المخزنة محلياً لأعضاء هيئة التدريس
  Future<void> loadAccounts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final localUsers = await DatabaseHelper.instance.getAllFacultyAccounts();
      _accounts = localUsers.map((map) => FacultyAccount.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error loading faculty accounts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // إنشاء حساب جديد لعضو هيئة تدريس وحفظه محلياً وعلى الفايربيس
  Future<String?> createFacultyAccount({
    required String name,
    required String email,
  }) async {
    _isSaving = true;
    notifyListeners();

    try {
      // 1. التحقق مما إذا كان الحساب مسجلاً مسبقاً محلياً
      final localUsers = await DatabaseHelper.instance.getAllFacultyAccounts();
      final duplicateLocal = localUsers.any((u) => (u['email'] as String).trim().toLowerCase() == email.trim().toLowerCase());
      if (duplicateLocal) {
        return 'هذا البريد الإلكتروني مسجل بالفعل في القائمة.';
      }

      final String id = 'fac_${DateTime.now().millisecondsSinceEpoch}';
      final String isoNow = DateTime.now().toIso8601String();

      // 2. التحقق من الاتصال بالإنترنت
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnection = connectivityResult.any((result) => result != ConnectivityResult.none);

      if (!hasConnection) {
        // حفظ في جدول faculty_accounts محلياً مع وضع sync = 0
        await DatabaseHelper.instance.saveFacultyAccount({
          'id': id,
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'role': 'عضو هيئة تدريس',
          'createAt': isoNow,
          'acceptAt': isoNow,
          'sync': 0,
        });
        await loadAccounts();
        return null; // نجاح العملية محلياً
      }

      // 3. حفظ بيانات المستخدم في Firestore كولكشن faculty_accounts مباشرة
      await FirebaseFirestore.instance.collection('faculty_accounts').doc(id).set({
        'id': id,
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'role': 'عضو هيئة تدريس',
        'createdAt': FieldValue.serverTimestamp(),
        'acceptAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 15));

      // 4. حفظ البيانات محلياً في SQLite بجدول faculty_accounts
      await DatabaseHelper.instance.saveFacultyAccount({
        'id': id,
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'role': 'عضو هيئة تدريس',
        'createAt': isoNow,
        'acceptAt': isoNow,
        'sync': 1,
      });

      // إعادة تحميل القائمة
      await loadAccounts();
      return null; // نجاح العملية
    } catch (e) {
      debugPrint('Error creating faculty account: $e');
      return 'حدث خطأ غير متوقع أثناء إنشاء الحساب: $e';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // حذف حساب عضو هيئة تدريس
  Future<String?> deleteFacultyAccount(String id) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. التحقق من الاتصال بالإنترنت للحذف من السيرفر
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnection = connectivityResult.any((result) => result != ConnectivityResult.none);

      if (!hasConnection) {
        // إذا كان الحساب غير مزامن، يمكن حذفه محلياً مباشرة
        final db = await DatabaseHelper.instance.database;
        final user = await db.query('faculty_accounts', where: 'id = ?', whereArgs: [id]);
        if (user.isNotEmpty && user.first['sync'] == 0) {
          await DatabaseHelper.instance.deleteFacultyAccount(id);
          await loadAccounts();
          return null;
        }
        return 'عذراً، يجب توفر اتصال بالإنترنت لحذف الحساب من السيرفر السحابي لمنع تعارض البيانات.';
      }

      // 2. حذف مستند المستخدم من Firestore كولكشن faculty_accounts
      await FirebaseFirestore.instance
          .collection('faculty_accounts')
          .doc(id)
          .delete()
          .timeout(const Duration(seconds: 15));

      // 3. حذف المستخدم من قاعدة البيانات المحلية SQLite جدول faculty_accounts
      await DatabaseHelper.instance.deleteFacultyAccount(id);

      // 4. تحديث القائمة المحلية
      await loadAccounts();
      return null; // نجاح العملية
    } catch (e) {
      debugPrint('Error deleting faculty account: $e');
      return 'حدث خطأ أثناء محاولة حذف الحساب: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // مزامنة الحسابات من Firestore للتحديث
  Future<bool> syncAccountsFromFirestore() async {
    _isLoading = true;
    notifyListeners();

    final connectivityResult = await Connectivity().checkConnectivity();
    final hasConnection = connectivityResult.any((result) => result != ConnectivityResult.none);

    if (!hasConnection) {
      _isLoading = false;
      notifyListeners();
      return false;
    }

    try {
      // 1. رفع أي تعديلات محلية معلقة
      await SyncService.instance.triggerSync();

      // 2. جلب وتحديث الحسابات من السيرفر
      final snapshot = await FirebaseFirestore.instance
          .collection('faculty_accounts')
          .get()
          .timeout(const Duration(seconds: 10));

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final dynamic firestoreCreatedAt = data['createdAt'];
        String? createdAtStr;
        if (firestoreCreatedAt is Timestamp) {
          createdAtStr = firestoreCreatedAt.toDate().toIso8601String();
        }

        await DatabaseHelper.instance.saveFacultyAccount({
          'id': doc.id,
          'name': data['name'] ?? '',
          'email': data['email'] ?? '',
          'role': 'عضو هيئة تدريس',
          'createAt': createdAtStr ?? DateTime.now().toIso8601String(),
          'acceptAt': createdAtStr ?? DateTime.now().toIso8601String(),
          'sync': 1,
        });
      }
      await loadAccounts();
      return true;
    } catch (e) {
      debugPrint('Error syncing faculty accounts: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
