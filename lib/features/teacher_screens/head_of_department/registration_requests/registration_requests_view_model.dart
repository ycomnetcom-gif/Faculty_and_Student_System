import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:student_attendance_system/features/sigin/registration_request_model.dart';

class RegistrationRequestsViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  List<RegistrationRequestModel> _requests = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  List<RegistrationRequestModel> get requests => _requests;

  // جلب الطلبات المعلقة يدوياً من السيرفر
  Future<void> fetchRequests() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('Registration_requests')
          .where('state', isEqualTo: 'قيد المراجعة')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));

      _requests = snapshot.docs
          .map((doc) => RegistrationRequestModel.fromMap(doc.data()))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل جلب طلبات التسجيل المعلقة: $e';
      notifyListeners();
    }
  }

  // قبول طلب تسجيل الطالب
  Future<bool> approveRequest(RegistrationRequestModel request) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    String? tempAppName;
    FirebaseApp? tempApp;

    try {
      // 1. إنشاء حساب في Firebase Authentication باستخدام تطبيق ثانوي لتجنب تسجيل خروج رئيس القسم الحالي
      tempAppName = 'temp_auth_${DateTime.now().millisecondsSinceEpoch}';
      tempApp = await Firebase.initializeApp(
        name: tempAppName,
        options: Firebase.app().options,
      );

      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      final userCredential = await tempAuth.createUserWithEmailAndPassword(
        email: request.email,
        password: request.password,
      );

      final String newUid = userCredential.user!.uid;

      // 2. إدخال بيانات الطالب في كولكشن users الرئيسي
      await _firestore.collection('users').doc(newUid).set({
        'id': request.id,
        'name': request.name,
        'email': request.email,
        'role': request.role, // طالب
        'createAt': Timestamp.fromDate(request.createdAt),
        'acceptAt': FieldValue.serverTimestamp(),
        'stu_info': request.stuInfo,
      });

      // 3. تحديث حالة الطلب في كولكشن Registration_requests إلى "مقبول"
      await _firestore
          .collection('Registration_requests')
          .doc(request.id)
          .update({
        'state': 'مقبول',
      });

      _requests.removeWhere((r) => r.id == request.id);
      _successMessage = 'تم تفعيل الحساب وقبول طلب الطالب ${request.name} بنجاح';
      _isLoading = false;
      notifyListeners();

      // حذف التطبيق المؤقت لتنظيف الذاكرة
      try {
        await tempApp.delete();
      } catch (e) {
        debugPrint('Error deleting temporary app: $e');
      }

      return true;
    } on FirebaseAuthException catch (authError) {
      _isLoading = false;
      if (authError.code == 'email-already-in-use') {
        _errorMessage = 'البريد الإلكتروني هذا مستخدم بالفعل في نظام المصادقة.';
      } else if (authError.code == 'weak-password') {
        _errorMessage = 'كلمة المرور المقترحة ضعيفة جداً.';
      } else {
        _errorMessage = 'خطأ في المصادقة: ${authError.message}';
      }
      notifyListeners();

      if (tempApp != null) {
        try {
          await tempApp.delete();
        } catch (e) {
          debugPrint('Error deleting temporary app: $e');
        }
      }
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'حدث خطأ غير متوقع: $e';
      notifyListeners();

      if (tempApp != null) {
        try {
          await tempApp.delete();
        } catch (e) {
          debugPrint('Error deleting temporary app: $e');
        }
      }
      return false;
    }
  }

  // رفض طلب تسجيل الطالب
  Future<bool> rejectRequest(RegistrationRequestModel request) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      // تحديث حالة الطلب إلى "مرفوض" في الفايربيس
      await _firestore
          .collection('Registration_requests')
          .doc(request.id)
          .update({
        'state': 'مرفوض',
      });

      _requests.removeWhere((r) => r.id == request.id);
      _successMessage = 'تم رفض طلب التسجيل الخاص بالطالب ${request.name}';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل رفض الطلب: $e';
      notifyListeners();
      return false;
    }
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}
