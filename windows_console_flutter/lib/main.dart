import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app.dart';
import 'core/localization/app_localization.dart';
import 'core/widgets/language_switcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Restore saved language preference
  const storage = FlutterSecureStorage();
  final savedLang = await storage.read(key: LanguageSwitcher.storageKey);
  if (savedLang != null) {
    final loc = Locale(savedLang);
    SiagaKitaConsoleApp.localeNotifier.value = loc;
    AppLocalization.currentLocale = loc;
  }

  runApp(const SiagaKitaConsoleApp());
}
