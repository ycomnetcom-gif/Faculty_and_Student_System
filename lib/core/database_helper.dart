import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('student_attendance.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // تهيئة SQLite للعمل على الويندوز والأنظمة المكتبية باستخدام FFI
    if (kIsWeb) {
      // الويب لا يدعم sqflite مباشرة بنفس الطريقة، نرجو الحذر
    } else if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 10,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // إنشاء جدول المستخدمين بالحقول المطلوبة مع حقل المزامنة (sync)
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        role TEXT NOT NULL,
        createAt TEXT,
        acceptAt TEXT,
        department TEXT,
        sync INTEGER DEFAULT 1
      )
    ''');

    // إنشاء جدول الأقسام مع عمود firestore_id و created_at
    await db.execute('''
      CREATE TABLE departments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firestore_id TEXT,
        name TEXT NOT NULL,
        head_id TEXT NOT NULL,
        head_name TEXT NOT NULL,
        sync INTEGER DEFAULT 0,
        created_at TEXT
      )
    ''');

    // إنشاء جدول حسابات أعضاء هيئة التدريس المصرح لهم
    await db.execute('''
      CREATE TABLE faculty_accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        role TEXT NOT NULL,
        createAt TEXT,
        acceptAt TEXT,
        sync INTEGER DEFAULT 1
      )
    ''');

    // إنشاء جدول مستخدمي أعضاء هيئة التدريس المسجلين
    await db.execute('''
      CREATE TABLE faculty_users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        role TEXT NOT NULL,
        createAt TEXT,
        acceptAt TEXT,
        department TEXT,
        sync INTEGER DEFAULT 1
      )
    ''');

    // إنشاء جدول تعيينات المواد الدراسية (استيراد الجدول الدراسي CSV)
    await db.execute('''
      CREATE TABLE course_assignments (
        id TEXT PRIMARY KEY,
        subject_name TEXT NOT NULL,
        teacher_uid TEXT NOT NULL,
        student_groups TEXT NOT NULL,
        room TEXT,
        sync_status INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE departments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          head_id TEXT NOT NULL,
          head_name TEXT NOT NULL,
          sync INTEGER DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE departments ADD COLUMN firestore_id TEXT');
      } catch (e) {
        debugPrint("Error upgrading to version 3: $e");
      }
    }
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE departments ADD COLUMN created_at TEXT');
      } catch (e) {
        debugPrint("Error upgrading to version 4: $e");
      }
    }
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN department TEXT');
      } catch (e) {
        debugPrint("Error upgrading to version 5: $e");
      }
    }
    if (oldVersion < 6) {
      try {
        await db.execute('''
          CREATE TABLE faculty_accounts (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT NOT NULL,
            role TEXT NOT NULL,
            createAt TEXT,
            acceptAt TEXT,
            sync INTEGER DEFAULT 1
          )
        ''');
      } catch (e) {
        debugPrint("Error upgrading to version 6: $e");
      }
    }
    if (oldVersion < 7) {
      try {
        await db.execute('''
          CREATE TABLE faculty_users (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT NOT NULL,
            role TEXT NOT NULL,
            createAt TEXT,
            acceptAt TEXT,
            department TEXT,
            sync INTEGER DEFAULT 1
          )
        ''');
      } catch (e) {
        debugPrint("Error upgrading to version 7: $e");
      }
    }
    if (oldVersion < 8) {
      try {
        await db.transaction((txn) async {
          // 1. إعادة تسمية الجدول القديم
          await txn.execute('ALTER TABLE faculty_accounts RENAME TO faculty_accounts_old');
          
          // 2. إنشاء الجدول الجديد بالهيكل الصحيح بدون department
          await txn.execute('''
            CREATE TABLE faculty_accounts (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              email TEXT NOT NULL,
              role TEXT NOT NULL,
              createAt TEXT,
              acceptAt TEXT,
              sync INTEGER DEFAULT 1
            )
          ''');
          
          // 3. نسخ البيانات
          await txn.execute('''
            INSERT INTO faculty_accounts (id, name, email, role, createAt, acceptAt, sync)
            SELECT id, name, email, role, createAt, acceptAt, sync 
            FROM faculty_accounts_old
          ''');
          
          // 4. حذف الجدول القديم
          await txn.execute('DROP TABLE faculty_accounts_old');
        });
        debugPrint("Database successfully upgraded to version 8 (removed department column from faculty_accounts).");
      } catch (e) {
        debugPrint("Error upgrading to version 8: $e");
      }
    }
    if (oldVersion < 9) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS course_assignments (
            id TEXT PRIMARY KEY,
            subject_name TEXT NOT NULL,
            teacher_uid TEXT NOT NULL,
            student_groups TEXT NOT NULL,
            sync_status INTEGER DEFAULT 0
          )
        ''');
        debugPrint("Database successfully upgraded to version 9 (added course_assignments table).");
      } catch (e) {
        debugPrint("Error upgrading to version 9: $e");
      }
    }
    if (oldVersion < 10) {
      try {
        await db.execute('ALTER TABLE course_assignments ADD COLUMN room TEXT');
        debugPrint("Database successfully upgraded to version 10 (added room column to course_assignments).");
      } catch (e) {
        debugPrint("Error upgrading to version 10: $e");
      }
    }
  }

  // حفظ أو تحديث بيانات مستخدم
  Future<int> saveUser(Map<String, dynamic> userMap, {int syncVal = 1}) async {
    final db = await instance.database;
    return await db.insert(
      'users',
      {
        'id': userMap['id'] ?? '',
        'name': userMap['name'] ?? '',
        'email': userMap['email'] ?? '',
        'role': userMap['role'] ?? '',
        'createAt': userMap['createAt']?.toString() ?? userMap['createdAt']?.toString(),
        'acceptAt': userMap['acceptAt']?.toString() ?? userMap['acceptedAt']?.toString(),
        'department': userMap['department']?.toString(),
        'sync': userMap['sync'] ?? syncVal,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // جلب جميع المستخدمين غير المزامنين مع السيرفر
  Future<List<Map<String, dynamic>>> getUnsyncedUsers() async {
    final db = await instance.database;
    return await db.query('users', where: 'sync = 0');
  }

  // تحديث حالة مزامنة مستخدم
  Future<int> updateSyncStatus(String id, int syncStatus) async {
    final db = await instance.database;
    return await db.update(
      'users',
      {'sync': syncStatus},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // تحديث دور وقسم عضو هيئة التدريس في جدول faculty_users
  Future<int> updateUserRoleAndDepartment(String id, String role, String? department, {int sync = 0}) async {
    final db = await instance.database;
    return await db.update(
      'faculty_users',
      {
        'role': role,
        'department': department,
        'sync': sync,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // جلب بيانات مستخدم بواسطة المعرف (id)
  Future<Map<String, dynamic>?> getUser(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      'users',
      columns: ['id', 'name', 'email', 'role', 'createAt', 'acceptAt', 'department', 'sync'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return maps.first;
    }

    // إذا لم يوجد في جدول users، نبحث في جدول faculty_users
    final facultyMaps = await db.query(
      'faculty_users',
      columns: ['id', 'name', 'email', 'role', 'createAt', 'acceptAt', 'department', 'sync'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (facultyMaps.isNotEmpty) {
      return facultyMaps.first;
    }
    return null;
  }

  // --- دوال حسابات أعضاء هيئة التدريس (faculty_accounts) ---

  Future<int> saveFacultyAccount(Map<String, dynamic> accountMap, {int syncVal = 1}) async {
    final db = await instance.database;
    return await db.insert(
      'faculty_accounts',
      {
        'id': accountMap['id'] ?? '',
        'name': accountMap['name'] ?? '',
        'email': accountMap['email'] ?? '',
        'role': accountMap['role'] ?? 'عضو هيئة تدريس',
        'createAt': accountMap['createAt']?.toString() ?? accountMap['createdAt']?.toString(),
        'acceptAt': accountMap['acceptAt']?.toString() ?? accountMap['acceptedAt']?.toString(),
        'sync': accountMap['sync'] ?? syncVal,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getUnsyncedFacultyAccounts() async {
    final db = await instance.database;
    return await db.query('faculty_accounts', where: 'sync = 0');
  }

  Future<int> updateFacultyAccountSyncStatus(String id, int syncStatus) async {
    final db = await instance.database;
    return await db.update(
      'faculty_accounts',
      {'sync': syncStatus},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getAllFacultyAccounts() async {
    final db = await instance.database;
    return await db.query('faculty_accounts', orderBy: 'name ASC');
  }

  Future<int> deleteFacultyAccount(String id) async {
    final db = await instance.database;
    return await db.delete(
      'faculty_accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearFacultyAccounts() async {
    final db = await instance.database;
    return await db.delete('faculty_accounts');
  }

  // --- دوال الأقسام ---

  // إدخال قسم جديد
  Future<int> insertDepartment(String name, String headId, String headName, {int sync = 0, String? firestoreId, String? createdAt}) async {
    final db = await instance.database;
    return await db.insert(
      'departments',
      {
        'name': name,
        'head_id': headId,
        'head_name': headName,
        'sync': sync,
        'firestore_id': firestoreId,
        'created_at': createdAt ?? DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // تحديث بيانات قسم موجود
  Future<int> updateDepartment(int localId, String name, String headId, String headName, {int sync = 0, String? firestoreId}) async {
    final db = await instance.database;
    return await db.update(
      'departments',
      {
        'name': name,
        'head_id': headId,
        'head_name': headName,
        'sync': sync,
        if (firestoreId != null) 'firestore_id': firestoreId,
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  // جلب الأقسام غير المزامنة
  Future<List<Map<String, dynamic>>> getUnsyncedDepartments() async {
    final db = await instance.database;
    return await db.query('departments', where: 'sync = 0');
  }

  // تحديث حالة مزامنة القسم
  Future<int> updateDepartmentSyncStatus(int id, int syncStatus) async {
    final db = await instance.database;
    return await db.update(
      'departments',
      {'sync': syncStatus},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // جلب جميع الأقسام المحلية
  Future<List<Map<String, dynamic>>> getAllDepartments() async {
    final db = await instance.database;
    // لا نجلب الأقسام التي تم حذفها محلياً وبانتظار المزامنة (sync = 2)
    return await db.query('departments', where: 'sync != 2', orderBy: 'id DESC');
  }

  // جلب الأقسام المحذوفة محلياً وبانتظار المزامنة مع السيرفر
  Future<List<Map<String, dynamic>>> getDeletedDepartments() async {
    final db = await instance.database;
    return await db.query('departments', where: 'sync = 2');
  }

  // حذف قسم نهائياً من قاعدة البيانات المحلية
  Future<int> deleteDepartmentFully(int id) async {
    final db = await instance.database;
    return await db.delete(
      'departments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // حفظ أو تحديث بيانات مستخدم عضو هيئة تدريس
  Future<int> saveFacultyUser(Map<String, dynamic> userMap, {int syncVal = 1}) async {
    final db = await instance.database;
    return await db.insert(
      'faculty_users',
      {
        'id': userMap['id'] ?? '',
        'name': userMap['name'] ?? '',
        'email': userMap['email'] ?? '',
        'role': userMap['role'] ?? 'عضو هيئة تدريس',
        'createAt': userMap['createAt']?.toString() ?? userMap['createdAt']?.toString(),
        'acceptAt': userMap['acceptAt']?.toString() ?? userMap['acceptedAt']?.toString(),
        'department': userMap['department']?.toString() ?? 'غير محدد',
        'sync': userMap['sync'] ?? syncVal,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // مسح جميع مستخدمي أعضاء هيئة التدريس من قاعدة البيانات المحلية
  Future<int> clearFacultyUsers() async {
    final db = await instance.database;
    return await db.delete('faculty_users');
  }

  // حذف عضو هيئة تدريس مسجل من قاعدة البيانات المحلية
  Future<int> deleteFacultyUser(String id) async {
    final db = await instance.database;
    return await db.delete(
      'faculty_users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // جلب جميع مستخدمي أعضاء هيئة التدريس غير المزامنين
  Future<List<Map<String, dynamic>>> getUnsyncedFacultyUsers() async {
    final db = await instance.database;
    return await db.query('faculty_users', where: 'sync = 0');
  }

  // تحديث حالة مزامنة مستخدم عضو هيئة تدريس
  Future<int> updateFacultyUserSyncStatus(String id, int syncStatus) async {
    final db = await instance.database;
    return await db.update(
      'faculty_users',
      {'sync': syncStatus},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // إغلاق قاعدة البيانات
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  // --- دوال تعيينات المواد الدراسية (course_assignments) ---

  /// إدراج أو استبدال تعيين مادة دراسية في قاعدة البيانات المحلية.
  Future<int> saveCourseAssignment(Map<String, dynamic> assignmentMap) async {
    final db = await instance.database;
    return await db.insert(
      'course_assignments',
      assignmentMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// جلب جميع التعيينات غير المزامنة مع Firestore (sync_status = 0).
  Future<List<Map<String, dynamic>>> getUnsyncedCourseAssignments() async {
    final db = await instance.database;
    return await db.query('course_assignments', where: 'sync_status = 0');
  }

  /// تحديث حالة مزامنة تعيين مادة دراسية.
  Future<int> updateCourseAssignmentSyncStatus(String id, int syncStatus) async {
    final db = await instance.database;
    return await db.update(
      'course_assignments',
      {'sync_status': syncStatus},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// جلب جميع تعيينات المواد الدراسية المحلية.
  Future<List<Map<String, dynamic>>> getAllCourseAssignments() async {
    final db = await instance.database;
    return await db.query('course_assignments', orderBy: 'subject_name ASC');
  }

  /// حذف تعيين مادة دراسية من قاعدة البيانات المحلية.
  Future<int> deleteCourseAssignment(String id) async {
    final db = await instance.database;
    return await db.delete(
      'course_assignments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
