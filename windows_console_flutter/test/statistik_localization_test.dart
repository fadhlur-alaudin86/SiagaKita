import 'package:flutter_test/flutter_test.dart';
import 'package:siagakita_console/core/localization/app_localization.dart';
import 'package:siagakita_console/core/models/models.dart';

void main() {
  group('Statistik & Analytics Localization & Model Tests', () {
    test(
      'Translates Indonesian stats keys to English properly when locale is EN',
      () {
        AppLocalization.currentLocale = AppLocalization.localeEn;

        expect(AppLocalization.translate('1 Minggu'), equals('1 Week'));
        expect(AppLocalization.translate('1 Bulan'), equals('1 Month'));
        expect(AppLocalization.translate('1 Tahun'), equals('1 Year'));
        expect(
          AppLocalization.translate('Statistik Terakhir'),
          equals('Recent Statistics'),
        );
        expect(AppLocalization.translate('Tren SOS'), equals('SOS Trend'));
        expect(
          AppLocalization.translate('Distribusi Tipe Insiden'),
          equals('Incident Type Distribution'),
        );
        expect(AppLocalization.translate('TOTAL SOS'), equals('TOTAL SOS'));
        expect(AppLocalization.translate('SELESAI'), equals('RESOLVED'));
        expect(AppLocalization.translate('RATA-RATA'), equals('AVERAGE'));
        expect(AppLocalization.translate('ALARM PALSU'), equals('FALSE ALARM'));
        expect(AppLocalization.translate('RELAWAN'), equals('VOLUNTEERS'));
        expect(AppLocalization.translate('mnt'), equals('min'));
        expect(
          AppLocalization.translate('Belum ada data statistik'),
          equals('No statistical data yet'),
        );
        expect(
          AppLocalization.translate(
            'Gagal memuat statistik. Silakan coba lagi.',
          ),
          equals('Failed to load statistics. Please try again.'),
        );
        expect(AppLocalization.translate('Coba Lagi'), equals('Try Again'));

        // Incident type dictionary keys
        expect(AppLocalization.translate('Kebakaran'), equals('Fire'));
        expect(AppLocalization.translate('Medis'), equals('Medical'));
        expect(AppLocalization.translate('Kriminalitas'), equals('Crime'));
        expect(AppLocalization.translate('Bencana'), equals('Disaster'));
        expect(AppLocalization.translate('Kecelakaan'), equals('Accident'));
        expect(AppLocalization.translate('Umum'), equals('General'));
        expect(AppLocalization.translate('Tidak Diketahui'), equals('Unknown'));
      },
    );

    test('Retains original Indonesian strings when locale is ID', () {
      AppLocalization.currentLocale = AppLocalization.localeId;

      expect(AppLocalization.translate('1 Minggu'), equals('1 Minggu'));
      expect(AppLocalization.translate('1 Bulan'), equals('1 Bulan'));
      expect(
        AppLocalization.translate('Statistik Terakhir'),
        equals('Statistik Terakhir'),
      );
      expect(AppLocalization.translate('Kebakaran'), equals('Kebakaran'));
    });

    test(
      'StatsModel JSON deserialization parses all metrics and chart series',
      () {
        final json = {
          'total_sos': 42,
          'total_resolved': 38,
          'avg_response_minutes': 3.5,
          'false_alarm_rate': 4.2,
          'active_volunteers': 15,
          'by_type': {'fire': 10, 'medical': 20, 'crime': 8, 'accident': 4},
          'by_status': {'resolved': 38, 'cancelled': 4},
          'monthly': [
            {'month': '2026-04-01', 'count': 12},
            {'month': '2026-04-02', 'count': 18},
            {'month': '2026-04-03', 'count': 12},
          ],
        };

        final stats = StatsModel.fromJson(json);
        expect(stats.totalSOS, equals(42));
        expect(stats.totalResolved, equals(38));
        expect(stats.avgResponseMinutes, equals(3.5));
        expect(stats.falseAlarmRate, equals(4.2));
        expect(stats.activeVolunteers, equals(15));
        expect(stats.byType['fire'], equals(10));
        expect(stats.byType['medical'], equals(20));
        expect(stats.monthly.length, equals(3));
        expect(stats.monthly[1]['count'], equals(18));
      },
    );

    test(
      'StatsModel.empty() produces zeroed values and empty series safely',
      () {
        final empty = StatsModel.empty();
        expect(empty.totalSOS, equals(0));
        expect(empty.totalResolved, equals(0));
        expect(empty.avgResponseMinutes, equals(0.0));
        expect(empty.falseAlarmRate, equals(0.0));
        expect(empty.activeVolunteers, equals(0));
        expect(empty.byType, isEmpty);
        expect(empty.byStatus, isEmpty);
        expect(empty.monthly, isEmpty);
      },
    );
  });
}
