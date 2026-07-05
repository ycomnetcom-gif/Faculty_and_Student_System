import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:student_attendance_system/core/database_helper.dart';
import 'package:student_attendance_system/core/sync_service.dart';
import 'package:student_attendance_system/features/vice_dean_for_academic _affairs/departments/department_model.dart';

class AppUser {
  final String id;
  final String name;
  final String email;
  final String role;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });
}

class DepartmentsViewModel extends ChangeNotifier {
  List<AppUser> _users = [];
  AppUser? _selectedUser;
  List<Department> _departments = [];
  Department? _editingDepartment;
  bool _isLoading = false;
  bool _isSaving = false;

  // Getters
  List<AppUser> get users => _users;
  AppUser? get selectedUser => _selectedUser;
  List<Department> get departments => _departments;
  Department? get editingDepartment => _editingDepartment;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;

  void setSelectedUser(AppUser? user) {
    _selectedUser = user;
    notifyListeners();
  }

  void setEditingDepartment(Department? dept) {
    _editingDepartment = dept;
    if (dept != null) {
      // ملء المستخدم المختار تلقائياً بناءً على رئيس القسم الحالي
      final matchedUser = _users.firstWhere(
        (u) => u.id == dept.headId,
        orElse: () => AppUser(id: dept.headId, name: dept.headName, email: '', role: ''),
      );
      _selectedUser = matchedUser;
    } else {
      _selectedUser = null;
    }
    notifyListeners();
  }

  // تحميل الأقسام والمستخدمين من SQLite مباشرة
  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. تحميل الأقسام من SQLite وتحويلها إلى كائنات Department
      final localDepts = await DatabaseHelper.instance.getAllDepartments();
      _departments = localDepts.map((d) => Department.fromMap(d)).toList();

