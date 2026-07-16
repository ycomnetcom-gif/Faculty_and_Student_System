import 'dart:convert';
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

      // 2. تحميل أعضاء هيئة التدريس المسجلين من SQLite (جدول faculty_users) فقط
      final db = await DatabaseHelper.instance.database;
      final localFacultyUsers = await db.query('faculty_users');

      final List<AppUser> list = [];
      for (final fUser in localFacultyUsers) {
        list.add(AppUser(
          id: fUser['id']?.toString() ?? '',
          name: fUser['name']?.toString() ?? 'غير معروف',
          email: fUser['email']?.toString() ?? '',
          role: fUser['role']?.toString() ?? 'عضو هيئة تدريس',
        ));
      }

      _users = list;
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // دوال مساعدة لتحديد الأدوار لمنع تداخل صلاحيات نائب العميد ورئيس القسم
  Future<String> _determineRoleForNewHead(String userId) async {
    final userMap = await DatabaseHelper.instance.getFacultyUser(userId);
    if (userMap != null) {
      final currentRole = userMap['role']?.toString() ?? '';
      if (currentRole.contains('نائب العميد') || currentRole.toLowerCase().contains('vice_dean')) {
        return 'نائب العميد ورئيس قسم';
      }
    }
    return 'رئيس قسم';
  }

  Future<String> _determineRoleForOldHead(String userId) async {
    final userMap = await DatabaseHelper.instance.getFacultyUser(userId);
    if (userMap != null) {
      final currentRole = userMap['role']?.toString() ?? '';
      if (currentRole.contains('نائب العميد') || currentRole.toLowerCase().contains('vice_dean')) {
        return 'نائب العميد للشؤون الأكاديمية';
      }
    }
    return 'عضو هيئة تدريس';
  }

  // إضافة أو تعديل قسم
  Future<String?> saveDepartment({
    required String deptName,
    required String headId,
    required String headName,
    required int levelsCount,
    required bool hasTracks,
    required List<String> tracks,
    required int? startLevelForTracks,
  }) async {
    _isSaving = true;
    notifyListeners();

    final String isoNow = DateTime.now().toIso8601String();

    try {
      final results = await Connectivity().checkConnectivity();
      final hasConnection = results.any((result) => result != ConnectivityResult.none);

      // تحديد الأدوار الجديدة والقديمة بديناميكية لمنع الكتابة فوق دور نائب العميد
      final String newHeadRole = await _determineRoleForNewHead(headId);
      final String oldHeadRole = _editingDepartment != null
          ? await _determineRoleForOldHead(_editingDepartment!.headId)
          : 'عضو هيئة تدريس';

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
            'levels_count': levelsCount,
            'has_tracks': hasTracks,
            'tracks': tracks,
            'start_level_for_tracks': startLevelForTracks,
          }).timeout(const Duration(seconds: 10));

          // تحديث دور رئيس القسم الجديد وقسمه في Firestore (faculty_users دائماً)
          try {
            await FirebaseFirestore.instance.collection('faculty_users').doc(headId).update({
              'role': newHeadRole,
              'department': deptName,
            }).timeout(const Duration(seconds: 5));
            await DatabaseHelper.instance.updateUserRoleAndDepartment(headId, newHeadRole, deptName, sync: 1);
          } catch (e) {
            debugPrint('Failed to update head role in Firestore, will sync later: $e');
            await DatabaseHelper.instance.updateUserRoleAndDepartment(headId, newHeadRole, deptName, sync: 0);
          }

          await DatabaseHelper.instance.insertDepartment(deptName, headId, headName, sync: 1, firestoreId: docRef.id, createdAt: isoNow, levelsCount: levelsCount, hasTracks: hasTracks, tracks: tracks, startLevelForTracks: startLevelForTracks);
          await loadData();
          return 'add_success_online';
        } else {
          // حفظ القسم محلياً
          await DatabaseHelper.instance.insertDepartment(deptName, headId, headName, sync: 0, createdAt: isoNow, levelsCount: levelsCount, hasTracks: hasTracks, tracks: tracks, startLevelForTracks: startLevelForTracks);
          await DatabaseHelper.instance.updateUserRoleAndDepartment(headId, newHeadRole, deptName, sync: 0);
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
            'levels_count': levelsCount,
            'has_tracks': hasTracks,
            'tracks': tracks,
            'start_level_for_tracks': startLevelForTracks,
          }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));

          if (headChanged) {
            // 1. إرجاع دور رئيس القسم القديم إلى دوره الأصلي المناسب
            try {
              await FirebaseFirestore.instance.collection('faculty_users').doc(oldHeadId).update({
                'role': oldHeadRole,
                'department': null,
              }).timeout(const Duration(seconds: 5));
              await DatabaseHelper.instance.updateUserRoleAndDepartment(oldHeadId, oldHeadRole, null, sync: 1);
            } catch (e) {
              await DatabaseHelper.instance.updateUserRoleAndDepartment(oldHeadId, oldHeadRole, null, sync: 0);
            }

            // 2. تعيين دور رئيس القسم الجديد
            try {
              await FirebaseFirestore.instance.collection('faculty_users').doc(headId).update({
                'role': newHeadRole,
                'department': deptName,
              }).timeout(const Duration(seconds: 5));
              await DatabaseHelper.instance.updateUserRoleAndDepartment(headId, newHeadRole, deptName, sync: 1);
            } catch (e) {
              await DatabaseHelper.instance.updateUserRoleAndDepartment(headId, newHeadRole, deptName, sync: 0);
            }
          } else {
            // تحديث اسم القسم لرئيس القسم الحالي فقط ودوره
            try {
              await FirebaseFirestore.instance.collection('faculty_users').doc(headId).update({
                'role': newHeadRole,
                'department': deptName,
              }).timeout(const Duration(seconds: 5));
              await DatabaseHelper.instance.updateUserRoleAndDepartment(headId, newHeadRole, deptName, sync: 1);
            } catch (e) {
              await DatabaseHelper.instance.updateUserRoleAndDepartment(headId, newHeadRole, deptName, sync: 0);
            }
          }

          await DatabaseHelper.instance.updateDepartment(localId, deptName, headId, headName, sync: 1, firestoreId: fId, levelsCount: levelsCount, hasTracks: hasTracks, tracks: tracks, startLevelForTracks: startLevelForTracks);
          _editingDepartment = null;
          await loadData();
          return 'edit_success_online';
        } else {
          // حفظ التعديل محلياً
          await DatabaseHelper.instance.updateDepartment(localId, deptName, headId, headName, sync: 0, firestoreId: fId, levelsCount: levelsCount, hasTracks: hasTracks, tracks: tracks, startLevelForTracks: startLevelForTracks);

          if (headChanged) {
            await DatabaseHelper.instance.updateUserRoleAndDepartment(oldHeadId, oldHeadRole, null, sync: 0);
            await DatabaseHelper.instance.updateUserRoleAndDepartment(headId, newHeadRole, deptName, sync: 0);
          } else {
            await DatabaseHelper.instance.updateUserRoleAndDepartment(headId, newHeadRole, deptName, sync: 0);
          }

          _editingDepartment = null;
          await loadData();
          return 'edit_success_offline';
        }
      }
    } catch (e) {
      debugPrint('Error saving department: $e');
      
      // الحصول على الأدوار البديلة مجدداً للحالة الاستثنائية
      final String newHeadRole = await _determineRoleForNewHead(headId);
      final String oldHeadRole = _editingDepartment != null
          ? await _determineRoleForOldHead(_editingDepartment!.headId)
          : 'عضو هيئة تدريس';

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
            levelsCount: levelsCount,
            hasTracks: hasTracks,
            tracks: tracks,
            startLevelForTracks: startLevelForTracks,
          );

          if (headChanged) {
            await DatabaseHelper.instance.updateUserRoleAndDepartment(oldHeadId, oldHeadRole, null, sync: 0);
            await DatabaseHelper.instance.updateUserRoleAndDepartment(headId, newHeadRole, deptName, sync: 0);
          } else {
            await DatabaseHelper.instance.updateUserRoleAndDepartment(headId, newHeadRole, deptName, sync: 0);
          }

          _editingDepartment = null;
          await loadData();
          return 'edit_success_offline_fallback';
        } catch (dbError) {
          return 'error: $dbError';
        }
      } else {
        try {
          await DatabaseHelper.instance.insertDepartment(deptName, headId, headName, sync: 0, createdAt: isoNow, levelsCount: levelsCount, hasTracks: hasTracks, tracks: tracks, startLevelForTracks: startLevelForTracks);
          await DatabaseHelper.instance.updateUserRoleAndDepartment(headId, newHeadRole, deptName, sync: 0);
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

      // 2. تنزيل وتحديث أعضاء هيئة التدريس المسجلين من كولكشن faculty_users وتخزينهم في SQLite
      final facultyUsersSnapshot = await FirebaseFirestore.instance
          .collection('faculty_users')
          .get()
          .timeout(const Duration(seconds: 10));

      for (final doc in facultyUsersSnapshot.docs) {
        final data = doc.data();
        await DatabaseHelper.instance.saveFacultyUser({
          'id': doc.id,
          'name': data['name'] ?? '',
          'email': data['email'] ?? '',
          'role': data['role'] ?? 'عضو هيئة تدريس',
          'department': data['department'],
          'sync': 1,
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

        final int levelsCount = data['levels_count'] is int ? data['levels_count'] : 4;
        final bool hasTracks = data['has_tracks'] is bool ? data['has_tracks'] : false;
        final List<dynamic> rawTracks = data['tracks'] is List ? data['tracks'] : [];
        final List<String> tracks = rawTracks.map((t) => t.toString()).toList();
        final int? startLevelForTracks = data['start_level_for_tracks'] is int ? data['start_level_for_tracks'] : null;

        final existing = await localDb.query(
          'departments',
          where: 'name = ?',
          whereArgs: [name],
        );

        if (existing.isEmpty) {
          await DatabaseHelper.instance.insertDepartment(name, headId, headName, sync: 1, firestoreId: doc.id, createdAt: createdAtStr, levelsCount: levelsCount, hasTracks: hasTracks, tracks: tracks, startLevelForTracks: startLevelForTracks);
        } else {
          await localDb.update(
            'departments',
            {
              'head_id': headId,
              'head_name': headName,
              'sync': 1,
              'firestore_id': doc.id,
              if (createdAtStr != null) 'created_at': createdAtStr,
              'levels_count': levelsCount,
              'has_tracks': hasTracks ? 1 : 0,
              'tracks': jsonEncode(tracks),
              'start_level_for_tracks': startLevelForTracks,
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

      // تحديد الدور المناسب لرئيس القسم المحذوف لمنع حذف صلاحية نائب العميد
      final String oldHeadRole = await _determineRoleForOldHead(headId);

      if (hasConnection && dept.firestoreId != null && dept.firestoreId!.isNotEmpty) {
        // 1. حذف القسم من Firestore
        await FirebaseFirestore.instance
            .collection('departments')
            .doc(dept.firestoreId)
            .delete()
            .timeout(const Duration(seconds: 10));

        // 2. إرجاع دور رئيس القسم في faculty_users إلى دوره الأصلي المناسب
        if (headId.isNotEmpty) {
          try {
            await FirebaseFirestore.instance.collection('faculty_users').doc(headId).update({
              'role': oldHeadRole,
              'department': null,
            }).timeout(const Duration(seconds: 5));
            await DatabaseHelper.instance.updateUserRoleAndDepartment(headId, oldHeadRole, null, sync: 1);
          } catch (e) {
            debugPrint('Failed to update user role to teacher on Firestore: $e');
            await DatabaseHelper.instance.updateUserRoleAndDepartment(headId, oldHeadRole, null, sync: 0);
          }
        }

        // 3. حذف القسم نهائياً من SQLite محلياً
        await DatabaseHelper.instance.deleteDepartmentFully(dept.id!);
        await loadData();
        return 'delete_success_online';
      } else {
        // أوفلاين أو لم يتم رفعه للفايربيس أصلاً
        // 1. إرجاع دور رئيس القسم وقسمه محلياً إلى دوره الأصلي بوضع المزامنة = 0
        if (headId.isNotEmpty) {
          await DatabaseHelper.instance.updateUserRoleAndDepartment(headId, oldHeadRole, null, sync: 0);
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
