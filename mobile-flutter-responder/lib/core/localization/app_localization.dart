import 'package:flutter/material.dart';

/// AppLocalization manages bilingual localization (id and en) with 100% dictionary parity.
/// Adheres strictly to SiagaKita Localization Governance.
class AppLocalization {
  AppLocalization._();

  static const Locale localeId = Locale('id');
  static const Locale localeEn = Locale('en');

  static const Map<String, String> _idToEn = {
    // App & Auth
    'SiagaKita Responder': 'SiagaKita Responder',
    'Sistem Penugasan Darurat Lapangan': 'Field Emergency Dispatch System',
    'Masuk Petugas Lapangan': 'Field Responder Login',
    'Nomor Lencana atau Email': 'Badge Number or Email',
    'Kata Sandi': 'Password',
    'Masuk': 'Log In',
    'Nomor Lencana / Email dan Kata Sandi wajib diisi': 'Badge Number / Email and Password are required',
    'Role tidak diizinkan. Aplikasi ini khusus Petugas Instansi.': 'Role unauthorized. This application is restricted to Agency Personnel.',
    'Gagal masuk. Periksa kredensial Anda.': 'Login failed. Please verify your credentials.',
    'Terjadi kesalahan': 'An error occurred',

    // Mission Board & Shell
    'Papan Misi': 'Mission Board',
    'Misi Aktif': 'Active Missions',
    'Semua Insiden': 'All Incidents',
    'Petugas Lapangan': 'Field Officer',
    'Aktif': 'Active',
    'Menghubungkan ke Markas Komando...': 'Connecting to Command Center...',
    'Tidak ada misi darurat aktif saat ini.': 'No active emergency missions at this time.',
    'Tarik untuk memuat ulang': 'Pull to refresh',
    'Keluar': 'Log Out',
    'Konfirmasi Keluar': 'Confirm Logout',
    'Apakah Anda yakin ingin keluar dari akun petugas?': 'Are you sure you want to log out of your personnel account?',

    // Mission Detail & Evidence
    'Detail Misi': 'Mission Detail',
    'Lokasi Kejadian': 'Incident Location',
    'Peta Taktis': 'Tactical Map',
    'Arahkan Navigasi': 'Start Navigation',
    'Buka Navigasi': 'Open Navigation',
    'Informasi Pelapor': 'Reporter Information',
    'Nama': 'Name',
    'Telepon': 'Phone',
    'Golongan Darah': 'Blood Type',
    'Alergi': 'Allergies',
    'Label Kepercayaan': 'Trust Label',
    'Bukti Rekaman Suara': 'Voice Audio Evidence',

    // Status Lifecycle Transitions
    'Terima Tugas': 'Accept Mission',
    'Dalam Perjalanan': 'En Route',
    'Tiba di Lokasi': 'On Scene',
    'Selesai': 'Resolve Mission',
    'Status misi berhasil diperbarui': 'Mission status successfully updated',
    'Gagal memperbarui status misi': 'Failed to update mission status',
    'Konfirmasi Selesai': 'Confirm Completion',
    'Pastikan situasi di lapangan telah terkendali sebelum menyelesaikan misi.': 'Ensure the on-scene situation is resolved before closing the mission.',
    'Batal': 'Cancel',
    'Ya, Selesai': 'Yes, Resolve',

    // Tactical Navigation Map
    'Navigasi Lapangan': 'Field Navigation',
    'Menuju Lokasi Insiden': 'Heading to Incident',
    'Buka di Google Maps': 'Open in Google Maps',
    'Buka di Waze': 'Open in Waze',
  };

  static String translate(BuildContext context, String key) {
    final locale = Localizations.localeOf(context);
    return translateWithLocale(key, locale);
  }

  static String translateWithLocale(String key, Locale locale) {
    if (locale.languageCode == 'en') {
      return _idToEn[key] ?? key;
    }
    return key;
  }

  static bool hasKey(String key) {
    return _idToEn.containsKey(key);
  }

  static Map<String, String> get idToEnMap => Map.unmodifiable(_idToEn);
}

extension AppLocalizationExtension on String {
  String tr(BuildContext context) {
    return AppLocalization.translate(context, this);
  }
}
