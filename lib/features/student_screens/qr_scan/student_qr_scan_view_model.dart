import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'student_qr_scan_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ViewModel الطالب لمسح QR والتحقق من التواجد بالقاعة
// ─────────────────────────────────────────────────────────────────────────────

class StudentQrScanViewModel extends ChangeNotifier {
  // مفتاح التشفير (يجب أن يطابق مفتاح المعلم تماماً)
  static final _secretKey =
      encrypt.Key.fromUtf8('my32lengthsupersecretnooneknows1');
  static final _iv = encrypt.IV.fromLength(16);

  /// مدة انتهاء صلاحية QR بالثواني (35 ثانية = 30s interval + 5s buffer)
  static const int _qrExpirySeconds = 35;

  /// الحد الأقصى للمسافة بالمتر لقبول الموقع الجغرافي
  static const double _maxDistanceMeters = 100.0;

  /// مدة مسح البلوتوث بالثواني
  static const int _btScanSeconds = 8;

  AttendanceVerificationStatus _status = AttendanceVerificationStatus.idle;
  AttendanceVerificationStatus get status => _status;

  String _statusMessage = '';
  String get statusMessage => _statusMessage;

  bool get isProcessing =>
      _status == AttendanceVerificationStatus.scanningBluetooth;

  bool get isVerified => _status == AttendanceVerificationStatus.verified;
  bool get isFailed => _status == AttendanceVerificationStatus.failed;

  DecodedPayload? _payload;

  /// حمولة QR المفكوك تشفيرها — تُعاد كـ Map لتجنب كشف النوع الخاص
  Map<String, dynamic>? get payloadInfo => _payload == null
      ? null
      : {
          'courseId': _payload!.courseId,
          'subjectName': _payload!.subjectName,
          'group': _payload!.group,
          'teacherId': _payload!.teacherId,
        };

  /// هل المنصة الحالية لا تدعم خدمات الأمان في الموبايل (مثل ويندوز)؟
  bool get _isPlatformUnsupported =>
      !Platform.isAndroid && !Platform.isIOS;

  // ─── خطوة 1: فك تشفير QR والتحقق من انتهاء صلاحيته ───────────────────────