      // 2. تحميل المستخدمين من SQLite مباشرة
      final db = await DatabaseHelper.instance.database;
      final localUsers = await db.query('users', where: "role != 'طالب'");
      _users = localUsers.map((u) {
        return AppUser(
          id: u['id']?.toString() ?? '',
          name: u['name']?.toString() ?? 'غير معروف',
          email: u['email']?.toString() ?? '',
          role: u['role']?.toString() ?? 'مدرس',
        );
      }).toList();
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // إضافة أو تعديل قسم
  Future<String?> saveDepartment({
    required String deptName,
    required String headId,
    required String headName,
  }) async {
    _isSaving = true;
    notifyListeners();

    final String isoNow = DateTime.now().toIso8601String();

    try {
      final results = await Connectivity().checkConnectivity();
      final hasConnection = results.any((result) => result != ConnectivityResult.none);

      if (_editingDepartment == null) {
        // إضافة قسم جديد
        if (hasConnection) {
          final docRef = FirebaseFirestore.instance.collection('departments').doc();
          await docRef.set({
            'id': docRef.id,
            'name': deptName,
            'head_id': headId,
            'head_name': headName,
            'createdAt': FieldValue.serverTimestamp(),
          }).timeout(const Duration(seconds: 10));

          // تحديث دور رئيس القسم الجديد في Firestore
          try {
            await FirebaseFirestore.instance.collection('users').doc(headId).update({
              'role': 'رئيس قسم',
            }).timeout(const Duration(seconds: 5));
            await DatabaseHelper.instance.updateUserRole(headId, 'رئيس قسم', sync: 1);
          } catch (e) {
            debugPrint('Failed to update head role in Firestore, will sync later: $e');
            await DatabaseHelper.instance.updateUserRole(headId, 'رئيس قسم', sync: 0);
          }

          await DatabaseHelper.instance.insertDepartment(deptName, headId, headName, sync: 1, firestoreId: docRef.id, createdAt: isoNow);
          await loadData();
          return 'add_success_online';
        } else {
          // حفظ القسم محلياً
          await DatabaseHelper.instance.insertDepartment(deptName, headId, headName, sync: 0, createdAt: isoNow);
          // تحديث دور المستخدم محلياً
          await DatabaseHelper.instance.updateUserRole(headId, 'رئيس قسم', sync: 0);
          await loadData();
          return 'add_success_offline';
        }
      } else {
        // تعديل قسم أكاديمي موجود
        final localId = _editingDepartment!.id!;
        final String? fId = _editingDepartment!.firestoreId;
        final String oldHeadId = _editingDepartment!.headId;
        final bool headChanged = oldHeadId != headId;

        if (hasConnection && fId != null && fId.isNotEmpty) {
          // تحديث مباشر في Firestore
          await FirebaseFirestore.instance.collection('departments').doc(fId).set({
            'name': deptName,
            'head_id': headId,
            'head_name': headName,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));

          if (headChanged) {
            // 1. إرجاع دور رئيس القسم القديم إلى عضو هيئة تدريس
            try {
              await FirebaseFirestore.instance.collection('users').doc(oldHeadId).update({
                'role': 'عضو هيئة تدريس',
              }).timeout(const Duration(seconds: 5));
              await DatabaseHelper.instance.updateUserRole(oldHeadId, 'عضو هيئة تدريس', sync: 1);
            } catch (e) {
              await DatabaseHelper.instance.updateUserRole(oldHeadId, 'عضو هيئة تدريس', sync: 0);
            }

            // 2. تعيين دور رئيس القسم الجديد
            try {
              await FirebaseFirestore.instance.collection('users').doc(headId).update({
                'role': 'رئيس قسم',
              }).timeout(const Duration(seconds: 5));
              await DatabaseHelper.instance.updateUserRole(headId, 'رئيس قسم', sync: 1);
            } catch (e) {
              await DatabaseHelper.instance.updateUserRole(headId, 'رئيس قسم', sync: 0);
            }
          }

          await DatabaseHelper.instance.updateDepartment(localId, deptName, headId, headName, sync: 1, firestoreId: fId);
          _editingDepartment = null;
          await loadData();
          return 'edit_success_online';
        } else {
          // حفظ التعديل محلياً مع جعل حالة المزامنة = 0 ليتم رفعها لاحقاً
          await DatabaseHelper.instance.updateDepartment(localId, deptName, headId, headName, sync: 0, firestoreId: fId);

          if (headChanged) {
            await DatabaseHelper.instance.updateUserRole(oldHeadId, 'عضو هيئة تدريس', sync: 0);
            await DatabaseHelper.instance.updateUserRole(headId, 'رئيس قسم', sync: 0);
          }

          _editingDepartment = null;
          await loadData();
          return 'edit_success_offline';
        }
      }
    } catch (e) {
      debugPrint('Error saving department: $e');
      // معالجة استثنائية عند حدوث خطأ
      if (_editingDepartment != null) {
        try {
          final oldHeadId = _editingDepartment!.headId;
          final bool headChanged = oldHeadId != headId;

          await DatabaseHelper.instance.updateDepartment(
            _editingDepartment!.id!,
            deptName,
            headId,
            headName,
            sync: 0,
            firestoreId: _editingDepartment!.firestoreId,
          );

          if (headChanged) {
            await DatabaseHelper.instance.updateUserRole(oldHeadId, 'عضو هيئة تدريس', sync: 0);
            await DatabaseHelper.instance.updateUserRole(headId, 'رئيس قسم', sync: 0);
          }

          _editingDepartment = null;
          await loadData();
          return 'edit_success_offline_fallback';
        } catch (dbError) {
          return 'error: $dbError';
        }
      } else {
        try {
          await DatabaseHelper.instance.insertDepartment(deptName, headId, headName, sync: 0, createdAt: isoNow);
          await DatabaseHelper.instance.updateUserRole(headId, 'رئيس قسم', sync: 0);
          await loadData();
          return 'add_success_offline_fallback';
        } catch (dbError) {
          return 'error: $dbError';
        }
      }
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // مزامنة يدوية وجلب التحديثات
  Future<bool> performSync() async {
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Connectivity().checkConnectivity();
      final hasConnection = results.any((result) => result != ConnectivityResult.none);

      if (!hasConnection) {
        return false;
      }

      // 1. رفع البيانات المحلية غير المزامنة
      await SyncService.instance.triggerSync();

      // 2. تنزيل وتحديث المستخدمين من الفايربيس وتخزينهم في SQLite
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isNotEqualTo: 'طالب')
          .get()
          .timeout(const Duration(seconds: 10));

      for (final doc in usersSnapshot.docs) {
        final data = doc.data();
        await DatabaseHelper.instance.saveUser({
          'id': doc.id,
          'name': data['name'] ?? '',
          'email': data['email'] ?? '',
          'role': data['role'] ?? '',
        });
      }

      // 3. تنزيل وتحديث الأقسام من الفايربيس وتخزينها في SQLite
      final deptsSnapshot = await FirebaseFirestore.instance
          .collection('departments')
          .get()
          .timeout(const Duration(seconds: 10));

      final localDb = await DatabaseHelper.instance.database;
      for (final doc in deptsSnapshot.docs) {
        final data = doc.data();
        final String name = data['name'] ?? '';
        final String headId = data['head_id'] ?? '';
        final String headName = data['head_name'] ?? '';

        // استخراج تاريخ الإنشاء من الفايربيس
        final dynamic firestoreCreatedAt = data['createdAt'];
        String? createdAtStr;
        if (firestoreCreatedAt is Timestamp) {
          createdAtStr = firestoreCreatedAt.toDate().toIso8601String();
        } else if (firestoreCreatedAt is String) {
          createdAtStr = firestoreCreatedAt;
        }

        final existing = await localDb.query(
          'departments',
          where: 'name = ?',
          whereArgs: [name],
        );

        if (existing.isEmpty) {
          await DatabaseHelper.instance.insertDepartment(name, headId, headName, sync: 1, firestoreId: doc.id, createdAt: createdAtStr);
        } else {
          await localDb.update(
            'departments',
            {
              'head_id': headId,
              'head_name': headName,
              'sync': 1,
              'firestore_id': doc.id,
              if (createdAtStr != null) 'created_at': createdAtStr,
            },
            where: 'name = ?',
            whereArgs: [name],
          );
        }
      }
      return true;
    } catch (e) {
      debugPrint('Sync error: $e');
      rethrow;
    } finally {
      await loadData();
    }
  }

