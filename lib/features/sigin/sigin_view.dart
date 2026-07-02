import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_attendance_system/core/theme.dart';
import 'package:student_attendance_system/features/login/login_view.dart';
import 'package:student_attendance_system/features/sigin/sigin_view_model.dart';

class SiginView extends StatefulWidget {
  const SiginView({super.key});

  @override
  State<SiginView> createState() => _SiginViewState();
}

class _SiginViewState extends State<SiginView> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _roleController = TextEditingController(text: 'طالب'); // قيمة ثابتة للدور
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // قيم الاختيارات للقوائم المنسدلة
  String _selectedMajor = 'تقنية المعلومات';
  String _selectedLevel = 'المستوى الأول';
  String _selectedTrack = 'عام';

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  void _handleSubmit(SiginViewModel viewModel) async {
    if (_formKey.currentState!.validate()) {
      final success = await viewModel.submitRegistrationRequest(
        id: _idController.text.trim(),
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        major: _selectedMajor,
        level: _selectedLevel,
        track: _selectedTrack,
      );

      if (mounted) {
        if (success) {
          // عرض رسالة نجاح جميلة بواسطة Dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Column(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.successColor,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'تم إرسال الطلب بنجاح',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              content: const Text(
                'لقد تم تسجيل طلبك بنجاح في النظام كـ (طالب). الطلب الآن قيد المراجعة من قِبل الإدارة لتفعيل حسابك.',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.5),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // إغلاق الحوار
                    // الانتقال إلى شاشة تسجيل الدخول
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginView()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    minimumSize: const Size(140, 48),
                  ),
                  child: const Text('العودة لتسجيل الدخول'),
                ),
              ],
            ),
          );
        } else {
          // عرض رسالة خطأ
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(viewModel.errorMessage ?? 'حدث خطأ أثناء إرسال الطلب'),
                  ),
                ],
              ),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final viewModel = Provider.of<SiginViewModel>(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0F172A), // كحلي داكن
                    const Color(0xFF1E293B), // رمادي داكن
                  ]
                : [
                    const Color(0xFFEFF6FF), // أزرق خفيف جداً
                    const Color(0xFFDBEAFE), // أزرق باهت
                    const Color(0xFFF8FAFC), // رمادي ناعم
                  ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // بطاقة طلب التسجيل
                  Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    decoration: AppTheme.cardDecoration(context),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 36,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.app_registration_rounded,
                                    size: 48,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'طلب تسجيل جديد',
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'أدخل بياناتك لإرسال طلب تسجيل الحساب لإدارة النظام لتفعيله',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // حقل رقم القيد
                          Text(
                            'رقم القيد الأكاديمي',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _idController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              hintText: 'أدخل رقم القيد الأكاديمي الخاص بك',
                              hintStyle: TextStyle(
                                color: theme.colorScheme.onSurface.withOpacity(0.4),
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.badge_outlined,
                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'الرجاء إدخال رقم القيد الأكاديمي';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // حقل الاسم الكامل
                          Text(
                            'الاسم الكامل',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameController,
                            keyboardType: TextInputType.name,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              hintText: 'أدخل اسمك الرباعي بالكامل',
                              hintStyle: TextStyle(
                                color: theme.colorScheme.onSurface.withOpacity(0.4),
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.person_outline_rounded,
                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'الرجاء إدخال الاسم الكامل';
                              }
                              if (value.trim().split(' ').length < 2) {
                                return 'الرجاء إدخال الاسم ثنائي على الأقل';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // حقل البريد الإلكتروني
                          Text(
                            'البريد الإلكتروني',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              hintText: 'أدخل البريد الإلكتروني الفعال الخاص بك',
                              hintStyle: TextStyle(
                                color: theme.colorScheme.onSurface.withOpacity(0.4),
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'الرجاء إدخال البريد الإلكتروني';
                              }
                              // تحقق بسيط من صيغة البريد الإلكتروني
                              final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                              if (!emailRegex.hasMatch(value.trim())) {
                                return 'الرجاء إدخال بريد إلكتروني صحيح';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // حقل كلمة المرور
                          Text(
                            'كلمة المرور',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              hintText: 'أدخل كلمة مرور قوية لحسابك',
                              hintStyle: TextStyle(
                                color: theme.colorScheme.onSurface.withOpacity(0.4),
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.lock_outline_rounded,
                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'الرجاء إدخال كلمة المرور';
                              }
                              if (value.length < 8) {
                                return 'يجب أن تكون كلمة المرور 8 خانات على الأقل';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // حقل تأكيد كلمة المرور
                          Text(
                            'تأكيد كلمة المرور',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              hintText: 'أعد كتابة كلمة المرور لتأكيدها',
                              hintStyle: TextStyle(
                                color: theme.colorScheme.onSurface.withOpacity(0.4),
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.lock_clock_outlined,
                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword = !_obscureConfirmPassword;
                                  });
                                },
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'الرجاء تأكيد كلمة المرور';
                              }
                              if (value != _passwordController.text) {
                                return 'كلمتا المرور غير متطابقتين';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // حقل التخصص (دروب داون)
                          Text(
                            'التخصص',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedMajor,
                            decoration: InputDecoration(
                              prefixIcon: Icon(
                                Icons.category_outlined,
                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'تقنية المعلومات', child: Text('تقنية المعلومات')),
                              DropdownMenuItem(value: 'أمن المعلومات', child: Text('أمن المعلومات')),
                              DropdownMenuItem(value: 'علوم الحاسوب', child: Text('علوم الحاسوب')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedMajor = value;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 20),

                          // حقل المستوى (دروب داون)
                          Text(
                            'المستوى الدراسي',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedLevel,
                            decoration: InputDecoration(
                              prefixIcon: Icon(
                                Icons.bar_chart_outlined,
                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'المستوى الأول', child: Text('المستوى الأول')),
                              DropdownMenuItem(value: 'المستوى الثاني', child: Text('المستوى الثاني')),
                              DropdownMenuItem(value: 'المستوى الثالث', child: Text('المستوى الثالث')),
                              DropdownMenuItem(value: 'المستوى الرابع', child: Text('المستوى الرابع')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedLevel = value;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 20),

                          // حقل المسار (دروب داون)
                          Text(
                            'المسار الدراسي',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedTrack,
                            decoration: InputDecoration(
                              prefixIcon: Icon(
                                Icons.alt_route_outlined,
                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'عام', child: Text('عام (الافتراضي)')),
                              DropdownMenuItem(value: 'برمجيات', child: Text('برمجيات')),
                              DropdownMenuItem(value: 'شبكات', child: Text('شبكات')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedTrack = value;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 20),

                          // حقل الدور (معطل / غير قابل للتعديل)
                          Text(
                            'الدور / الصلاحية',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _roleController,
                            enabled: false, // لا يمكن للمستخدم تعديله كما طلب العميل
                            decoration: InputDecoration(
                              prefixIcon: Icon(
                                Icons.school_outlined,
                                color: theme.colorScheme.onSurface.withOpacity(0.4),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              fillColor: theme.brightness == Brightness.light
                                  ? const Color(0xFFE2E8F0) // لون أغمق ليوضح أنه غير قابل للتعديل
                                  : const Color(0xFF0F172A),
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // زر إرسال الطلب
                          ElevatedButton(
                            onPressed: viewModel.isLoading
                                ? null
                                : () => _handleSubmit(viewModel),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              minimumSize: const Size(double.infinity, 54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: viewModel.isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'إرسال طلب التسجيل',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // زر العودة لتسجيل الدخول
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'لديك حساب بالفعل؟ ',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const LoginView()),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'تسجيل الدخول',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
