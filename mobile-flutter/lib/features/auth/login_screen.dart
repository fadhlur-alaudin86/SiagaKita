import 'package:flutter/material.dart';
import '../../core/localization/app_localization.dart';
import '../../core/models/user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/location_service.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import '../masyarakat/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ─── Validators ────────────────────────────────────────────────────────────

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email tidak boleh kosong';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) {
      return 'Format email tidak valid';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Kata sandi tidak boleh kosong';
    return null;
  }

  // ─── Submit: email+password → JWT langsung → GPS → HomeScreen ─────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final result = await AuthService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;

      // TODO Task 6: simpan token ke secure storage
      debugPrint('[Auth] Login berhasil: ${result.user.email}');

      // Perbarui global state (nama, role, email, dsb.)
      UserModel.currentUser.value = UserModel(
        id: result.user.id,
        name: result.user.fullName ?? 'Pengguna',
        email: result.user.email,
        role: result.user.role == 'admin'
            ? UserRole.admin
            : result.user.role == 'instansi'
                ? UserRole.instansi
                : result.user.role == 'relawan'
                    ? UserRole.relawan
                    : UserRole.masyarakat,
      );

      // Minta izin GPS setelah auth berhasil (poin 4)
      await LocationService.requestPermission();
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  void _goToRegister() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RegisterScreen())).then((_) {
      if (mounted) {
        _formKey.currentState?.reset();
        _emailController.clear();
        _passwordController.clear();
        setState(() {});
      }
    });
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                _logo(colors, primaryColor),
                const SizedBox(height: 32),
                Text(
                  'Selamat Datang'.tr(context),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Masuk untuk mengakses sistem pelaporan darurat.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 48),
                _buildField(
                  colors: colors,
                  primaryColor: primaryColor,
                  controller: _emailController,
                  hint: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),
                _buildField(
                  colors: colors,
                  primaryColor: primaryColor,
                  controller: _passwordController,
                  hint: 'Kata Sandi',
                  icon: Icons.lock_outline,
                  obscure: _obscurePassword,
                  validator: _validatePassword,
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: colors.onSurface.withValues(alpha: 0.4),
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Lupa sandi?'.tr(context),
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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
                          'Masuk'.tr(context),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Belum punya akun?',
                      style: TextStyle(
                        color: colors.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    TextButton(
                      onPressed: _goToRegister,
                      child: Text(
                        'Daftar di sini',
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
          ),
        ),
      ),
    );
  }

  // ─── Shared helpers ────────────────────────────────────────────────────────

  Widget _logo(ColorScheme colors, Color primaryColor) {
    return Center(
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: colors.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          'lib/components/logo_siagakita_transparant.png',
          fit: BoxFit.cover,
          errorBuilder: (_, e, s) =>
              Icon(Icons.shield, size: 55, color: primaryColor),
        ),
      ),
    );
  }

  Widget _buildField({
    required ColorScheme colors,
    required Color primaryColor,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    String? Function(String?)? validator,
    Widget? suffix,
  }) {
    final r = BorderRadius.circular(16);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: TextStyle(color: colors.onSurface),
      validator: validator,
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
}
