import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../app.dart';
import '../localization/app_localization.dart';

class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key});

  static const _storage = FlutterSecureStorage();
  static const storageKey = 'console_language_code';

  static Future<void> switchLanguage(Locale newLocale) async {
    SiagaKitaConsoleApp.localeNotifier.value = newLocale;
    AppLocalization.currentLocale = newLocale;
    await _storage.write(key: storageKey, value: newLocale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: SiagaKitaConsoleApp.localeNotifier,
      builder: (context, currentLocale, _) {
        final isEn =
            currentLocale.languageCode == AppLocalization.localeEn.languageCode;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildOption(
                label: 'ID',
                isSelected: !isEn,
                onTap: () => switchLanguage(AppLocalization.localeId),
              ),
              _buildOption(
                label: 'EN',
                isSelected: isEn,
                onTap: () => switchLanguage(AppLocalization.localeEn),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF7418) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
