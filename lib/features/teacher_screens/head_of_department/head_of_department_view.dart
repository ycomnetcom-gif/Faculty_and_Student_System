import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:student_attendance_system/core/theme.dart';
import 'registration_requests/registration_requests_view.dart';

class HeadOfDepartmentView extends StatefulWidget {
  const HeadOfDepartmentView({super.key});

  @override
  State<HeadOfDepartmentView> createState() => _HeadOfDepartmentViewState();
}

class _HeadOfDepartmentViewState extends State<HeadOfDepartmentView> {
  int? _pendingCount;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchPendingCount();
  }

  // جلب عدد الطلبات المعلقة يدوياً من السيرفر
  Future<void> _fetchPendingCount() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final aggregateQuery = await FirebaseFirestore.instance
          .collection('Registration_requests')
          .where('state', isEqualTo: 'قيد المراجعة')
          .count()
          .get(source: AggregateSource.server)
          .timeout(const Duration(seconds: 10));

      if (mounted) {
        setState(() {
          _pendingCount = aggregateQuery.count;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching pending requests count: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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
        actions: [
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.sync_rounded),
                  tooltip: 'مزامنة البيانات',
                  onPressed: _fetchPendingCount,
                ),
        ],
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
          child: RefreshIndicator(
            onRefresh: _fetchPendingCount,
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

                  // 1. زر مراجعة طلبات التسجيل (مهمة عريضة)
                  _buildTaskCard(
                    context: context,
                    title: 'مراجعة طلبات التسجيل',
                    subtitle: 'اعتماد أو رفض طلبات إنشاء حسابات الطلاب الجدد',
                    icon: Icons.people_outline_rounded,
                    gradientColors: [
                      const Color(0xFF3B82F6),
                      const Color(0xFF1D4ED8),
                    ],
                    trailingWidget: _pendingCount != null && _pendingCount! > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$_pendingCount طلب معلق',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white70,
                            size: 18,
                          ),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RegistrationRequestsView(),
                        ),
                      );
                      // إعادة جلب العدد عند الرجوع من صفحة الطلبات لتحديث الـ Badge
                      _fetchPendingCount();
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
