import 'package:flutter_test/flutter_test.dart';
import 'package:siagakita_console/core/localization/app_localization.dart';
import 'package:siagakita_console/core/models/models.dart';

void main() {
  group('Gamifikasi Ranks Localization & Invariant Tests', () {
    test(
      'Translates Indonesian rank keys to English properly when locale is EN',
      () {
        AppLocalization.currentLocale = AppLocalization.localeEn;

        expect(
          AppLocalization.translate('Rank (XP Otomatis)'),
          equals('Ranks (Automatic XP)'),
        );
        expect(AppLocalization.translate('Tambah Rank'), equals('Add Rank'));
        expect(
          AppLocalization.translate('Tambah Rank Baru'),
          equals('Add New Rank'),
        );
        expect(AppLocalization.translate('Edit Rank'), equals('Edit Rank'));
        expect(AppLocalization.translate('Nama Rank'), equals('Rank Name'));
        expect(AppLocalization.translate('Minimum XP'), equals('Minimum XP'));
        expect(
          AppLocalization.translate('Hapus Rank?'),
          equals('Delete Rank?'),
        );
        expect(
          AppLocalization.translate(
            'Rank dasar (min_exp = 0) tidak dapat dihapus.',
          ),
          equals('Base rank (min_exp = 0) cannot be deleted.'),
        );
        expect(
          AppLocalization.translate(
            'Rank dasar memiliki batas minimum 0 XP dan tidak dapat diubah.',
          ),
          equals(
            'Base rank has a minimum threshold of 0 XP and cannot be changed.',
          ),
        );
        expect(
          AppLocalization.translate(
            'Relawan yang berada di rank ini akan otomatis di-downgrade ke rank di bawahnya.',
          ),
          equals(
            'Volunteers at this rank will be automatically downgraded to the tier below.',
          ),
        );
        expect(
          AppLocalization.translate('Rank berhasil ditambahkan'),
          equals('Rank successfully added'),
        );
        expect(
          AppLocalization.translate('Rank berhasil diupdate'),
          equals('Rank successfully updated'),
        );
        expect(
          AppLocalization.translate('Rank dihapus.'),
          equals('Rank deleted.'),
        );
        expect(
          AppLocalization.translate('Nama rank wajib diisi'),
          equals('Rank name is required'),
        );
        expect(
          AppLocalization.translate(
            'Minimum XP untuk rank baru harus lebih besar dari 0',
          ),
          equals('Minimum XP for new ranks must be greater than 0'),
        );
      },
    );

    test('Retains original Indonesian strings when locale is ID', () {
      AppLocalization.currentLocale = AppLocalization.localeId;

      expect(
        AppLocalization.translate(
          'Rank dasar (min_exp = 0) tidak dapat dihapus.',
        ),
        equals('Rank dasar (min_exp = 0) tidak dapat dihapus.'),
      );
      expect(AppLocalization.translate('Tambah Rank'), equals('Tambah Rank'));
    });

    test('RankModel JSON serialization and base rank invariant detection', () {
      final baseRank = RankModel.fromJson({
        'id': 'r-base',
        'rank_name': 'Relawan Pemula',
        'min_exp': 0,
        'icon_url': '🌱',
      });
      expect(baseRank.minExp, equals(0));
      expect(
        baseRank.minExp == 0,
        isTrue,
      ); // Invariant: Base rank cannot be deleted

      final advancedRank = RankModel.fromJson({
        'id': 'r-adv',
        'rank_name': 'Relawan Ahli',
        'min_exp': 1500,
        'icon_url': '🏅',
      });
      expect(advancedRank.minExp, equals(1500));
      expect(advancedRank.minExp == 0, isFalse);
    });
  });
}
