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
      version: 1,
      onCreate: _createDB,
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

  // مسح جميع المستخدمين من قاعدة البيانات المحلية (عند تسجيل الخروج مثلاً)
  Future<int> clearUsers() async {
    final db = await instance.database;
    return await db.delete('users');
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
