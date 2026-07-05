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
      version: 4,
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

  // تحديث دور المستخدم
  Future<int> updateUserRole(String id, String role, {int sync = 0}) async {
    final db = await instance.database;
    return await db.update(
      'users',
      {
        'role': role,
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
      columns: ['id', 'name', 'email', 'role', 'createAt', 'acceptAt', 'sync'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return maps.first;
    } else {
      return null;
    }
  }

  // جلب جميع المستخدمين ذوي دور محدد
  Future<List<Map<String, dynamic>>> getUsersByRole(String role) async {
    final db = await instance.database;
    return await db.query(
      'users',
      where: 'role = ?',
      whereArgs: [role],
      orderBy: 'name ASC',
    );
  }

  // مسح جميع المستخدمين من قاعدة البيانات المحلية (عند تسجيل الخروج مثلاً)
  Future<int> clearUsers() async {
    final db = await instance.database;
    return await db.delete('users');
  }

  // حذف مستخدم بواسطة معرفه (id)
  Future<int> deleteUser(String id) async {
    final db = await instance.database;
    return await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
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

  // إغلاق قاعدة البيانات
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
