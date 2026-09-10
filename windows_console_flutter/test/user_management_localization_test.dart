import 'package:flutter_test/flutter_test.dart';
import 'package:siagakita_console/core/localization/app_localization.dart';

void main() {
  group('User Management Localization Tests', () {
    test(
      'Translates Indonesian keys to English properly when locale is EN',
      () {
        AppLocalization.currentLocale = AppLocalization.localeEn;

        expect(AppLocalization.translate('Masyarakat'), equals('Civilian'));
        expect(
          AppLocalization.translate('Status Akun'),
          equals('Account Status'),
        );
        expect(AppLocalization.translate('Koneksi'), equals('Connection'));
        expect(AppLocalization.translate('Aktif'), equals('Active'));
        expect(AppLocalization.translate('Banned'), equals('Banned'));
        expect(
          AppLocalization.translate('Latar Belakang'),
          equals('Background'),
        );
        expect(
          AppLocalization.translate('Semua Strike'),
          equals('All Strikes'),
        );
        expect(AppLocalization.translate('Urutkan'), equals('Sort By'));
        expect(
          AppLocalization.translate('Cari nama atau email...'),
          equals('Search name or email...'),
        );
        expect(AppLocalization.translate('Durasi Ban'), equals('Ban Duration'));
        expect(
          AppLocalization.translate('Konfirmasi Reset Strike'),
          equals('Confirm Reset Strike'),
        );
        expect(
          AppLocalization.translate('Reset Strike'),
          equals('Reset Strike'),
        );
        expect(
          AppLocalization.translate('Strike berhasil direset.'),
          equals('Strikes successfully reset.'),
        );
        expect(
          AppLocalization.translate('Alasan ban wajib diisi'),
          equals('Ban reason is required'),
        );
      },
    );

    test('Retains original Indonesian strings when locale is ID', () {
      AppLocalization.currentLocale = AppLocalization.localeId;

      expect(AppLocalization.translate('Masyarakat'), equals('Masyarakat'));
      expect(AppLocalization.translate('Status Akun'), equals('Status Akun'));
      expect(
        AppLocalization.translate('Konfirmasi Reset Strike'),
        equals('Konfirmasi Reset Strike'),
      );
      expect(AppLocalization.translate('Durasi Ban'), equals('Durasi Ban'));
    });
  });
}
