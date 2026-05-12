import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static const Color brandOrange = Color(0xFFFF7418);
  static const Color navy = Color(0xFF0D1B3E);
  static const Color surface = Color(0xFFF5F7FB);

  static ThemeData light() {
    return ThemeData(
      platform: TargetPlatform.linux,
      useMaterial3: true,
      scaffoldBackgroundColor: surface,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandOrange,
        brightness: Brightness.light,
        primary: brandOrange,
        secondary: const Color(0xFF18A3FF),
        surface: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.w800, color: navy),
          titleMedium: TextStyle(fontWeight: FontWeight.w700, color: navy),
          bodyMedium: TextStyle(color: Color(0xFF24324A)),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE6EAF2)),
        ),
      ),
    );
  }
}
