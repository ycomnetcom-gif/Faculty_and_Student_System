import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:student_attendance_system/features/student_screens/qr_scan/student_qr_scan_view.dart';

class StudentQrScanEntryView extends StatefulWidget {
  const StudentQrScanEntryView({super.key});

  @override
  State<StudentQrScanEntryView> createState() => _StudentQrScanEntryViewState();
}

class _StudentQrScanEntryViewState extends State<StudentQrScanEntryView>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _hasDetected = false;

  late AnimationController _animController;
  late Animation<double> _animation;

  // هل المنصة تدعم الكاميرا والمسح؟
  bool get _isCameraSupported => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onCodeDetected(String code) {
    if (_hasDetected) return;
    setState(() {
      _hasDetected = true;
    });

    if (_isCameraSupported) {
      // إيقاف مؤقت للمسح لتجنب فتح الشاشة عدة مرات
      _scannerController.stop();
    }

    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => StudentQrScanView(rawQrData: code),
      ),
    )
        .then((_) {
      // إعادة التشغيل عند العودة للشاشة
      setState(() {
        _hasDetected = false;
      });
      if (_isCameraSupported) {
        _scannerController.start();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مسح باركود التحضير'),
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
                : [
                    const Color(0xFFEFF6FF),
                    const Color(0xFFDBEAFE),
                    const Color(0xFFF8FAFC),
                  ],
          ),
        ),
        child: SafeArea(
          child: _isCameraSupported ? _buildCameraMode(theme) : _buildUnsupportedPlatform(theme),
        ),
      ),
    );
  }

  // ─── وضع الكاميرا (مسح الباركود الحقيقي) ──────────────────────────────────
  Widget _buildCameraMode(ThemeData theme) {
    return Stack(
      children: [
        // ودجت المسح
        Positioned.fill(
          child: MobileScanner(
            controller: _scannerController,
            onDetect: (BarcodeCapture capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final code = barcodes.first.rawValue;
                if (code != null && code.isNotEmpty) {
                  _onCodeDetected(code);
                }
              }
            },
          ),
        ),

        // إطار محاكاة المسح والزخرفة البصرية
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // صندوق المسح
                  Stack(
                    children: [
                      Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24, width: 2),
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      // الزوايا المميزة بلون أخضر/أزرق
                      Positioned(
                        top: 0,
                        left: 0,
                        child: _buildCorner(top: true, left: true),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: _buildCorner(top: true, left: false),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: _buildCorner(top: false, left: true),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: _buildCorner(top: false, left: false),
                      ),
                      // خط الليزر المتحرك
                      AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) {
                          return Positioned(
                            top: 15 + (_animation.value * 230),
                            left: 15,
                            right: 15,
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary,
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'ضع باركود التحضير (QR) داخل المربع لمسحه',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // أزرار التحكم بالفلاش والكاميرا بالأسفل
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildControlButton(
                icon: Icons.flash_on_rounded,
                onPressed: () => _scannerController.toggleTorch(),
              ),
              const SizedBox(width: 24),
              _buildControlButton(
                icon: Icons.flip_camera_ios_rounded,
                onPressed: () => _scannerController.switchCamera(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCorner({required bool top, required bool left}) {
    final theme = Theme.of(context);
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        border: Border(
          top: top
              ? BorderSide(color: theme.colorScheme.primary, width: 4)
              : BorderSide.none,
          bottom: !top
              ? BorderSide(color: theme.colorScheme.primary, width: 4)
              : BorderSide.none,
          left: left
              ? BorderSide(color: theme.colorScheme.primary, width: 4)
              : BorderSide.none,
          right: !left
              ? BorderSide(color: theme.colorScheme.primary, width: 4)
              : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: top && left ? const Radius.circular(12) : Radius.zero,
          topRight: top && !left ? const Radius.circular(12) : Radius.zero,
          bottomLeft: !top && left ? const Radius.circular(12) : Radius.zero,
          bottomRight: !top && !left ? const Radius.circular(12) : Radius.zero,
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        iconSize: 28,
        onPressed: onPressed,
      ),
    );
  }

  // ─── واجهة المنصات غير المدعومة (Windows) ──────────────────────────────────
  Widget _buildUnsupportedPlatform(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.no_photography_rounded,
                size: 72,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'الكاميرا غير مدعومة',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'مسح الباركود يتطلب تشغيل التطبيق على هاتف ذكي (Android / iOS) لاستخدام الكاميرا. نظام تشغيل Windows لا يدعم فحص الكاميرا في هذه النسخة.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.65),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
