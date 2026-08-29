import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens and light theme tailored to match the TaskVassal UX.
class AppTheme {
  // Brand & Accent Colors
  static const Color primaryBlue = Color(0xFF0969DA);
  static const Color primaryHover = Color(0xFF0550AE);
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Colors.white;
  static const Color sidebarBackground = Color(0xFFF9FAFB);

  // Border & Divider Colors
  static const Color borderSubtle = Color(0xFFE5E7EB);
  static const Color borderMedium = Color(0xFFD1D5DB);

  // Text Colors
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textPlaceholder = Color(0xFF9CA3AF);

  // Badge & Status Colors
  static const Color badgeBugBg = Color(0xFFFEE2E2);
  static const Color badgeBugText = Color(0xFFB91C1C);

  static const Color badgeEnhancementBg = Color(0xFFDBEAFE);
  static const Color badgeEnhancementText = Color(0xFF1D4ED8);

  static const Color badgeDocsBg = Color(0xFFF3F4F6);
  static const Color badgeDocsText = Color(0xFF4B5563);

  static const Color badgePurpleBg = Color(0xFFEDE9FE);
  static const Color badgePurpleText = Color(0xFF6D28D9);

  static const Color dotRed = Color(0xFFDC2626);
  static const Color dotBlue = Color(0xFF2563EB);

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryBlue,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        surface: surface,
        brightness: Brightness.light,
      ),
      textTheme: baseTextTheme.copyWith(
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          fontSize: 14,
          color: textSecondary,
        ),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
          fontSize: 12,
          color: textMuted,
        ),
        labelSmall: baseTextTheme.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderSubtle,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        hintStyle: const TextStyle(color: textPlaceholder, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: borderMedium),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
        ),
      ),
    );
  }
}
