import 'package:flutter/material.dart';
import 'configure_student_accounts/configure_student_accounts_view.dart';

class HeadOfDepartmentView extends StatefulWidget {
  const HeadOfDepartmentView({super.key});

  @override
  State<HeadOfDepartmentView> createState() => _HeadOfDepartmentViewState();
}

class _HeadOfDepartmentViewState extends State<HeadOfDepartmentView> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مهام رئيس القسم'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
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
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // رأس الصفحة الترحيبي
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.admin_panel_settings_rounded,
                        size: 32,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'لوحة إدارة القسم',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'متابعة وإدارة الصلاحيات والمقررات الدراسية',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // عنوان القسم المهام
                Text(
                  'المهام الإدارية والرقابية',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),

                // 1. تعيين حسابات الطلاب (مهمة عريضة)
                _buildTaskCard(
                  context: context,
                  title: 'تعيين حسابات الطلاب',
                  subtitle: 'تهيئة حسابات الطلاب الجدد من خلال استيراد ملفات Excel/CSV',
                  icon: Icons.assignment_ind_rounded,
                  gradientColors: [
                    const Color(0xFF8B5CF6),
                    const Color(0xFF6D28D9),
                  ],
                  trailingWidget: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ConfigureStudentAccountsView(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // 2. إحصائيات وتقارير القسم (مهمة عريضة)
                _buildTaskCard(
                  context: context,
                  title: 'تقارير الحضور والغياب',
                  subtitle: 'متابعة نسب حضور الطلاب الإجمالية في جميع المقررات',
                  icon: Icons.insert_chart_outlined_rounded,
                  gradientColors: [
                    const Color(0xFF10B981),
                    const Color(0xFF047857),
                  ],
                  trailingWidget: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                  onTap: () {
                    _showComingSoonSnackBar(context, 'تقارير الحضور والغياب');
                  },
                ),

                const SizedBox(height: 16),

                // 3. إدارة الجداول الدراسية والشعب (مهمة عريضة)
                _buildTaskCard(
                  context: context,
                  title: 'إدارة الشعب والمقررات',
                  subtitle: 'إعداد وتوزيع الشعب الدراسية لمدرسي القسم',
                  icon: Icons.grid_view_rounded,
                  gradientColors: [
                    const Color(0xFFF59E0B),
                    const Color(0xFFD97706),
                  ],
                  trailingWidget: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                  onTap: () {
                    _showComingSoonSnackBar(context, 'إدارة الشعب والمقررات');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // بناء بطاقة المهمة العريضة
  Widget _buildTaskCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required Widget trailingWidget,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Row(
              children: [
                // أيقونة الخدمة
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),

                // نصوص البطاقة
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                trailingWidget,
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showComingSoonSnackBar(BuildContext context, String title) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ميزة ($title) قيد التطوير حالياً وسجلت في خطة العمل.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
