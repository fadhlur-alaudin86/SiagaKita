import 'package:flutter_test/flutter_test.dart';
import 'package:siagakita_console/core/localization/app_localization.dart';

void main() {
  group('Audit batch localization keys', () {
    test('New keys resolve in Indonesian', () {
      AppLocalization.currentLocale = AppLocalization.localeId;

      expect(AppLocalization.translate('Kepolisian'), equals('Kepolisian'));
      expect(AppLocalization.translate('Fokus Lokasi'), equals('Fokus Lokasi'));
    });

    test('New keys translate to English', () {
      AppLocalization.currentLocale = AppLocalization.localeEn;

      expect(AppLocalization.translate('Kepolisian'), equals('Police'));
      expect(AppLocalization.translate('Tim SAR'), equals('SAR Team'));
      expect(
        AppLocalization.translate('Pemadam Kebakaran'),
        equals('Fire Department'),
      );
      expect(
        AppLocalization.translate('Medis / Rumah Sakit'),
        equals('Medical / Hospital'),
      );
      expect(
        AppLocalization.translate('Rekaman Audio'),
        equals('Audio Recording'),
      );
      expect(
        AppLocalization.translate('Fokus Lokasi'),
        equals('Focus Location'),
      );
      expect(
        AppLocalization.translate('Tolak Verifikasi NIK?'),
        equals('Reject NIK Verification?'),
      );
      expect(
        AppLocalization.translate('Setujui Verifikasi NIK?'),
        equals('Approve NIK Verification?'),
      );
    });

    tearDown(() {
      AppLocalization.currentLocale = AppLocalization.localeId;
    });
  });
}
