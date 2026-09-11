import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/localization/app_localization.dart';
import 'core/models/user_model.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/session_service.dart';
import 'core/services/user_service.dart';
import 'core/services/background_service.dart';
import 'core/services/local_storage_service.dart';
import 'features/auth/login_screen.dart';
import 'features/masyarakat/main_screen.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Hive Local Storage
  await LocalStorageService.init();

  // Persistensi Bahasa & Tema
  final prefs = await SharedPreferences.getInstance();
  final savedLang = prefs.getString('language_code');
  if (savedLang != null) {
    final loc = Locale(savedLang);
    SiagaKitaApp.localeNotifier.value = loc;
    AppLocalization.currentLocale = loc;
  }

  await ConnectivityService.instance.init();
  await AppBackgroundService.initialize();
  runApp(const SiagaKitaApp());
}

class SiagaKitaApp extends StatefulWidget {
  const SiagaKitaApp({super.key});

  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(
    ThemeMode.dark, // Paksa Dark Mode
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

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: SiagaKitaApp.themeNotifier,
      builder: (_, ThemeMode currentMode, child) {
        return ValueListenableBuilder<Locale>(
          valueListenable: SiagaKitaApp.localeNotifier,
          builder: (_, Locale currentLocale, w) {
            final darkTheme = ThemeData(
              platform: TargetPlatform.android,
              brightness: Brightness.dark,
              primaryColor: primaryColor,
              scaffoldBackgroundColor: darkBgColor,
              colorScheme: const ColorScheme.dark(
                primary: primaryColor,
                secondary: Color(0xFF18A3FF),
                surface: darkCardColor,
                onSurface: Colors.white,
              ),
              textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
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
            );

            return MaterialApp(
              title: 'SiagaKita',
              debugShowCheckedModeBanner: false,
              themeMode: ThemeMode.dark, // Selalu Dark
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
              theme: darkTheme,
              darkTheme: darkTheme,
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
    final prefs = await SharedPreferences.getInstance();
    final hasCompletedOnboarding =
        prefs.getBool('has_completed_onboarding') ?? false;

    if (!hasCompletedOnboarding) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
      return;
    }

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
            : UserRole.masyarakat,
      );

      // Ambil data profil lengkap dari server (background refresh)
      UserService.refreshCurrentUser(session.token);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              MainScreen(accessToken: session.token, userId: session.userId),
        ),
      );
    } else {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Layar loading sementara sambil cek sesi
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
