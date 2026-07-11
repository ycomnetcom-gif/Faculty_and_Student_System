import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_attendance_system/core/theme.dart';
import 'package:student_attendance_system/features/login/login_view_model.dart';
import 'package:student_attendance_system/features/sigin/faculty_signup_view.dart';
import 'package:student_attendance_system/features/teacher_screens/home/teacher_home_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedUserType = 'general';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin(LoginViewModel viewModel) async {
    if (_formKey.currentState!.validate()) {
      final success = await viewModel.login(
        _emailController.text,
        _passwordController.text,
        userType: _selectedUserType,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('تم تسجيل الدخول بنجاح'),
                ],
              ),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const TeacherHomeView()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(viewModel.errorMessage ?? 'فشل تسجيل الدخول'),
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

  void _showActivationDialog(BuildContext context, LoginViewModel viewModel) {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        bool localIsLoading = false;

        return StatefulBuilder(
          builder: (stateContext, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mark_email_read_outlined, color: theme.colorScheme.primary, size: 40),
                    const SizedBox(height: 8),
                    const Text(
                      'تفعيل حساب الطالب',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'أدخل بريدك الإلكتروني المسجل من قبل رئيس القسم لتصلك رسالة تفعيل حسابك وإنشاء كلمة المرور:',
                      style: TextStyle(fontFamily: 'Cairo', height: 1.4, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !localIsLoading,
                      style: const TextStyle(fontSize: 14, fontFamily: 'Cairo'),
                      decoration: const InputDecoration(
                        hintText: 'student@example.com',
                        prefixIcon: Icon(Icons.email_outlined, size: 20),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'الرجاء إدخال البريد الإلكتروني';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                          return 'الرجاء إدخال بريد إلكتروني صحيح';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                // زر التأكيد أو مؤشر التحميل
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: localIsLoading
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              setState(() {
                                localIsLoading = true;
                              });

                              final success = await viewModel.activateAccount(emailController.text.trim());

                              if (success) {
                                if (dialogContext.mounted) {
                                  Navigator.of(dialogContext).pop(); // إغلاق ديالوج الإدخال
                                }
                                if (context.mounted) {
                                  // إظهار ديالوج النجاح باستخدام الـ context الخارجي الآمن
                                  showDialog(
                                    context: context,
                                    builder: (successCtx) => AlertDialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      title: const Center(
                                        child: Column(
                                          children: [
                                            Icon(Icons.check_circle_outline, color: AppTheme.successColor, size: 50),
                                            SizedBox(height: 8),
                                            Text(
                                              'تم تفعيل الحساب',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                            ),
                                          ],
                                        ),
                                      ),
                                      content: const Text(
                                        'تم تفعيل حسابك بنجاح وإضافتك للنظام. تم إرسال رابط تعيين كلمة المرور إلى بريدك الإلكتروني بنجاح، يرجى فحص بريدك لإنشاء كلمة مرور جديدة ومن ثم تسجيل الدخول.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontFamily: 'Cairo', height: 1.5, fontSize: 13),
                                      ),
                                      actions: [
                                        Center(
                                          child: ElevatedButton(
                                            onPressed: () => Navigator.of(successCtx).pop(),
                                            child: const Text('موافق', style: TextStyle(fontFamily: 'Cairo')),
                                          ),
                                        )
                                      ],
                                    ),
                                  );
                                }
                              } else {
                                if (stateContext.mounted) {
                                  setState(() {
                                    localIsLoading = false;
                                  });
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.error_outline, color: Colors.white),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(viewModel.errorMessage ?? 'فشل تفعيل الحساب'),
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
                          },
                          child: const Text(
                            'إرسال رابط التفعيل',
                            style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                // زر الإلغاء بالمنتصف أسفل منه
                if (!localIsLoading)
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(
                        'إلغاء',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    ).then((_) {
      emailController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewModel = Provider.of<LoginViewModel>(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: theme.brightness == Brightness.light
                ? [
                    const Color(0xFFEFF6FF), // أزرق خفيف جداً
                    const Color(0xFFDBEAFE), // أزرق باهت
                    const Color(0xFFF8FAFC), // رمادي ناعم
                  ]
                : [
                    const Color(0xFF0F172A), // كحلي داكن
                    const Color(0xFF1E293B), // رمادي داكن
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
                  // بطاقة تسجيل الدخول
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
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    size: 48,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'تسجيل الدخول',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'أهلاً بك! سجل دخولك للوصول إلى نظام إدارة الحضور والغياب',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.6),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // نوع المستخدم (طالب/إدارة أو عضو هيئة تدريس)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.05,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedUserType = 'general';
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _selectedUserType == 'general'
                                            ? theme.colorScheme.primary
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'طالب',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: _selectedUserType == 'general'
                                              ? theme.colorScheme.onPrimary
                                              : theme.colorScheme.onSurface
                                                    .withOpacity(0.7),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedUserType = 'faculty';
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _selectedUserType == 'faculty'
                                            ? theme.colorScheme.primary
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'عضو هيئة تدريس',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: _selectedUserType == 'faculty'
                                              ? theme.colorScheme.onPrimary
                                              : theme.colorScheme.onSurface
                                                    .withOpacity(0.7),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          Text(
                            'البريد الإلكتروني',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              hintText: 'أدخل البريد الإلكتروني',
                              hintStyle: TextStyle(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.4,
                                ),
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.badge_outlined,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.5,
                                ),
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
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // حقل كلمة المرور
                          Text(
                            'كلمة المرور',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: viewModel.obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleLogin(viewModel),
                            decoration: InputDecoration(
                              hintText: 'أدخل كلمة المرور الخاصة بك',
                              hintStyle: TextStyle(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.4,
                                ),
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.lock_outlined,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.5,
                                ),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  viewModel.obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                                ),
                                onPressed: viewModel.toggleObscurePassword,
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
                          const SizedBox(height: 16),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: viewModel.rememberMe,
                                      onChanged: (value) {
                                        viewModel.setRememberMe(value ?? false);
                                      },
                                      activeColor: theme.colorScheme.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'تذكرني',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.7),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: () {
                                  // إجراء استعادة كلمة المرور
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'نسيت كلمة المرور؟',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // زر تسجيل الدخول
                          ElevatedButton(
                            onPressed: viewModel.isLoading
                                ? null
                                : () => _handleLogin(viewModel),
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
                                    'تسجيل الدخول',
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
                  const SizedBox(height: 20),

                  // زر تفعيل الحساب للطلاب
                  Center(
                    child: TextButton(
                      onPressed: () => _showActivationDialog(context, viewModel),
                      child: Text(
                        'تفعيل حسابك (للطلاب فقط)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // زر الانتقال لتسجيل عضو هيئة التدريس
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'هل أنت عضو هيئة تدريس؟ ',
                        style: TextStyle(
                          color: theme.brightness == Brightness.light
                              ? const Color(0xFF475569)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const FacultySignupView(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'تسجيل كعضو هيئة تدريس',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // تذييل الصفحة / الدعم الفني
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.support_agent_rounded,
                        size: 18,
                        color: theme.brightness == Brightness.light
                            ? const Color(0xFF64748B)
                            : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'تواجه مشكلة؟ تواصل مع الدعم الفني ',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.brightness == Brightness.light
                              ? const Color(0xFF64748B)
                              : const Color(0xFF94A3B8),
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
