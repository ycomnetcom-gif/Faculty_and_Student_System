import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // منع إنشاء نسخة من الكلاس
  AppTheme._();

  // ألوان ثابتة مساعدة
  static const Color successColor = Color(0xFF16A34A); // أخضر قبول
  static const Color errorColor = Color(0xFFDC2626);   // أحمر رفض / إلغاء
  static const Color warningColor = Color(0xFFD97706); // برتقالي / تحذير

  // تصميم صندوق البطاقات (Card Decoration) المشترك
  static BoxDecoration cardDecoration(BuildContext context) {
    final theme = Theme.of(context);
    return BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: theme.colorScheme.primary.withOpacity(0.03),
          blurRadius: 40,
          offset: const Offset(0, 20),
        ),
      ],
    );
  }

  // 1. الثيم الفاتح (Light Theme)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // تطبيق خط Cairo على كل النصوص في الثيم الفاتح
      textTheme: GoogleFonts.cairoTextTheme(ThemeData.light().textTheme),

      // الألوان الأساسية للثيم الفاتح
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF2563EB), // الأزرق الملكي (الأساسي)
        onPrimary: Colors.white,
        secondary: Color(0xFF0EA5E9), // أزرق سماوي (secondary)
        background: Color(0xFFF8FAFC), // خلفية التطبيق بيضاء مائلة للرمادي
        surface: Colors.white, // خلفية الكروت والبطاقات
        onBackground: Color(0xFF0F172A), // لون النصوص الأساسية (داكن جداً)
        onSurface: Color(0xFF334155), // لون النصوص الثانوية
      ),

      // تخصيص الـ AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Color(0xFF0F172A)),
        titleTextStyle: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),

      // تخصيص الأزرار (ElevatedButton)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52), // طول وعرض زر قياسي
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // تخصيص حقول المدخلات (TextField)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        prefixIconColor: const Color(0xFF64748B),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
        ),
      ),

      // تخصيص الحوارات (Dialogs)
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: Colors.white,
      ),

      // تخصيص البطاقات (Cards)
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  // 2. الثيم المظلم (Dark Theme)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // تطبيق خط Cairo على كل النصوص في الثيم المظلم
      textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme),

      // الألوان الأساسية للثيم المظلم
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF3B82F6), // أزرق فاتح قليلاً ليناسب الظلام
        onPrimary: Colors.white,
        secondary: Color(0xFF38BDF8),
        background: Color(0xFF0F172A), // خلفية التطبيق (داكنة مائلة للكحلي)
        surface: Color(0xFF1E293B), // خلفية الكروت (رمادي داكن)
        onBackground: Color(0xFFF8FAFC), // لون النصوص (فاتح جداً)
        onSurface: Color(0xFFE2E8F0),
      ),

      // تخصيص الـ AppBar للثيم المظلم
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E293B),
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),

      // تخصيص الأزرار في الثيم المظلم
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3B82F6),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // تخصيص حقول المدخلات في الثيم المظلم
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        prefixIconColor: const Color(0xFF94A3B8),
        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
        ),
      ),

      // تخصيص الحوارات في الثيم المظلم
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: const Color(0xFF1E293B),
      ),

      // تخصيص البطاقات في الثيم المظلم
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