  /// استدعاء هذه الدالة عند نجاح مسح QR
  Future<void> processQrCode(String rawQrData) async {
    _reset();
    notifyListeners();

    // 1. فك التشفير
    DecodedPayload? decoded;
    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(_secretKey));
      final decrypted = encrypter.decrypt64(rawQrData, iv: _iv);
      final map = jsonDecode(decrypted) as Map<String, dynamic>;
      decoded = DecodedPayload.fromMap(map);
    } catch (e) {
      _setFailed('رمز QR غير صالح أو تالف.');
      return;
    }

    // 2. التحقق من انتهاء الصلاحية
    final age = DateTime.now().millisecondsSinceEpoch - decoded.timestamp;
    if (age > _qrExpirySeconds * 1000) {
      _setFailed('انتهت صلاحية رمز QR. يرجى طلب باركود جديد من المعلم.');
      return;
    }

    _payload = decoded;

    // إذا كانت المنصة ويندوز أو غير مدعومة للموبايل، نتجاوز التحقق للتطوير
    if (_isPlatformUnsupported) {
      _statusMessage = 'تم تجاوز فحص الموقع الجغرافي والبلوتوث (منصة تطوير غير مدعومة).';
      notifyListeners();
      await Future.delayed(const Duration(seconds: 2));
      _setVerified();
      return;
    }

    // 3. التحقق من الموقع الجغرافي (إذا كان الـ payload يحتوي على إحداثيات)
    if (decoded.latitude != 0.0 || decoded.longitude != 0.0) {
      final locationOk = await _verifyLocation(decoded);
      if (!locationOk) return;
    }

    // 4. البحث عن بلوتوث المعلم
    await _scanForTeacherBluetooth(decoded.btDeviceName);
  }

  // ─── خطوة 2: التحقق من الموقع الجغرافي ───────────────────────────────────

  Future<bool> _verifyLocation(DecodedPayload decoded) async {
    _statusMessage = 'جارٍ التحقق من موقعك الجغرافي...';
    notifyListeners();

    try {
      // 1. تحقق واطلب إذن الموقع أولاً
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _setFailed('لم يتم منح إذن الموقع الجغرافي.');
        return false;
      }

      // 2. تحقق من تشغيل خدمة الموقع (GPS)
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setFailed('يرجى تفعيل خدمة الموقع الجغرافي (GPS) على جهازك.');
        return false;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        decoded.latitude,
        decoded.longitude,
      );

      debugPrint('Distance from teacher: ${distance.toStringAsFixed(1)}m');

      if (distance > _maxDistanceMeters) {
        _status = AttendanceVerificationStatus.locationMismatch;
        _statusMessage =
            'أنت بعيد عن القاعة (${distance.toStringAsFixed(0)}م). '
            'يجب أن تكون على بُعد ${_maxDistanceMeters.toInt()}م من المعلم.';
        notifyListeners();
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Location error: $e');
      // في حالة خطأ الموقع نكمل إلى البلوتوث (لا نوقف العملية)
      return true;
    }
  }

  // ─── خطوة 3: البحث عن بلوتوث المعلم ──────────────────────────────────────

  Future<void> _scanForTeacherBluetooth(String teacherBtName) async {
    if (teacherBtName.isEmpty) {
      // لا يوجد اسم BT في payload → نقبل مباشرة
      _setVerified();
      return;
    }

    _status = AttendanceVerificationStatus.scanningBluetooth;
    _statusMessage = 'جارٍ البحث عن جهاز المعلم عبر البلوتوث...\n'
        'يرجى التأكد من تفعيل البلوتوث على جهازك.';
    notifyListeners();

    try {
      // طلب أذونات البلوتوث
      bool permissionsGranted = false;
      if (Platform.isAndroid) {
        final statuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
        ].request();
        
        permissionsGranted = statuses[Permission.bluetoothScan] == PermissionStatus.granted &&
            statuses[Permission.bluetoothConnect] == PermissionStatus.granted;
      } else if (Platform.isIOS) {
        final status = await Permission.bluetooth.request();
        permissionsGranted = status == PermissionStatus.granted;
      } else {
        permissionsGranted = true;
      }

      if (!permissionsGranted) {
        _setFailed('يجب منح صلاحيات البلوتوث للتحقق من وجودك في القاعة.');
        return;
      }

      var adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState == BluetoothAdapterState.unknown || adapterState == BluetoothAdapterState.turningOn) {
        try {
          adapterState = await FlutterBluePlus.adapterState
              .firstWhere((state) => state == BluetoothAdapterState.on || state == BluetoothAdapterState.off)
              .timeout(const Duration(seconds: 3));
        } catch (_) {}
      }

      if (adapterState != BluetoothAdapterState.on) {
        _setFailed('يرجى تفعيل البلوتوث على جهازك للتحقق من تواجدك في القاعة.');
        return;
      }

      bool found = false;

      // بدء مسح BLE
      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: _btScanSeconds),
        androidUsesFineLocation: true,
      );

      // الاستماع لنتائج المسح
      final subscription = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final name = r.device.platformName.trim();
          debugPrint('Found BT device: "$name"');

          // مقارنة اسم الجهاز مع اسم بلوتوث المعلم
          if (name.isNotEmpty &&
              name.toLowerCase() == teacherBtName.toLowerCase()) {
            found = true;
            debugPrint('✅ Teacher device found: $name');
            break;
          }
        }
      });

      // انتظار انتهاء المسح
      await FlutterBluePlus.isScanning.where((s) => !s).first;
      await subscription.cancel();

      if (found) {
        _setVerified();
      } else {
        _status = AttendanceVerificationStatus.bluetoothNotFound;
        _statusMessage =
            'لم يتم العثور على جهاز المعلم عبر البلوتوث.\n'
            'تأكد من أنك داخل القاعة وأن البلوتوث مفعّل لدى المعلم والطالب.';
        notifyListeners();
      }
    } catch (e) {
      debugPrint('BLE scan error: $e');
      await FlutterBluePlus.stopScan();
      _setFailed('حدث خطأ أثناء فحص البلوتوث: $e');
    }
  }

  // ─── حالات النتيجة ────────────────────────────────────────────────────────

  void _setVerified() {
    _status = AttendanceVerificationStatus.verified;
    _statusMessage = 'تم التحقق من حضورك بنجاح! ✅';
    notifyListeners();
    // TODO: هنا يتم تسجيل الحضور في Firestore / SQLite
  }

  void _setFailed(String message) {
    _status = AttendanceVerificationStatus.failed;
    _statusMessage = message;
    notifyListeners();
  }

  void _reset() {
    _status = AttendanceVerificationStatus.idle;
    _statusMessage = '';
    _payload = null;
  }

  void resetScan() {
    _reset();
    notifyListeners();
  }

  /// البريد الإلكتروني للطالب الحالي (للعرض)
  String get currentUserEmail =>
      FirebaseAuth.instance.currentUser?.email ?? '';
}
