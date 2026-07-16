import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:student_attendance_system/core/database_helper.dart';
import 'package:student_attendance_system/core/sync_service.dart';
import 'package:student_attendance_system/features/vice_dean_for_academic _affairs/departments/department_model.dart';
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
// Helper – Student Group Parser
// ---------------------------------------------------------------------------

/// يحلل اسم المجموعة الطلابية لاستخراج التخصص والمستوى الدراسي.
/// مثال: "تقنية معلومات - مستوى ثالث" -> التخصص: "تقنية معلومات"، المستوى: 3
class StudentGroupParser {
  static const Map<String, int> _arabicLevelMap = {
    'أول': 1,
    'اول': 1,
    'الأول': 1,
    'الاول': 1,
    'ثاني': 2,
    'ثانى': 2,
    'الثاني': 2,
    'الثانى': 2,
    'ثالث': 3,
    'الثالث': 3,
    'رابع': 4,
    'الرابع': 4,
    'خامس': 5,
    'الخامس': 5,
  };

  /// يحلل اسم المجموعة ويُرجع خريطة تحتوي على اسم التخصص المقترح ورقم المستوى
  static Map<String, dynamic> parse(String groupName) {
    final parts = groupName.split(RegExp(r'[-–/]'));
    if (parts.isEmpty) {
      return {'departmentName': groupName.trim(), 'level': null};
    }

    final deptPart = parts[0].trim();
    if (parts.length < 2) {
      return {'departmentName': deptPart, 'level': null};
    }

    final levelPart = parts[1].trim();
    int? level;

    // البحث عن أرقام مباشرة (مثال: "مستوى 3" أو "مستوى 2")
    final numMatch = RegExp(r'\d+').firstMatch(levelPart);
    if (numMatch != null) {
      level = int.tryParse(numMatch.group(0)!);
    } else {
      // البحث عن الكلمات العربية المقابلة للمستوى
      for (final entry in _arabicLevelMap.entries) {
        if (levelPart.contains(entry.key)) {
          level = entry.value;
          break;
        }
      }
    }

    return {
      'departmentName': deptPart,
      'level': level,
    };
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

  /// هناك أسماء معلمين أو مجموعات تحتاج ربطاً يدوياً
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

  /// جميع الأقسام المسجلة في النظام (مُسترجَعون من SQLite).
  List<Department> _departments = [];
  List<Department> get departments => List.unmodifiable(_departments);

  /// الأسماء التي لم يُعثر لها على تطابق تلقائي للمعلمين.
  List<String> _unmappedTeacherNames = [];
  List<String> get unmappedTeacherNames =>
      List.unmodifiable(_unmappedTeacherNames);

  /// المجموعات التي لم يُعثر لها على تطابق تلقائي مع التخصصات أو المستويات.
  List<String> _unmappedGroupNames = [];
  List<String> get unmappedGroupNames =>
      List.unmodifiable(_unmappedGroupNames);

  /// خريطة التطابق التلقائي للمعلمين: rawTeacherName → teacherUid
  final Map<String, String> _autoMappings = {};

  /// خريطة التطابق التلقائي للمجموعات إلى الأقسام: groupName → departmentFirestoreId
  final Map<String, String> _autoDeptMappings = {};

  /// خريطة التطابق التلقائي للمجموعات إلى المستويات: groupName → levelNumber
  final Map<String, int> _autoLevelMappings = {};

  /// خريطة الربط اليدوي للمعلمين: rawTeacherName → teacherUid
  final Map<String, String> _manualMappings = {};
  Map<String, String> get manualMappings => Map.unmodifiable(_manualMappings);

  /// خريطة الربط اليدوي للمجموعات إلى الأقسام: groupName → departmentFirestoreId
  final Map<String, String> _manualDeptMappings = {};
  Map<String, String> get manualDeptMappings => Map.unmodifiable(_manualDeptMappings);

  /// خريطة الربط اليدوي للمجموعات إلى المستويات: groupName → levelNumber
  final Map<String, int> _manualLevelMappings = {};
  Map<String, int> get manualLevelMappings => Map.unmodifiable(_manualLevelMappings);

  ImportStep _currentStep = ImportStep.idle;
  ImportStep get currentStep => _currentStep;

  // ----------------------------- Public API --------------------------------

  /// يُحضّر قائمة المعلمين والأقسام المسجلين من SQLite عند فتح الشاشة.
  Future<void> loadRegisteredTeachers() async {
    try {
      final db = await DatabaseHelper.instance.database;
      
      // 1. جلب المعلمين
      final teacherRows = await db.rawQuery(
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
      _registeredTeachers = teacherRows;

      // 2. جلب الأقسام
      final deptRows = await db.query('departments', where: 'sync != 2');
      _departments = deptRows.map((r) => Department.fromMap(r)).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('TimetableImportVM: Error loading initial data: $e');
    }
  }

  /// يفتح نافذة اختيار الملف، يقرأ محتوى CSV، يحلّله، ويُطابق المعلمين والمجموعات تلقائياً.
  Future<void> pickAndParseFile() async {
    _clearMessages();
    _isLoading = true;
    _currentStep = ImportStep.idle;
    _parsedRows = [];
    _unmappedTeacherNames = [];
    _unmappedGroupNames = [];
    _autoMappings.clear();
    _autoDeptMappings.clear();
    _autoLevelMappings.clear();
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
        csvContent = utf8.decode(pickedFile.bytes!, allowMalformed: true);
      } else if (pickedFile.path != null) {
        final file = File(pickedFile.path!);
        final bytes = await file.readAsBytes();
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

      // 4. الكشف عن رؤوس الأعمدة
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
          'تأكد من وجود الأعمدة: Subject, Teachers, Student Sets.',
        );
      }

      // 5. استخراج الصفوف وإزالة التكرار مع تقسيم المجموعات المنفصلة بـ +
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

        // تقسيم المجموعات على علامة + (لمطابقة كل مجموعة بتخصص ومستوى)
        final groups = rawGroups
            .split('+')
            .map((g) => g.trim())
            .where((g) => g.isNotEmpty)
            .toList();

        for (final groupName in groups) {
          final dedupeKey = '$subject|$rawTeacher|$groupName';
          if (seen.contains(dedupeKey)) continue;
          seen.add(dedupeKey);

          rows.add(TimetableRow(
            rawTeacherName: rawTeacher,
            subjectName: subject,
            studentGroups: [groupName],
            room: room,
          ));
        }
      }

