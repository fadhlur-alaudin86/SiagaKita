import 'package:flutter/material.dart';

/// Tactical Emergency Response Color Palette.
/// Designed for high visibility, low glare in dark emergency vehicles, and rapid contrast recognition.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF0B1120);
  static const Color surface = Color(0xFF162032);
  static const Color surfaceHighlight = Color(0xFF1E293B);
  static const Color border = Color(0xFF334155);

  static const Color emergencyRed = Color(0xFFDC2626);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color operationalBlue = Color(0xFF2563EB);
  static const Color successGreen = Color(0xFF10B981);
  static const Color sirenOrange = Color(0xFFEA580C);

  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Status colors
  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'handling':
      case 'en_route':
        return operationalBlue;
      case 'on_scene':
        return warningAmber;
      case 'resolved':
        return successGreen;
      case 'canceled':
        return textMuted;
      default:
        return emergencyRed;
    }
  }
}
