import 'package:flutter/material.dart';

import 'core/services/auth_service.dart';
import 'core/services/ws_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/admin/presentation/admin_shell.dart';
import 'features/instansi/presentation/instansi_shell.dart';

class SiagaKitaConsoleApp extends StatelessWidget {
  const SiagaKitaConsoleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SiagaKita Console',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const _SplashRouter(),
    );
  }
}

/// Cek session JWT yang tersimpan. Jika ada → langsung masuk ke shell yang sesuai.
/// Jika tidak → tampilkan login screen.
class _SplashRouter extends StatefulWidget {
  const _SplashRouter();

  @override
  State<_SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<_SplashRouter> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final session = await AuthService.restoreSession();
    if (!mounted) return;

    if (session == null) {
      // Tidak ada session — tampilkan login
      _navigateTo(const LoginScreen());
      return;
    }

    // Ada session — sambungkan WS dan masuk ke shell
    final ws = WsService();
    await ws.connect(session.accessToken);

    Widget shell;
    if (session.role == 'admin' || session.role == 'superadmin') {
      shell = AdminShell(
        token: session.accessToken,
        role: session.role,
        name: session.fullName,
        ws: ws,
      );
    } else {
      shell = InstansiShell(token: session.accessToken, ws: ws);
    }
    _navigateTo(shell);
  }

  void _navigateTo(Widget dest) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => dest,
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Layar splash sederhana selama cek session
    return const Scaffold(
      backgroundColor: Color(0xFF0A1628),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined, color: Color(0xFFFF7418), size: 64),
            SizedBox(height: 20),
            Text(
              'SiagaKita Console',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Memuat...',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(
              color: Color(0xFFFF7418),
              strokeWidth: 2.5,
            ),
          ],
        ),
      ),
    );
  }
}
