import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static const Color brandOrange = Color(0xFFFF7418);
  static const Color navy = Color(0xFF0D1B3E);
  static const Color surface = Color(0xFFF5F7FB);

  static ThemeData dark() {
    return ThemeData(
      platform: TargetPlatform.linux,
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0A1628),
      colorScheme: const ColorScheme.dark(
        primary: brandOrange,
        secondary: Color(0xFF18A3FF),
        surface: Color(0xFF1A2035),
        onSurface: Colors.white,
        onSurfaceVariant: Colors.white70,
        outline: Colors.white12,
      ),
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          displaySmall: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
            color: Colors.white,
          ),
          titleLarge: TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
          titleMedium: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontSize: 16,
          ),
          bodyMedium: TextStyle(color: Colors.white, fontSize: 14),
          bodySmall: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1A2035),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white10),
        ),
      ),
      dividerTheme: const DividerThemeData(color: Colors.white12, thickness: 1),
    );
  }
}
