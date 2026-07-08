import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:student_attendance_system/core/theme.dart';
import 'package:student_attendance_system/features/login/login_view.dart';
import 'package:student_attendance_system/features/login/login_view_model.dart';
import 'package:student_attendance_system/features/sigin/sigin_view_model.dart';
import 'package:student_attendance_system/features/sigin/faculty_signup_view_model.dart';
import 'package:student_attendance_system/features/teacher_screens/home/teacher_home_view_model.dart';
import 'package:student_attendance_system/features/vice_dean_for_academic _affairs/departments/departments_view_model.dart';
import 'package:student_attendance_system/features/vice_dean_for_academic _affairs/faculty_accounts/faculty_accounts_view_model.dart';
import 'package:student_attendance_system/features/teacher_screens/head_of_department/registration_requests/registration_requests_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_attendance_system/features/teacher_screens/home/teacher_home_view.dart';
import 'package:student_attendance_system/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // تنظيف الكاش المحلي لحل مشاكل تعليق اتصالات Firestore على ويندوز
  try {
    await FirebaseFirestore.instance.terminate();
    await FirebaseFirestore.instance.clearPersistence();
  } catch (e) {
    debugPrint("Failed to clear Firestore persistence: $e");
  }

  // قراءة حالة الدخول المخزنة بفضل خاصية "تذكرني"
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('is_logged_in') ?? false;

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LoginViewModel()),
        ChangeNotifierProvider(create: (_) => TeacherHomeViewModel()),
        ChangeNotifierProvider(create: (_) => SiginViewModel()),
        ChangeNotifierProvider(create: (_) => FacultySignupViewModel()),
        ChangeNotifierProvider(create: (_) => DepartmentsViewModel()),
        ChangeNotifierProvider(create: (_) => FacultyAccountsViewModel()),
        ChangeNotifierProvider(create: (_) => RegistrationRequestsViewModel()),
      ],
      child: MaterialApp(
        title: 'نظام حضور الطلاب',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        // Localize app to Arabic (RTL) by default
        locale: const Locale('ar', 'AE'),
        supportedLocales: const [Locale('ar', 'AE'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: isLoggedIn ? const TeacherHomeView() : const LoginView(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

