import 'package:flutter/material.dart';

/// Tokens semánticos oficiales alineados con EventHub_frontend (Tailwind config v2).
class AppColors {
  // Fondos
  static const Color bg = Color(0xFFFFFFFF);
  static const Color bgSoft = Color(0xFFF5F5F4);
  static const Color bgAlt = Color(0xFFFAFAFA);

  // Textos
  static const Color fg = Color(0xFF1A1A1A);
  static const Color fgMuted = Color(0xFF737373);
  static const Color fgLight = Color(0xFFA3A3A3);

  // Acento de marca
  static const Color accent = Color(0xFFEC3013);
  static const Color accentFg = Color(0xFFFFFFFF);
  static const Color accentSoft = Color(0xFFFEECE9);

  // Bordes y divisores
  static const Color border = Color(0xFFE5E5E5);
  static const Color borderDark = Color(0xFFD4D4D4);

  // Estados
  static const Color success = Color(0xFF16A34A);
  static const Color successBg = Color(0xFFF0FDF4);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFDC2626);
  static const Color errorBg = Color(0xFFFEF2F2);
  static const Color info = Color(0xFF2563EB);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bg,
      primaryColor: AppColors.accent,
      colorScheme: const ColorScheme.light(
        primary: AppColors.accent,
        onPrimary: AppColors.accentFg,
        secondary: AppColors.accent,
        onSecondary: AppColors.accentFg,
        surface: AppColors.bg,
        onSurface: AppColors.fg,
        error: AppColors.error,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.fg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.fg),
        titleTextStyle: TextStyle(
          color: AppColors.fg,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.bg,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.accentFg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.fg,
          side: const BorderSide(color: AppColors.border, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgSoft,
        hintStyle: const TextStyle(color: AppColors.fgMuted, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.fgMuted, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.error),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.bgSoft,
        disabledColor: AppColors.bgSoft,
        selectedColor: AppColors.accent,
        secondarySelectedColor: AppColors.accent,
        labelStyle: const TextStyle(color: AppColors.fg, fontSize: 13),
        secondaryLabelStyle: const TextStyle(color: AppColors.accentFg, fontSize: 13),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}
