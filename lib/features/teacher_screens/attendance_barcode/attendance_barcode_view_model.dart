import 'dart:async';
import 'dart:io';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:student_attendance_system/core/database_helper.dart';
import 'package:student_attendance_system/features/teacher_screens/attendance_barcode/attendance_barcode_model.dart';

/// حالة خدمات الأمان (الموقع / البلوتوث)
enum SecurityServiceStatus {
  /// لم يتم التحقق بعد
  idle,
  /// جارٍ طلب الأذونات
  requesting,
  /// تم منح الإذن والخدمة فعّالة
  granted,
  /// تم رفض الإذن أو الخدمة معطّلة
  denied,
  /// المنصة لا تدعم هذه الخدمة (Desktop)
  unsupported,
}

class AttendanceBarcodeViewModel extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<AttendanceCourseModel> _courses = [];
  List<AttendanceCourseModel> get courses => _courses;

  AttendanceCourseModel? _selectedCourse;
  AttendanceCourseModel? get selectedCourse => _selectedCourse;

  String? _selectedGroup;
  String? get selectedGroup => _selectedGroup;

  String? _qrDataEncrypted;
  String? get qrDataEncrypted => _qrDataEncrypted;

  // --- حالة الموقع الجغرافي ---
  SecurityServiceStatus _locationStatus = SecurityServiceStatus.idle;
  SecurityServiceStatus get locationStatus => _locationStatus;

  // --- حالة البلوتوث ---
  SecurityServiceStatus _bluetoothStatus = SecurityServiceStatus.idle;
  SecurityServiceStatus get bluetoothStatus => _bluetoothStatus;

  /// هل تم تفعيل كلتا خدمتي الأمان (أو أن المنصة لا تدعمهما فيُسمح بالمرور)؟
  bool get isSecurityReady {
    // على Desktop: نسمح بالمرور مباشرة لأغراض التطوير
    if (_isPlatformUnsupported) return true;
    return _locationStatus == SecurityServiceStatus.granted &&
        _bluetoothStatus == SecurityServiceStatus.granted;
  }

  /// هل المنصة الحالية لا تدعم GPS/BT (Windows / Linux / macOS)؟
  bool get _isPlatformUnsupported =>
      !Platform.isAndroid && !Platform.isIOS;

  /// آخر موقع جغرافي تم جلبه
  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  /// اسم جهاز البلوتوث للمعلم (المُضمَّن في QR)
  String _btDeviceName = '';
  String get btDeviceName => _btDeviceName;

  Timer? _qrTimer;

  // مفتاح التشفير (32 حرفاً لتشفير AES-256)
  static final _secretKey =
      encrypt.Key.fromUtf8('my32lengthsupersecretnooneknows1');
  static final _iv = encrypt.IV.fromLength(16);

  AttendanceBarcodeViewModel() {
    _loadTeacherCourses();
  }

  @override
  void dispose() {
    _qrTimer?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  تحميل المواد
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadTeacherCourses() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _errorMessage = 'لم يتم العثور على المعلم المسجل';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'course_assignments',
        columns: ['id', 'subject_name', 'student_groups'],
        where: 'teacher_uid = ? AND sync_status != 2',
        whereArgs: [user.uid],
      );

      _courses = rows
          .map((row) => AttendanceCourseModel.fromSqliteRow(row))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'حدث خطأ أثناء جلب المواد: $e';
      _isLoading = false;
      debugPrint('AttendanceBarcodeVM Error: $e');
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  طلب أذونات الأمان (الموقع + البلوتوث)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> requestSecurityPermissions({bool isManual = false}) async {
    // على Desktop لا تتوفر هذه الخدمات — نضعها كـ unsupported مباشرة
    if (_isPlatformUnsupported) {
      _locationStatus = SecurityServiceStatus.unsupported;
      _bluetoothStatus = SecurityServiceStatus.unsupported;
      notifyListeners();
      return;
    }

    _locationStatus = SecurityServiceStatus.requesting;
    _bluetoothStatus = SecurityServiceStatus.requesting;
    notifyListeners();

    // ── الموقع الجغرافي ──
    await _checkAndRequestLocation(isManual: isManual);

    // ── البلوتوث ──
    await _checkAndRequestBluetooth(isManual: isManual);

    notifyListeners();
  }

  Future<void> _checkAndRequestLocation({bool isManual = false}) async {
    try {
      // 1. تحقق واطلب إذن الموقع أولاً
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (isManual) {
          // الإذن مرفوض بشكل دائم — نقوم بفتح إعدادات التطبيق
          await openAppSettings();
        }
        _locationStatus = SecurityServiceStatus.denied;
        return;
      } else if (permission == LocationPermission.denied) {
        _locationStatus = SecurityServiceStatus.denied;
        return;
      }

      // 2. إذا تم منح الإذن، تحقق من تشغيل خدمة الـ GPS نفسها
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (isManual) {
          // فتح إعدادات الموقع الجغرافي للمستخدم لتشغيل الـ GPS
          await Geolocator.openLocationSettings();
          await Future.delayed(const Duration(seconds: 1));
          serviceEnabled = await Geolocator.isLocationServiceEnabled();
        }
        if (!serviceEnabled) {
          _locationStatus = SecurityServiceStatus.denied;
          return;
        }
      }

      _locationStatus = SecurityServiceStatus.granted;
      await _fetchCurrentLocation();
    } catch (e) {
      debugPrint('Location check error: $e');
      _locationStatus = SecurityServiceStatus.denied;
    }
  }

  Future<void> _checkAndRequestBluetooth({bool isManual = false}) async {
    try {
      // طلب أذونات البلوتوث المناسبة حسب المنصة
      bool permissionsGranted = false;
      bool isPermanentlyDenied = false;

      if (Platform.isAndroid) {
        final scanStatus = await Permission.bluetoothScan.status;
        final connectStatus = await Permission.bluetoothConnect.status;

        if (scanStatus.isPermanentlyDenied || connectStatus.isPermanentlyDenied) {
          isPermanentlyDenied = true;
        }

        final statuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
        ].request();
        
        permissionsGranted = statuses[Permission.bluetoothScan] == PermissionStatus.granted &&
            statuses[Permission.bluetoothConnect] == PermissionStatus.granted;

        if (statuses[Permission.bluetoothScan]!.isPermanentlyDenied || 
            statuses[Permission.bluetoothConnect]!.isPermanentlyDenied) {
          isPermanentlyDenied = true;
        }
      } else if (Platform.isIOS) {
        final status = await Permission.bluetooth.status;
        if (status.isPermanentlyDenied) {
          isPermanentlyDenied = true;
        }
        final requestStatus = await Permission.bluetooth.request();
        permissionsGranted = requestStatus == PermissionStatus.granted;
        if (requestStatus.isPermanentlyDenied) {
          isPermanentlyDenied = true;
        }
      } else {
        permissionsGranted = true;
      }

      if (isPermanentlyDenied && isManual) {
        // الإذن مرفوض بشكل دائم — نقوم بفتح إعدادات التطبيق
        await openAppSettings();
      }

      if (!permissionsGranted) {
        _bluetoothStatus = SecurityServiceStatus.denied;
        return;
      }

      // تحقق أن البلوتوث مفعّل على الجهاز
      var adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState == BluetoothAdapterState.unknown || adapterState == BluetoothAdapterState.turningOn) {
        try {
          adapterState = await FlutterBluePlus.adapterState
              .firstWhere((state) => state == BluetoothAdapterState.on || state == BluetoothAdapterState.off)
              .timeout(const Duration(seconds: 3));
        } catch (_) {}
      }

      if (adapterState != BluetoothAdapterState.on) {
        if (Platform.isAndroid) {
          try {
            await FlutterBluePlus.turnOn();
            adapterState = await FlutterBluePlus.adapterState
                .firstWhere((state) => state == BluetoothAdapterState.on)
                .timeout(const Duration(seconds: 3));
          } catch (e) {
            debugPrint('Failed to turn on bluetooth: $e');
          }
        }
      }

      if (adapterState != BluetoothAdapterState.on) {
        _bluetoothStatus = SecurityServiceStatus.denied;
        return;
      }

      // جلب اسم جهاز البلوتوث للمعلم وتضمينه في QR لاحقاً
      await _fetchBluetoothDeviceName();

      _bluetoothStatus = SecurityServiceStatus.granted;
    } catch (e) {
      debugPrint('Bluetooth check error: $e');
      _bluetoothStatus = SecurityServiceStatus.denied;
    }
  }

  /// جلب اسم بلوتوث الجهاز من FlutterBluePlus
  Future<void> _fetchBluetoothDeviceName() async {
    try {
      _btDeviceName = await FlutterBluePlus.adapterName;
      if (_btDeviceName.isEmpty) {
        _btDeviceName = 'Teacher_Device';
      }
      debugPrint('BT Device Name: $_btDeviceName');
    } catch (e) {
      debugPrint('Failed to get BT name: $e');
      _btDeviceName = 'Teacher_Device';
    }
  }

  /// جلب الموقع الجغرافي الحالي للمعلم
  Future<void> _fetchCurrentLocation() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (e) {
      debugPrint('Location fetch error: $e');
      _currentPosition = null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  اختيار المادة / المجموعة
  // ─────────────────────────────────────────────────────────────────────────

  void selectCourse(AttendanceCourseModel? course) {
    _selectedCourse = course;
    _selectedGroup = null;
    _stopTimerAndClearQR();
    notifyListeners();
  }

  void selectGroup(String? group) {
    _selectedGroup = group;
    if (_selectedCourse != null && _selectedGroup != null) {
      _generateAndStartTimer();
    } else {
      _stopTimerAndClearQR();
    }
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  توليد QR
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _generateAndStartTimer() async {
    // 1. اطلب الصلاحيات أولاً عند بدء التحضير للمجموعة المحددة
    await requestSecurityPermissions();

    if (isSecurityReady) {
      _generateQRData();
      _qrTimer?.cancel();
      _qrTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
        if (_locationStatus == SecurityServiceStatus.granted) {
          await _fetchCurrentLocation();
        }
        _generateQRData();
      });
    } else {
      _stopTimerAndClearQR();
      notifyListeners();
    }
  }

  void _stopTimerAndClearQR() {
    _qrTimer?.cancel();
    _qrDataEncrypted = null;
  }

  /// بناء الـ Payload (يشمل موقع GPS + اسم بلوتوث المعلم) وتشفيره
  void _generateQRData() {
    if (_selectedCourse == null || _selectedGroup == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final payload = QrPayloadModel(
      courseId: _selectedCourse!.id,
      subjectName: _selectedCourse!.subjectName,
      group: _selectedGroup!,
      teacherId: user.uid,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      latitude: _currentPosition?.latitude ?? 0.0,
      longitude: _currentPosition?.longitude ?? 0.0,
      locationAccuracy: _currentPosition?.accuracy ?? 0.0,
      btDeviceName: _btDeviceName,
    );

    final encrypter = encrypt.Encrypter(encrypt.AES(_secretKey));
    final encrypted = encrypter.encrypt(payload.toJson(), iv: _iv);

    _qrDataEncrypted = encrypted.base64;
    notifyListeners();
  }
}