      if (rows.isEmpty) {
        throw Exception('لم يتم العثور على صفوف بيانات صالحة في الملف.');
      }

      _parsedRows = rows;

      // 6. مطابقة الأسماء تلقائياً للأساتذة والمجموعات
      _matchTeacherNames();
      _matchGroups();

      // 7. تحديد الخطوة التالية
      _currentStep = (_unmappedTeacherNames.isEmpty && _unmappedGroupNames.isEmpty)
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
  void setManualMapping(String rawTeacherName, String teacherUid) {
    _manualMappings[rawTeacherName] = teacherUid;
    notifyListeners();
  }

  /// يُعيّن نائب العميد تخصصاً ومستوى يدوياً لمجموعة غير معروفة.
  void setManualGroupMapping(String groupName, String departmentId, int level) {
    _manualDeptMappings[groupName] = departmentId;
    _manualLevelMappings[groupName] = level;
    notifyListeners();
  }

  /// يتحقق من اكتمال جميع الربطات اليدوية (المعلمين والمجموعات).
  bool get isManualMappingComplete {
    final teachersOk = _unmappedTeacherNames.every(
      (name) => _manualMappings.containsKey(name),
    );
    final groupsOk = _unmappedGroupNames.every(
      (name) => _manualDeptMappings.containsKey(name) && _manualLevelMappings.containsKey(name),
    );
    return teachersOk && groupsOk;
  }

