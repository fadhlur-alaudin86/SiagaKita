import 'package:flutter_test/flutter_test.dart';
import 'package:siagakita/core/localization/app_localization.dart';

void main() {
  group('Audit batch localization keys', () {
    test('New keys resolve in Indonesian', () {
      AppLocalization.currentLocale = AppLocalization.localeId;

      expect(
        AppLocalization.translate('Tidak Diketahui'),
        equals('Tidak Diketahui'),
      );
      expect(AppLocalization.translate('Baru saja'), equals('Baru saja'));
      expect(
        AppLocalization.translate('Gagal membatalkan laporan: '),
        equals('Gagal membatalkan laporan: '),
      );
    });

    test('New keys translate to English', () {
      AppLocalization.currentLocale = AppLocalization.localeEn;

      expect(AppLocalization.translate('Tidak Diketahui'), equals('Unknown'));
      expect(AppLocalization.translate('Baru saja'), equals('Just now'));
      expect(AppLocalization.translate('menit lalu'), equals('minutes ago'));
      expect(
        AppLocalization.translate('Gagal membatalkan laporan: '),
        equals('Failed to cancel report: '),
      );
      expect(
        AppLocalization.translate('Gagal mengirim ulang: '),
        equals('Failed to resend: '),
      );
    });

    tearDown(() {
      AppLocalization.currentLocale = AppLocalization.localeId;
    });
  });
}
