import 'package:flutter_test/flutter_test.dart';
import 'package:siagakita_console/core/localization/app_localization.dart';

void main() {
  group('KYC Relawan Localization Tests', () {
    test(
      'Translates Indonesian keys to English properly when locale is EN',
      () {
        AppLocalization.currentLocale = AppLocalization.localeEn;

        expect(AppLocalization.translate('Antrian KYC'), equals('KYC Queue'));
        expect(
          AppLocalization.translate('Tidak ada antrian'),
          equals('No queue'),
        );
        expect(
          AppLocalization.translate(
            'Pilih relawan dari daftar untuk verifikasi',
          ),
          equals('Select a volunteer from the list to verify'),
        );
        expect(
          AppLocalization.translate('Konfirmasi Persetujuan'),
          equals('Approval Confirmation'),
        );
        expect(
          AppLocalization.translate('Buka Dokumen Eksternal'),
          equals('Open External Document'),
        );
        expect(
          AppLocalization.translate('Alasan penolakan wajib diisi'),
          equals('Rejection reason is required'),
        );
        expect(
          AppLocalization.translate('Pendaftaran berhasil disetujui'),
          equals('Registration successfully approved'),
        );
        expect(
          AppLocalization.translate('Pendaftaran relawan ditolak'),
          equals('Volunteer registration rejected'),
        );
      },
    );

    test('Retains original Indonesian strings when locale is ID', () {
      AppLocalization.currentLocale = AppLocalization.localeId;

      expect(AppLocalization.translate('Antrian KYC'), equals('Antrian KYC'));
      expect(
        AppLocalization.translate('Buka Dokumen Eksternal'),
        equals('Buka Dokumen Eksternal'),
      );
      expect(
        AppLocalization.translate('Konfirmasi Persetujuan'),
        equals('Konfirmasi Persetujuan'),
      );
    });
  });
}
