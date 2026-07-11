import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_attendance_system/features/student_screens/qr_scan/student_qr_scan_model.dart';
import 'package:student_attendance_system/features/student_screens/qr_scan/student_qr_scan_view_model.dart';

/// شاشة مسح QR التحضير للطالب.
/// تُستدعى بعد مسح الباركود بأي مكتبة QR وتمرير النص الخام لها.
class StudentQrScanView extends StatelessWidget {
  /// النص المُستخرَج من QR بعد المسح
  final String rawQrData;

  const StudentQrScanView({super.key, required this.rawQrData});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => StudentQrScanViewModel()..processQrCode(rawQrData),
      child: const _StudentQrScanBody(),
    );
  }
}

class _StudentQrScanBody extends StatelessWidget {
  const _StudentQrScanBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('التحقق من الحضور'),
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
                : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
          ),
        ),
        child: SafeArea(
          child: Consumer<StudentQrScanViewModel>(
            builder: (context, vm, _) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),

                    // ── أيقونة الحالة الرئيسية ──
                    _StatusIcon(status: vm.status),

                    const SizedBox(height: 24),

                    // ── عنوان الحالة ──
                    Text(
                      _statusTitle(vm.status),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _statusColor(vm.status),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 12),

                    // ── رسالة التفاصيل ──
                    if (vm.statusMessage.isNotEmpty)
                      Text(
                        vm.statusMessage,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),

                    const SizedBox(height: 32),

                    // ── مراحل التحقق ──
                    _VerificationSteps(status: vm.status),

                    const Spacer(),

                    // ── معلومات المادة إذا نجح التحقق ──
                    if (vm.isVerified && vm.payloadInfo != null)
                      _CourseInfoCard(payloadInfo: vm.payloadInfo!),

                    const SizedBox(height: 16),

                    // ── أزرار الإجراءات ──
                    if (vm.isFailed ||
                        vm.status == AttendanceVerificationStatus.bluetoothNotFound ||
                        vm.status == AttendanceVerificationStatus.locationMismatch)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          label: const Text('العودة ومسح مجدداً'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),

                    if (vm.isVerified)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.check_circle_rounded),
                          label: const Text('تم — العودة للصفحة الرئيسية'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),

                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _statusTitle(AttendanceVerificationStatus status) {
    return switch (status) {
      AttendanceVerificationStatus.idle             => 'جارٍ التحقق...',
      AttendanceVerificationStatus.scanningBluetooth => 'البحث عن المعلم',
      AttendanceVerificationStatus.bluetoothFound   => 'تم العثور على المعلم',
      AttendanceVerificationStatus.bluetoothNotFound => 'لم يُعثر على المعلم',
      AttendanceVerificationStatus.locationMismatch => 'أنت خارج القاعة',
      AttendanceVerificationStatus.verified         => 'تم تسجيل الحضور!',
      AttendanceVerificationStatus.failed           => 'فشل التحقق',
    };
  }

  Color _statusColor(AttendanceVerificationStatus status) {
    return switch (status) {
      AttendanceVerificationStatus.verified => Colors.green,
      AttendanceVerificationStatus.failed ||
      AttendanceVerificationStatus.bluetoothNotFound ||
      AttendanceVerificationStatus.locationMismatch => Colors.red,
      _ => Colors.blue,
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Widget: أيقونة الحالة المتحركة
// ─────────────────────────────────────────────────────────────────────────────

class _StatusIcon extends StatelessWidget {
  final AttendanceVerificationStatus status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == AttendanceVerificationStatus.scanningBluetooth ||
        status == AttendanceVerificationStatus.idle) {
      return const SizedBox(
        width: 80,
        height: 80,
        child: CircularProgressIndicator(strokeWidth: 5),
      );
    }

    final (IconData icon, Color color) = switch (status) {
      AttendanceVerificationStatus.verified         => (Icons.verified_rounded, Colors.green),
      AttendanceVerificationStatus.bluetoothNotFound => (Icons.bluetooth_disabled_rounded, Colors.red),
      AttendanceVerificationStatus.locationMismatch => (Icons.location_off_rounded, Colors.orange),
      AttendanceVerificationStatus.failed           => (Icons.gpp_bad_rounded, Colors.red),
      _                                             => (Icons.qr_code_scanner_rounded, Colors.blue),
    };

    return Icon(icon, size: 80, color: color);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Widget: خطوات التحقق التسلسلية
// ─────────────────────────────────────────────────────────────────────────────

class _VerificationSteps extends StatelessWidget {
  final AttendanceVerificationStatus status;
  const _VerificationSteps({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final steps = [
      _StepInfo(
        icon: Icons.qr_code_rounded,
        label: 'فك تشفير الباركود',
        done: status != AttendanceVerificationStatus.idle &&
            status != AttendanceVerificationStatus.failed,
        active: status == AttendanceVerificationStatus.idle,
        failed: status == AttendanceVerificationStatus.failed,
      ),
      _StepInfo(
        icon: Icons.location_on_rounded,
        label: 'التحقق من الموقع الجغرافي',
        done: status == AttendanceVerificationStatus.scanningBluetooth ||
            status == AttendanceVerificationStatus.bluetoothFound ||
            status == AttendanceVerificationStatus.bluetoothNotFound ||
            status == AttendanceVerificationStatus.verified,
        active: false,
        failed: status == AttendanceVerificationStatus.locationMismatch,
      ),
      _StepInfo(
        icon: Icons.bluetooth_rounded,
        label: 'البحث عن بلوتوث المعلم',
        done: status == AttendanceVerificationStatus.verified,
        active: status == AttendanceVerificationStatus.scanningBluetooth,
        failed: status == AttendanceVerificationStatus.bluetoothNotFound,
      ),
      _StepInfo(
        icon: Icons.how_to_reg_rounded,
        label: 'تسجيل الحضور',
        done: status == AttendanceVerificationStatus.verified,
        active: false,
        failed: false,
      ),
    ];

    return Column(
      children: steps.map((step) {
        final (Color color, IconData stateIcon) = step.failed
            ? (Colors.red, Icons.close_rounded)
            : step.done
                ? (Colors.green, Icons.check_rounded)
                : step.active
                    ? (Colors.blue, Icons.hourglass_top_rounded)
                    : (Colors.grey, Icons.radio_button_unchecked_rounded);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(step.icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  step.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: step.active || step.done
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
              Icon(stateIcon, color: color, size: 18),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _StepInfo {
  final IconData icon;
  final String label;
  final bool done;
  final bool active;
  final bool failed;

  const _StepInfo({
    required this.icon,
    required this.label,
    required this.done,
    required this.active,
    required this.failed,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  Widget: بطاقة معلومات المادة عند النجاح
// ─────────────────────────────────────────────────────────────────────────────

class _CourseInfoCard extends StatelessWidget {
  final Map<String, dynamic> payloadInfo;
  const _CourseInfoCard({required this.payloadInfo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF065F46), Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
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
              const Icon(Icons.school_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'تفاصيل الحضور المسجَّل',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            payloadInfo['subjectName'] as String? ?? '',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'المجموعة: ${payloadInfo['group']}',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
