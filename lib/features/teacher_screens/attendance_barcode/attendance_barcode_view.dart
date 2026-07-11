import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:student_attendance_system/features/teacher_screens/attendance_barcode/attendance_barcode_model.dart';
import 'package:student_attendance_system/features/teacher_screens/attendance_barcode/attendance_barcode_view_model.dart';

class AttendanceBarcodeView extends StatelessWidget {
  const AttendanceBarcodeView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AttendanceBarcodeViewModel(),
      child: const _AttendanceBarcodeBody(),
    );
  }
}

class _AttendanceBarcodeBody extends StatelessWidget {
  const _AttendanceBarcodeBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('باركود التحضير'),
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
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE), const Color(0xFFF8FAFC)],
          ),
        ),
        child: SafeArea(
          child: Consumer<AttendanceBarcodeViewModel>(
            builder: (context, vm, _) {
              if (vm.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (vm.errorMessage != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          vm.errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (vm.courses.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.assignment_late_outlined, size: 80, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text(
                        'لا يوجد لديك مواد مسندة حالياً.',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── بطاقة حالة الأمان ──
                    _SecurityStatusCard(vm: vm),

                    const SizedBox(height: 20),

                    // ── بطاقة الاختيار ──
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.settings_suggest_rounded, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'إعدادات التحضير',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32),

                          // اختيار المادة
                          Text(
                            'المادة الدراسية',
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<AttendanceCourseModel>(
                            initialValue: vm.selectedCourse,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.book_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            hint: const Text('اختر المادة الدراسية'),
                            items: vm.courses.map((course) {
                              return DropdownMenuItem(
                                value: course,
                                child: Text(course.subjectName),
                              );
                            }).toList(),
                            onChanged: (val) => vm.selectCourse(val),
                          ),

                          const SizedBox(height: 24),

                          // اختيار المجموعة
                          if (vm.selectedCourse != null) ...[
                            Text(
                              'المجموعة / التخصص',
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            if (vm.selectedCourse!.studentGroups.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'لم يتم تعيين مجموعات طلابية لهذه المادة.',
                                        style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              DropdownButtonFormField<String>(
                                initialValue: vm.selectedGroup,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.groups_outlined),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                hint: const Text('اختر المجموعة أو التخصص'),
                                items: vm.selectedCourse!.studentGroups.map((group) {
                                  return DropdownMenuItem(
                                    value: group,
                                    child: Text(group),
                                  );
                                }).toList(),
                                onChanged: (val) => vm.selectGroup(val),
                              ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── عرض الباركود ──
                    if (!vm.isSecurityReady && vm.selectedGroup != null)
                      _SecurityBlockedBanner(vm: vm)
                    else if (vm.qrDataEncrypted != null)
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: QrImageView(
                                data: vm.qrDataEncrypted!,
                                version: QrVersions.auto,
                                size: 250.0,
                                backgroundColor: Colors.white,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: Colors.black87,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // معلومات الموقع المُضمَّن
                            if (vm.currentPosition != null)
                              _LocationInfoChip(position: vm.currentPosition!),

                            const SizedBox(height: 8),

                            // اسم بلوتوث المعلم المُضمَّن في QR
                            if (vm.btDeviceName.isNotEmpty)
                              _BluetoothNameChip(deviceName: vm.btDeviceName),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.security_rounded, color: theme.colorScheme.primary, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'يتم تحديث الباركود تلقائياً كل 30 ثانية للأمان',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (vm.selectedCourse != null && vm.selectedCourse!.studentGroups.isNotEmpty)
                      Center(
                        child: Text(
                          'يرجى تحديد المجموعة لعرض باركود التحضير',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Widget: بطاقة حالة خدمات الأمان
// ─────────────────────────────────────────────────────────────────────────────

class _SecurityStatusCard extends StatelessWidget {
  final AttendanceBarcodeViewModel vm;
  const _SecurityStatusCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allReady = vm.isSecurityReady;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: allReady
              ? [const Color(0xFF065F46), const Color(0xFF047857)]
              : [const Color(0xFF7C3AED), const Color(0xFF6D28D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (allReady ? Colors.green : Colors.purple).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allReady ? Icons.verified_user_rounded : Icons.shield_outlined,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'حالة أمان التحضير',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (!allReady)
                TextButton.icon(
                  onPressed: () => vm.requestSecurityPermissions(isManual: true),
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 16),
                  label: const Text('إعادة المحاولة',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ServiceStatusTile(
                  icon: Icons.location_on_rounded,
                  label: 'الموقع الجغرافي',
                  status: vm.locationStatus,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ServiceStatusTile(
                  icon: Icons.bluetooth_rounded,
                  label: 'البلوتوث',
                  status: vm.bluetoothStatus,
                ),
              ),
            ],
          ),
          if (allReady) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  vm.locationStatus == SecurityServiceStatus.unsupported
                      ? Icons.info_outline_rounded
                      : Icons.check_circle_rounded,
                  color: vm.locationStatus == SecurityServiceStatus.unsupported
                      ? Colors.lightBlueAccent
                      : Colors.greenAccent,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    vm.locationStatus == SecurityServiceStatus.unsupported
                        ? 'تم تجاوز فحص الأمان للتطوير (نظام تشغيل Windows لا يدعم خدمات الهاتف)'
                        : 'جميع خدمات الأمان مفعّلة — الباركود يحمل موقعك الجغرافي',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ServiceStatusTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final SecurityServiceStatus status;

  const _ServiceStatusTile({
    required this.icon,
    required this.label,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isGranted = status == SecurityServiceStatus.granted;
    final isRequesting = status == SecurityServiceStatus.requesting;
    final isUnsupported = status == SecurityServiceStatus.unsupported;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (isRequesting) {
      statusColor = Colors.amber;
      statusIcon = Icons.hourglass_top_rounded;
      statusText = 'جارٍ الطلب...';
    } else if (isGranted) {
      statusColor = Colors.greenAccent;
      statusIcon = Icons.check_circle_rounded;
      statusText = 'مفعّل';
    } else if (isUnsupported) {
      statusColor = Colors.lightBlueAccent;
      statusIcon = Icons.info_outline_rounded;
      statusText = 'غير مدعوم (PC)';
    } else if (status == SecurityServiceStatus.idle) {
      statusColor = Colors.white60;
      statusIcon = Icons.radio_button_unchecked_rounded;
      statusText = 'بانتظار الاختيار...';
    } else {
      statusColor = Colors.redAccent;
      statusIcon = Icons.cancel_rounded;
      statusText = 'معطّل';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 12),
                    const SizedBox(width: 4),
                    Text(statusText,
                        style: TextStyle(color: statusColor, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Widget: تنبيه عند منع QR بسبب الأمان
// ─────────────────────────────────────────────────────────────────────────────

class _SecurityBlockedBanner extends StatelessWidget {
  final AttendanceBarcodeViewModel vm;
  const _SecurityBlockedBanner({required this.vm});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.gpp_bad_rounded, color: Colors.red, size: 56),
            const SizedBox(height: 12),
            Text(
              'لا يمكن إنشاء باركود التحضير',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'يجب تفعيل الموقع الجغرافي والبلوتوث لضمان وجود الطلاب داخل القاعة.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.red.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => vm.requestSecurityPermissions(isManual: true),
              icon: const Icon(Icons.security_rounded),
              label: const Text('تفعيل خدمات الأمان'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Widget: شريحة معلومات الموقع المُضمَّن في QR
// ─────────────────────────────────────────────────────────────────────────────

class _LocationInfoChip extends StatelessWidget {
  final dynamic position;
  const _LocationInfoChip({required this.position});

  @override
  Widget build(BuildContext context) {
    final lat = position.latitude.toStringAsFixed(5);
    final lng = position.longitude.toStringAsFixed(5);
    final acc = position.accuracy.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on_rounded, color: Colors.green, size: 16),
          const SizedBox(width: 6),
          Text(
            '$lat, $lng  ±$acc م',
            style: const TextStyle(
              color: Colors.green,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Widget: شريحة اسم بلوتوث المعلم المُضمَّن في QR
// ─────────────────────────────────────────────────────────────────────────────

class _BluetoothNameChip extends StatelessWidget {
  final String deviceName;
  const _BluetoothNameChip({required this.deviceName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bluetooth_rounded, color: Colors.blue, size: 16),
          const SizedBox(width: 6),
          Text(
            'بلوتوث المعلم: $deviceName',
            style: const TextStyle(
              color: Colors.blue,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
