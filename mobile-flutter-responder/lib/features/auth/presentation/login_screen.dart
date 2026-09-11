import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/constants/api_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localization.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/background_telemetry_service.dart';
import '../../../core/services/session_service.dart';
import '../../missions/presentation/mission_board_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    try {
      final res = await ApiClient.post(
        ApiConfig.loginPersonnel,
        body: {'email': identifier, 'password': password},
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = (body['data'] as Map<String, dynamic>?) ?? {};
        final user = (data['user'] as Map<String, dynamic>?) ?? {};

        final accessToken = data['access_token'] as String? ?? '';
        final refreshToken = data['refresh_token'] as String? ?? '';
        final role = user['role'] as String? ?? '';
        final userId = user['id'] as String? ?? '';
        final fullName = user['full_name'] as String?;
        final badgeNumber = user['badge_number'] as String?;

        if (role != 'agency_personnel') {
          setState(() {
            _isLoading = false;
            _errorMessage =
                'Role tidak diizinkan. Aplikasi ini khusus Petugas Instansi.'
                    .tr(context);
          });
          return;
        }

        await SessionService.saveSession(
          accessToken: accessToken,
          refreshToken: refreshToken,
          userId: userId,
          role: role,
          fullName: fullName,
          badgeNumber: badgeNumber,
        );

        // Start background telemetry streaming
        await BackgroundTelemetryService.start();

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MissionBoardScreen()),
        );
      } else {
        final body = jsonDecode(res.body) as Map<String, dynamic>?;
        final msg =
            body?['message'] as String? ??
            'Gagal masuk. Periksa kredensial Anda.'.tr(context);
        setState(() {
          _isLoading = false;
          _errorMessage = msg;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Terjadi kesalahan'.tr(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    size: 72,
                    color: AppColors.warningAmber,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'SiagaKita Responder'.tr(context),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sistem Penugasan Darurat Lapangan'.tr(context),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Masuk Petugas Lapangan'.tr(context),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _identifierController,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Nomor Lencana atau Email'.tr(context),
                            labelStyle: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                            prefixIcon: const Icon(
                              Icons.badge_outlined,
                              color: AppColors.textSecondary,
                            ),
                            filled: true,
                            fillColor: AppColors.surfaceHighlight,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Nomor Lencana / Email dan Kata Sandi wajib diisi'
                                  .tr(context);
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Kata Sandi'.tr(context),
                            labelStyle: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: AppColors.textSecondary,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: AppColors.surfaceHighlight,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Nomor Lencana / Email dan Kata Sandi wajib diisi'
                                  .tr(context);
                            }
                            return null;
                          },
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.emergencyRed.withAlpha(40),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.emergencyRed),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: AppColors.emergencyRed,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: AppColors.emergencyRed,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.operationalBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _isLoading ? null : _handleLogin,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    'Masuk'.tr(context),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
