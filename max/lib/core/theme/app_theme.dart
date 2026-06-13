import 'dart:ui';
import 'package:flutter/material.dart';

class AppColors {
  static const Color spaceBlack = Color(0xFF0A0E17);
  static const Color darkCard = Color(0xFF141A29);
  static const Color electricCyan = Color(0xFF00F5FF);
  static const Color neonPurple = Color(0xFF9900FF);
  static const Color glowingGreen = Color(0xFF39FF14);
  static const Color textPrimary = Color(0xFFF0F4F8);
  static const Color textSecondary = Color(0xFF8A9Aad);
  
  // Glassmorphic translucent colors
  static Color glassBg = const Color(0xFF162035).withOpacity(0.45);
  static Color glassBorder = const Color(0xFFFFFFFF).withOpacity(0.08);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.spaceBlack,
      primaryColor: AppColors.electricCyan,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.electricCyan,
        secondary: AppColors.neonPurple,
        surface: AppColors.darkCard,
        error: Colors.redAccent,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.glassBorder),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AppColors.textSecondary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.electricCyan, width: 1.5),
        ),
      ),
    );
  }

  // Premium Glassmorphic Container Decoration
  static BoxDecoration glassBox({
    double borderRadius = 16.0,
    Color? borderCol,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      color: AppColors.glassBg,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderCol ?? AppColors.glassBorder,
        width: 1.2,
      ),
      boxShadow: shadows ?? [
        BoxShadow(
          color: AppColors.spaceBlack.withOpacity(0.3),
          blurRadius: 20,
          offset: const Offset(0, 10),
        )
      ],
    );
  }
}
