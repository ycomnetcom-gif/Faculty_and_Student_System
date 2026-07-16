import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:csv/csv.dart';
import 'package:student_attendance_system/core/database_helper.dart';
import 'package:student_attendance_system/core/sync_service.dart';
import 'student_account_config_model.dart';

class ConfigureStudentAccountsViewModel extends ChangeNotifier {
  bool _isLoading = false;
  String _department = 'جاري التحميل...';
  String _selectedLevel = 'المستوى الأول';
  String _selectedTrack = 'الخطة العامة';
  List<StudentAccountConfigModel> _configs = [];
  String? _successMessage;
  String? _errorMessage;

  // Getters
  bool get isLoading => _isLoading;
  String get department => _department;
  String get selectedLevel => _selectedLevel;
  String get selectedTrack => _selectedTrack;
  List<StudentAccountConfigModel> get configs => _configs;
  String? get successMessage => _successMessage;
  String? get errorMessage => _errorMessage;

  List<String> _levels = [
    'المستوى الأول',
    'المستوى الثاني',
    'المستوى الثالث',
    'المستوى الرابع',
  ];
  List<String> get levels => _levels;

  List<String> _tracks = ['الخطة العامة'];
  List<String> get tracks => _tracks;

  ConfigureStudentAccountsViewModel() {
    _loadDepartment();
    fetchConfigs();
  }

  // ─── دالة مساعدة لتقليل تكرار بوابة التحميل ──────────────────────────────
  Future<void> _runOperation(Future<void> Function() action) async {
    _isLoading = true;
    _successMessage = null;
    _errorMessage = null;
    notifyListeners();
    try {
      await action();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── مساعد: تحديث القائمة من DB مباشرةً ─────────────────────────────────
  Future<void> _refreshLocalConfigs() async {
    final maps = await DatabaseHelper.instance.getAllStudentAccountConfigs();
    _configs = maps.map((m) => StudentAccountConfigModel.fromMap(m)).toList();
  }

  // ─── تحميل بيانات القسم ──────────────────────────────────────────────────
  Future<void> _loadDepartment() async {
    final prefs = await SharedPreferences.getInstance();
    _department = prefs.getString('department') ?? 'غير محدد';
    if (_department == 'غير محدد' || _department == 'غير مححدد') {
      try {
        final userId = prefs.getString('id');
        if (userId != null) {
          final localUser = await DatabaseHelper.instance.getUser(userId);
          if (localUser != null && localUser['department'] != null) {
            _department = localUser['department'];
          }
        }
      } catch (e) {
        debugPrint('Error retrieving local user department: $e');
      }
    }
    await _loadLevelsAndTracksFromDb();
    notifyListeners();
  }

  Future<void> _loadLevelsAndTracksFromDb() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> result = await db.query(
        'departments',
        where: 'name = ? AND sync != 2',
        whereArgs: [_department],
        limit: 1,
      );

      if (result.isNotEmpty) {
        final row = result.first;
        _updateLevelsList(row['levels_count'] is int ? row['levels_count'] : 4);

        final int hasTracksVal = row['has_tracks'] is int ? row['has_tracks'] : 0;
        if (hasTracksVal == 1 && row['tracks'] != null) {
          try {
            final parsed = List<String>.from(jsonDecode(row['tracks'] as String));
            final unique = <String>{'الخطة العامة'};
            unique.addAll(parsed.where((t) => t.trim().isNotEmpty));
            _tracks = unique.toList();
          } catch (e) {
            debugPrint('Error parsing tracks: $e');
            _tracks = ['الخطة العامة'];
          }
        } else {
          _tracks = ['الخطة العامة'];
        }
      } else {
        _updateLevelsList(4);
        _tracks = ['الخطة العامة'];
      }
    } catch (e) {
      debugPrint('Error loading department config from local DB: $e');
      _updateLevelsList(4);
      _tracks = ['الخطة العامة'];
    }

    if (!_tracks.contains(_selectedTrack)) _selectedTrack = _tracks.first;
  }

  void _updateLevelsList(int count) {
    const arabicLevels = [
      'المستوى الأول',
      'المستوى الثاني',
      'المستوى الثالث',
      'المستوى الرابع',
      'المستوى الخامس',
      'المستوى السادس',
      'المستوى السابع',
      'المستوى الثامن',
    ];
    _levels = arabicLevels.take(count).toList();
    if (_levels.isEmpty) _levels = ['المستوى الأول'];
    if (!_levels.contains(_selectedLevel)) _selectedLevel = _levels.first;
  }

  void setLevel(String value) {
    _selectedLevel = value;
    notifyListeners();
  }

  void setTrack(String value) {
    _selectedTrack = value;
    notifyListeners();
  }

