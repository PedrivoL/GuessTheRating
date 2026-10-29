import 'package:flutter/material.dart';

/// Paleta inspirada na identidade visual escura do Letterboxd.
abstract final class AppColors {
  static const Color background = Color(0xFF14181C);
  static const Color surface = Color(0xFF1C2228);
  static const Color surfaceElevated = Color(0xFF283038);
  static const Color border = Color(0xFF38424D);

  // Trio clássico de cores do Letterboxd
  static const Color letterboxdOrange = Color(0xFFFF8000);
  static const Color letterboxdGreen = Color(0xFF00E054);
  static const Color letterboxdBlue = Color(0xFF40BCF4);

  static const Color errorRed = Color(0xFFFF4D4F);
  static const Color textPrimary = Color(0xFFF4F7FA);
  static const Color textSecondary = Color(0xFF9AB0C4);
}

abstract final class AppTheme {
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.letterboxdGreen,
      brightness: Brightness.dark,
      surface: AppColors.surface,
      primary: AppColors.letterboxdGreen,
      secondary: AppColors.letterboxdOrange,
      tertiary: AppColors.letterboxdBlue,
      error: AppColors.errorRed,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
        ),
      ),
    );
  }
}

