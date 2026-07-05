import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'database_helper.dart';

class SyncService {
  static final SyncService instance = SyncService._init();
  bool _isSyncing = false;

  SyncService._init();

  bool get isSyncing => _isSyncing;

  // دالة تشغيل المزامنة لجميع الجداول وتُرجع عدد السجلات التي تمت مزامنتها
  Future<int> triggerSync() async {
    if (_isSyncing) return 0;

    // التحقق من وجود اتصال بالشبكة أولاً
    final results = await Connectivity().checkConnectivity();
    final hasConnection = results.any((result) => result != ConnectivityResult.none);
    if (!hasConnection) {
      throw Exception('no_internet');
    }

    _isSyncing = true;
    int totalSynced = 0;

    try {
      totalSynced += await _syncUsers();
      totalSynced += await _syncDepartments();
      totalSynced += await _syncDeletedDepartments();
    } catch (e) {
      debugPrint('Sync execution failed: $e');
      rethrow;
    } finally {
      _isSyncing = false;
    }

    return totalSynced;
  }

  // مزامنة جدول المستخدمين (users) وتُرجع عدد السجلات المزامنة
  Future<int> _syncUsers() async {
    final unsyncedUsers = await DatabaseHelper.instance.getUnsyncedUsers();
    if (unsyncedUsers.isEmpty) return 0;

    debugPrint('Found ${unsyncedUsers.length} unsynced users. Starting sync...');
    final firestore = FirebaseFirestore.instance;
    int syncedCount = 0;

    for (final userMap in unsyncedUsers) {
      final String id = userMap['id'];
      try {
        // رفع المستند إلى كولكشن users في Firestore
        await firestore.collection('users').doc(id).set({
          'id': userMap['id'],
          'name': userMap['name'],
          'email': userMap['email'],
          'role': userMap['role'],
          'createAt': userMap['createAt'],
          'acceptAt': userMap['acceptAt'],
          'department': userMap['department'],
        });

        // تحديث حالة المزامنة في SQLite محلياً إلى 1 (تمت المزامنة)
        await DatabaseHelper.instance.updateSyncStatus(id, 1);
        syncedCount++;
        debugPrint('User with ID $id synced successfully.');
      } catch (e) {
        debugPrint('Failed to sync user with ID $id: $e');
      }
    }

    return syncedCount;
  }

  // مزامنة جدول الأقسام (departments) وتُرجع عدد السجلات المزامنة
  Future<int> _syncDepartments() async {
    final unsyncedDepts = await DatabaseHelper.instance.getUnsyncedDepartments();
    if (unsyncedDepts.isEmpty) return 0;

    debugPrint('Found ${unsyncedDepts.length} unsynced departments. Starting sync...');
    final firestore = FirebaseFirestore.instance;
    int syncedCount = 0;

    for (final deptMap in unsyncedDepts) {
      final int localId = deptMap['id'];
      final String? firestoreId = deptMap['firestore_id'];
      try {
        if (firestoreId == null || firestoreId.isEmpty) {
          // إنشاء مستند جديد
          final docRef = firestore.collection('departments').doc();
          final String? localCreatedAt = deptMap['created_at'];
          await docRef.set({
            'id': docRef.id,
            'name': deptMap['name'],
            'head_id': deptMap['head_id'],
            'head_name': deptMap['head_name'],
            'createdAt': localCreatedAt != null
                ? Timestamp.fromDate(DateTime.parse(localCreatedAt))
                : FieldValue.serverTimestamp(),
          });

          // تحديث حالة المزامنة وحفظ الـ firestore_id محلياً
          final db = await DatabaseHelper.instance.database;
          await db.update(
            'departments',
            {
              'sync': 1,
              'firestore_id': docRef.id,
            },
            where: 'id = ?',
            whereArgs: [localId],
          );
        } else {
          // تحديث مستند موجود في السيرفر لمنع التكرار عند التعديل
          await firestore.collection('departments').doc(firestoreId).set({
            'id': firestoreId,
            'name': deptMap['name'],
            'head_id': deptMap['head_id'],
            'head_name': deptMap['head_name'],
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          // تحديث حالة المزامنة في SQLite محلياً إلى 1
          await DatabaseHelper.instance.updateDepartmentSyncStatus(localId, 1);
        }
        syncedCount++;
        debugPrint('Department with ID $localId synced successfully.');
      } catch (e) {
        debugPrint('Failed to sync department with ID $localId: $e');
      }
    }

    return syncedCount;
  }

  // مزامنة حذف الأقسام مع Firestore
  Future<int> _syncDeletedDepartments() async {
    final deletedDepts = await DatabaseHelper.instance.getDeletedDepartments();
    if (deletedDepts.isEmpty) return 0;

    debugPrint('Found ${deletedDepts.length} pending department deletions. Starting sync...');
    final firestore = FirebaseFirestore.instance;
    int syncedCount = 0;

    for (final deptMap in deletedDepts) {
      final int localId = deptMap['id'];
      final String? firestoreId = deptMap['firestore_id'];
      try {
        if (firestoreId != null && firestoreId.isNotEmpty) {
          // حذف المستند من Firestore
          await firestore.collection('departments').doc(firestoreId).delete();
        }
        // حذف القسم نهائياً من SQLite محلياً
        await DatabaseHelper.instance.deleteDepartmentFully(localId);
        syncedCount++;
        debugPrint('Deleted department with local ID $localId synced successfully.');
      } catch (e) {
        debugPrint('Failed to sync deletion for local ID $localId: $e');
      }
    }

    return syncedCount;
  }
}
