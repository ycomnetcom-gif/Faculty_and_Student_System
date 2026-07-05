import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_attendance_system/core/theme.dart';
import 'package:student_attendance_system/features/vice_dean_for_academic _affairs/head_accounts/head_account_model.dart';
import 'package:student_attendance_system/features/vice_dean_for_academic _affairs/head_accounts/head_accounts_view_model.dart';

class HeadAccountsView extends StatefulWidget {
  const HeadAccountsView({super.key});

  @override
  State<HeadAccountsView> createState() => _HeadAccountsViewState();
}

class _HeadAccountsViewState extends State<HeadAccountsView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = Provider.of<HeadAccountsViewModel>(context, listen: false);
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
        title: const Text('حسابات رؤساء الأقسام'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          Consumer<HeadAccountsViewModel>(
            builder: (context, viewModel, _) {
              return IconButton(
                icon: const Icon(Icons.sync_rounded),
                tooltip: 'تحديث البيانات السحابية',
                onPressed: viewModel.isLoading
                    ? null
                    : () async {
                        await viewModel.syncAccountsFromFirestore();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تمت مزامنة الحسابات من السيرفر بنجاح'),
                              backgroundColor: AppTheme.successColor,
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
          child: Consumer<HeadAccountsViewModel>(
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
                          hintText: 'البحث عن رئيس قسم بالاسم أو البريد...',
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
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                  ),

                  // قائمة الحسابات
                  Expanded(
                    child: viewModel.isLoading
                        ? const Center(
                            child: CircularProgressIndicator(),
                          )
                        : filteredAccounts.isEmpty
                            ? _buildEmptyPlaceholder(theme)
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                itemCount: filteredAccounts.length,
                                itemBuilder: (context, index) {
                                  final account = filteredAccounts[index];
                                  return _buildAccountCard(context, account, theme);
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
        onPressed: () => _showCreateAccountBottomSheet(context),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text(
          'إنشاء حساب جديد',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // كارت رئيس القسم
  Widget _buildAccountCard(BuildContext context, HeadAccount account, ThemeData theme) {
    final avatarColor = _getAvatarColor(account.name);
    final initial = account.name.isNotEmpty ? account.name.trim().substring(0, 1) : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecoration(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // أفاتار الحساب
              CircleAvatar(
                radius: 24,
                backgroundColor: avatarColor.withOpacity(0.12),
                child: Text(
                  initial,
                  style: TextStyle(
                    color: avatarColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // معلومات الحساب
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      account.email,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.55),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (account.createAt != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 10,
                            color: theme.colorScheme.onSurface.withOpacity(0.4),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'تاريخ الإنشاء: ${_formatDate(account.createAt)}',
                            style: TextStyle(
                              fontSize: 9,
                              color: theme.colorScheme.onSurface.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                    ]
                  ],
                ),
              ),

              // شارة الدور مع زر الحذف
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      'رئيس قسم',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor),
                    tooltip: 'حذف الحساب نهائياً',
                    onPressed: () {
                      final viewModel = Provider.of<HeadAccountsViewModel>(context, listen: false);
                      _confirmDelete(context, viewModel, account);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // واجهة عرض فارغة
  Widget _buildEmptyPlaceholder(ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_alt_rounded,
                size: 64,
                color: theme.colorScheme.primary.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'لا توجد حسابات رؤساء أقسام',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'لا توجد نتائج تطابق بحثك الحالي.'
                  : 'لم تقم بإنشاء أي حسابات لرؤساء الأقسام بعد.\nاضغط على الزر بالأسفل للبدء.',
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

  // فتح ديالوج / شيت إنشاء حساب جديد
  void _showCreateAccountBottomSheet(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool obscurePassword = true;
    String? localError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final localTheme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setModalState) {
            // دالة لتوليد كلمة مرور قوية تلقائياً للتسهيل على المستخدم
            void generatePassword() {
              const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()';
              final rand = Random();
              final length = 10 + rand.nextInt(5); // بين 10 و 14 حرفاً
              final generated = List.generate(length, (index) => chars[rand.nextInt(chars.length)]).join();
              setModalState(() {
                passwordController.text = generated;
                localError = null;
              });
            }

            return Container(
              decoration: BoxDecoration(
                color: localTheme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  )
                ],
              ),
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // مقبض السحب بالأعلى للتصميم
                      Center(
                        child: Container(
                          width: 48,
                          height: 4,
                          decoration: BoxDecoration(
                            color: localTheme.colorScheme.onSurface.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Icon(Icons.person_add_alt_1_rounded, color: localTheme.colorScheme.primary, size: 28),
                          const SizedBox(width: 10),
                          const Text(
                            'إنشاء حساب رئيس قسم جديد',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'سيتم إدراج الحساب تلقائياً كـ (رئيس قسم) وتاريخ الإنشاء الحالي.',
                        style: TextStyle(
                          fontSize: 12,
                          color: localTheme.colorScheme.onSurface.withOpacity(0.55),
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (localError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
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
                        const SizedBox(height: 16),
                      ],

                      // حقل الاسم الكامل
                      TextFormField(
                        controller: nameController,
                        keyboardType: TextInputType.name,
                        decoration: InputDecoration(
                          labelText: 'الاسم الكامل',
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
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // حقل البريد الإلكتروني
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'البريد الإلكتروني',
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
                      const SizedBox(height: 16),

                      // حقل كلمة المرور
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                onPressed: () {
                                  setModalState(() {
                                    obscurePassword = !obscurePassword;
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.auto_awesome_rounded, color: Colors.amber),
                                tooltip: 'توليد كلمة مرور عشوائية',
                                onPressed: generatePassword,
                              ),
                            ],
                          ),
                        ),
                        onChanged: (_) {
                          if (localError != null) {
                            setModalState(() {
                              localError = null;
                            });
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'يرجى إدخال كلمة المرور لحساب المصادقة';
                          }
                          if (value.length < 8) {
                            return 'يجب أن لا تقل كلمة المرور عن 8 أحرف أو أرقام';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // عرض تاريخ الإنشاء تلقائياً
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: localTheme.colorScheme.onSurface.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: localTheme.colorScheme.onSurface.withOpacity(0.08)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 20, color: localTheme.colorScheme.onSurface.withOpacity(0.5)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'تاريخ الإنشاء (تلقائي)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: localTheme.colorScheme.onSurface.withOpacity(0.4),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatDate(DateTime.now().toIso8601String()),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: localTheme.colorScheme.onSurface.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // أزرار الحفظ والإلغاء
                      Consumer<HeadAccountsViewModel>(
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
                                            final error = await viewModel.createHeadAccount(
                                              name: nameController.text,
                                              email: emailController.text,
                                              password: passwordController.text,
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
                                                    content: Text('تم إنشاء حساب رئيس القسم بنجاح ومزامنته'),
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
                                          'إنشاء الحساب',
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
            );
          },
        );
      },
    );
  }

  // ديالوج تأكيد الحذف
  void _confirmDelete(BuildContext context, HeadAccountsViewModel viewModel, HeadAccount account) {
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
            'هل أنت متأكد من رغبتك في حذف حساب رئيس القسم "${account.name}" نهائياً؟\n\n'
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
                    
                    final error = await viewModel.deleteHeadAccount(account.id);
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
