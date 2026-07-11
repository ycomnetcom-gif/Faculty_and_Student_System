import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_attendance_system/features/vice_dean_for_academic _affairs/view_assignments/view_assignments_view_model.dart';

class ViewAssignmentsView extends StatelessWidget {
  const ViewAssignmentsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ViewAssignmentsViewModel()..loadAssignments(),
      child: const _ViewAssignmentsBody(),
    );
  }
}

class _ViewAssignmentsBody extends StatefulWidget {
  const _ViewAssignmentsBody();

  @override
  State<_ViewAssignmentsBody> createState() => _ViewAssignmentsBodyState();
}

class _ViewAssignmentsBodyState extends State<_ViewAssignmentsBody> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = Provider.of<ViewAssignmentsViewModel>(context, listen: false);
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
    _searchController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الاطلاع على المواد ومعلميها'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          Consumer<ViewAssignmentsViewModel>(
            builder: (context, vm, _) {
              if (vm.isLoading && vm.assignments.isEmpty) {
                return const SizedBox.shrink();
              }
              if (vm.isLoading) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                );
              }
              return IconButton(
                icon: const Icon(Icons.sync_rounded),
                tooltip: 'مزامنة أعضاء هيئة التدريس',
                onPressed: () => vm.syncNow(),
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
                : [
                    const Color(0xFFEFF6FF),
                    const Color(0xFFDBEAFE),
                    const Color(0xFFF8FAFC),
                  ],
          ),
        ),
        child: SafeArea(
          child: Consumer<ViewAssignmentsViewModel>(
            builder: (context, vm, _) {
              // تصفية التعيينات حسب نص البحث
              final filteredList = vm.assignments.where((item) {
                final query = _searchQuery.toLowerCase();
                return item.subjectName.toLowerCase().contains(query) ||
                    item.teacherName.toLowerCase().contains(query) ||
                    item.room.toLowerCase().contains(query) ||
                    item.studentGroups.any(
                      (g) => g.toLowerCase().contains(query),
                    );
              }).toList();

              return Column(
                children: [
                  // شريط البحث والإحصائيات
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'البحث عن مادة، معلم، أو مجموعة...',
                            prefixIcon: const Icon(Icons.search_rounded),
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
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surface.withOpacity(
                              0.8,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                        ),
                        if (vm.message != null) ...[
                          const SizedBox(height: 12),
                          _NotificationBanner(
                            message: vm.message!,
                            isSuccess: vm.isSuccess,
                            onClose: () => vm.clearMessage(),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // قائمة التعيينات
                  Expanded(
                    child: vm.isLoading && vm.assignments.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : filteredList.isEmpty
                        ? _buildEmptyState(theme)
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            itemCount: filteredList.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = filteredList[index];
                              return _AssignmentCard(
                                assignment: item,
                                onEdit: () =>
                                    _showEditDialog(context, vm, item),
                                onDelete: () =>
                                    _confirmDelete(context, vm, item),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today_rounded,
                size: 64,
                color: theme.colorScheme.primary.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'لا توجد تعيينات حالية',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'لم يتم العثور على نتائج تطابق بحثك.'
                  : 'يرجى استيراد ملف الجدول الدراسي أولاً لإضافة وتعيين المواد.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    ViewAssignmentsViewModel vm,
    AssignedCourse item,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف التعيين'),
        content: Text(
          'هل أنت متأكد من رغبتك في حذف تعيين مادة "${item.subjectName}" للدكتور "${item.teacherName}"؟',
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    vm.deleteAssignment(item.id);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('حذف'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('إلغاء'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    ViewAssignmentsViewModel vm,
    AssignedCourse item,
  ) {
    final formKey = GlobalKey<FormState>();
    final subjectController = TextEditingController(text: item.subjectName);
    final roomController = TextEditingController(text: item.room);
    final groupsController = TextEditingController(
      text: item.studentGroups.join(', '),
    );
    final teacherController = TextEditingController(text: item.teacherName);
    final teacherFocusNode = FocusNode();
    String selectedTeacherUid = item.teacherUid;

    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.edit_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text('تعديل بيانات المادة'),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      // اسم المادة
                      TextFormField(
                        controller: subjectController,
                        decoration: InputDecoration(
                          labelText: 'اسم المادة',
                          prefixIcon: const Icon(Icons.book_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'هذا الحقل مطلوب'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // المعلم المسؤول
                      Autocomplete<Map<String, dynamic>>(
                        textEditingController: teacherController,
                        focusNode: teacherFocusNode,
                        displayStringForOption: (Map<String, dynamic> option) => option['name'] as String? ?? '',
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return vm.teachers;
                          }
                          return vm.teachers.where((Map<String, dynamic> t) {
                            final name = (t['name'] as String? ?? '').toLowerCase();
                            final role = (t['role'] as String? ?? '').toLowerCase();
                            final search = textEditingValue.text.toLowerCase();
                            return name.contains(search) || role.contains(search);
                          });
                        },
                        onSelected: (Map<String, dynamic> selectedTeacher) {
                          setDialogState(() {
                            selectedTeacherUid = selectedTeacher['id'] as String;
                          });
                        },
                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                          return TextFormField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: 'المعلم المسؤول',
                              hintText: 'ابحث أو اكتب اسم المعلم...',
                              prefixIcon: const Icon(Icons.person_search_rounded),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'الرجاء تحديد المعلم المسؤول';
                              }
                              final matchExists = vm.teachers.any(
                                (t) => (t['name'] as String? ?? '').trim().toLowerCase() == value.trim().toLowerCase()
                              );
                              if (!matchExists) {
                                    return 'الرجاء اختيار معلم صحيح من القائمة المنسدلة';
                              }
                              return null;
                            },
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          final double screenWidth = MediaQuery.of(context).size.width;
                          final double optionsWidth = screenWidth > 500 ? 380.0 : screenWidth * 0.72;

                          return Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Material(
                                elevation: 8,
                                borderRadius: BorderRadius.circular(16),
                                color: theme.colorScheme.surface,
                                child: Container(
                                  width: optionsWidth,
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
                                      final Map<String, dynamic> t = options.elementAt(index);
                                      final name = t['name'] as String? ?? '';
                                      final role = t['role'] as String? ?? 'عضو هيئة تدريس';
                                      return ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                                        title: Text(
                                          name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        subtitle: Text(
                                          'الدور / الصفة: $role',
                                          style: TextStyle(
                                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                                            fontSize: 11,
                                          ),
                                        ),
                                        leading: CircleAvatar(
                                          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                                          child: Text(
                                            name.isNotEmpty ? name[0] : 'أ',
                                            style: TextStyle(
                                              color: theme.colorScheme.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        onTap: () => onSelected(t),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // القاعة
                      TextFormField(
                        controller: roomController,
                        decoration: InputDecoration(
                          labelText: 'القاعة الدراسية',
                          prefixIcon: const Icon(Icons.meeting_room_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // المجموعات الطلابية
                      TextFormField(
                        controller: groupsController,
                        decoration: InputDecoration(
                          labelText: 'المجموعات الطلابية (مفصولة بفاصلة)',
                          hintText: 'مثال: مجموعة 1, مجموعة 2',
                          prefixIcon: const Icon(Icons.groups_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (formKey.currentState?.validate() ?? false) {
                            final nameVal = teacherController.text.trim();
                            final matched = vm.teachers.firstWhere(
                              (t) => (t['name'] as String? ?? '').trim().toLowerCase() == nameVal.toLowerCase(),
                              orElse: () => <String, dynamic>{},
                            );
                            if (matched.isNotEmpty) {
                              selectedTeacherUid = matched['id'] as String;
                            }

                            // تحويل المجموعات الطلابية من نص مفصول بفواصل إلى قائمة
                            final groupsText = groupsController.text;
                            List<String> groupsList = [];
                            if (groupsText.isNotEmpty) {
                              groupsList = groupsText
                                  .split(',')
                                  .map((g) => g.trim())
                                  .where((g) => g.isNotEmpty)
                                  .toList();
                            }

                            vm.updateAssignment(
                              id: item.id,
                              subjectName: subjectController.text,
                              teacherUid: selectedTeacherUid,
                              room: roomController.text,
                              studentGroups: groupsList,
                            );
                            Navigator.of(ctx).pop();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('حفظ التعديلات'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('إلغاء'),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final AssignedCourse assignment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AssignmentCard({
    required this.assignment,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSynced = assignment.syncStatus == 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // اسم المادة
              Expanded(
                child: Text(
                  assignment.subjectName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // أزرار التحكم (تعديل وحذف)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed: onEdit,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                    ),
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // اسم المعلم
          Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 16,
                color: theme.colorScheme.onSurface.withOpacity(0.55),
              ),
              const SizedBox(width: 8),
              Text(
                assignment.teacherName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // القاعة
          if (assignment.room.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.meeting_room_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurface.withOpacity(0.55),
                ),
                const SizedBox(width: 8),
                Text(
                  'القاعة: ${assignment.room}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: 6),
          // المجموعات الطلابية كـ Chips
          if (assignment.studentGroups.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: assignment.studentGroups.map((group) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    group,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],
          // حالة المزامنة
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isSynced
                      ? Colors.green.withOpacity(0.08)
                      : Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSynced
                        ? Colors.green.withOpacity(0.3)
                        : Colors.orange.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSynced
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_off_rounded,
                      size: 14,
                      color: isSynced ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isSynced ? 'مزامن' : 'بانتظار المزامنة',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isSynced ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationBanner extends StatelessWidget {
  final String message;
  final bool isSuccess;
  final VoidCallback onClose;

  const _NotificationBanner({
    required this.message,
    required this.isSuccess,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSuccess ? Colors.green : Colors.red;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess
                ? Icons.check_circle_outline_rounded
                : Icons.error_outline_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, height: 1.4, fontSize: 13),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: color, size: 18),
            onPressed: onClose,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
