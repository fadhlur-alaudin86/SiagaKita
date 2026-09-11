import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_colors.dart';
import 'core/localization/app_localization.dart';
import 'core/services/background_telemetry_service.dart';
import 'core/services/responder_ws_service.dart';
import 'core/services/session_service.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/missions/presentation/mission_board_screen.dart';
import 'features/missions/services/mission_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize background fleet telemetry channel
  try {
    await BackgroundTelemetryService.initialize();
  } catch (_) {}

  final isLoggedIn = await SessionService.isLoggedIn();
  final initialLang = await SessionService.getLocale();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MissionService()),
        ChangeNotifierProvider(create: (_) => ResponderWsService()),
      ],
      child: ResponderApp(
        isLoggedIn: isLoggedIn,
        initialLocale: Locale(initialLang),
      ),
    ),
  );
}

class ResponderApp extends StatefulWidget {
  final bool isLoggedIn;
  final Locale initialLocale;

  const ResponderApp({
    super.key,
    required this.isLoggedIn,
    required this.initialLocale,
  });

  static void setLocale(BuildContext context, Locale newLocale) {
    final state = context.findAncestorStateOfType<_ResponderAppState>();
    state?.changeLocale(newLocale);
  }

  @override
  State<ResponderApp> createState() => _ResponderAppState();
}

class _ResponderAppState extends State<ResponderApp> {
  late Locale _currentLocale;

  @override
  void initState() {
    super.initState();
    _currentLocale = widget.initialLocale;
  }

  void changeLocale(Locale newLocale) {
    setState(() {
      _currentLocale = newLocale;
    });
    SessionService.setLocale(newLocale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SiagaKita Responder',
      debugShowCheckedModeBanner: false,
      locale: _currentLocale,
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
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.operationalBlue,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.operationalBlue,
          secondary: AppColors.warningAmber,
          surface: AppColors.surface,
          error: AppColors.emergencyRed,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: widget.isLoggedIn ? const MissionBoardScreen() : const LoginScreen(),
    );
  }
}