  /// يحفظ جميع التعيينات في SQLite بـ sync_status = 0 (Offline-First) ثم يحاول رفعها إلى Firestore.
  Future<void> saveAssignments() async {
    if ((_unmappedTeacherNames.isNotEmpty || _unmappedGroupNames.isNotEmpty) && !isManualMappingComplete) {
      _errorMessage = 'يرجى ربط جميع المعلمين والمجموعات غير المطابقة قبل الحفظ.';
      notifyListeners();
      return;
    }

    _clearMessages();
    _isSaving = true;
    notifyListeners();

    try {
      final db   = await DatabaseHelper.instance.database;
      final uuid = const Uuid();

      // بناء الخرائط النهائية للربط
      final Map<String, String> finalTeacherMapping = {
        ..._autoMappings,
        ..._manualMappings,
      };

      final Map<String, String> finalDeptMapping = {
        ..._autoDeptMappings,
        ..._manualDeptMappings,
      };

      final Map<String, int> finalLevelMapping = {
        ..._autoLevelMappings,
        ..._manualLevelMappings,
      };

      int savedCount = 0;

      for (final row in _parsedRows) {
        final String? teacherUid = finalTeacherMapping[row.rawTeacherName];
        if (teacherUid == null || teacherUid.isEmpty) continue;

        // استخراج اسم المجموعة الطلابية
        final String groupName = row.studentGroups.isNotEmpty ? row.studentGroups.first : '';
        final String? departmentId = finalDeptMapping[groupName];
        final int? level = finalLevelMapping[groupName];

        final model = CourseAssignmentModel(
          id: uuid.v4(),
          subjectName: row.subjectName,
          teacherUid: teacherUid,
          studentGroups: row.studentGroups,
          room: row.room,
          departmentId: departmentId,
          level: level,
          syncStatus: 0, // Offline-First
        );

        await db.insert(
          'course_assignments',
          model.toSqliteMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        savedCount++;
      }

      // محاولة المزامنة الفورية مع Firestore (تحديث السجلات المحلية غير المزامنة فقط)
      try {
        await SyncService.instance.triggerSync();
        _successMessage = 'تم حفظ $savedCount تعيين بنجاح ومزامنتها تلقائياً مع السحابة (Firestore).';
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
    _unmappedGroupNames = [];
    _autoMappings.clear();
    _autoDeptMappings.clear();
    _autoLevelMappings.clear();
    _manualMappings.clear();
    _manualDeptMappings.clear();
    _manualLevelMappings.clear();
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

      if (_manualMappings.containsKey(rawName)) continue;

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

  /// يُطابق المجموعات الطلابية القادمة من CSV مع الأقسام والمستويات تلقائياً.
  void _matchGroups() {
    final Set<String> unmapped = {};

    for (final row in _parsedRows) {
      final String groupName = row.studentGroups.isNotEmpty ? row.studentGroups.first : '';
      if (groupName.isEmpty) continue;

      if (_manualDeptMappings.containsKey(groupName)) continue;

      // تحليل التخصص والمستوى من اسم المجموعة
      final parsed = StudentGroupParser.parse(groupName);
      final String parsedDeptName = parsed['departmentName'] ?? '';
      final int? parsedLevel = parsed['level'];

      // محاولة إيجاد القسم المقابل
      Department? matchedDept;
      final cleanParsedDept = parsedDeptName.replaceAll(' ', '').toLowerCase();
      
      for (final dept in _departments) {
        final cleanDeptName = dept.name.replaceAll(' ', '').toLowerCase();
        // مطابقة تامة أو جزئية
        if (cleanDeptName == cleanParsedDept || 
            cleanDeptName.contains(cleanParsedDept) || 
            cleanParsedDept.contains(cleanDeptName)) {
          matchedDept = dept;
          break;
        }
      }

      // إذا وجدنا القسم والمستوى يقع في نطاق عدد مستويات القسم
      if (matchedDept != null && 
          parsedLevel != null && 
          parsedLevel >= 1 && 
          parsedLevel <= matchedDept.levelsCount) {
        // نستخدم firestoreId أولاً، وفي حال لم يتوفر بعد (أوفلاين) نستخدم local ID كـ string مؤقت
        final deptId = (matchedDept.firestoreId != null && matchedDept.firestoreId!.isNotEmpty)
            ? matchedDept.firestoreId!
            : matchedDept.id.toString();
            
        _autoDeptMappings[groupName] = deptId;
        _autoLevelMappings[groupName] = parsedLevel;
      } else {
        unmapped.add(groupName);
      }
    }

    _unmappedGroupNames = unmapped.toList();
  }

  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
  }
}
