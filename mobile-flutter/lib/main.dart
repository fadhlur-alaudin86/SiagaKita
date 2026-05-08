import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/localization/app_localization.dart';
import 'core/models/user_model.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/location_service.dart';
import 'core/services/session_service.dart';
import 'core/services/background_service.dart';
import 'features/auth/login_screen.dart';
import 'features/masyarakat/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConnectivityService.instance.init();
  await AppBackgroundService.initialize();
  runApp(const SiagaKitaApp());
}

class SiagaKitaApp extends StatefulWidget {
  const SiagaKitaApp({super.key});

  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(
    ThemeMode.dark,
  );
  static final ValueNotifier<Locale> localeNotifier = ValueNotifier(
    AppLocalization.localeId,
  );

  @override
  State<SiagaKitaApp> createState() => _SiagaKitaAppState();
}

class _SiagaKitaAppState extends State<SiagaKitaApp> {
  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFFF7418); // Oranye Utama

    // Dark Theme Colors
    const Color darkBgColor = Color(0xFF0D1B3E); // Deep Royal Navy
    const Color darkCardColor = Color(0xFF162A5A); // Cobalt Blue

    // Light Theme Colors
    const Color lightBgColor = Color(0xFFF1F5F9); // Slate 100
    const Color lightCardColor = Color(0xFFFFFFFF); // White

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: SiagaKitaApp.themeNotifier,
      builder: (_, ThemeMode currentMode, child) {
        return ValueListenableBuilder<Locale>(
          valueListenable: SiagaKitaApp.localeNotifier,
          builder: (_, Locale currentLocale, w) {
            return MaterialApp(
              title: 'SiagaKita',
              debugShowCheckedModeBanner: false,
              themeMode: currentMode,
              locale: currentLocale,
              supportedLocales: const [
                AppLocalization.localeId,
                AppLocalization.localeEn,
              ],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: ThemeData(
                brightness: Brightness.light,
                primaryColor: primaryColor,
                scaffoldBackgroundColor: lightBgColor,
                colorScheme: const ColorScheme.light(
                  primary: primaryColor,
                  secondary: Color(0xFF18A3FF),
                  surface: lightCardColor,
                  onSurface: Color(0xFF1E293B),
                ),
                fontFamily: 'Inter',
                appBarTheme: const AppBarTheme(
                  backgroundColor: lightBgColor,
                  elevation: 0,
                  iconTheme: IconThemeData(color: Color(0xFF1E293B)),
                  titleTextStyle: TextStyle(
                    color: Color(0xFF1E293B),
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                  backgroundColor: lightCardColor,
                  selectedItemColor: primaryColor,
                  unselectedItemColor: Colors.black54,
                  type: BottomNavigationBarType.fixed,
                ),
              ),
              darkTheme: ThemeData(
                brightness: Brightness.dark,
                primaryColor: primaryColor,
                scaffoldBackgroundColor: darkBgColor,
                colorScheme: const ColorScheme.dark(
                  primary: primaryColor,
                  secondary: Color(0xFF18A3FF),
                  surface: darkCardColor,
                  onSurface: Colors.white,
                ),
                fontFamily: 'Inter',
                appBarTheme: const AppBarTheme(
                  backgroundColor: darkBgColor,
                  elevation: 0,
                ),
                bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                  backgroundColor: Color(0xFF162A5A),
                  selectedItemColor: primaryColor,
                  unselectedItemColor: Colors.white54,
                  type: BottomNavigationBarType.fixed,
                ),
              ),
              home: const _AppStartup(),
            );
          },
        );
      },
    );
  }
}

/// Menangani logika startup: cek sesi tersimpan → auto-login atau ke LoginScreen.
class _AppStartup extends StatefulWidget {
  const _AppStartup();

  @override
  State<_AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<_AppStartup> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final session = await SessionService.loadSession();
    if (!mounted) return;

    if (session != null) {
      // Perbarui UserModel dengan data sesi tersimpan
      UserModel.currentUser.value = UserModel(
        id: session.userId,
        name: session.name ?? 'Pengguna',
        email: session.email,
        role: session.role == 'volunteer'
            ? UserRole.relawan
            : session.role == 'admin'
                ? UserRole.admin
                : UserRole.masyarakat,
      );

      // Minta izin GPS jika online, abaikan jika offline
      if (ConnectivityService.isOnline.value) {
        await LocationService.requestPermission(context);
        if (!mounted) return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MainScreen(
            accessToken: session.token,
            userId: session.userId,
          ),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Layar loading sementara sambil cek sesi
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
