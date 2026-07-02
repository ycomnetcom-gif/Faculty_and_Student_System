import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'registration_request_model.dart';

class SiginViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String? _errorMessage;
  bool _isSuccess = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isSuccess => _isSuccess;

  // إعادة تعيين الحالات عند مغادرة أو فتح الشاشة
  void resetState() {
    _isLoading = false;
    _errorMessage = null;
    _isSuccess = false;
    notifyListeners();
  }

  // منطق إرسال طلب التسجيل إلى كولكشن Registration_requests
  Future<bool> submitRegistrationRequest({
    required String id,
    required String name,
    required String email,
    required String password,
    required String major,
    required String level,
    required String track,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _isSuccess = false;
    notifyListeners();

    try {
      // 1. التحقق مما إذا كان رقم القيد مسجلاً مسبقاً في الطلبات أو المستخدمين النشطين
      final duplicateIdQuery = await _firestore
          .collection('Registration_requests')
          .where('id', isEqualTo: id)
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));

      if (duplicateIdQuery.docs.isNotEmpty) {
        _errorMessage = 'رقم القيد هذا مسجل بالفعل في طلبات التسجيل السابقة';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final duplicateUserIdQuery = await _firestore
          .collection('users')
          .where('id', isEqualTo: id)
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));

      if (duplicateUserIdQuery.docs.isNotEmpty) {
        _errorMessage = 'رقم القيد هذا مسجل بالفعل كمستخدم نشط في التطبيق';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 2. التحقق مما إذا كان البريد الإلكتروني مسجلاً مسبقاً في الطلبات أو المستخدمين النشطين
      final duplicateEmailQuery = await _firestore
          .collection('Registration_requests')
          .where('email', isEqualTo: email)
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));

      if (duplicateEmailQuery.docs.isNotEmpty) {
        _errorMessage = 'البريد الإلكتروني هذا تم استخدامه في طلب تسجيل سابق';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final duplicateUserEmailQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));

      if (duplicateUserEmailQuery.docs.isNotEmpty) {
        _errorMessage = 'البريد الإلكتروني هذا مسجل بالفعل لمستخدم آخر في التطبيق';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 3. إنشاء كائن طلب التسجيل بالقيم الافتراضية
      final request = RegistrationRequestModel(
        id: id,
        name: name,
        email: email,
        password: password,
        role: 'طالب', // الدور يُعيّن تلقائياً إلى طالب كما طلب المستخدم
        state: 'قيد المراجعة', // حالة الطلب تكون معلقة انتظاراً لموافقة الإدارة
        createdAt: DateTime.now(),
        stuInfo: {
          'major': major,
          'level': level,
          'track': track,
        },
      );

      // 4. حفظ الكائن في كولكشن Registration_requests باستخدام رقم القيد كـ Document ID
      await _firestore
          .collection('Registration_requests')
          .doc(id)
          .set(request.toMap())
          .timeout(const Duration(seconds: 10));

      _isLoading = false;
      _isSuccess = true;
      notifyListeners();
      return true;
    } on FirebaseException catch (e) {
      _isLoading = false;
      if (e.code == 'unavailable' || e.code == 'network-request-failed') {
        _errorMessage = 'فشل الاتصال بالخادم. يرجى التحقق من اتصالك بالإنترنت والمحاولة مجدداً.';
      } else if (e.code == 'permission-denied') {
        _errorMessage = 'تم رفض الوصول. يرجى التحقق من صلاحيات وقواعد الحماية لقاعدة البيانات.';
      } else {
        _errorMessage = 'حدث خطأ في قاعدة البيانات: ${e.message}';
      }
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      if (e.toString().contains('TimeoutException')) {
        _errorMessage = 'انتهت مهلة الاتصال بالخادم. يرجى التحقق من جودة اتصال الإنترنت.';
      } else {
        _errorMessage = 'حدث خطأ غير متوقع: ${e.toString()}';
      }
      notifyListeners();
      return false;
    }
  }
}
