import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static Completer<Database>? _dbCompleter;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    if (_dbCompleter == null) {
      _dbCompleter = Completer<Database>();
      _initDB('student_attendance.db')
          .then((db) {
            _database = db;
            _dbCompleter!.complete(db);
          })
          .catchError((e) {
            _dbCompleter!.completeError(e);
            _dbCompleter = null;
          });
    }
    return _dbCompleter!.future;
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

    final db = await openDatabase(
      path,
      version: 14,
      onConfigure: (db) async {
        try {
          await db.execute('PRAGMA busy_timeout = 5000;');
          await db.execute('PRAGMA journal_mode = WAL;');
        } catch (e) {
          debugPrint('PRAGMA init warning: $e');
        }
      },
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );

    // تحقق ديناميكي لضمان وجود عمود createdAt في جدول users لتفادي أي تعارض في النسخ السابقة
    try {
      final columns = await db.rawQuery('PRAGMA table_info(users)');
      final hasCreatedAt = columns.any((column) => column['name'] == 'createdAt');
      if (!hasCreatedAt) {
        final hasAcceptAt = columns.any((column) => column['name'] == 'acceptAt');
        if (hasAcceptAt) {
          await db.execute('ALTER TABLE users RENAME COLUMN acceptAt TO createdAt');
          debugPrint("Dynamic migration: Renamed acceptAt to createdAt in users table.");
        } else {
          await db.execute('ALTER TABLE users ADD COLUMN createdAt TEXT');
          debugPrint("Dynamic migration: Added createdAt column to users table.");
        }
      }
    } catch (e) {
      debugPrint("Error in dynamic migration check: $e");
    }

    return db;
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
        createdAt TEXT,
        department TEXT,
        sync INTEGER DEFAULT 1
      )
    ''');

    // إنشاء جدول الأقسام مع عمود firestore_id و created_at والحقول الجديدة
    await db.execute('''
      CREATE TABLE departments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firestore_id TEXT,
        name TEXT NOT NULL,
        head_id TEXT NOT NULL,
        head_name TEXT NOT NULL,
        sync INTEGER DEFAULT 0,
        created_at TEXT,
        levels_count INTEGER DEFAULT 4,
        has_tracks INTEGER DEFAULT 0,
        tracks TEXT DEFAULT '[]',
        start_level_for_tracks INTEGER
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
        sync_status INTEGER DEFAULT 0,
        department_id TEXT,
        level INTEGER
      )
    ''');

    // إنشاء جدول تهيئة حسابات الطلاب
    await db.execute('''
      CREATE TABLE "Configure student accounts" (
        registration_id TEXT PRIMARY KEY,
        student_name TEXT NOT NULL,
        email TEXT NOT NULL,
        department TEXT NOT NULL,
        level TEXT NOT NULL,
        track TEXT NOT NULL,
        sync INTEGER DEFAULT 0
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
        await db.execute(
          'ALTER TABLE departments ADD COLUMN firestore_id TEXT',
        );
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
          await txn.execute(
            'ALTER TABLE faculty_accounts RENAME TO faculty_accounts_old',
          );

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
        debugPrint(
          "Database successfully upgraded to version 8 (removed department column from faculty_accounts).",
        );
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
        debugPrint(
          "Database successfully upgraded to version 9 (added course_assignments table).",
        );
      } catch (e) {
        debugPrint("Error upgrading to version 9: $e");
      }
    }
    if (oldVersion < 10) {
      try {
        await db.execute('ALTER TABLE course_assignments ADD COLUMN room TEXT');
        debugPrint(
          "Database successfully upgraded to version 10 (added room column to course_assignments).",
        );
      } catch (e) {
        debugPrint("Error upgrading to version 10: $e");
      }
    }
    if (oldVersion < 11) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS "Configure student accounts" (
            registration_id TEXT PRIMARY KEY,
            student_name TEXT NOT NULL,
            email TEXT NOT NULL,
            department TEXT NOT NULL,
            level TEXT NOT NULL,
            track TEXT NOT NULL,
            sync INTEGER DEFAULT 0
          )
        ''');
        debugPrint(
          "Database successfully upgraded to version 11 (added Configure student accounts table).",
        );
      } catch (e) {
        debugPrint("Error upgrading to version 11: $e");
      }
      if (oldVersion < 12) {
        try {
          await db.transaction((txn) async {
            await txn.execute(
              'ALTER TABLE users RENAME COLUMN acceptAt TO createdAt',
            );
          });
          debugPrint(
            "Database successfully upgraded to version 12 (renamed acceptAt to createdAt in users).",
          );
        } catch (e) {
          debugPrint("Error upgrading to version 12: $e");
          try {
            await db.execute('ALTER TABLE users ADD COLUMN createdAt TEXT');
          } catch (innerEx) {
            debugPrint(
              "Error adding createdAt column in version 12 fallback: $innerEx",
            );
          }
        }
      }
    }

    if (oldVersion < 13) {
      try {
        await db.execute('ALTER TABLE departments ADD COLUMN levels_count INTEGER DEFAULT 4');
        await db.execute('ALTER TABLE departments ADD COLUMN has_tracks INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE departments ADD COLUMN tracks TEXT DEFAULT \'[]\'');
        await db.execute('ALTER TABLE departments ADD COLUMN start_level_for_tracks INTEGER');
        debugPrint(
          "Database successfully upgraded to version 13 (added levels_count, has_tracks, tracks, and start_level_for_tracks columns to departments).",
        );
      } catch (e) {
        debugPrint("Error upgrading to version 13: $e");
      }
    }

    if (oldVersion < 14) {
      try {
        await db.execute('ALTER TABLE course_assignments ADD COLUMN department_id TEXT');
        await db.execute('ALTER TABLE course_assignments ADD COLUMN level INTEGER');
        debugPrint(
          "Database successfully upgraded to version 14 (added department_id and level columns to course_assignments).",
        );
      } catch (e) {
        debugPrint("Error upgrading to version 14: $e");
      }
    }
  }

  // حفظ أو تحديث بيانات مستخدم
  Future<int> saveUser(Map<String, dynamic> userMap, {int syncVal = 1}) async {
    final db = await instance.database;
    return await db.insert('users', {
      'id': userMap['id'] ?? '',
      'name': userMap['name'] ?? '',
      'email': userMap['email'] ?? '',
      'role': userMap['role'] ?? '',
      'createAt':
          userMap['createAt']?.toString() ?? userMap['createdAt']?.toString(),
      'createdAt':
          userMap['createdAt']?.toString() ??
          userMap['acceptAt']?.toString() ??
          userMap['acceptedAt']?.toString(),
      'department': userMap['department']?.toString(),
      'sync': userMap['sync'] ?? syncVal,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
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
  Future<int> updateUserRoleAndDepartment(
    String id,
    String role,
    String? department, {
    int sync = 0,
  }) async {
    final db = await instance.database;
    return await db.update(
      'faculty_users',
      {'role': role, 'department': department, 'sync': sync},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // جلب بيانات مستخدم بواسطة المعرف (id)
  Future<Map<String, dynamic>?> getUser(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      'users',
      columns: [
        'id',
        'name',
        'email',
        'role',
        'createAt',
        'createdAt',
        'department',
        'sync',
      ],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return maps.first;
    }

    // إذا لم يوجد في جدول users، نبحث في جدول faculty_users
    final facultyMaps = await db.query(
      'faculty_users',
      columns: [
        'id',
        'name',
        'email',
        'role',
        'createAt',
        'acceptAt',
        'department',
        'sync',
      ],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (facultyMaps.isNotEmpty) {
      return facultyMaps.first;
    }
    return null;
  }

  // جلب بيانات عضو هيئة التدريس بواسطة المعرف (id)
  Future<Map<String, dynamic>?> getFacultyUser(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      'faculty_users',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  // --- دوال حسابات أعضاء هيئة التدريس (faculty_accounts) ---

  Future<int> saveFacultyAccount(
    Map<String, dynamic> accountMap, {
    int syncVal = 1,
  }) async {
    final db = await instance.database;
    return await db.insert('faculty_accounts', {
      'id': accountMap['id'] ?? '',
      'name': accountMap['name'] ?? '',
      'email': accountMap['email'] ?? '',
      'role': accountMap['role'] ?? 'عضو هيئة تدريس',
      'createAt':
          accountMap['createAt']?.toString() ??
          accountMap['createdAt']?.toString(),
      'acceptAt':
          accountMap['acceptAt']?.toString() ??
          accountMap['acceptedAt']?.toString(),
      'sync': accountMap['sync'] ?? syncVal,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
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
  Future<int> insertDepartment(
    String name,
    String headId,
    String headName, {
    int sync = 0,
    String? firestoreId,
    String? createdAt,
    int levelsCount = 4,
    bool hasTracks = false,
    List<String> tracks = const [],
    int? startLevelForTracks,
  }) async {
    final db = await instance.database;
    return await db.insert('departments', {
      'name': name,
      'head_id': headId,
      'head_name': headName,
      'sync': sync,
      'firestore_id': firestoreId,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
      'levels_count': levelsCount,
      'has_tracks': hasTracks ? 1 : 0,
      'tracks': jsonEncode(tracks),
      'start_level_for_tracks': startLevelForTracks,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // تحديث بيانات قسم موجود
  Future<int> updateDepartment(
    int localId,
    String name,
    String headId,
    String headName, {
    int sync = 0,
    String? firestoreId,
    int levelsCount = 4,
    bool hasTracks = false,
    List<String> tracks = const [],
    int? startLevelForTracks,
  }) async {
    final db = await instance.database;
    return await db.update(
      'departments',
      {
        'name': name,
        'head_id': headId,
        'head_name': headName,
        'sync': sync,
        if (firestoreId != null) 'firestore_id': firestoreId,
        'levels_count': levelsCount,
        'has_tracks': hasTracks ? 1 : 0,
        'tracks': jsonEncode(tracks),
        'start_level_for_tracks': startLevelForTracks,
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
    return await db.query(
      'departments',
      where: 'sync != 2',
      orderBy: 'id DESC',
    );
  }

  // جلب الأقسام المحذوفة محلياً وبانتظار المزامنة مع السيرفر
  Future<List<Map<String, dynamic>>> getDeletedDepartments() async {
    final db = await instance.database;
    return await db.query('departments', where: 'sync = 2');
  }

  // حذف قسم نهائياً من قاعدة البيانات المحلية
  Future<int> deleteDepartmentFully(int id) async {
    final db = await instance.database;
    return await db.delete('departments', where: 'id = ?', whereArgs: [id]);
  }

  // حفظ أو تحديث بيانات مستخدم عضو هيئة تدريس
  Future<int> saveFacultyUser(
    Map<String, dynamic> userMap, {
    int syncVal = 1,
  }) async {
    final db = await instance.database;
    return await db.insert('faculty_users', {
      'id': userMap['id'] ?? '',
      'name': userMap['name'] ?? '',
      'email': userMap['email'] ?? '',
      'role': userMap['role'] ?? 'عضو هيئة تدريس',
      'createAt':
          userMap['createAt']?.toString() ?? userMap['createdAt']?.toString(),
      'acceptAt':
          userMap['acceptAt']?.toString() ?? userMap['acceptedAt']?.toString(),
      'department': userMap['department']?.toString() ?? 'غير محدد',
      'sync': userMap['sync'] ?? syncVal,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // مسح جميع مستخدمي أعضاء هيئة التدريس من قاعدة البيانات المحلية
  Future<int> clearFacultyUsers() async {
    final db = await instance.database;
    return await db.delete('faculty_users');
  }

  // حذف عضو هيئة تدريس مسجل من قاعدة البيانات المحلية
  Future<int> deleteFacultyUser(String id) async {
    final db = await instance.database;
    return await db.delete('faculty_users', where: 'id = ?', whereArgs: [id]);
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
  Future<int> updateCourseAssignmentSyncStatus(
    String id,
    int syncStatus,
  ) async {
    final db = await instance.database;
    return await db.update(
      'course_assignments',
      {'sync_status': syncStatus},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// جلب جميع تعيينات المواد الدراسية المحلية (غير المحذوفة محلياً).
  Future<List<Map<String, dynamic>>> getAllCourseAssignments() async {
    final db = await instance.database;
    return await db.query(
      'course_assignments',
      where: 'sync_status != 2',
      orderBy: 'subject_name ASC',
    );
  }

  /// جلب التعيينات المحذوفة محلياً وبانتظار المزامنة مع السيرفر.
  Future<List<Map<String, dynamic>>> getDeletedCourseAssignments() async {
    final db = await instance.database;
    return await db.query('course_assignments', where: 'sync_status = 2');
  }

  /// حذف تعيين مادة دراسية من قاعدة البيانات المحلية (سوفت دليت إذا كانت مزامنة).
  Future<int> deleteCourseAssignment(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      'course_assignments',
      columns: ['sync_status'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      final syncStatus = maps.first['sync_status'] as int? ?? 0;
      if (syncStatus == 1) {
        // إذا كانت المادة مرفوعة مسبقاً، نغير حالتها إلى 2 ليتم حذفها من السيرفر لاحقاً
        return await db.update(
          'course_assignments',
          {'sync_status': 2},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }

    // إذا لم تكن مرفوعة بعد (0)، نحذفها مباشرة
    return await db.delete(
      'course_assignments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// حذف تعيين مادة دراسية نهائياً من قاعدة البيانات المحلية بعد المزامنة.
  Future<int> deleteCourseAssignmentFully(String id) async {
    final db = await instance.database;
    return await db.delete(
      'course_assignments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- دوال تهيئة حسابات الطلاب (Configure student accounts) ---

  Future<int> saveStudentAccountConfig(Map<String, dynamic> configMap) async {
    final db = await instance.database;
    return await db.insert('"Configure student accounts"', {
      'registration_id': configMap['registration_id'] ?? '',
      'student_name': configMap['student_name'] ?? '',
      'email': configMap['email'] ?? '',
      'department': configMap['department'] ?? '',
      'level': configMap['level'] ?? '',
      'track': configMap['track'] ?? '',
      'sync': configMap['sync'] ?? 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedStudentAccountConfigs() async {
    final db = await instance.database;
    return await db.query('"Configure student accounts"', where: 'sync = 0');
  }

  Future<int> updateStudentAccountConfigSyncStatus(
    String registrationId,
    int syncStatus,
  ) async {
    final db = await instance.database;
    return await db.update(
      '"Configure student accounts"',
      {'sync': syncStatus},
      where: 'registration_id = ?',
      whereArgs: [registrationId],
    );
  }

  Future<List<Map<String, dynamic>>> getAllStudentAccountConfigs() async {
    final db = await instance.database;
    return await db.query(
      '"Configure student accounts"',
      where: 'sync != 2',
      orderBy: 'student_name ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getDeletedStudentAccountConfigs() async {
    final db = await instance.database;
    return await db.query('"Configure student accounts"', where: 'sync = 2');
  }

  Future<int> deleteStudentAccountConfig(String registrationId) async {
    final db = await instance.database;
    final maps = await db.query(
      '"Configure student accounts"',
      columns: ['sync'],
      where: 'registration_id = ?',
      whereArgs: [registrationId],
    );

    if (maps.isNotEmpty) {
      final syncStatus = maps.first['sync'] as int? ?? 0;
      if (syncStatus == 1) {
        // إذا كان مسجلاً ومرفوعاً للسيرفر، نقوم بعملية soft delete بتعيين sync = 2
        return await db.update(
          '"Configure student accounts"',
          {'sync': 2},
          where: 'registration_id = ?',
          whereArgs: [registrationId],
        );
      }
    }

    // إذا كان غير مرفوع (0)، نحذفه نهائياً مباشرة
    return await db.delete(
      '"Configure student accounts"',
      where: 'registration_id = ?',
      whereArgs: [registrationId],
    );
  }

  Future<int> deleteStudentAccountConfigFully(String registrationId) async {
    final db = await instance.database;
    return await db.delete(
      '"Configure student accounts"',
      where: 'registration_id = ?',
      whereArgs: [registrationId],
    );
  }

  Future<bool> isRegistrationIdExists(String registrationId) async {
    final db = await instance.database;
    final maps = await db.query(
      '"Configure student accounts"',
      columns: ['registration_id'],
      where: 'registration_id = ? AND sync != 2',
      whereArgs: [registrationId],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  Future<bool> isStudentEmailExists(
    String email, {
    String? excludeRegistrationId,
  }) async {
    final db = await instance.database;
    List<Map<String, dynamic>> maps;
    if (excludeRegistrationId != null) {
      maps = await db.query(
        '"Configure student accounts"',
        where: 'email = ? AND registration_id != ? AND sync != 2',
        whereArgs: [email, excludeRegistrationId],
      );
    } else {
      maps = await db.query(
        '"Configure student accounts"',
        where: 'email = ? AND sync != 2',
        whereArgs: [email],
      );
    }
    return maps.isNotEmpty;
  }

  Future<int> clearStudentAccountConfigs() async {
    final db = await instance.database;
    return await db.delete('"Configure student accounts"');
  }
}
