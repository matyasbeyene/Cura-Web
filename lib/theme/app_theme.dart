import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Warm "specialty-coffee" brand palette, exposed as semantic tokens so colors
/// are never hard-coded ad-hoc throughout the UI.
class AppColors {
  AppColors._();

  static const Color espresso = Color(0xFF3B2A20); // deep coffee brown
  static const Color mocha = Color(0xFF4A3528); // mid brown (body text)
  static const Color latte = Color(0xFFE8DCC8); // light tan
  static const Color cream = Color(0xFFFAF6EF); // off-white background
  static const Color white = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFD2D2D2); // video border / page surround
  static const Color warmBlack = Color(0xFF1A1410); // near-black, warm
  static const Color forest = Color(0xFF3A5A40); // forest green accent
  static const Color forestDark = Color(0xFF2F4A37);
}

/// Central theme. Fraunces (editorial serif) for display, Inter for UI + body.
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.espresso,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.espresso,
      secondary: AppColors.forest,
      surface: AppColors.cream,
      onPrimary: AppColors.cream,
      onSurface: AppColors.warmBlack,
    );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.cream,
    );

    final TextTheme text = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.fraunces(
        fontSize: 76,
        fontWeight: FontWeight.w600,
        height: 1.0,
        letterSpacing: -2.0,
        color: AppColors.warmBlack,
      ),
      displayMedium: GoogleFonts.fraunces(
        fontSize: 52,
        fontWeight: FontWeight.w600,
        height: 1.05,
        letterSpacing: -1.0,
        color: AppColors.warmBlack,
      ),
      headlineMedium: GoogleFonts.fraunces(
        fontSize: 34,
        fontWeight: FontWeight.w600,
        height: 1.15,
        color: AppColors.warmBlack,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.espresso,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 18,
        height: 1.6,
        color: AppColors.mocha,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 16,
        height: 1.6,
        color: AppColors.mocha,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );

    return base.copyWith(textTheme: text);
  }
}
