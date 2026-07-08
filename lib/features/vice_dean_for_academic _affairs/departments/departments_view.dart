import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import 'package:student_attendance_system/core/theme.dart';
import 'package:student_attendance_system/features/vice_dean_for_academic _affairs/departments/department_model.dart';
import 'package:student_attendance_system/features/vice_dean_for_academic _affairs/departments/departments_view_model.dart';

class DepartmentsView extends StatefulWidget {
  const DepartmentsView({super.key});

  @override
  State<DepartmentsView> createState() => _DepartmentsViewState();
}

class _DepartmentsViewState extends State<DepartmentsView> {
  final _formKey = GlobalKey<FormState>();
  final _deptNameController = TextEditingController();
  TextEditingController? _headController; // سيتم تعيينه داخل Autocomplete

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = Provider.of<DepartmentsViewModel>(context, listen: false);
      viewModel.loadData();

      // الاستماع لحالة الاتصال بالإنترنت لمزامنة البيانات تلقائياً
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
        final hasConnection = results.any((result) => result != ConnectivityResult.none);
        if (hasConnection) {
          viewModel.autoSync();
        }
      });
    });
  }

  @override
  void dispose() {
    _deptNameController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  // إضافة أو تعديل القسم
  Future<void> _saveDepartment(DepartmentsViewModel viewModel) async {
    if (!_formKey.currentState!.validate()) return;
    if (viewModel.selectedUser == null || _headController == null || _headController!.text != viewModel.selectedUser!.name) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('الرجاء اختيار رئيس قسم صحيح من القائمة المنسدلة'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final String deptName = _deptNameController.text.trim();
    final String headId = viewModel.selectedUser!.id;
    final String headName = viewModel.selectedUser!.name;

    final result = await viewModel.saveDepartment(
      deptName: deptName,
      headId: headId,
      headName: headName,
    );

    if (mounted) {
      if (result != null && result.contains('success')) {
        String msg = '';
        if (result.contains('add')) {
          msg = result.contains('online')
              ? 'تمت إضافة قسم "$deptName" ورفعه للسيرفر بنجاح!'
              : 'تم حفظ القسم محلياً بنجاح (سيتم رفعه تلقائياً فور توفر الإنترنت)';
        } else {
          msg = result.contains('online')
              ? 'تم تعديل قسم "$deptName" وتحديثه في السيرفر بنجاح!'
              : 'تم تعديل القسم محلياً بنجاح (سيتم مزامنته تلقائياً فور توفر الإنترنت)';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: result.contains('online') ? AppTheme.successColor : AppTheme.warningColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء حفظ القسم: $result'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }

      // تنظيف المدخلات وإخلاء حالة التعديل
      _deptNameController.clear();
      if (_headController != null) _headController!.clear();
      viewModel.setEditingDepartment(null);
    }
  }

  // مزامنة وجلب التحديثات
  Future<void> _performSync(DepartmentsViewModel viewModel) async {
    try {
      final success = await viewModel.performSync();
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تمت مزامنة وجلب التحديثات بنجاح!'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يوجد اتصال بالإنترنت لإجراء المزامنة'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشلت المزامنة: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // دالة لتنسيق تاريخ ووقت الإنشاء بشكل مقروء
  String _formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'غير متوفر';
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final year = dateTime.year;
      final month = dateTime.month.toString().padLeft(2, '0');
      final day = dateTime.day.toString().padLeft(2, '0');
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$year/$month/$day $hour:$minute';
    } catch (e) {
      return isoString;
    }
  }

  // عرض تفاصيل القسم الأكاديمي في Dialog
  void _showDepartmentDetails(BuildContext context, Department dept) {
    final theme = Theme.of(context);
    final bool isSynced = dept.sync == 1;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Icon(Icons.business_rounded, color: theme.colorScheme.primary, size: 28),
              const SizedBox(width: 10),
              const Text(
                'تفاصيل القسم الأكاديمي',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(context, 'اسم القسم:', dept.name, Icons.label_important_outline_rounded),
              const SizedBox(height: 12),
              _buildDetailRow(context, 'رئيس القسم:', dept.headName.isNotEmpty ? dept.headName : 'غير معين', Icons.person_outline_rounded),
              const SizedBox(height: 12),
              _buildDetailRow(context, 'معرف رئيس القسم:', dept.headId.isNotEmpty ? dept.headId : 'غير متوفر', Icons.vpn_key_outlined),
              const SizedBox(height: 12),
              _buildDetailRow(context, 'تاريخ الإنشاء:', _formatDateTime(dept.createdAt), Icons.calendar_today_rounded),
              const SizedBox(height: 12),
              _buildDetailRow(
                context,
                'حالة المزامنة:',
                isSynced ? 'متزامن بنجاح' : 'معلق الرفع (أوفلاين)',
                Icons.sync_rounded,
                valueColor: isSynced ? AppTheme.successColor : AppTheme.warningColor,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // ديالوج تأكيد حذف القسم
  void _confirmDelete(BuildContext context, Department dept, DepartmentsViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor, size: 28),
              const SizedBox(width: 10),
              const Text('تأكيد الحذف', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'هل أنت متأكد من رغبتك في حذف قسم "${dept.name}"؟\nسيتم إرجاع دور رئيس القسم الحالي إلى عضو هيئة تدريس.',
          ),
          actions: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    final result = await viewModel.deleteDepartment(dept);
                    if (context.mounted) {
                      if (result != null && result.startsWith('error')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('حدث خطأ أثناء الحذف: $result'),
                            backgroundColor: AppTheme.errorColor,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result == 'delete_success_online' 
                                ? 'تم حذف القسم وتحديث دور رئيس القسم بنجاح' 
                                : 'تم حذف القسم محلياً وسيتم المزامنة لاحقاً'),
                            backgroundColor: AppTheme.successColor,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('حذف القسم', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'إلغاء',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // بناء سطر لعرض معلومة محددة في الديالوج
  Widget _buildDetailRow(BuildContext context, String label, String value, IconData icon, {Color? valueColor}) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary.withOpacity(0.7)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final viewModel = Provider.of<DepartmentsViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الأقسام الكلية'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          viewModel.isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
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
                  tooltip: 'مزامنة وجلب التحديثات',
                  onPressed: () => _performSync(viewModel),
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
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE), const Color(0xFFF8FAFC)],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => _performSync(viewModel),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // بطاقة إضافة قسم جديد
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: AppTheme.cardDecoration(context).copyWith(
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.08),
                        width: 1.5,
                      ),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                viewModel.editingDepartment != null ? Icons.edit_road_rounded : Icons.add_home_work_rounded,
                                color: theme.colorScheme.primary,
                                size: 28,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  viewModel.editingDepartment != null ? 'تعديل القسم الأكاديمي' : 'إضافة قسم أكاديمي جديد',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (viewModel.editingDepartment != null) ...[
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  icon: const Icon(Icons.cancel_outlined, size: 16),
                                  label: const Text(
                                    'إلغاء',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  onPressed: () {
                                    viewModel.setEditingDepartment(null);
                                    _deptNameController.clear();
                                    if (_headController != null) _headController!.clear();
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.errorColor,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const Divider(height: 24, thickness: 1),

                          // حقل اسم القسم
                          Text(
                            'اسم القسم الأكاديمي',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _deptNameController,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              hintText: 'مثال: قسم علوم الحاسوب',
                              prefixIcon: Icon(Icons.school_rounded, color: theme.colorScheme.primary),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'الرجاء إدخال اسم القسم الأكاديمي';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // حقل رئيس القسم (بحث / دروب داون منيو قابل للكتابة فيه)
                          Text(
                            'رئيس القسم',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              return Autocomplete<AppUser>(
                                displayStringForOption: (AppUser user) => user.name,
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty) {
                                    return viewModel.users;
                                  }
                                  return viewModel.users.where((AppUser user) {
                                    return user.name
                                        .toLowerCase()
                                        .contains(textEditingValue.text.toLowerCase()) ||
                                        user.role
                                        .toLowerCase()
                                        .contains(textEditingValue.text.toLowerCase());
                                  });
                                },
                                onSelected: (AppUser user) {
                                  viewModel.setSelectedUser(user);
                                },
                                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                  _headController = textEditingController;
                                  return TextFormField(
                                    controller: textEditingController,
                                    focusNode: focusNode,
                                    decoration: InputDecoration(
                                      hintText: 'ابحث أو اكتب اسم رئيس القسم...',
                                      prefixIcon: Icon(Icons.person_search_rounded, color: theme.colorScheme.primary),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'الرجاء تحديد رئيس القسم الأكاديمي';
                                      }
                                      return null;
                                    },
                                  );
                                },
                                optionsViewBuilder: (context, onSelected, options) {
                                  return Align(
                                    alignment: Alignment.topRight,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Material(
                                        elevation: 8,
                                        borderRadius: BorderRadius.circular(16),
                                        color: theme.colorScheme.surface,
                                        child: Container(
                                          width: constraints.maxWidth,
                                          constraints: const BoxConstraints(maxHeight: 220),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: theme.colorScheme.primary.withOpacity(0.12),
                                              width: 1,
                                            ),
                                          ),
                                          child: ListView.builder(
                                            padding: EdgeInsets.zero,
                                            shrinkWrap: true,
                                            itemCount: options.length,
                                            itemBuilder: (BuildContext context, int index) {
                                              final AppUser user = options.elementAt(index);
                                              return ListTile(
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                                                title: Text(
                                                  user.name,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                ),
                                                subtitle: Text(
                                                  'الدور / الصفة: ${user.role}',
                                                  style: TextStyle(
                                                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                leading: CircleAvatar(
                                                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                                                  child: Text(
                                                    user.name.isNotEmpty ? user.name[0] : 'أ',
                                                    style: TextStyle(
                                                      color: theme.colorScheme.primary,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                onTap: () => onSelected(user),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 24),

                          // زر إضافة أو تعديل القسم الأكاديمي
                          ElevatedButton(
                            onPressed: viewModel.isSaving ? null : () => _saveDepartment(viewModel),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            child: viewModel.isSaving
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(viewModel.editingDepartment != null ? Icons.edit_rounded : Icons.save_rounded),
                                        const SizedBox(width: 8),
                                        Text(
                                          viewModel.editingDepartment != null ? 'تعديل وحفظ التغييرات' : 'إضافة وحفظ القسم الأكاديمي',
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // عنوان قائمة الأقسام المضافة
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'الأقسام الأكاديمية المسجلة',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'العدد: ${viewModel.departments.length}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // قائمة الأقسام من SQLite
                  viewModel.isLoading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 40.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : viewModel.departments.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 48.0),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.domain_disabled_rounded,
                                      size: 64,
                                      color: theme.colorScheme.onSurface.withOpacity(0.12),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'لا توجد أقسام مسجلة حالياً.',
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: viewModel.departments.length,
                              itemBuilder: (context, index) {
                                final dept = viewModel.departments[index];
                                final bool isSynced = dept.sync == 1;

                                 return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color: theme.colorScheme.primary.withOpacity(0.05),
                                      width: 1,
                                    ),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => _showDepartmentDetails(context, dept),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
                                            child: Icon(Icons.business_rounded, color: theme.colorScheme.primary),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  dept.name,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.person_outline_rounded,
                                                      size: 14,
                                                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        'رئيس القسم: ${dept.headName.isNotEmpty ? dept.headName : "غير معين"}',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // الأزرار وحالة المزامنة
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: isSynced
                                                      ? AppTheme.successColor.withOpacity(0.1)
                                                      : AppTheme.warningColor.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(30),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      isSynced ? Icons.check_circle_rounded : Icons.cloud_upload_rounded,
                                                      size: 11,
                                                      color: isSynced ? AppTheme.successColor : AppTheme.warningColor,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      isSynced ? 'متزامن' : 'معلق الرفع',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                        color: isSynced ? AppTheme.successColor : AppTheme.warningColor,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: Icon(Icons.edit_rounded, color: theme.colorScheme.primary, size: 20),
                                                    tooltip: 'تعديل القسم',
                                                    constraints: const BoxConstraints(),
                                                    padding: const EdgeInsets.all(4),
                                                    onPressed: () {
                                                      viewModel.setEditingDepartment(dept);
                                                      _deptNameController.text = dept.name;
                                                      if (_headController != null) {
                                                        _headController!.text = dept.headName;
                                                      }
                                                    },
                                                  ),
                                                  const SizedBox(width: 8),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor, size: 20),
                                                    tooltip: 'حذف القسم',
                                                    constraints: const BoxConstraints(),
                                                    padding: const EdgeInsets.all(4),
                                                    onPressed: () => _confirmDelete(context, dept, viewModel),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
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
      ),
    );
  }
}
