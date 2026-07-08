import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_attendance_system/core/theme.dart';
import 'package:student_attendance_system/features/vice_dean_for_academic _affairs/faculty_accounts/faculty_account_model.dart';
import 'package:student_attendance_system/features/vice_dean_for_academic _affairs/faculty_accounts/faculty_accounts_view_model.dart';

class FacultyAccountsView extends StatefulWidget {
  const FacultyAccountsView({super.key});

  @override
  State<FacultyAccountsView> createState() => _FacultyAccountsViewState();
}

class _FacultyAccountsViewState extends State<FacultyAccountsView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = Provider.of<FacultyAccountsViewModel>(context, listen: false);
      viewModel.loadAccounts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // توليد لون عشوائي متناسق للأفاتار بناء على اسم المستخدم
  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF3B82F6), // Blue
      const Color(0xFF10B981), // Emerald
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEC4899), // Pink
      const Color(0xFF06B6D4), // Cyan
    ];
    if (name.isEmpty) return colors[0];
    final hash = name.codeUnits.fold(0, (prev, element) => prev + element);
    return colors[hash % colors.length];
  }

  // تنسيق التاريخ بشكل مقروء
  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'غير متوفر';
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final year = dateTime.year;
      final month = dateTime.month.toString().padLeft(2, '0');
      final day = dateTime.day.toString().padLeft(2, '0');
      return '$year/$month/$day';
    } catch (e) {
      return isoString.split('T').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('حسابات أعضاء هيئة التدريس'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          Consumer<FacultyAccountsViewModel>(
            builder: (context, viewModel, _) {
              return IconButton(
                icon: const Icon(Icons.sync_rounded),
                tooltip: 'تحديث البيانات السحابية',
                onPressed: viewModel.isLoading
                    ? null
                    : () async {
                        final success = await viewModel.syncAccountsFromFirestore();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success
                                  ? 'تمت مزامنة الحسابات من السيرفر بنجاح'
                                  : 'فشلت المزامنة: يرجى التحقق من اتصال الإنترنت'),
                              backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
                            ),
                          );
                        }
                      },
              );
            },
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
          child: Consumer<FacultyAccountsViewModel>(
            builder: (context, viewModel, _) {
              // تصفية الحسابات بناءً على الاستعلام في البحث
              final filteredAccounts = viewModel.accounts.where((account) {
                final query = _searchQuery.toLowerCase();
                return account.name.toLowerCase().contains(query) ||
                    account.email.toLowerCase().contains(query);
              }).toList();

              return Column(
                children: [
                  // شريط البحث والفرز
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Container(
                      decoration: AppTheme.cardDecoration(context).copyWith(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'البحث عن عضو هيئة تدريس بالاسم أو البريد...',
                          hintStyle: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.4),
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: theme.colorScheme.primary.withOpacity(0.7),
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                    ),
                  ),

                  // عرض القائمة أو المحتوى الفارغ أو شاشة التحميل
                  Expanded(
                    child: viewModel.isLoading && viewModel.accounts.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : filteredAccounts.isEmpty
                            ? _buildEmptyState(theme, viewModel.isLoading)
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                physics: const BouncingScrollPhysics(),
                                itemCount: filteredAccounts.length,
                                itemBuilder: (context, index) {
                                  final account = filteredAccounts[index];
                                  return _buildAccountCard(context, theme, viewModel, account);
                                },
                              ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAccountSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'إضافة عضو هيئة تدريس',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 4,
      ),
    );
  }

  // واجهة العرض الفارغ
  Widget _buildEmptyState(ThemeData theme, bool isLoading) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.school_outlined,
                size: 64,
                color: theme.colorScheme.primary.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isLoading ? 'جاري جلب البيانات...' : 'لا يوجد أعضاء هيئة تدريس',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isLoading
                  ? 'يرجى الانتظار قليلاً.'
                  : 'يمكنك البدء بإضافة أعضاء هيئة التدريس الجدد بالنقر على زر الإضافة بالأسفل.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // بناء بطاقة العرض لكل عضو هيئة تدريس
  Widget _buildAccountCard(
    BuildContext context,
    ThemeData theme,
    FacultyAccountsViewModel viewModel,
    FacultyAccount account,
  ) {
    final avatarColor = _getAvatarColor(account.name);
    final bool isOfflineAccount = account.sync == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: AppTheme.cardDecoration(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: isOfflineAccount ? Colors.orange : theme.colorScheme.primary.withOpacity(0.3),
                width: 5,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // الصورة الشخصية الافتراضية
                CircleAvatar(
                  radius: 26,
                  backgroundColor: avatarColor.withOpacity(0.15),
                  child: Text(
                    account.name.isNotEmpty ? account.name[0].toUpperCase() : 'F',
                    style: TextStyle(
                      color: avatarColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // تفاصيل المستخدم
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              account.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isOfflineAccount)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'غير مزامن',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        account.email,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.55),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 13,
                            color: theme.colorScheme.onSurface.withOpacity(0.4),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'تاريخ الإضافة: ${_formatDate(account.createAt)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.4),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // زر خيارات الحذف
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: AppTheme.errorColor.withOpacity(0.8),
                  ),
                  tooltip: 'حذف الحساب',
                  onPressed: () => _confirmDelete(context, viewModel, account),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // فتح ورقة إدخال مستخدم جديد من الأسفل
  void _showAddAccountSheet(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final localTheme = Theme.of(context);
    String? localError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // مؤشر السحب
                        Center(
                          child: Container(
                            width: 48,
                            height: 5,
                            decoration: BoxDecoration(
                              color: localTheme.colorScheme.onSurface.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        Text(
                          'إضافة عضو هيئة تدريس جديد',
                          style: localTheme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'سيتم حفظ الحساب محلياً والمزامنة تلقائياً. يقوم عضو هيئة التدريس بتفعيل حسابه وتحديد كلمة المرور بنفسه لاحقاً.',
                          style: localTheme.textTheme.bodySmall?.copyWith(
                            color: localTheme.colorScheme.onSurface.withOpacity(0.5),
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        if (localError != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.errorColor.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline_rounded, color: AppTheme.errorColor, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    localError!,
                                    style: TextStyle(
                                      color: AppTheme.errorColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // حقل الاسم الكامل
                        TextFormField(
                          controller: nameController,
                          keyboardType: TextInputType.name,
                          decoration: InputDecoration(
                            labelText: 'الاسم الكامل لعضو هيئة التدريس',
                            prefixIcon: const Icon(Icons.person_outline_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onChanged: (_) {
                            if (localError != null) {
                              setModalState(() {
                                    localError = null;
                              });
                            }
                          },
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'يرجى إدخال الاسم الكامل';
                            }
                            if (value.trim().length < 5) {
                              return 'يرجى إدخال اسم ثلاثي على الأقل';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // حقل البريد الإلكتروني
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'البريد الإلكتروني المعتمد',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onChanged: (_) {
                            if (localError != null) {
                              setModalState(() {
                                    localError = null;
                              });
                            }
                          },
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'يرجى إدخال البريد الإلكتروني';
                            }
                            final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                            if (!emailRegExp.hasMatch(value.trim())) {
                              return 'صيغة البريد الإلكتروني غير صحيحة';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // أزرار الحفظ والإلغاء
                        Consumer<FacultyAccountsViewModel>(
                          builder: (context, viewModel, _) {
                            return Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    onPressed: viewModel.isSaving ? null : () => Navigator.pop(context),
                                    child: const Text('إلغاء'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      backgroundColor: localTheme.colorScheme.primary,
                                      foregroundColor: localTheme.colorScheme.onPrimary,
                                    ),
                                    onPressed: viewModel.isSaving
                                        ? null
                                        : () async {
                                            if (formKey.currentState!.validate()) {
                                              final error = await viewModel.createFacultyAccount(
                                                name: nameController.text,
                                                email: emailController.text,
                                              );

                                              if (context.mounted) {
                                                if (error != null) {
                                                  setModalState(() {
                                                    localError = error;
                                                  });
                                                } else {
                                                  Navigator.pop(context);
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('تمت إضافة عضو هيئة التدريس بنجاح ومزامنته'),
                                                      backgroundColor: AppTheme.successColor,
                                                    ),
                                                  );
                                                }
                                              }
                                            }
                                          },
                                    child: viewModel.isSaving
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Text(
                                            'إضافة الحساب',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                  ),
                                ),
                              ],
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
        );
      },
    );
  }

  // ديالوج تأكيد الحذف
  void _confirmDelete(BuildContext context, FacultyAccountsViewModel viewModel, FacultyAccount account) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor),
              const SizedBox(width: 8),
              const Text('تأكيد حذف الحساب'),
            ],
          ),
          content: Text(
            'هل أنت متأكد من رغبتك في حذف حساب عضو هيئة التدريس "${account.name}" نهائياً؟\n\n'
            'تنبيه: سيتم حذف بيانات الحساب من السيرفر السحابي (Firestore) ومن التطبيق محلياً.',
            style: const TextStyle(height: 1.4),
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
                  child: const Text('حذف نهائي', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    Navigator.of(context).pop(); // إغلاق الديالوج
                    
                    final error = await viewModel.deleteFacultyAccount(account.id);
                    if (context.mounted) {
                      if (error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(error),
                            backgroundColor: AppTheme.errorColor,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('تم حذف حساب "${account.name}" بنجاح من النظام السحابي والمحلي.'),
                            backgroundColor: AppTheme.successColor,
                          ),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
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
}