  // ─── جلب القائمة المحلية ──────────────────────────────────────────────────
  Future<void> fetchConfigs() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _refreshLocalConfigs();
    } catch (e) {
      _errorMessage = 'حدث خطأ أثناء تحميل الحسابات المحلية: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── مساعدات قراءة ملفات الاستيراد ──────────────────────────────────────

  List<int?> _detectColumnIndices(List<dynamic> headerRow) {
    int? nameIdx, regIdx, emailIdx;
    for (int i = 0; i < headerRow.length; i++) {
      final v = headerRow[i]?.toString().trim();
      if (v == 'اسم الطالب') nameIdx = i;
      if (v == 'رقم القيد') regIdx = i;
      if (v == 'البريد الإلكتروني') emailIdx = i;
    }
    return [nameIdx ?? 0, regIdx ?? 1, emailIdx ?? 2];
  }

  Map<String, String>? _extractRow(List<dynamic> row, List<int?> idx) {
    final ni = idx[0]!, ri = idx[1]!, ei = idx[2]!;
    if (row.length <= ni || row.length <= ri || row.length <= ei) return null;
    final name = row[ni].toString().trim();
    final regId = row[ri].toString().trim();
    final email = row[ei].toString().trim();
    if (name.isEmpty || regId.isEmpty || email.isEmpty) return null;
    return {'name': name, 'registration_id': regId, 'email': email};
  }

  List<Map<String, String>> _parseXlsx(String filePath) {
    final data = <Map<String, String>>[];
    final bytes = File(filePath).readAsBytesSync();
    final decoder = SpreadsheetDecoder.decodeBytes(bytes);
    for (final tableName in decoder.tables.keys) {
      final table = decoder.tables[tableName];
      if (table == null || table.rows.isEmpty) continue;
      final idx = _detectColumnIndices(table.rows.first);
      for (int r = 1; r < table.rows.length; r++) {
        final entry = _extractRow(table.rows[r], idx);
        if (entry != null) data.add(entry);
      }
    }
    return data;
  }

  Future<List<Map<String, String>>> _parseCsv(String filePath) async {
    final data = <Map<String, String>>[];
    final csvString = await File(filePath).readAsString(encoding: utf8);
    final rows = const CsvToListConverter().convert(csvString);
    if (rows.isEmpty) return data;
    final idx = _detectColumnIndices(rows.first);
    for (int r = 1; r < rows.length; r++) {
      final entry = _extractRow(rows[r], idx);
      if (entry != null) data.add(entry);
    }
    return data;
  }

  // ─── استيراد ملف Excel / CSV ──────────────────────────────────────────────
  Future<void> importStudentAccounts() async {
    await _runOperation(() async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
      );
      if (result == null || result.files.single.path == null) return;

      final filePath = result.files.single.path!;
      final ext = filePath.split('.').last.toLowerCase();
      final studentsData = ext == 'xlsx'
          ? _parseXlsx(filePath)
          : await _parseCsv(filePath);

      if (studentsData.isEmpty) {
        throw Exception(
          'الملف فارغ أو لا يحتوي على التنسيق المطلوب (اسم الطالب، رقم القيد، البريد الإلكتروني)',
        );
      }

      int savedCount = 0;
      int skippedDuplicates = 0;
      final processedEmails = <String>{};
      final processedRegIds = <String>{};

      for (final student in studentsData) {
        final regId = student['registration_id']!;
        final email = student['email']!;
        final name = student['name']!;

        if (processedRegIds.contains(regId) || processedEmails.contains(email)) {
          skippedDuplicates++;
          continue;
        }
        if (await DatabaseHelper.instance.isRegistrationIdExists(regId)) {
          skippedDuplicates++;
          continue;
        }
        if (await DatabaseHelper.instance.isStudentEmailExists(email, excludeRegistrationId: regId)) {
          skippedDuplicates++;
          continue;
        }

        processedRegIds.add(regId);
        processedEmails.add(email);
        await DatabaseHelper.instance.saveStudentAccountConfig(
          StudentAccountConfigModel(
            registrationId: regId,
            studentName: name,
            email: email,
            department: _department,
            level: _selectedLevel,
            track: _selectedTrack,
            syncStatus: 0,
          ).toMap(),
        );
        savedCount++;
      }

      if (savedCount == 0 && skippedDuplicates > 0) {
        throw Exception('جميع الطلاب في الملف مكررين بالفعل.');
      }

      await _refreshLocalConfigs();
      _successMessage = skippedDuplicates > 0
          ? 'تم استيراد $savedCount طالب محلياً. (تم تخطي $skippedDuplicates مكررين)'
          : 'تم استيراد $savedCount طالب محلياً بنجاح.';

      // رفع فقط — بدون Pull لتوفير quota القراءة
      try {
        await SyncService.instance.syncStudentAccountConfigsOnly(department: _department);
        await _refreshLocalConfigs();
        _successMessage = skippedDuplicates > 0
            ? 'تم استيراد $savedCount طالب ومزامنتهم. (تم تخطي $skippedDuplicates مكررين)'
            : 'تم استيراد $savedCount طالب ومزامنتهم تلقائياً.';
      } catch (syncError) {
        debugPrint('Auto sync failed: $syncError');
        _successMessage = skippedDuplicates > 0
            ? 'تم حفظ $savedCount طالب محلياً. (تم تخطي $skippedDuplicates، المزامنة عند الإنترنت)'
            : 'تم حفظ $savedCount طالب محلياً. (سيتم مزامنتهم عند توفر الإنترنت)';
      }
    });
  }

  // ─── إضافة يدوية ─────────────────────────────────────────────────────────
  Future<void> addStudentAccountConfig({
    required String name,
    required String registrationId,
    required String email,
  }) async {
    if (name.trim().isEmpty || registrationId.trim().isEmpty || email.trim().isEmpty) {
      _errorMessage = 'الرجاء ملء جميع الحقول المطلوبة.';
      notifyListeners();
      return;
    }

    await _runOperation(() async {
      if (await DatabaseHelper.instance.isRegistrationIdExists(registrationId.trim())) {
        _errorMessage = 'رقم القيد هذا مستخدم بالفعل لطالب آخر.';
        return;
      }
      if (await DatabaseHelper.instance.isStudentEmailExists(email.trim())) {
        _errorMessage = 'البريد الإلكتروني هذا مستخدم بالفعل لطالب آخر.';
        return;
      }

      await DatabaseHelper.instance.saveStudentAccountConfig(
        StudentAccountConfigModel(
          registrationId: registrationId.trim(),
          studentName: name.trim(),
          email: email.trim(),
          department: _department,
          level: _selectedLevel,
          track: _selectedTrack,
          syncStatus: 0,
        ).toMap(),
      );

      await _refreshLocalConfigs();
      _successMessage = 'تم إضافة الطالب "$name" محلياً بنجاح.';

      try {
        await SyncService.instance.syncStudentAccountConfigsOnly(department: _department);
        await _refreshLocalConfigs();
        _successMessage = 'تم إضافة الطالب "$name" ومزامنته مع السيرفر تلقائياً.';
      } catch (syncError) {
        debugPrint('Auto sync failed: $syncError');
        _successMessage = 'تم إضافة الطالب "$name" محلياً (سيتم مزامنته عند توفر الإنترنت).';
      }
    });
  }

  // ─── مزامنة يدوية ────────────────────────────────────────────────────────
  Future<void> syncConfigs() async {
    await _runOperation(() async {
      try {
        await SyncService.instance.syncStudentAccountConfigsOnly(department: _department);
        await _refreshLocalConfigs();
        _successMessage = 'تمت مزامنة كافة إعدادات الطلاب بنجاح.';
      } catch (e) {
        _errorMessage = e.toString().contains('no_internet')
            ? 'لا يوجد اتصال بالإنترنت حالياً.'
            : 'فشلت المزامنة: $e';
      }
    });
  }

  void clearMessages() {
    _successMessage = null;
    _errorMessage = null;
    notifyListeners();
  }

  // ─── حذف ─────────────────────────────────────────────────────────────────
  Future<void> deleteConfig(String regId) async {
    await DatabaseHelper.instance.deleteStudentAccountConfig(regId);
    await _refreshLocalConfigs();
    notifyListeners();

    // مزامنة الحذف في الخلفية بدون تغيير حالة isLoading
    try {
      await SyncService.instance.syncStudentAccountConfigsOnly(department: _department);
    } catch (e) {
      debugPrint('Auto sync deletion failed: $e');
    }
  }

  // ─── تعديل ───────────────────────────────────────────────────────────────
  Future<void> updateStudentAccountConfig({
    required String registrationId,
    required String name,
    required String email,
    required String level,
    required String track,
  }) async {
    if (name.trim().isEmpty || email.trim().isEmpty) {
      _errorMessage = 'الرجاء ملء جميع الحقول المطلوبة.';
      notifyListeners();
      return;
    }

    await _runOperation(() async {
      if (await DatabaseHelper.instance.isStudentEmailExists(
        email.trim(),
        excludeRegistrationId: registrationId,
      )) {
        _errorMessage = 'البريد الإلكتروني هذا مستخدم بالفعل لطالب آخر.';
        return;
      }

      await DatabaseHelper.instance.saveStudentAccountConfig(
        StudentAccountConfigModel(
          registrationId: registrationId,
          studentName: name.trim(),
          email: email.trim(),
          department: _department,
          level: level,
          track: track,
          syncStatus: 0,
        ).toMap(),
      );

      await _refreshLocalConfigs();
      _successMessage = 'تم تعديل بيانات الطالب "$name" محلياً بنجاح.';

      try {
        await SyncService.instance.syncStudentAccountConfigsOnly(department: _department);
        await _refreshLocalConfigs();
        _successMessage = 'تم تعديل بيانات الطالب "$name" ومزامنتها مع السيرفر تلقائياً.';
      } catch (syncError) {
        debugPrint('Auto sync failed for update: $syncError');
      }
    });
  }
}
