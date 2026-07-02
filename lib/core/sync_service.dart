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
      
      // في المستقبل عند إضافة جداول جديدة، يمكنك استدعاء دوال مزامنتها وجمع عدد السجلات هنا:
      // totalSynced += await _syncAttendance();
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

}
