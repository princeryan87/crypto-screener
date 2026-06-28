import 'package:flutter/material.dart';

/// Palet warna tema hijau-hitam, terinspirasi dari estetika trading
/// terminal (candlestick hijau = bullish) dan dashboard crypto gelap.
/// Dipakai konsisten di semua halaman - JANGAN hardcode warna baru di
/// luar file ini supaya tema tetap seragam.
class AppColors {
  static const Color background = Color(0xFF0A0F0D); // hitam kehijauan gelap
  static const Color surface = Color(0xFF131A17); // permukaan card
  static const Color surfaceElevated = Color(0xFF1B2420);
  static const Color border = Color(0xFF22302A);
  static const Color primaryGreen = Color(0xFF00E676); // hijau neon/terang
  static const Color secondaryGreen = Color(0xFF1DB954); // hijau lebih kalem
  static const Color textPrimary = Color(0xFFE8F5E9);
  static const Color textSecondary = Color(0xFF8FA89B);
  static const Color textMuted = Color(0xFF5C7268);
  static const Color warningAmber = Color(0xFFFFB300);
  static const Color dangerRed = Color(0xFFFF5252);
}

/// Tema Material terpusat, dipakai di MaterialApp.
ThemeData buildCryptostratTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryGreen,
      brightness: Brightness.dark,
      primary: AppColors.primaryGreen,
      secondary: AppColors.secondaryGreen,
      surface: AppColors.surface,
    ),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.primaryGreen.withOpacity(0.12)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceElevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryGreen),
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintStyle: const TextStyle(color: AppColors.textMuted),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primaryGreen,
      unselectedItemColor: AppColors.textMuted,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.textPrimary),
      bodyMedium: TextStyle(color: AppColors.textPrimary),
      titleMedium: TextStyle(color: AppColors.textPrimary),
    ),
  );
}
