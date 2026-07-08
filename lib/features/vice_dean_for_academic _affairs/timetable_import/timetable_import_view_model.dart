import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:student_attendance_system/core/database_helper.dart';
import 'package:student_attendance_system/core/sync_service.dart';
import 'package:student_attendance_system/features/vice_dean_for_academic _affairs/timetable_import/course_assignment_model.dart';
import 'package:uuid/uuid.dart';

// ---------------------------------------------------------------------------
// Helper – Name Sanitizer
// ---------------------------------------------------------------------------

/// ينظّف أسماء المعلمين القادمة من ملف CSV بإزالة الألقاب الأكاديمية الشائعة
/// ثم تقليم المسافات الزائدة حتى يمكن مطابقتها مع أسماء قاعدة البيانات.
class NameSanitizer {
  /// الألقاب المراد إزالتها مرتّبة من الأطول إلى الأقصر لتجنّب التطابق الجزئي.
  static const List<String> _titlesToRemove = [
    'أ.م.د. ',
    'أ.د. ',
    'د. ',
    'م. ',
    'أ. ',
  ];

  /// يُرجع الاسم مجرداً من أي لقب أكاديمي معروف، ومقلَّم من المسافات.
  static String sanitize(String rawName) {
    String name = rawName.trim();
    for (final title in _titlesToRemove) {
      if (name.startsWith(title)) {
        name = name.substring(title.length).trim();
        break; // نزيل لقباً واحداً فقط
      }
    }
    return name.trim();
  }
}

// ---------------------------------------------------------------------------
// Data class – represents one parsed CSV row (after deduplication)
// ---------------------------------------------------------------------------

/// تمثّل تعيين مادة دراسية واحدة كما استُخرج من ملف CSV.
class TimetableRow {
  final String rawTeacherName;
  final String subjectName;
  final List<String> studentGroups;
  final String room;

  const TimetableRow({
    required this.rawTeacherName,
    required this.subjectName,
    required this.studentGroups,
    required this.room,
  });
}

// ---------------------------------------------------------------------------
// Enum – Import Step
// ---------------------------------------------------------------------------

enum ImportStep {
  /// الحالة الابتدائية: لم يُختر ملف بعد
  idle,

  /// هناك أسماء معلمين تحتاج ربطاً يدوياً
  manualMapping,

  /// اكتملت الربطات وأصبح الحفظ ممكناً
  readyToSave,

  /// تم الحفظ بنجاح
  done,
}

// ---------------------------------------------------------------------------
// ViewModel
// ---------------------------------------------------------------------------

class TimetableImportViewModel extends ChangeNotifier {
  // ----------------------------- State -------------------------------------

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _successMessage;
  String? get successMessage => _successMessage;

  String? _selectedFileName;
  String? get selectedFileName => _selectedFileName;

  /// الصفوف المحلَّلة من CSV بعد إزالة التكرار.
  List<TimetableRow> _parsedRows = [];
  List<TimetableRow> get parsedRows => List.unmodifiable(_parsedRows);

  /// جميع المعلمين المسجلين في النظام (مُسترجَعون من SQLite).
  List<Map<String, dynamic>> _registeredTeachers = [];
  List<Map<String, dynamic>> get registeredTeachers =>
      List.unmodifiable(_registeredTeachers);

  /// الأسماء التي لم يُعثر لها على تطابق تلقائي.
  List<String> _unmappedTeacherNames = [];
  List<String> get unmappedTeacherNames =>
      List.unmodifiable(_unmappedTeacherNames);

  /// خريطة التطابق التلقائي: rawName → teacherUid
  final Map<String, String> _autoMappings = {};

  /// خريطة الربط اليدوي (كاش): rawName → teacherUid
  /// تُحفظ طوال دورة حياة الـ ViewModel لتجنّب إعادة السؤال.
  final Map<String, String> _manualMappings = {};
  Map<String, String> get manualMappings => Map.unmodifiable(_manualMappings);

  ImportStep _currentStep = ImportStep.idle;
  ImportStep get currentStep => _currentStep;

  // ----------------------------- Public API --------------------------------

