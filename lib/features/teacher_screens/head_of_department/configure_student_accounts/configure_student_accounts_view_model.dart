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

  final List<String> levels = [
    'المستوى الأول',
    'المستوى الثاني',
    'المستوى الثالث',
    'المستوى الرابع',
  ];

  final List<String> tracks = ['الخطة العامة', 'برمجيات', 'شبكات'];

  ConfigureStudentAccountsViewModel() {
    _loadDepartment();
    fetchConfigs();
  }

  Future<void> _loadDepartment() async {
    final prefs = await SharedPreferences.getInstance();
    _department = prefs.getString('department') ?? 'غير مححدد';
    if (_department == 'غير محدد' || _department == 'غير مححدد') {
      // محاولة استرجاع القسم من قاعدة البيانات المحلية لمزيد من الموثوقية
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
    notifyListeners();
  }

  void setLevel(String value) {
    _selectedLevel = value;
    notifyListeners();
  }

  void setTrack(String value) {
    _selectedTrack = value;
    notifyListeners();
  }

  Future<void> fetchConfigs() async {
    _isLoading = true;
    notifyListeners();
    try {
      final maps = await DatabaseHelper.instance.getAllStudentAccountConfigs();
      _configs = maps.map((m) => StudentAccountConfigModel.fromMap(m)).toList();
    } catch (e) {
      _errorMessage = 'حدث خطأ أثناء تحميل الحسابات المحلية: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // استيراد ومعالجة ملف Excel أو CSV
  Future<void> importStudentAccounts() async {
    _isLoading = true;
    _successMessage = null;
    _errorMessage = null;
    notifyListeners();

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
      );

      if (result == null || result.files.single.path == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final filePath = result.files.single.path!;
      final fileExtension = filePath.split('.').last.toLowerCase();
      List<Map<String, String>> studentsData = [];

      if (fileExtension == 'xlsx') {
        // قراءة ملف Excel (.xlsx)
        final bytes = File(filePath).readAsBytesSync();
        final decoder = SpreadsheetDecoder.decodeBytes(bytes);
        for (var tableName in decoder.tables.keys) {
          var table = decoder.tables[tableName];
          if (table == null || table.rows.isEmpty) continue;

          // تحديد فهارس الأعمدة بناءً على العناوين
          var firstRow = table.rows.first;
          int nameIndex = -1;
          int regIndex = -1;
          int emailIndex = -1;

          for (int i = 0; i < firstRow.length; i++) {
            final cellVal = firstRow[i]?.toString().trim();
            if (cellVal == "اسم الطالب") nameIndex = i;
            if (cellVal == "رقم القيد") regIndex = i;
            if (cellVal == "البريد الإلكتروني") emailIndex = i;
          }

          // فحص بديل إذا لم يعثر على العناوين بالاسم
          if (nameIndex == -1) nameIndex = 0;
          if (regIndex == -1) regIndex = 1;
          if (emailIndex == -1) emailIndex = 2;

          for (int r = 1; r < table.rows.length; r++) {
            var row = table.rows[r];
            if (row.length <= nameIndex ||
                row.length <= regIndex ||
                row.length <= emailIndex)
              continue;

            String name = row[nameIndex]?.toString().trim() ?? '';
            String regId = row[regIndex]?.toString().trim() ?? '';
            String email = row[emailIndex]?.toString().trim() ?? '';

            if (name.isNotEmpty && regId.isNotEmpty && email.isNotEmpty) {
              studentsData.add({
                'name': name,
                'registration_id': regId,
                'email': email,
              });
            }
          }
        }
      } else if (fileExtension == 'csv') {
        // قراءة ملف CSV (.csv)
        final csvFile = File(filePath);
        final csvString = await csvFile.readAsString(encoding: utf8);
        final List<List<dynamic>> rows = const CsvToListConverter().convert(
          csvString,
        );

        if (rows.isNotEmpty) {
          var firstRow = rows.first;
          int nameIndex = -1;
          int regIndex = -1;
          int emailIndex = -1;

          for (int i = 0; i < firstRow.length; i++) {
            final cellVal = firstRow[i]?.toString().trim();
            if (cellVal == "اسم الطالب") nameIndex = i;
            if (cellVal == "رقم القيد") regIndex = i;
            if (cellVal == "البريد الإلكتروني") emailIndex = i;
          }

          if (nameIndex == -1) nameIndex = 0;
          if (regIndex == -1) regIndex = 1;
          if (emailIndex == -1) emailIndex = 2;

          for (int r = 1; r < rows.length; r++) {
            var row = rows[r];
            if (row.length <= nameIndex ||
                row.length <= regIndex ||
                row.length <= emailIndex)
              continue;

            String name = row[nameIndex]?.toString().trim() ?? '';
            String regId = row[regIndex]?.toString().trim() ?? '';
            String email = row[emailIndex]?.toString().trim() ?? '';

            if (name.isNotEmpty && regId.isNotEmpty && email.isNotEmpty) {
              studentsData.add({
                'name': name,
                'registration_id': regId,
                'email': email,
              });
            }
          }
        }
      }

      if (studentsData.isEmpty) {
        throw Exception(
          'الملف فارغ أو لا يحتوي على التنسيق المطلوب (اسم الطالب، رقم القيد، البريد الإلكتروني)',
        );
      }

      // حفظ البيانات في SQLite
      int savedCount = 0;
      int skippedDuplicates = 0;
      final Set<String> processedEmails = {};
      final Set<String> processedRegIds = {};

      for (var student in studentsData) {
        final regId = student['registration_id']!;
        final email = student['email']!;
        final name = student['name']!;

        // تلافي التكرار داخل نفس الملف المرفوع
        if (processedRegIds.contains(regId) || processedEmails.contains(email)) {
          skippedDuplicates++;
          continue;
        }

        // تلافي تكرار البريد الإلكتروني مع أي طالب آخر في قاعدة البيانات
        final emailExists = await DatabaseHelper.instance.isStudentEmailExists(email, excludeRegistrationId: regId);
        if (emailExists) {
          skippedDuplicates++;
          continue;
        }

        processedRegIds.add(regId);
        processedEmails.add(email);

        final model = StudentAccountConfigModel(
          registrationId: regId,
          studentName: name,
          email: email,
          department: _department,
          level: _selectedLevel,
          track: _selectedTrack,
          syncStatus: 0,
        );

        await DatabaseHelper.instance.saveStudentAccountConfig(model.toMap());
        savedCount++;
      }

      if (savedCount == 0 && skippedDuplicates > 0) {
        throw Exception('جميع الطلاب في الملف مكررين بالفعل (سواء رقم القيد أو البريد الإلكتروني).');
      }

      _successMessage = skippedDuplicates > 0
          ? 'تم استيراد وحفظ $savedCount طالب محلياً بنجاح. (تم تخطي $skippedDuplicates سجلات مكررة)'
          : 'تم استيراد وحفظ $savedCount طالب محلياً بنجاح.';
      await fetchConfigs();

      // محاولة المزامنة تلقائياً مع السيرفر
      try {
        await SyncService.instance.syncStudentAccountConfigsOnly(
          department: _department,
        );
        await fetchConfigs();
        _successMessage = skippedDuplicates > 0
            ? 'تم استيراد وحفظ $savedCount طالب ومزامنتهم تلقائياً. (تم تخطي $skippedDuplicates سجلات مكررة)'
            : 'تم استيراد وحفظ $savedCount طالب ومزامنتهم مع السيرفر تلقائياً.';
      } catch (syncError) {
        debugPrint('Auto sync failed (saved locally): $syncError');
        _successMessage = skippedDuplicates > 0
            ? 'تم حفظ $savedCount طالب محلياً. (تم تخطي $skippedDuplicates مكررين، وسيتم المزامنة عند توفر اتصال بالإنترنت)'
            : 'تم حفظ $savedCount طالب محلياً. (سيتم مزامنتهم عند توفر اتصال بالإنترنت)';
      }
    } catch (e) {
      _errorMessage =
          'فشل استيراد الملف: ${e.toString().replaceAll('Exception:', '')}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // إضافة حساب طالب يدوياً
  Future<void> addStudentAccountConfig({
    required String name,
    required String registrationId,
    required String email,
  }) async {
    if (name.trim().isEmpty ||
        registrationId.trim().isEmpty ||
        email.trim().isEmpty) {
      _errorMessage = 'الرجاء ملء جميع الحقول المطلوبة.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _successMessage = null;
    _errorMessage = null;
    notifyListeners();

    try {
      // التحقق من تكرار رقم القيد
      final allConfigs = await DatabaseHelper.instance.getAllStudentAccountConfigs();
      final registrationIdExists = allConfigs.any((c) => c['registration_id'] == registrationId.trim());
      if (registrationIdExists) {
        _errorMessage = 'رقم القيد هذا مستخدم بالفعل لطالب آخر.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // التحقق من تكرار البريد الإلكتروني
      final emailExists = await DatabaseHelper.instance.isStudentEmailExists(email.trim());
      if (emailExists) {
        _errorMessage = 'البريد الإلكتروني هذا مستخدم بالفعل لطالب آخر.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final model = StudentAccountConfigModel(
        registrationId: registrationId.trim(),
        studentName: name.trim(),
        email: email.trim(),
        department: _department,
        level: _selectedLevel,
        track: _selectedTrack,
        syncStatus: 0,
      );

      await DatabaseHelper.instance.saveStudentAccountConfig(model.toMap());
      await fetchConfigs();
      _successMessage = 'تم إضافة الطالب "$name" محلياً بنجاح.';

      // محاولة المزامنة تلقائياً
      try {
        await SyncService.instance.syncStudentAccountConfigsOnly(
          department: _department,
        );
        await fetchConfigs();
        _successMessage =
            'تم إضافة الطالب "$name" ومزامنته مع السيرفر تلقائياً.';
      } catch (syncError) {
        debugPrint('Auto sync failed (saved locally): $syncError');
        _successMessage =
            'تم إضافة الطالب "$name" محلياً (سيتم مزامنته عند توفر اتصال بالإنترنت).';
      }
    } catch (e) {
      _errorMessage = 'فشلت إضافة الطالب: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // مزامنة يدوية
  Future<void> syncConfigs() async {
    _isLoading = true;
    _successMessage = null;
    _errorMessage = null;
    notifyListeners();

    try {
      await SyncService.instance.syncStudentAccountConfigsOnly(
        department: _department,
      );
      await fetchConfigs();
      _successMessage = 'تمت مزامنة كافة إعدادات الطلاب بنجاح.';
    } catch (e) {
      final errorMsg = e.toString().contains('no_internet')
          ? 'لا يوجد اتصال بالإنترنت حالياً.'
          : 'فشلت المزامنة: $e';
      _errorMessage = errorMsg;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    _successMessage = null;
    _errorMessage = null;
    notifyListeners();
  }

  // حذف تكوين طالب
  Future<void> deleteConfig(String regId) async {
    await DatabaseHelper.instance.deleteStudentAccountConfig(regId);
    await fetchConfigs();

    // محاولة مزامنة الحذف مع السيرفر
    try {
      await SyncService.instance.syncStudentAccountConfigsOnly(
        department: _department,
      );
    } catch (e) {
      debugPrint('Auto sync deletion failed (marked for offline deletion): $e');
    }
  }

  // تعديل حساب طالب
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

    _isLoading = true;
    _successMessage = null;
    _errorMessage = null;
    notifyListeners();

    try {
      // التحقق من تكرار البريد الإلكتروني مع طالب آخر
      final emailExists = await DatabaseHelper.instance.isStudentEmailExists(email.trim(), excludeRegistrationId: registrationId);
      if (emailExists) {
        _errorMessage = 'البريد الإلكتروني هذا مستخدم بالفعل لطالب آخر.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final model = StudentAccountConfigModel(
        registrationId: registrationId,
        studentName: name.trim(),
        email: email.trim(),
        department: _department,
        level: level,
        track: track,
        syncStatus: 0, // يعاد تعيينه كـ 0 لمزامنته مجدداً كـ تحديث/تعديل
      );

      await DatabaseHelper.instance.saveStudentAccountConfig(model.toMap());
      await fetchConfigs();
      _successMessage = 'تم تعديل بيانات الطالب "$name" محلياً بنجاح.';

      // محاولة المزامنة تلقائياً
      try {
        await SyncService.instance.syncStudentAccountConfigsOnly(
          department: _department,
        );
        await fetchConfigs();
        _successMessage =
            'تم تعديل بيانات الطالب "$name" ومزامنتها مع السيرفر تلقائياً.';
      } catch (syncError) {
        debugPrint('Auto sync failed for update (saved locally): $syncError');
      }
    } catch (e) {
      _errorMessage = 'فشل تعديل بيانات الطالب: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
