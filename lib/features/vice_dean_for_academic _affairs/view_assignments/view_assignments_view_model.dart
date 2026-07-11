import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
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

  final _firestore = FirebaseFirestore.instance;

  // -- دالة مساعدة: هل يتوفر اتصال بالإنترنت؟ --
  Future<bool> _hasInternet() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// تحميل جميع التعيينات مع أسماء المعلمين (من SQLite فقط، بدون فايربيس)
  Future<void> loadAssignments() async {
    _isLoading = true;
    _message = null;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;

      // جلب قائمة المعلمين لاستخدامها في نافذة التعديل
      _teachers = await db.query(
        'faculty_users',
        columns: ['id', 'name', 'email', 'role'],
        orderBy: 'name ASC',
      );

      // جلب التعيينات مع اسم المعلم (استبعاد المحذوفة sync_status=2)
      final List<Map<String, dynamic>> rows = await db.rawQuery('''
        SELECT ca.id, ca.subject_name, ca.student_groups, ca.room, ca.sync_status, ca.teacher_uid,
               COALESCE(fu.name, u.name, 'معلم غير معروف') as teacher_name
        FROM course_assignments ca
        LEFT JOIN faculty_users fu ON ca.teacher_uid = fu.id
        LEFT JOIN users u ON ca.teacher_uid = u.id
        WHERE ca.sync_status != 2
        ORDER BY ca.subject_name ASC
      ''');

      _assignments = rows.map((row) {
        List<String> groups = [];
        final dynamic rawGroups = row['student_groups'];
        if (rawGroups is String && rawGroups.isNotEmpty) {
          try {
            final decoded = jsonDecode(rawGroups);
            if (decoded is List) groups = decoded.cast<String>();
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
      debugPrint('ViewAssignmentsVM loadAssignments Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// تعديل تعيين مادة:
  /// - يحدث محلياً فوراً دائماً.
  /// - إذا توفر الإنترنت: يرفع التغيير مباشرة لفايربيس ويضع sync_status=1.
  /// - إذا لم يتوفر: يضع sync_status=0 وتتولى autoSync الرفع لاحقاً.
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
      final groupsJson = jsonEncode(studentGroups.map((g) => g.trim()).toList());
      final db = await DatabaseHelper.instance.database;

      if (await _hasInternet()) {
        // 1. رفع مباشر إلى فايربيس
        await _firestore.collection('course_assignments').doc(id).set({
          'id': id,
          'subject_name': subjectName.trim(),
          'teacher_uid': teacherUid,
          'room': room.trim(),
          'student_groups': studentGroups.map((g) => g.trim()).toList(),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // 2. تحديث محلي مع sync_status=1 (تم الرفع)
        await db.update(
          'course_assignments',
          {
            'subject_name': subjectName.trim(),
            'teacher_uid': teacherUid,
            'room': room.trim(),
            'student_groups': groupsJson,
            'sync_status': 1,
          },
          where: 'id = ?',
          whereArgs: [id],
        );

        _message = 'تم تحديث التعيين وحفظه على السيرفر بنجاح ✓';
      } else {
        // لا إنترنت: حفظ محلي فقط مع sync_status=0 للمزامنة لاحقاً
        await db.update(
          'course_assignments',
          {
            'subject_name': subjectName.trim(),
            'teacher_uid': teacherUid,
            'room': room.trim(),
            'student_groups': groupsJson,
            'sync_status': 0,
          },
          where: 'id = ?',
          whereArgs: [id],
        );

        _message = 'تم التعديل محلياً. سيتم الرفع تلقائياً عند توفر الإنترنت.';
      }

      _isSuccess = true;
      await loadAssignments();
    } catch (e) {
      _message = 'فشل في التعديل: $e';
      _isSuccess = false;
      debugPrint('ViewAssignmentsVM updateAssignment Error: $e');
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// حذف تعيين مادة:
  /// - يخفيه من الواجهة فوراً.
  /// - إذا توفر الإنترنت: يحذفه مباشرة من فايربيس ونهائياً من SQLite.
  /// - إذا لم يتوفر: يضع sync_status=2 وتتولى autoSync الحذف من فايربيس لاحقاً.
  Future<void> deleteAssignment(String id) async {
    // إخفاء من الواجهة فوراً
    _assignments.removeWhere((item) => item.id == id);
    notifyListeners();

    try {
      if (await _hasInternet()) {
        // حذف مباشر من فايربيس
        await _firestore.collection('course_assignments').doc(id).delete();

        // حذف نهائي من SQLite
        await DatabaseHelper.instance.deleteCourseAssignmentFully(id);

        _message = 'تم حذف التعيين من السيرفر والقاعدة المحلية بنجاح ✓';
      } else {
        // لا إنترنت: تعليم بالحذف المعلق (sync_status=2)
        await DatabaseHelper.instance.deleteCourseAssignment(id);

        _message = 'تم الحذف محلياً. سيتم الحذف من السيرفر تلقائياً عند توفر الإنترنت.';
      }

      _isSuccess = true;
      notifyListeners();
    } catch (e) {
      _message = 'فشل في الحذف: $e';
      _isSuccess = false;
      debugPrint('ViewAssignmentsVM deleteAssignment Error: $e');
      notifyListeners();
    }
  }

  /// مزامنة يدوية (زر المزامنة): رفع المعلق + تنزيل التحديثات
  Future<void> syncNow() async {
    _isLoading = true;
    _message = null;
    notifyListeners();

    try {
      if (!await _hasInternet()) {
        _message = 'لا يوجد اتصال بالإنترنت حالياً.';
        _isSuccess = false;
        return;
      }

      await SyncService.instance.syncBidirectional();
      _message = 'تمت المزامنة الكاملة مع السيرفر بنجاح ✓';
      _isSuccess = true;
      await loadAssignments();
    } catch (e) {
      _message = 'فشلت المزامنة: $e';
      _isSuccess = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// مزامنة تلقائية صامتة عند عودة الإنترنت
  Future<void> autoSync() async {
    try {
      if (await _hasInternet()) {
        await SyncService.instance.syncBidirectional();
        await loadAssignments();
      }
    } catch (e) {
      debugPrint('ViewAssignmentsVM autoSync Error: $e');
    }
  }

  void clearMessage() {
    _message = null;
    notifyListeners();
  }
}