  /// يُحضّر قائمة المعلمين المسجلين من SQLite عند فتح الشاشة.
  /// الأدوار المعتمدة في النظام: "عضو هيئة تدريس"، "رئيس قسم"، "نائب العميد للشؤون الأكاديمية".
  Future<void> loadRegisteredTeachers() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.rawQuery(
        '''
        SELECT id, name FROM faculty_users
        WHERE role = 'عضو هيئة تدريس'
           OR role = 'رئيس قسم'
           OR role = 'نائب العميد للشؤون الأكاديمية'
        UNION
        SELECT id, name FROM users
        WHERE role = 'عضو هيئة تدريس'
           OR role = 'رئيس قسم'
           OR role = 'نائب العميد للشؤون الأكاديمية'
        ORDER BY name ASC
        ''',
      );
      _registeredTeachers = rows;
      notifyListeners();
    } catch (e) {
      debugPrint('TimetableImportVM: Error loading teachers: $e');
    }
  }

  /// يفتح نافذة اختيار الملف، يقرأ محتوى CSV، يحلّله، ويُطابق أسماء المعلمين.
  Future<void> pickAndParseFile() async {
    _clearMessages();
    _isLoading = true;
    _currentStep = ImportStep.idle;
    _parsedRows = [];
    _unmappedTeacherNames = [];
    _autoMappings.clear();
    notifyListeners();

    try {
      // 1. فتح نافذة اختيار الملف
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final pickedFile = result.files.first;
      _selectedFileName = pickedFile.name;

      // 2. قراءة محتوى الملف مع فك تشفير UTF-8 بشكل صحيح
      final String csvContent;
      if (pickedFile.bytes != null) {
        // Web – الملف متوفر كـ bytes مباشرة
        csvContent = utf8.decode(pickedFile.bytes!, allowMalformed: true);
      } else if (pickedFile.path != null) {
        // Desktop (Windows/Linux/macOS)
        final file = File(pickedFile.path!);
        final bytes = await file.readAsBytes();
        // utf8.decode بدلاً من String.fromCharCodes لتجنب تشويه الأحرف العربية
        csvContent = utf8.decode(bytes, allowMalformed: true);
      } else {
        throw Exception('لا يمكن قراءة الملف: مسار أو بيانات غير متاحة.');
      }

      // 3. تحليل CSV
      final List<List<dynamic>> csvTable = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(csvContent);

      if (csvTable.isEmpty) {
        throw Exception('الملف فارغ أو غير صالح.');
      }

      // 4. الكشف عن رؤوس الأعمدة (case-insensitive, trim)
      final headers = csvTable.first
          .map((h) => h.toString().trim().toLowerCase())
          .toList();

      final subjectIdx = _findColumnIndex(headers, 'subject');
      final teacherIdx = _findColumnIndex(headers, 'teachers');
      final groupsIdx  = _findColumnIndex(headers, 'student sets');
      final roomIdx    = _findColumnIndex(headers, 'room');

      if (subjectIdx == -1 || teacherIdx == -1 || groupsIdx == -1) {
        throw Exception(
          'تعذّر العثور على أعمدة مطلوبة.\n'
          'تأكد من وجود: Subject, Teachers, Student Sets.',
        );
      }

      // 5. استخراج الصفوف وإزالة التكرار (subject + teacher)
      final seen = <String>{};
      final List<TimetableRow> rows = [];

      for (int i = 1; i < csvTable.length; i++) {
        final row = csvTable[i];
        final maxIdx = [subjectIdx, teacherIdx, groupsIdx, roomIdx].reduce(
          (a, b) => a > b ? a : b,
        );
        if (row.length <= maxIdx) continue;

        final subject    = row[subjectIdx].toString().trim();
        final rawTeacher = row[teacherIdx].toString().trim();
        final rawGroups  = row[groupsIdx].toString().trim();
        final room       = roomIdx != -1 ? row[roomIdx].toString().trim() : '';

        if (subject.isEmpty || rawTeacher.isEmpty) continue;

        final dedupeKey = '$subject|$rawTeacher';
        if (seen.contains(dedupeKey)) continue;
        seen.add(dedupeKey);

        // تقسيم المجموعات على علامة +
        final groups = rawGroups
            .split('+')
            .map((g) => g.trim())
            .where((g) => g.isNotEmpty)
            .toList();

        rows.add(TimetableRow(
          rawTeacherName: rawTeacher,
          subjectName: subject,
          studentGroups: groups,
          room: room,
        ));
      }

      if (rows.isEmpty) {
        throw Exception('لم يتم العثور على صفوف بيانات صالحة في الملف.');
      }

      _parsedRows = rows;

      // 6. مطابقة الأسماء تلقائياً
      _matchTeacherNames();

      // 7. تحديد الخطوة التالية
      _currentStep = _unmappedTeacherNames.isEmpty
          ? ImportStep.readyToSave
          : ImportStep.manualMapping;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _currentStep = ImportStep.idle;
      debugPrint('TimetableImportVM: CSV parse error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// يُعيّن نائب العميد معلماً يدوياً لاسم غير معروف.
  /// يُخزَّن هذا الربط في الذاكرة المؤقتة (Cache).
  void setManualMapping(String rawTeacherName, String teacherUid) {
    _manualMappings[rawTeacherName] = teacherUid;
    notifyListeners();
  }

  /// يتحقق من اكتمال جميع الربطات اليدوية.
  bool get isManualMappingComplete {
    return _unmappedTeacherNames.every(
      (name) => _manualMappings.containsKey(name),
    );
  }

  /// يحفظ جميع التعيينات في SQLite بـ sync_status = 0 (Offline-First) ثم يحاول رفعها إلى Firestore.
  Future<void> saveAssignments() async {
    if (_unmappedTeacherNames.isNotEmpty && !isManualMappingComplete) {
      _errorMessage = 'يرجى ربط جميع المعلمين غير المعروفين قبل الحفظ.';
      notifyListeners();
      return;
    }

    _clearMessages();
    _isSaving = true;
    notifyListeners();

    try {
      final db   = await DatabaseHelper.instance.database;
      final uuid = const Uuid();

      // بناء الخريطة النهائية: rawName → uid
      final Map<String, String> finalMapping = {
        ..._autoMappings,
        ..._manualMappings,
      };

      int savedCount = 0;

      for (final row in _parsedRows) {
        final String? teacherUid = finalMapping[row.rawTeacherName];
        if (teacherUid == null || teacherUid.isEmpty) {
          debugPrint(
            'TimetableImportVM: No mapping for "${row.rawTeacherName}", skipping.',
          );
          continue;
        }

        final model = CourseAssignmentModel(
          id: uuid.v4(),
          subjectName: row.subjectName,
          teacherUid: teacherUid,
          studentGroups: row.studentGroups,
          room: row.room,
          syncStatus: 0, // Offline-First
        );

        await db.insert(
          'course_assignments',
          model.toSqliteMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        savedCount++;
      }

      // محاولة المزامنة الفورية مع Firestore
      try {
        await SyncService.instance.triggerSync();
        _successMessage = 'تم حفظ $savedCount تعيين بنجاح ومزامنتها مع السحابة (Firestore).';
      } catch (syncError) {
        debugPrint('TimetableImportVM: Sync failed or offline: $syncError');
        _successMessage = 'تم حفظ $savedCount تعيين بنجاح محلياً. (ستتم المزامنة تلقائياً عند توفر الإنترنت)';
      }

      _currentStep = ImportStep.done;
    } catch (e) {
      _errorMessage = 'حدث خطأ أثناء الحفظ: $e';
      debugPrint('TimetableImportVM: Save error: $e');
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// إعادة ضبط الحالة للبدء من جديد.
  void reset() {
    _parsedRows = [];
    _unmappedTeacherNames = [];
    _autoMappings.clear();
    _manualMappings.clear();
    _selectedFileName = null;
    _currentStep = ImportStep.idle;
    _clearMessages();
    notifyListeners();
  }

  // ----------------------------- Private helpers ---------------------------

  int _findColumnIndex(List<String> headers, String targetKey) {
    final key = targetKey.toLowerCase();
    for (int i = 0; i < headers.length; i++) {
      if (headers[i].contains(key)) return i;
    }
    return -1;
  }

  /// يُطابق أسماء المعلمين القادمة من CSV مع المسجلين تلقائياً.
  void _matchTeacherNames() {
    // بناء فهرس: اسم_منظَّف → uid
    final Map<String, String> nameIndex = {};
    for (final teacher in _registeredTeachers) {
      final raw = teacher['name'] as String? ?? '';
      final sanitized = NameSanitizer.sanitize(raw);
      if (sanitized.isNotEmpty) {
        nameIndex[sanitized] = teacher['id'] as String? ?? '';
      }
    }

    final Set<String> unmapped = {};

    for (final row in _parsedRows) {
      final rawName = row.rawTeacherName;

      // إذا كان في كاش الربط اليدوي السابق نتخطاه
      if (_manualMappings.containsKey(rawName)) continue;

      // تجربة التطابق التلقائي
      final sanitizedCsvName = NameSanitizer.sanitize(rawName);
      final matchedUid = nameIndex[sanitizedCsvName];

      if (matchedUid != null && matchedUid.isNotEmpty) {
        _autoMappings[rawName] = matchedUid;
      } else {
        unmapped.add(rawName);
      }
    }

    _unmappedTeacherNames = unmapped.toList();
  }

  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
  }
}
