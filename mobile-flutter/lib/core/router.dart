import 'package:flutter/material.dart';
import 'models/user_model.dart';
import '../features/masyarakat/main_screen.dart';
import '../features/relawan/relawan_main_screen.dart';

/// Router utama SiagaKita.
/// Setelah login berhasil, panggil [getHomeByRole] dengan role, token, dan userId.
class AppRouter {
  AppRouter._(); // Prevent instantiation

  /// Kembalikan widget home sesuai role.
  /// [accessToken] dan [userId] diperlukan untuk masyarakat/relawan.
  static Widget getHomeByRole(
    UserRole role, {
    String accessToken = '',
    String userId = '',
  }) {
    switch (role) {
      case UserRole.masyarakat:
        return MainScreen(accessToken: accessToken, userId: userId);
      case UserRole.relawan:
        return RelawanMainScreen(accessToken: accessToken);
    }
  }

  /// Navigasi ke home screen berdasarkan role (hapus semua history)
  static void navigateToHome(
    BuildContext context,
    UserRole role, {
    String accessToken = '',
    String userId = '',
  }) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
            getHomeByRole(role, accessToken: accessToken, userId: userId),
      ),
      (route) => false,
    );
  }
}