  // حذف قسم أكاديمي
  Future<String?> deleteDepartment(Department dept) async {
    _isSaving = true;
    notifyListeners();

    try {
      final results = await Connectivity().checkConnectivity();
      final hasConnection = results.any((result) => result != ConnectivityResult.none);
      final String headId = dept.headId;

      if (hasConnection && dept.firestoreId != null && dept.firestoreId!.isNotEmpty) {
        // 1. حذف القسم من Firestore
        await FirebaseFirestore.instance
            .collection('departments')
            .doc(dept.firestoreId)
            .delete()
            .timeout(const Duration(seconds: 10));

        // 2. إرجاع دور رئيس القسم في Firestore إلى عضو هيئة تدريس
        if (headId.isNotEmpty) {
          try {
            await FirebaseFirestore.instance.collection('users').doc(headId).update({
              'role': 'عضو هيئة تدريس',
            }).timeout(const Duration(seconds: 5));
            await DatabaseHelper.instance.updateUserRole(headId, 'عضو هيئة تدريس', sync: 1);
          } catch (e) {
            debugPrint('Failed to update user role to teacher on Firestore: $e');
            await DatabaseHelper.instance.updateUserRole(headId, 'عضو هيئة تدريس', sync: 0);
          }
        }

        // 3. حذف القسم نهائياً من SQLite محلياً
        await DatabaseHelper.instance.deleteDepartmentFully(dept.id!);
        await loadData();
        return 'delete_success_online';
      } else {
        // أوفلاين أو لم يتم رفعه للفايربيس أصلاً
        // 1. إرجاع دور رئيس القسم محلياً إلى عضو هيئة تدريس بوضع المزامنة = 0
        if (headId.isNotEmpty) {
          await DatabaseHelper.instance.updateUserRole(headId, 'عضو هيئة تدريس', sync: 0);
        }

        if (dept.firestoreId != null && dept.firestoreId!.isNotEmpty) {
          // تم رفعه مسبقاً للفايربيس، لذا نحتاج لـ Soft Delete محلياً بوضع sync = 2 لتتم مزامنته لاحقاً
          await DatabaseHelper.instance.updateDepartmentSyncStatus(dept.id!, 2);
        } else {
          // لم يتم رفعه للفايربيس أصلاً، يمكن حذفه نهائياً فوراً
          await DatabaseHelper.instance.deleteDepartmentFully(dept.id!);
        }

        await loadData();
        return 'delete_success_offline';
      }
    } catch (e) {
      debugPrint('Error deleting department: $e');
      return 'error: $e';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // التزامن التلقائي
  Future<void> autoSync() async {
    try {
      final synced = await SyncService.instance.triggerSync();
      if (synced > 0) {
        await loadData();
      }
    } catch (e) {
      debugPrint('Auto sync failed: $e');
    }
  }
}
