import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:student_attendance_system/core/database_helper.dart';
import 'package:student_attendance_system/core/sync_service.dart';

class AssignedCourse {
  final String id;
  final String subjectName;
  final String teacherUid;
  final String teacherName;
  final List<String> studentGroups;
  final String room;
  final int syncStatus;

  AssignedCourse({
    required this.id,
    required this.subjectName,
    required this.teacherUid,
    required this.teacherName,
    required this.studentGroups,
    required this.room,
    required this.syncStatus,
  });
}

class ViewAssignmentsViewModel extends ChangeNotifier {
  List<AssignedCourse> _assignments = [];
  List<AssignedCourse> get assignments => _assignments;

  List<Map<String, dynamic>> _teachers = [];
  List<Map<String, dynamic>> get teachers => _teachers;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _message;
  String? get message => _message;

  bool _isSuccess = true;
  bool get isSuccess => _isSuccess;

  /// تحميل جميع التعيينات والجداول مع أسماء المعلمين المقابلة
  Future<void> loadAssignments() async {
    _isLoading = true;
    _message = null;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      
      // جلب المعلمين المسجلين أولاً لاستخدامهم في التعديل
      _teachers = await db.query(
        'faculty_users',
        columns: ['id', 'name', 'email', 'role'],
        orderBy: 'name ASC',
      );

      final List<Map<String, dynamic>> rows = await db.rawQuery('''
        SELECT ca.id, ca.subject_name, ca.student_groups, ca.room, ca.sync_status, ca.teacher_uid, 
               COALESCE(u.name, fu.name, 'معلم غير معروف') as teacher_name
        FROM course_assignments ca
        LEFT JOIN users u ON ca.teacher_uid = u.id
        LEFT JOIN faculty_users fu ON ca.teacher_uid = fu.id
        ORDER BY ca.subject_name ASC
      ''');

      _assignments = rows.map((row) {
        List<String> groups = [];
        final dynamic rawGroups = row['student_groups'];
        if (rawGroups is String && rawGroups.isNotEmpty) {
          try {
            final decoded = jsonDecode(rawGroups);
            if (decoded is List) {
              groups = decoded.cast<String>();
            }
          } catch (_) {}
        }

        return AssignedCourse(
          id: row['id'] as String? ?? '',
          subjectName: row['subject_name'] as String? ?? '',
          teacherUid: row['teacher_uid'] as String? ?? '',
          teacherName: row['teacher_name'] as String? ?? 'معلم غير معروف',
          studentGroups: groups,
          room: row['room'] as String? ?? '',
          syncStatus: row['sync_status'] as int? ?? 0,
        );
      }).toList();

      _isSuccess = true;
    } catch (e) {
      _message = 'فشل في تحميل التعيينات: $e';
      _isSuccess = false;
      debugPrint('ViewAssignmentsVM Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// تحديث بيانات تعيين مادة دراسية
  Future<void> updateAssignment({
    required String id,
    required String subjectName,
    required String teacherUid,
    required String room,
    required List<String> studentGroups,
  }) async {
    _isLoading = true;
    _message = null;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'course_assignments',
        {
          'subject_name': subjectName.trim(),
          'teacher_uid': teacherUid,
          'room': room.trim(),
          'student_groups': jsonEncode(studentGroups.map((g) => g.trim()).toList()),
          'sync_status': 0, // إعادة تعيين حالة المزامنة ليتم رفع التعديل
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      _message = 'تم تحديث التعيين بنجاح وجارٍ مزامنته...';
      _isSuccess = true;

      // بدء المزامنة فوراً في الخلفية
      SyncService.instance.triggerSync().catchError((e) {
        debugPrint('Sync after update failed: $e');
        return 0;
      });

      await loadAssignments();
    } catch (e) {
      _message = 'فشل في تحديث البيانات: $e';
      _isSuccess = false;
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// حذف تعيين مادة معين
  Future<void> deleteAssignment(String id) async {
    try {
      await DatabaseHelper.instance.deleteCourseAssignment(id);
      _assignments.removeWhere((item) => item.id == id);
      _message = 'تم حذف التعيين محلياً بنجاح.';
      _isSuccess = true;
      notifyListeners();
    } catch (e) {
      _message = 'فشل في حذف التعيين: $e';
      _isSuccess = false;
      notifyListeners();
    }
  }

  /// مزامنة مستخدمي هيئة التدريس يدوياً من Firestore
  Future<void> syncNow() async {
    _isLoading = true;
    _message = null;
    notifyListeners();

    try {
      final results = await Connectivity().checkConnectivity();
      final hasConnection = results.any((result) => result != ConnectivityResult.none);

      if (!hasConnection) {
        _message = 'لا يوجد اتصال بالإنترنت حالياً.';
        _isSuccess = false;
        return;
      }

      // تنزيل وتحديث أعضاء هيئة التدريس المسجلين من كولكشن faculty_users وتخزينهم في SQLite
      final facultyUsersSnapshot = await FirebaseFirestore.instance
          .collection('faculty_users')
          .get()
          .timeout(const Duration(seconds: 10));

      int updatedCount = 0;
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
        updatedCount++;
      }

      _message = 'تمت مزامنة أعضاء هيئة التدريس بنجاح. تم تحديث $updatedCount معلم.';
      _isSuccess = true;
      await loadAssignments(); // إعادة تحميل لتحديث القائمة المحلية والأسماء
    } catch (e) {
      _message = 'فشلت المزامنة: $e';
      _isSuccess = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearMessage() {
    _message = null;
    notifyListeners();
  }
}
