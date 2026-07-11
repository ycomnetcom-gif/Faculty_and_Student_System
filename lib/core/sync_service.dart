import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      totalSynced += await _syncFacultyUsers();
      totalSynced += await _syncFacultyAccounts();
      totalSynced += await _syncDepartments();
      totalSynced += await _syncDeletedDepartments();
      totalSynced += await _syncCourseAssignments();
      totalSynced += await _syncDeletedCourseAssignments();
      totalSynced += await _syncStudentAccountConfigs();
      totalSynced += await _syncDeletedStudentAccountConfigs();
    } catch (e) {
      debugPrint('Sync execution failed: $e');
      rethrow;
    } finally {
      _isSyncing = false;
    }

    return totalSynced;
  }

  // مزامنة جدول حسابات أعضاء هيئة التدريس (faculty_accounts)
  Future<int> _syncFacultyAccounts() async {
    final unsyncedFaculty = await DatabaseHelper.instance.getUnsyncedFacultyAccounts();
    if (unsyncedFaculty.isEmpty) return 0;

    debugPrint('Found ${unsyncedFaculty.length} unsynced faculty accounts. Starting sync...');
    final firestore = FirebaseFirestore.instance;
    int syncedCount = 0;

    for (final userMap in unsyncedFaculty) {
      final String id = userMap['id'];
      final String name = userMap['name'] ?? '';
      final String email = userMap['email'] ?? '';
      final String role = userMap['role'] ?? '';
      final String? createAt = userMap['createAt'];
      final String? acceptAt = userMap['acceptAt'];

      try {
        await firestore.collection('faculty_accounts').doc(id).set({
          'id': id,
          'name': name,
          'email': email,
          'role': role,
          'createdAt': createAt != null ? Timestamp.fromDate(DateTime.parse(createAt)) : FieldValue.serverTimestamp(),
          'acceptAt': acceptAt != null ? Timestamp.fromDate(DateTime.parse(acceptAt)) : FieldValue.serverTimestamp(),
        });

        await DatabaseHelper.instance.updateFacultyAccountSyncStatus(id, 1);
        syncedCount++;
        debugPrint('Faculty account with ID $id synced successfully.');
      } catch (e) {
        debugPrint('Failed to sync faculty account with ID $id: $e');
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

  // مزامنة مستخدمي أعضاء هيئة التدريس المسجلين (faculty_users)
  Future<int> _syncFacultyUsers() async {
    final unsyncedUsers = await DatabaseHelper.instance.getUnsyncedFacultyUsers();
    if (unsyncedUsers.isEmpty) return 0;

    debugPrint('Found ${unsyncedUsers.length} unsynced faculty users. Starting sync...');
    final firestore = FirebaseFirestore.instance;
    int syncedCount = 0;

    for (final userMap in unsyncedUsers) {
      final String id = userMap['id'];
      final String name = userMap['name'] ?? '';
      final String email = userMap['email'] ?? '';
      final String role = userMap['role'] ?? '';
      final String? createAt = userMap['createAt'];
      final String? acceptAt = userMap['acceptAt'];
      final String? department = userMap['department'];

      try {
        await firestore.collection('faculty_users').doc(id).set({
          'id': id,
          'name': name,
          'email': email,
          'role': role,
          'createAt': createAt,
          'acceptAt': acceptAt,
          'department': department,
        });

        await DatabaseHelper.instance.updateFacultyUserSyncStatus(id, 1);
        syncedCount++;
        debugPrint('Faculty user with ID $id synced successfully.');
      } catch (e) {
        debugPrint('Failed to sync faculty user with ID $id: $e');
      }
    }

    return syncedCount;
  }
  // مزامنة تعيينات المواد الدراسية مع Firestore
  Future<int> _syncCourseAssignments() async {
    final unsynced = await DatabaseHelper.instance.getUnsyncedCourseAssignments();
    if (unsynced.isEmpty) return 0;

    debugPrint('Found ${unsynced.length} unsynced course assignments. Starting sync...');
    final firestore = FirebaseFirestore.instance;
    int syncedCount = 0;

    for (final row in unsynced) {
      final String id = row['id'] as String;
      try {
        // تحويل student_groups من نص JSON إلى قائمة للحفظ في Firestore
        final dynamic rawGroups = row['student_groups'];
        List<String> groups = [];
        if (rawGroups is String && rawGroups.isNotEmpty) {
          try {
            final decoded = jsonDecode(rawGroups);
            if (decoded is List) {
              groups = decoded.cast<String>();
            }
          } catch (_) {
            groups = [];
          }
        }

        await firestore.collection('course_assignments').doc(id).set({
          'id': id,
          'subject_name': row['subject_name'] ?? '',
          'teacher_uid': row['teacher_uid'] ?? '',
          'student_groups': groups,
          'room': row['room'] ?? '',
          'created_at': FieldValue.serverTimestamp(),
        });

        await DatabaseHelper.instance.updateCourseAssignmentSyncStatus(id, 1);
        syncedCount++;
        debugPrint('Course assignment $id synced successfully.');
      } catch (e) {
        debugPrint('Failed to sync course assignment $id: $e');
      }
    }

    return syncedCount;
  }

  // مزامنة حذف تعيينات المواد مع Firestore
  Future<int> _syncDeletedCourseAssignments() async {
    final deleted = await DatabaseHelper.instance.getDeletedCourseAssignments();
    if (deleted.isEmpty) return 0;

    debugPrint('Found ${deleted.length} pending course assignment deletions. Starting sync...');
    final firestore = FirebaseFirestore.instance;
    int syncedCount = 0;

    for (final row in deleted) {
      final String id = row['id'] as String;
      try {
        await firestore.collection('course_assignments').doc(id).delete();
        await DatabaseHelper.instance.deleteCourseAssignmentFully(id);
        syncedCount++;
        debugPrint('Deleted course assignment $id synced from Firestore.');
      } catch (e) {
        debugPrint('Failed to sync deletion of course assignment $id: $e');
      }
    }

    return syncedCount;
  }

  // جلب كل التحديثات من السيرفر وتخزينها في قاعدة البيانات المحلية (SQL)
  Future<void> pullUpdatesFromServer() async {
    final results = await Connectivity().checkConnectivity();
    final hasConnection = results.any((result) => result != ConnectivityResult.none);
    if (!hasConnection) {
      throw Exception('no_internet');
    }

    final firestore = FirebaseFirestore.instance;

    // 1. مزامنة faculty_users (أعضاء هيئة التدريس المسجلين)
    try {
      final snapshot = await firestore.collection('faculty_users').get().timeout(const Duration(seconds: 15));
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          await DatabaseHelper.instance.saveFacultyUser({
            'id': doc.id,
            'name': data['name'] ?? '',
            'email': data['email'] ?? '',
            'role': data['role'] ?? 'عضو هيئة تدريس',
            'department': data['department'],
            'sync': 1,
          });
        } catch (e) {
          debugPrint('Error saving faculty user ${doc.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('Error pulling faculty_users: $e');
    }

    // 2. مزامنة faculty_accounts (الحسابات المصرح لها)
    try {
      final snapshot = await firestore.collection('faculty_accounts').get().timeout(const Duration(seconds: 10));
      for (final doc in snapshot.docs) {
        final data = doc.data();
        await DatabaseHelper.instance.saveFacultyAccount({
          'id': doc.id,
          'name': data['name'] ?? '',
          'email': data['email'] ?? '',
          'role': data['role'] ?? 'عضو هيئة تدريس',
          'createAt': data['createdAt'] is Timestamp 
              ? (data['createdAt'] as Timestamp).toDate().toIso8601String() 
              : data['createdAt']?.toString(),
          'acceptAt': data['acceptAt'] is Timestamp 
              ? (data['acceptAt'] as Timestamp).toDate().toIso8601String() 
              : data['acceptAt']?.toString(),
          'sync': 1,
        });
      }
    } catch (e) {
      debugPrint('Error pulling faculty_accounts: $e');
    }

    // 3. مزامنة departments (الأقسام)
    try {
      final snapshot = await firestore.collection('departments').get().timeout(const Duration(seconds: 10));
      final db = await DatabaseHelper.instance.database;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final String firestoreId = doc.id;
        final String name = data['name'] ?? '';
        final String headId = data['head_id'] ?? '';
        final String headName = data['head_name'] ?? '';
        final String? createdAt = data['createdAt'] is Timestamp 
            ? (data['createdAt'] as Timestamp).toDate().toIso8601String() 
            : data['createdAt']?.toString();

        final existing = await db.query(
          'departments',
          where: 'firestore_id = ?',
          whereArgs: [firestoreId],
        );

        if (existing.isNotEmpty) {
          final int localId = existing.first['id'] as int;
          await DatabaseHelper.instance.updateDepartment(
            localId,
            name,
            headId,
            headName,
            sync: 1,
            firestoreId: firestoreId,
          );
        } else {
          await DatabaseHelper.instance.insertDepartment(
            name,
            headId,
            headName,
            sync: 1,
            firestoreId: firestoreId,
            createdAt: createdAt,
          );
        }
      }
    } catch (e) {
      debugPrint('Error pulling departments: $e');
    }

    // 4. مزامنة course_assignments (تعيينات المواد)
    try {
      final snapshot = await firestore.collection('course_assignments').get().timeout(const Duration(seconds: 10));
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final String id = doc.id;
        final String subjectName = data['subject_name'] ?? '';
        final String teacherUid = data['teacher_uid'] ?? '';
        final String room = data['room'] ?? '';
        final List<dynamic> groupsList = data['student_groups'] ?? [];
        final String studentGroupsJson = jsonEncode(groupsList.map((g) => g.toString()).toList());

        await DatabaseHelper.instance.saveCourseAssignment({
          'id': id,
          'subject_name': subjectName,
          'teacher_uid': teacherUid,
          'student_groups': studentGroupsJson,
          'room': room,
          'sync_status': 1,
        });
      }
    } catch (e) {
      debugPrint('Error pulling course_assignments: $e');
    }

    // 5. مزامنة Configure student accounts (إعداد حسابات الطلاب)
    try {
      final prefs = await SharedPreferences.getInstance();
      final department = prefs.getString('department');
      Query query = firestore.collection('Configure student accounts');
      if (department != null && department.isNotEmpty && department != 'غير محدد' && department != 'غير مححدد') {
        query = query.where('department', isEqualTo: department);
      }
      final snapshot = await query.get().timeout(const Duration(seconds: 10));
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        await DatabaseHelper.instance.saveStudentAccountConfig({
          'registration_id': doc.id,
          'student_name': data['student_name'] ?? '',
          'email': data['email'] ?? '',
          'department': data['department'] ?? '',
          'level': data['level'] ?? '',
          'track': data['track'] ?? '',
          'sync': 1,
        });
      }
    } catch (e) {
      debugPrint('Error pulling Configure student accounts: $e');
    }
  }

  // مزامنة ثنائية الاتجاه (رفع وتنزيل)
  Future<void> syncBidirectional() async {
    // رفع
    await triggerSync();
    // تنزيل
    await pullUpdatesFromServer();
  }

  // مزامنة إعدادات حسابات الطلاب إلى السيرفر
  Future<int> _syncStudentAccountConfigs() async {
    final unsynced = await DatabaseHelper.instance.getUnsyncedStudentAccountConfigs();
    if (unsynced.isEmpty) return 0;

    debugPrint('Found ${unsynced.length} unsynced student account configurations. Starting sync...');
    final firestore = FirebaseFirestore.instance;
    int syncedCount = 0;

    for (final row in unsynced) {
      final String regId = row['registration_id'] as String;
      try {
        await firestore.collection('Configure student accounts').doc(regId).set({
          'registration_id': regId,
          'student_name': row['student_name'] ?? '',
          'email': row['email'] ?? '',
          'department': row['department'] ?? '',
          'level': row['level'] ?? '',
          'track': row['track'] ?? '',
          'created_at': FieldValue.serverTimestamp(),
        });

        await DatabaseHelper.instance.updateStudentAccountConfigSyncStatus(regId, 1);
        syncedCount++;
        debugPrint('Student account config $regId synced successfully.');
      } catch (e) {
        debugPrint('Failed to sync student account config $regId: $e');
      }
    }

    return syncedCount;
  }

  // مزامنة حذف إعدادات حسابات الطلاب مع Firestore
  Future<int> _syncDeletedStudentAccountConfigs() async {
    final deleted = await DatabaseHelper.instance.getDeletedStudentAccountConfigs();
    if (deleted.isEmpty) return 0;

    debugPrint('Found ${deleted.length} pending student account configuration deletions. Starting sync...');
    final firestore = FirebaseFirestore.instance;
    int syncedCount = 0;

    for (final row in deleted) {
      final String regId = row['registration_id'] as String;
      try {
        await firestore.collection('Configure student accounts').doc(regId).delete();
        await DatabaseHelper.instance.deleteStudentAccountConfigFully(regId);
        syncedCount++;
        debugPrint('Deleted student account configuration $regId synced from Firestore.');
      } catch (e) {
        debugPrint('Failed to sync deletion of student account configuration $regId: $e');
      }
    }

    return syncedCount;
  }

  // مزامنة مخصصة وسريعة لإعدادات حسابات الطلاب فقط (رفع وتنزيل)
  Future<int> syncStudentAccountConfigsOnly({String? department}) async {
    final results = await Connectivity().checkConnectivity();
    final hasConnection = results.any((result) => result != ConnectivityResult.none);
    if (!hasConnection) {
      throw Exception('no_internet');
    }

    int totalSynced = 0;
    
    // 1. رفع المضاف حديثاً أوفلاين
    totalSynced += await _syncStudentAccountConfigs();
    
    // 2. رفع وحذف المحذوف أوفلاين
    totalSynced += await _syncDeletedStudentAccountConfigs();
    
    // 3. جلب التحديثات الجديدة فقط من كولكشن Configure student accounts
    try {
      final firestore = FirebaseFirestore.instance;
      Query query = firestore.collection('Configure student accounts');
      if (department != null && department.isNotEmpty) {
        query = query.where('department', isEqualTo: department);
      }
      final snapshot = await query.get().timeout(const Duration(seconds: 10));
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        await DatabaseHelper.instance.saveStudentAccountConfig({
          'registration_id': doc.id,
          'student_name': data['student_name'] ?? '',
          'email': data['email'] ?? '',
          'department': data['department'] ?? '',
          'level': data['level'] ?? '',
          'track': data['track'] ?? '',
          'sync': 1,
        });
      }
    } catch (e) {
      debugPrint('Error pulling Configure student accounts: $e');
    }

    return totalSynced;
  }
}
