import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:student_attendance_system/core/theme.dart';
import 'configure_student_accounts_view_model.dart';
import 'student_account_config_model.dart';

class ConfigureStudentAccountsView extends StatefulWidget {
  const ConfigureStudentAccountsView({super.key});

  @override
  State<ConfigureStudentAccountsView> createState() => _ConfigureStudentAccountsViewState();
}

class _ConfigureStudentAccountsViewState extends State<ConfigureStudentAccountsView> {
  late final ConfigureStudentAccountsViewModel _viewModel;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isFirstConnectivityEvent = true;

  bool _isManualMode = false;
  final _manualFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _regIdController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel = ConfigureStudentAccountsViewModel();

    // الاستماع لحالة الاتصال بالإنترنت لمزامنة البيانات تلقائياً فور عودة الشبكة
    // نتجاهل أول حدث لأنه يُطلق فورياً عند الاشتراك حتى لو لم تتغير الشبكة
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (_isFirstConnectivityEvent) {
        _isFirstConnectivityEvent = false;
        return;
      }
      final hasConnection = results.any((result) => result != ConnectivityResult.none);
      if (hasConnection) {
        _viewModel.syncConfigs();
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _nameController.dispose();
    _regIdController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _showDeleteConfirmation(BuildContext context, StudentAccountConfigModel student, ConfigureStudentAccountsViewModel viewModel) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor, size: 40),
                const SizedBox(height: 8),
                Text(
                  'تأكيد الحذف',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'هل أنت متأكد من رغبتك في حذف تهيئة حساب الطالب "${student.studentName}"؟',
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Cairo', height: 1.5),
              ),
              const SizedBox(height: 24),
              // زر الحذف (تأكيد)
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    viewModel.deleteConfig(student.registrationId);
                  },
                  child: const Text(
                    'تأكيد الحذف',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // زر الإلغاء بالمنتصف أسفل منه
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'إلغاء',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditBottomSheet(BuildContext context, StudentAccountConfigModel student, ConfigureStudentAccountsViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditStudentAccountBottomSheet(
        student: student,
        viewModel: viewModel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ConfigureStudentAccountsViewModel>.value(
      value: _viewModel,
      child: Consumer<ConfigureStudentAccountsViewModel>(
        builder: (context, viewModel, child) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;

          // استماع لرسائل النجاح أو الفشل وعرضها كـ SnackBar
          if (viewModel.successMessage != null || viewModel.errorMessage != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    viewModel.successMessage ?? viewModel.errorMessage!,
                    style: const TextStyle(fontFamily: 'Cairo'),
                  ),
                  backgroundColor: viewModel.successMessage != null
                      ? AppTheme.successColor
                      : AppTheme.errorColor,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              viewModel.clearMessages();
            });
          }

          return Scaffold(
            appBar: AppBar(
              title: const Text('تعيين حسابات الطلاب'),
              elevation: 0,
              backgroundColor: Colors.transparent,
              foregroundColor: theme.colorScheme.onSurface,
              actions: [
                viewModel.isLoading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.sync_rounded),
                        tooltip: 'مزامنة مع السيرفر',
                        onPressed: () => viewModel.syncConfigs(),
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
                          const Color(0xFF0F172A),
                          const Color(0xFF1E293B),
                        ]
                      : [
                          const Color(0xFFEFF6FF),
                          const Color(0xFFDBEAFE),
                          const Color(0xFFF8FAFC),
                        ],
                ),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      
                      // كارت نموذج الإدخال والاستيراد
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: AppTheme.cardDecoration(context).copyWith(
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.08),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إعدادات الدفعة الطلابية',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 1. حقل التخصص (غير قابل للتعديل)
                            Text(
                              'التخصص (القسم)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.school_rounded,
                                    color: theme.colorScheme.primary.withOpacity(0.7),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      viewModel.department,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.lock_rounded,
                                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 2. حقل المستوى (Dropdown)
                            Text(
                              'المستوى الدراسي',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: viewModel.selectedLevel,
                              decoration: InputDecoration(
                                prefixIcon: Icon(
                                  Icons.layers_rounded,
                                  color: theme.colorScheme.primary.withOpacity(0.7),
                                  size: 20,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              items: viewModel.levels.map((level) {
                                return DropdownMenuItem(
                                  value: level,
                                  child: Text(level, style: const TextStyle(fontSize: 14)),
                                );
                              }).toList(),
                              onChanged: viewModel.isLoading
                                  ? null
                                  : (val) {
                                      if (val != null) viewModel.setLevel(val);
                                    },
                            ),
                            const SizedBox(height: 16),

                            // 3. حقل المسار (Dropdown)
                            Text(
                              'المسار / الخطة الدراسية',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: viewModel.selectedTrack,
                              decoration: InputDecoration(
                                prefixIcon: Icon(
                                  Icons.alt_route_rounded,
                                  color: theme.colorScheme.primary.withOpacity(0.7),
                                  size: 20,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              items: viewModel.tracks.map((track) {
                                return DropdownMenuItem(
                                  value: track,
                                  child: Text(track, style: const TextStyle(fontSize: 14)),
                                );
                              }).toList(),
                              onChanged: viewModel.isLoading
                                  ? null
                                  : (val) {
                                      if (val != null) viewModel.setTrack(val);
                                    },
                            ),
                            const SizedBox(height: 20),

                            // 3.5. اختيار طريقة الإضافة
                            Row(
                              children: [
                                Expanded(
                                  child: ChoiceChip(
                                    label: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.upload_file_rounded, size: 16),
                                        SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            'استيراد ملف',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    selected: !_isManualMode,
                                    selectedColor: theme.colorScheme.primary.withOpacity(0.15),
                                    backgroundColor: Colors.transparent,
                                    labelStyle: TextStyle(
                                      color: !_isManualMode ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(
                                        color: !_isManualMode ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.12),
                                      ),
                                    ),
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() {
                                          _isManualMode = false;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ChoiceChip(
                                    label: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.person_add_alt_1_rounded, size: 16),
                                        SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            'إضافة يدوية',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    selected: _isManualMode,
                                    selectedColor: theme.colorScheme.primary.withOpacity(0.15),
                                    backgroundColor: Colors.transparent,
                                    labelStyle: TextStyle(
                                      color: _isManualMode ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(
                                        color: _isManualMode ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.12),
                                      ),
                                    ),
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() {
                                          _isManualMode = true;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            if (!_isManualMode) ...[
                              // 4. زر الاستيراد
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: LinearGradient(
                                    colors: viewModel.isLoading
                                        ? [Colors.grey, Colors.grey]
                                        : [theme.colorScheme.primary, theme.colorScheme.secondary],
                                  ),
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: viewModel.isLoading
                                      ? null
                                      : () => viewModel.importStudentAccounts(),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.upload_file_rounded, color: Colors.white),
                                      const SizedBox(width: 10),
                                      Flexible(
                                        child: Text(
                                          viewModel.isLoading
                                              ? 'جاري معالجة الملف واستيراده...'
                                              : 'استيراد قائمة الطلاب (Excel / CSV)',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ] else ...[
                              // نموذج الإضافة اليدوية
                              Form(
                                key: _manualFormKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // اسم الطالب
                                    Text(
                                      'اسم الطالب',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _nameController,
                                      keyboardType: TextInputType.name,
                                      style: const TextStyle(fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: 'اسم الطالب رباعي',
                                        prefixIcon: Icon(Icons.person_outline_rounded, color: theme.colorScheme.primary, size: 20),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'الرجاء إدخال اسم الطالب';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),

                                    // رقم القيد
                                    Text(
                                      'رقم القيد الجامعي',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _regIdController,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: 'مثال: 202310001',
                                        prefixIcon: Icon(Icons.badge_outlined, color: theme.colorScheme.primary, size: 20),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'الرجاء إدخال رقم القيد';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),

                                    // البريد الإلكتروني
                                    Text(
                                      'البريد الإلكتروني',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      style: const TextStyle(fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: 'مثال: student@example.com',
                                        prefixIcon: Icon(Icons.email_outlined, color: theme.colorScheme.primary, size: 20),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                                    const SizedBox(height: 20),

                                    // زر الحفظ اليدوي
                                    SizedBox(
                                      width: double.infinity,
                                      height: 48,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: theme.colorScheme.primary,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        onPressed: viewModel.isLoading
                                            ? null
                                            : () async {
                                                if (_manualFormKey.currentState!.validate()) {
                                                  await viewModel.addStudentAccountConfig(
                                                    name: _nameController.text,
                                                    registrationId: _regIdController.text,
                                                    email: _emailController.text,
                                                  );
                                                  if (viewModel.errorMessage == null) {
                                                    // نجاح الإضافة - تنظيف الحقول
                                                    _nameController.clear();
                                                    _regIdController.clear();
                                                    _emailController.clear();
                                                  }
                                                }
                                              },
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.save_rounded),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                viewModel.isLoading ? 'جاري الحفظ...' : 'إضافة وحفظ الطالب',
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),

                      // ترويسة قائمة الطلاب المستوردين
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'الطلاب المهيئين محلياً',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'العدد: ${viewModel.configs.length}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 10),

                      // قائمة الطلاب المستوردين
                      viewModel.configs.isEmpty
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.people_alt_rounded,
                                    size: 64,
                                    color: theme.colorScheme.onSurface.withOpacity(0.2),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'لا يوجد طلاب مهيئين حالياً.\nقم باستيراد ملف Excel أو إضافتهم يدوياً.',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: viewModel.configs.length,
                              itemBuilder: (context, index) {
                                final student = viewModel.configs[index];
                                final isSynced = student.syncStatus == 1;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // اسم الطالب + أزرار التحكم
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                student.studentName,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                              ),
                                            ),
                                            // مؤشر حالة المزامنة
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: isSynced
                                                    ? AppTheme.successColor.withOpacity(0.1)
                                                    : AppTheme.warningColor.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    isSynced ? Icons.check_circle_rounded : Icons.sync_problem_rounded,
                                                    size: 13,
                                                    color: isSynced ? AppTheme.successColor : AppTheme.warningColor,
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    isSynced ? 'مزامَن' : 'معلق',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: isSynced ? AppTheme.successColor : AppTheme.warningColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // زر تعديل
                                            SizedBox(
                                              width: 34,
                                              height: 34,
                                              child: IconButton(
                                                padding: EdgeInsets.zero,
                                                icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary, size: 20),
                                                onPressed: () => _showEditBottomSheet(context, student, viewModel),
                                              ),
                                            ),
                                            // زر حذف
                                            SizedBox(
                                              width: 34,
                                              height: 34,
                                              child: IconButton(
                                                padding: EdgeInsets.zero,
                                                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor, size: 20),
                                                onPressed: () => _showDeleteConfirmation(context, student, viewModel),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text('رقم القيد: ${student.registrationId}', style: const TextStyle(fontSize: 12)),
                                        Text('البريد: ${student.email}', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 6),
                                        // شارة المستوى والمسار
                                        Wrap(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.primary.withOpacity(0.08),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${student.level} · ${student.track}',
                                                style: TextStyle(
                                                  color: theme.colorScheme.primary,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EditStudentAccountBottomSheet extends StatefulWidget {
  final StudentAccountConfigModel student;
  final ConfigureStudentAccountsViewModel viewModel;

  const _EditStudentAccountBottomSheet({
    Key? key,
    required this.student,
    required this.viewModel,
  }) : super(key: key);

  @override
  State<_EditStudentAccountBottomSheet> createState() => _EditStudentAccountBottomSheetState();
}

class _EditStudentAccountBottomSheetState extends State<_EditStudentAccountBottomSheet> {
  final _editFormKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late String _selectedLevel;
  late String _selectedTrack;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.student.studentName);
    _emailController = TextEditingController(text: widget.student.email);
    _selectedLevel = widget.student.level;
    _selectedTrack = widget.student.track;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _editFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'تعديل بيانات الطالب',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'رقم القيد: ${widget.student.registrationId} (غير قابل للتعديل)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 20),

              // اسم الطالب
              Text(
                'اسم الطالب',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                keyboardType: TextInputType.name,
                style: const TextStyle(fontSize: 14, fontFamily: 'Cairo'),
                decoration: InputDecoration(
                  hintText: 'اسم الطالب رباعي',
                  prefixIcon: Icon(Icons.person_outline_rounded, color: theme.colorScheme.primary, size: 20),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الرجاء إدخال اسم الطالب';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // البريد الإلكتروني
              Text(
                'البريد الإلكتروني',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontSize: 14, fontFamily: 'Cairo'),
                decoration: InputDecoration(
                  hintText: 'student@example.com',
                  prefixIcon: Icon(Icons.email_outlined, color: theme.colorScheme.primary, size: 20),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
              const SizedBox(height: 12),

              // المستوى (Dropdown)
              Text(
                'المستوى الدراسي',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedLevel,
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.layers_rounded,
                    color: theme.colorScheme.primary.withOpacity(0.7),
                    size: 20,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: widget.viewModel.levels.map((level) {
                  return DropdownMenuItem(
                    value: level,
                    child: Text(level, style: const TextStyle(fontSize: 14, fontFamily: 'Cairo')),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedLevel = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),

              // المسار (Dropdown)
              Text(
                'المسار / الخطة الدراسية',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedTrack,
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.alt_route_rounded,
                    color: theme.colorScheme.primary.withOpacity(0.7),
                    size: 20,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: widget.viewModel.tracks.map((track) {
                  return DropdownMenuItem(
                    value: track,
                    child: Text(track, style: const TextStyle(fontSize: 14, fontFamily: 'Cairo')),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedTrack = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 24),

              // زر حفظ التعديل
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    if (_editFormKey.currentState!.validate()) {
                      Navigator.of(context).pop();
                      await widget.viewModel.updateStudentAccountConfig(
                        registrationId: widget.student.registrationId,
                        name: _nameController.text,
                        email: _emailController.text,
                        level: _selectedLevel,
                        track: _selectedTrack,
                      );
                    }
                  },
                  child: const Text(
                    'حفظ التعديلات',
                    style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

