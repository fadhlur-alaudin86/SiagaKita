import 'package:flutter/material.dart';
import '../../core/localization/app_localization.dart';
import '../../core/models/user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/location_service.dart';
import 'biodata_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  /// Step index:
  /// 0 = form data akun (nama + email + password)
  /// 1 = OTP email verification
  int _step = 0;
  final _formKey = GlobalKey<FormState>();

  // Step 0
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _repeatPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureRepeat = true;
  int _passwordStrength = 0; // 0=empty, 1=weak, 2=medium, 3=strong

  // Step 1 (OTP)
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isResendCooldown = false;
  int _cooldownSeconds = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _repeatPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // ─── Password Strength ────────────────────────────────────────────────────

  void _updateStrength(String value) {
    if (value.isEmpty) {
      setState(() => _passwordStrength = 0);
      return;
    }
    int score = 0;
    if (value.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(value)) score++;
    if (RegExp(r'[0-9]').hasMatch(value)) score++;
    if (RegExp(r'[!@#\$&*~%^()_\-+=\[\]{};:"\\|,.<>/?]').hasMatch(value)) {
      score++;
    }
    setState(
      () => _passwordStrength = score <= 1
          ? 1
          : score <= 2
          ? 2
          : 3,
    );
  }

  Color get _strengthColor => [
    Colors.transparent,
    Colors.red,
    Colors.orange,
    Colors.green,
  ][_passwordStrength];

  String get _strengthLabel =>
      ['', 'Lemah', 'Sedang', 'Kuat ✓'][_passwordStrength];

  // ─── Validators ────────────────────────────────────────────────────────────

  String? _validateName(String? v) => (v == null || v.trim().isEmpty)
      ? 'Nama lengkap tidak boleh kosong'
      : null;

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email tidak boleh kosong';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) {
      return 'Format email tidak valid';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Kata sandi tidak boleh kosong';
    if (v.length < 8) return 'Minimal 8 karakter';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Harus mengandung huruf besar';
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Harus mengandung angka';
    if (!RegExp(r'[!@#\$&*~%^()_\-+=\[\]{};:"\\|,.<>/?]').hasMatch(v)) {
      return 'Harus mengandung simbol';
    }
    return null;
  }

  String? _validateRepeat(String? v) {
    if (v == null || v.isEmpty) {
      return 'Konfirmasi kata sandi tidak boleh kosong';
    }
    if (v != _passwordController.text) return 'Kata sandi tidak cocok';
    return null;
  }

  // ─── Actions ───────────────────────────────────────────────────────────────

  /// Step 0 → buat akun dan kirim OTP ke email
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await AuthService.register(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _step = 1;
        _isResendCooldown = true;
        _cooldownSeconds = 60;
      });
      _startCooldown();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Gagal menghubungi server. Periksa koneksi.');
    }
  }

  /// Step 1 → verifikasi OTP email → JWT → biodata screen
  Future<void> _verifyOTP() async {
    if (_otpController.text.trim().length < 6) {
      _showError('Masukkan kode OTP 6 digit');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final result = await AuthService.verifyRegisterOTP(
        email: _emailController.text.trim(),
        otpCode: _otpController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      // simpan token ke secure storage
      debugPrint('[Auth] Register berhasil: ${result.user.email}');

      // Minta izin GPS setelah registrasi berhasil (poin 4)
      if (!mounted) return;
      await LocationService.requestPermission(context);
      if (!mounted) return;

      // Set global user state agar BiodataScreen bisa menggunakannya
      UserModel.currentUser.value = UserModel(
        id: result.user.id,
        name: result.user.fullName ?? 'Pengguna',
        email: result.user.email,
        role: result.user.role == 'volunteer'
            ? UserRole.relawan
            : result.user.role == 'admin'
                ? UserRole.admin
                : UserRole.masyarakat,
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BiodataScreen(
            accessToken: result.accessToken,
            userId: result.user.id,
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Gagal menghubungi server. Periksa koneksi.');
    }
  }

  void _startCooldown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _cooldownSeconds--);
      if (_cooldownSeconds <= 0) {
        setState(() => _isResendCooldown = false);
        return false;
      }
      return true;
    });
  }

  Future<void> _resendOTP() async {
    if (_isResendCooldown) return;
    await _submitForm();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: colors.onSurface,
          onPressed: () {
            if (_step == 1) {
              setState(() {
                _step = 0;
                _otpController.clear();
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 8.0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _step == 0
                ? _buildFormStep(colors, primaryColor)
                : _buildOTPStep(colors, primaryColor),
          ),
        ),
      ),
    );
  }

  // ─── Step 0: Form data akun ────────────────────────────────────────────────

  Widget _buildFormStep(ColorScheme colors, Color primaryColor) {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('form_step'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress indicator (2 steps)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(2, (i) {
              final active = i <= _step;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 6,
                width: active ? 28 : 14,
                decoration: BoxDecoration(
                  color: active
                      ? primaryColor
                      : colors.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 28),
          Text(
            'Buat Akun Baru'.tr(context),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bergabung dengan jejaring keselamatan SiagaKita.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurface.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 28),

          // Nama Lengkap
          _field(
            colors,
            primaryColor,
            controller: _nameController,
            hint: 'Nama Lengkap',
            icon: Icons.person_outline,
            validator: _validateName,
          ),
          const SizedBox(height: 16),

          // Email
          _field(
            colors,
            primaryColor,
            controller: _emailController,
            hint: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail,
          ),
          const SizedBox(height: 16),

          // Password + strength bar
          _field(
            colors,
            primaryColor,
            controller: _passwordController,
            hint: 'Kata Sandi',
            icon: Icons.lock_outline,
            obscure: _obscurePassword,
            validator: _validatePassword,
            onChanged: _updateStrength,
            suffix: _visibilityToggle(
              colors,
              _obscurePassword,
              () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),

          // Strength bar
          if (_passwordStrength > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                ...List.generate(3, (i) {
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 4,
                          color: _passwordStrength > i
                              ? _strengthColor
                              : colors.onSurface.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _strengthLabel,
                    key: ValueKey(_passwordStrength),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _strengthColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),

          // Konfirmasi password
          _field(
            colors,
            primaryColor,
            controller: _repeatPasswordController,
            hint: 'Ulangi Kata Sandi',
            icon: Icons.lock_reset,
            obscure: _obscureRepeat,
            validator: _validateRepeat,
            suffix: _visibilityToggle(
              colors,
              _obscureRepeat,
              () => setState(() => _obscureRepeat = !_obscureRepeat),
            ),
          ),

          const SizedBox(height: 28),
          _submitButton(primaryColor, 'Lanjut'.tr(context), _submitForm),

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Sudah punya akun?',
                style: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Masuk sekarang',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Step 1: OTP Email ─────────────────────────────────────────────────────

  Widget _buildOTPStep(ColorScheme colors, Color primaryColor) {
    return Column(
      key: const ValueKey('otp_step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Progress indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(2, (i) {
            final active = i <= _step;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              width: active ? 28 : 14,
              decoration: BoxDecoration(
                color: active
                    ? primaryColor
                    : colors.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
        const SizedBox(height: 32),
        Icon(Icons.mark_email_unread_outlined, size: 72, color: primaryColor),
        const SizedBox(height: 24),
        Text(
          'Verifikasi Email'.tr(context),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Kami telah mengirimkan kode OTP ke:\n${_emailController.text.trim()}\nKode berlaku 3 menit.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.onSurface.withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 28,
            letterSpacing: 10,
            fontWeight: FontWeight.bold,
          ),
          maxLength: 6,
          decoration: InputDecoration(
            hintText: '______',
            hintStyle: TextStyle(
              color: colors.onSurface.withValues(alpha: 0.25),
              fontSize: 28,
              letterSpacing: 10,
            ),
            counterText: '',
            filled: true,
            fillColor: colors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 20,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: colors.onSurface.withValues(alpha: 0.15),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _isResendCooldown ? null : _resendOTP,
          child: Text(
            _isResendCooldown
                ? 'Kirim ulang dalam ${_cooldownSeconds}s'
                : 'Kirim ulang kode OTP',
            style: TextStyle(
              color: _isResendCooldown
                  ? colors.onSurface.withValues(alpha: 0.4)
                  : primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _submitButton(
          primaryColor,
          'Verifikasi & Masuk'.tr(context),
          _verifyOTP,
        ),
      ],
    );
  }

  // ─── Shared helpers ────────────────────────────────────────────────────────

  Widget _field(
    ColorScheme colors,
    Color primaryColor, {
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    Widget? suffix,
  }) {
    final r = BorderRadius.circular(16);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: TextStyle(color: colors.onSurface),
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.4)),
        prefixIcon: Icon(icon, color: colors.onSurface.withValues(alpha: 0.5)),
        suffixIcon: suffix,
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: r,
          borderSide: BorderSide(
            color: colors.onSurface.withValues(alpha: 0.15),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: r,
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: r,
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: r,
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
        errorStyle: const TextStyle(fontSize: 11, height: 1.3),
      ),
    );
  }

  Widget _visibilityToggle(
    ColorScheme colors,
    bool obscure,
    VoidCallback onTap,
  ) {
    return IconButton(
      icon: Icon(
        obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: colors.onSurface.withValues(alpha: 0.4),
        size: 20,
      ),
      onPressed: onTap,
    );
  }

  Widget _submitButton(
    Color primaryColor,
    String label,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: _isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 5,
        shadowColor: primaryColor.withValues(alpha: 0.5),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
    );
  }
}
