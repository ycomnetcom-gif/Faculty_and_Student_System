import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_attendance_system/features/login/login_view.dart';
import 'package:student_attendance_system/core/sync_service.dart';
import 'package:student_attendance_system/core/database_helper.dart';
import 'package:student_attendance_system/features/teacher_screens/head_of_department/head_of_department_view.dart';
import 'teacher_home_view_model.dart';

class TeacherHomeView extends StatefulWidget {
  const TeacherHomeView({super.key});

  @override
  State<TeacherHomeView> createState() => _TeacherHomeViewState();
}

class _TeacherHomeViewState extends State<TeacherHomeView> {
  bool _isSyncingLocal = false;

  @override
  void initState() {
    super.initState();
    // جلب البيانات عند فتح الشاشة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TeacherHomeViewModel>().fetchTeacherProfile();
    });
  }

  void _handleSync(BuildContext context) async {
    if (_isSyncingLocal) return;

    setState(() {
      _isSyncingLocal = true;
    });

    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('جاري مزامنة البيانات مع السيرفر...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final syncedCount = await SyncService.instance.triggerSync();
      
      if (!mounted) return;

      if (syncedCount > 0) {
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 8),
                Text('تمت مزامنة $syncedCount من السجلات بنجاح!'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white),
                SizedBox(width: 8),
                Text('البيانات محدثة بالفعل. لا يوجد سجلات للمزامنة.'),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      String errorMsg = 'حدث خطأ أثناء المزامنة';
      if (e.toString().contains('no_internet')) {
        errorMsg = 'لا يتوفر اتصال بالإنترنت حالياً. يرجى التحقق من الشبكة.';
      } else {
        errorMsg = 'فشلت المزامنة: ${e.toString()}';
      }

      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(errorMsg)),
            ],
          ),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncingLocal = false;
        });
      }
    }
  }

  void _handleSignOut(BuildContext context, TeacherHomeViewModel viewModel) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'تسجيل الخروج',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج من التطبيق؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'إلغاء',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              minimumSize: const Size(80, 40),
            ),
            child: const Text('تسجيل خروج'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 1. تحقق مما إذا كانت هناك بيانات غير متزامنة محلياً
    try {
      final unsynced = await DatabaseHelper.instance.getUnsyncedUsers();
      
      if (unsynced.isNotEmpty) {
        // إظهار تنبيه جاري المزامنة قبل الخروج
        messenger.showSnackBar(
          const SnackBar(
            content: Text('جاري مزامنة التحديثات المعلقة قبل تسجيل الخروج...'),
            duration: Duration(seconds: 2),
          ),
        );

        try {
          await SyncService.instance.triggerSync();
        } catch (syncError) {
          // في حال فشل المزامنة (مثل انقطاع الإنترنت)
          if (!context.mounted) return;
          
          final forceSignOut = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text(
                'تنبيه: لم تكتمل المزامنة',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: const Text(
                'يتعذر الاتصال بالإنترنت لمزامنة البيانات المعلقة. تسجيل الخروج الآن سيؤدي إلى فقدان التحديثات غير المرفوعة محلياً. هل تريد الاستمرار وتسجيل الخروج على أي حال؟',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('إلغاء وتعديل الاتصال'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('تسجيل خروج وفقدان البيانات'),
                ),
              ],
            ),
          );

          if (forceSignOut != true) {
            return; // إلغاء عملية تسجيل الخروج
          }
        }
      }
    } catch (e) {
      debugPrint('Error during pre-signout check: $e');
    }

    // 2. إتمام عملية تسجيل الخروج ومسح التخزين المحلي
    await viewModel.signOut();
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<TeacherHomeViewModel>(
      builder: (context, viewModel, child) {
        final profile = viewModel.profile;

        return Scaffold(
          drawer: _buildDrawer(context, profile, isDark),
          appBar: AppBar(
            title: const Text('لوحة تحكم المدرس'),
            actions: [
              _isSyncingLocal
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.sync_rounded),
                      tooltip: 'مزامنة البيانات',
                      onPressed: () => _handleSync(context),
                    ),
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'تسجيل الخروج',
                onPressed: () => _handleSignOut(context, viewModel),
              ),
            ],
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          extendBodyBehindAppBar: true,
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
              child: viewModel.isLoading && profile == null
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. بطاقة معلومات المدرس
                          _buildTeacherCard(context, profile, isDark),
                          const SizedBox(height: 28),

                          // عنوان القسم
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              'الخدمات السريعة',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 2. شبكة الأزرار والبطاقات للخدمات
                          _buildServicesGrid(context, profile, isDark),
                          
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  // بطاقة معلومات المدرس المميزة
  Widget _buildTeacherCard(BuildContext context, TeacherProfile? profile, bool isDark) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    if (profile == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  primaryColor.withOpacity(0.2),
                  theme.colorScheme.secondary.withOpacity(0.1),
                ]
              : [
                  primaryColor,
                  theme.colorScheme.secondary,
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : primaryColor).withOpacity(isDark ? 0.2 : 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: isDark
            ? Border.all(color: Colors.white.withOpacity(0.08), width: 1.5)
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // خلفية زخرفية ناعمة
            Positioned(
              left: -40,
              top: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            Positioned(
              right: -20,
              bottom: -50,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Row(
                children: [
                  // الصورة الرمزية للمدرس
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(isDark ? 0.1 : 0.2),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: ClipOval(
                      child: Center(
                        child: Text(
                          profile.name.split(' ').where((s) => s.isNotEmpty).take(2).map((s) => s[0]).join(''),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // النصوص والمعلومات
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                profile.academicTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          profile.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.school_outlined,
                              color: Colors.white70,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                profile.department,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.email_outlined,
                              color: Colors.white70,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                profile.email,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // شبكة الخدمات والأزرار
  Widget _buildServicesGrid(BuildContext context, TeacherProfile? profile, bool isDark) {
    final services = [
      _ServiceItem(
        title: 'باركود التحضير',
        subtitle: 'توليد كود QR لحضور المحاضرة',
        icon: Icons.qr_code_scanner_rounded,
        color: const Color(0xFF2563EB), // أزرق
        onTap: () => _navigateToService(context, 'باركود التحضير'),
      ),
      _ServiceItem(
        title: 'التحضير اليدوي',
        subtitle: 'تسجيل الحضور يدويًا للطلاب',
        icon: Icons.playlist_add_check_rounded,
        color: const Color(0xFF059669), // أخضر
        onTap: () => _navigateToService(context, 'التحضير اليدوي'),
      ),
      _ServiceItem(
        title: 'إحصائيات المحاضرات',
        subtitle: 'مراجعة نسب الحضور وتقاريرها',
        icon: Icons.bar_chart_rounded,
        color: const Color(0xFFD97706), // برتقالي
        onTap: () => _navigateToService(context, 'إحصائيات المحاضرات'),
      ),
      _ServiceItem(
        title: 'رفع إلى رئيس القسم',
        subtitle: 'إرسال ومشاركة كشوفات الحضور',
        icon: Icons.cloud_upload_rounded,
        color: const Color(0xFF7C3AED), // بنفسجي
        onTap: () => _navigateToService(context, 'رفع إلى رئيس القسم'),
      ),
      if (profile != null &&
          (profile.academicTitle == 'رئيس قسم' ||
           profile.academicTitle == 'مطور' ||
           profile.academicTitle.toLowerCase() == 'developer' ||
           profile.academicTitle.toLowerCase() == 'admin'))
        _ServiceItem(
          title: 'مهام رئيس القسم',
          subtitle: 'مراجعة الطلبات والتحكم',
          icon: Icons.admin_panel_settings_rounded,
          color: const Color(0xFFDC2626), // أحمر
          onTap: () => _navigateToService(context, 'مهام رئيس القسم'),
        ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];
        return _buildServiceCard(context, service, isDark);
      },
    );
  }

  // بطاقة الخدمة الفردية
  Widget _buildServiceCard(BuildContext context, _ServiceItem service, bool isDark) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : theme.colorScheme.primary.withOpacity(0.05),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: service.onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: service.color.withOpacity(0.1),
          highlightColor: service.color.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // الأيقونة واللون المميز خلفها
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: service.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    service.icon,
                    color: service.color,
                    size: 32,
                  ),
                ),
                
                // النصوص
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      service.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.55),
                        height: 1.3,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // بناء الـ Drawer الجانبي المميز
  Widget _buildDrawer(BuildContext context, TeacherProfile? profile, bool isDark) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    final isHeadOrDev = profile != null &&
        (profile.academicTitle == 'رئيس قسم' ||
         profile.academicTitle == 'مطور' ||
         profile.academicTitle.toLowerCase() == 'developer' ||
         profile.academicTitle.toLowerCase() == 'admin');

    return Drawer(
      child: Container(
        color: theme.colorScheme.surface,
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF1E293B),
                          const Color(0xFF0F172A),
                        ]
                      : [
                          primaryColor,
                          theme.colorScheme.secondary,
                        ],
                ),
              ),
              currentAccountPicture: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white24,
                ),
                child: Center(
                  child: Text(
                    profile != null
                        ? profile.name.split(' ').where((s) => s.isNotEmpty).take(2).map((s) => s[0]).join('')
                        : 'أ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              accountName: Text(
                profile?.name ?? 'تحميل الاسم...',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              accountEmail: Text(
                profile?.email ?? 'تحميل البريد...',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('الرئيسية'),
              onTap: () {
                Navigator.of(context).pop();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner_rounded),
              title: const Text('باركود التحضير'),
              onTap: () {
                Navigator.of(context).pop();
                _navigateToService(context, 'باركود التحضير');
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_check_rounded),
              title: const Text('التحضير اليدوي'),
              onTap: () {
                Navigator.of(context).pop();
                _navigateToService(context, 'التحضير اليدوي');
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart_rounded),
              title: const Text('إحصائيات المحاضرات'),
              onTap: () {
                Navigator.of(context).pop();
                _navigateToService(context, 'إحصائيات المحاضرات');
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_upload_rounded),
              title: const Text('رفع إلى رئيس القسم'),
              onTap: () {
                Navigator.of(context).pop();
                _navigateToService(context, 'رفع إلى رئيس القسم');
              },
            ),
            if (isHeadOrDev) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined, color: Colors.red),
                title: const Text(
                  'مهام رئيس القسم',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _navigateToService(context, 'مهام رئيس القسم');
                },
              ),
            ],
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              title: const Text('تسجيل الخروج'),
              onTap: () {
                Navigator.of(context).pop();
                final viewModel = Provider.of<TeacherHomeViewModel>(context, listen: false);
                _handleSignOut(context, viewModel);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // التنقل إلى الخدمات (مؤقت حالياً لعرض رسالة تنبيه)
  void _navigateToService(BuildContext context, String serviceName) {
    ScaffoldMessenger.of(context).clearSnackBars();
    if (serviceName == 'مهام رئيس القسم') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const HeadOfDepartmentView()),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 8),
            Text('تم الانتقال إلى وجهة: $serviceName'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

// كلاس مساعد لبيانات الخدمات
class _ServiceItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _ServiceItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
