import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_attendance_system/features/vice_dean_for_academic _affairs/timetable_import/timetable_import_view_model.dart';

class TimetableImportView extends StatelessWidget {
  const TimetableImportView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final vm = TimetableImportViewModel();
        vm.loadRegisteredTeachers();
        return vm;
      },
      child: Consumer<TimetableImportViewModel>(
        builder: (context, vm, _) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Scaffold(
            appBar: AppBar(
              title: const Text('استيراد الجدول الدراسي لربط المعلمين بالمواد'),
              elevation: 0,
              backgroundColor: Colors.transparent,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
            extendBodyBehindAppBar: true,
            body: DecoratedBox(
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
                child: switch (vm.currentStep) {
                  ImportStep.idle => _IdleStep(vm: vm),
                  ImportStep.manualMapping => _ManualMappingStep(vm: vm),
                  ImportStep.readyToSave => _ReadyToSaveStep(vm: vm),
                  ImportStep.done => _DoneStep(vm: vm),
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Step 1 – Idle
// =============================================================================
class _IdleStep extends StatelessWidget {
  final TimetableImportViewModel vm;
  const _IdleStep({required this.vm});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'استيراد الجدول الدراسي لربط المعلمين بالمواد',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'اختر ملف CSV يحتوي على أعمدة: Subject, Teachers, Student Sets.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: vm.isLoading ? null : () => vm.pickAndParseFile(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.35),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: vm.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.upload_file_rounded,
                          size: 64,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          vm.selectedFileName ?? 'اضغط لاختيار ملف CSV',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: vm.selectedFileName != null
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withOpacity(0.55),
                          ),
                        ),
                        if (vm.selectedFileName == null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'الصيغة المدعومة: .csv',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
          if (vm.errorMessage != null) ...[
            const SizedBox(height: 20),
            _ErrorBanner(message: vm.errorMessage!),
          ],
          const SizedBox(height: 24),
          _InfoCard(
            icon: Icons.people_alt_rounded,
            title: 'المعلمون المسجلون',
            value: '${vm.registeredTeachers.length} عضو هيئة تدريس متاح',
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Step 2 – Manual Mapping  (Stack approach – no Expanded needed)
// =============================================================================
class _ManualMappingStep extends StatelessWidget {
  final TimetableImportViewModel vm;
  const _ManualMappingStep({required this.vm});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // نستخدم CustomScrollView بدل Column+Expanded لتجنب مشكلة الارتفاع غير المحدد
    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.link_rounded,
                        color: Colors.orange,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ربط المعلمين يدوياً',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'الأسماء التالية لم تُطابَق تلقائياً، يُرجى ربطها.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.55,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (vm.errorMessage != null)
                  _ErrorBanner(message: vm.errorMessage!),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),

        // Mapping cards
        SliverList.separated(
          itemCount: vm.unmappedTeacherNames.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final rawName = vm.unmappedTeacherNames[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _TeacherMappingCard(
                rawName: rawName,
                currentUid: vm.manualMappings[rawName],
                teachers: vm.registeredTeachers,
                onChanged: (uid) => vm.setManualMapping(rawName, uid),
              ),
            );
          },
        ),

        // Save button (last item)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: vm.isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      onPressed: vm.isManualMappingComplete
                          ? () => vm.saveAssignments()
                          : null,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text(
                        'حفظ التعيينات',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Step 3 – Ready to save
// =============================================================================
class _ReadyToSaveStep extends StatelessWidget {
  final TimetableImportViewModel vm;
  const _ReadyToSaveStep({required this.vm});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SuccessBanner(
                  message:
                      'تم التعرف على جميع المعلمين تلقائياً (${vm.parsedRows.length} صف جاهز للحفظ).',
                ),
                const SizedBox(height: 20),
                Text(
                  'معاينة التعيينات',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...vm.parsedRows
                    .take(15)
                    .map(
                      (row) => _PreviewRow(
                        subject: row.subjectName,
                        teacher: row.rawTeacherName,
                        groups: row.studentGroups,
                        room: row.room,
                      ),
                    ),
                if (vm.parsedRows.length > 15)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '... و ${vm.parsedRows.length - 15} صف إضافي',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ),
                if (vm.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(message: vm.errorMessage!),
                ],
              ],
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: vm.isSaving
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: () => vm.saveAssignments(),
                        icon: const Icon(Icons.save_rounded),
                        label: const Text(
                          'حفظ التعيينات',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Step 4 – Done
// =============================================================================
class _DoneStep extends StatelessWidget {
  final TimetableImportViewModel vm;
  const _DoneStep({required this.vm});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Colors.green,
              size: 72,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'اكتملت العملية',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            vm.successMessage ?? 'تم حفظ التعيينات بنجاح.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.65),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ستتم مزامنة البيانات مع الخادم فور توفّر الاتصال.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange),
          ),
          const SizedBox(height: 36),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: () => vm.reset(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('استيراد ملف آخر'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.home_rounded),
                label: const Text('العودة'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Sub-widgets
// =============================================================================

class _TeacherMappingCard extends StatelessWidget {
  final String rawName;
  final String? currentUid;
  final List<Map<String, dynamic>> teachers;
  final ValueChanged<String> onChanged;

  const _TeacherMappingCard({
    required this.rawName,
    required this.currentUid,
    required this.teachers,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: currentUid != null
              ? Colors.green.withOpacity(0.4)
              : Colors.orange.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                currentUid != null
                    ? Icons.check_circle_outline_rounded
                    : Icons.warning_amber_rounded,
                color: currentUid != null ? Colors.green : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'من الـ CSV: $rawName',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (teachers.isEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'لا يوجد أعضاء هيئة تدريس مسجلون في النظام بعد.',
                style: TextStyle(color: Colors.orange),
              ),
            )
          else
            DropdownButtonFormField<String>(
              value: currentUid,
              isExpanded: true,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withOpacity(0.4),
                hintText: 'اختر المعلم المقابل...',
              ),
              items: teachers
                  .map(
                    (t) => DropdownMenuItem<String>(
                      value: t['id'] as String,
                      child: Text(
                        t['name'] as String? ?? '',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (uid) {
                if (uid != null) onChanged(uid);
              },
            ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String subject;
  final String teacher;
  final List<String> groups;
  final String room;
  const _PreviewRow({
    required this.subject,
    required this.teacher,
    required this.groups,
    required this.room,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.75),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              subject,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              teacher,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              groups.join(', '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              room.isNotEmpty ? room : 'بلا قاعة',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.secondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  final String message;
  const _SuccessBanner({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: Colors.green,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.green, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 28),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
