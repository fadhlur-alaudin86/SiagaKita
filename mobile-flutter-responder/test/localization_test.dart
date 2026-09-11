import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siagakita_responder/core/localization/app_localization.dart';

void main() {
  group('AppLocalization Parity & Translation Tests', () {
    test('Dictionary parity has non-empty keys and values', () {
      final map = AppLocalization.idToEnMap;
      expect(map.isNotEmpty, isTrue);

      for (final entry in map.entries) {
        expect(entry.key.trim().isNotEmpty, isTrue, reason: 'Key cannot be blank');
        expect(entry.value.trim().isNotEmpty, isTrue, reason: 'Translation cannot be blank for ${entry.key}');
      }
    });

    test('Translates to English correctly', () {
      const localeEn = Locale('en');
      final translated = AppLocalization.translateWithLocale('Papan Misi', localeEn);
      expect(translated, equals('Mission Board'));

      final loginTitle = AppLocalization.translateWithLocale('Masuk Petugas Lapangan', localeEn);
      expect(loginTitle, equals('Field Responder Login'));
    });

    test('Returns Indonesian verbatim when locale is id', () {
      const localeId = Locale('id');
      final text = AppLocalization.translateWithLocale('Papan Misi', localeId);
      expect(text, equals('Papan Misi'));
    });

    test('All critical mission lifecycle statuses exist in dictionary', () {
      final criticalKeys = [
        'Terima Tugas',
        'Dalam Perjalanan',
        'Tiba di Lokasi',
        'Selesai',
        'Status misi berhasil diperbarui',
        'Gagal memperbarui status misi',
      ];

      for (final key in criticalKeys) {
        expect(AppLocalization.hasKey(key), isTrue, reason: 'Missing key: $key');
      }
    });
  });
}
