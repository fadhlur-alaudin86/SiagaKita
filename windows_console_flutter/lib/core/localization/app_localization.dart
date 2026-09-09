import 'package:flutter/material.dart';

class AppLocalization {
  AppLocalization._();

  static const Locale localeId = Locale('id');
  static const Locale localeEn = Locale('en');

  static Locale currentLocale = localeId;
  static String get currentLocaleCode => currentLocale.languageCode;

  static const Map<String, String> _idToEn = {
    // ─── App & Splash ───────────────────────────────────────────────────────────
    'SiagaKita Console': 'SiagaKita Console',
    'Memuat...': 'Loading...',
    'Masuk ke Console': 'Log in to Console',
    'Khusus operator instansi & admin sistem':
        'Exclusively for agency operators & system admins',
    'Koneksi gagal. Pastikan server berjalan.':
        'Connection failed. Make sure the server is running.',
    'Email': 'Email',
    'Kata Sandi': 'Password',
    'Password': 'Password',
    'Login': 'Log In',
    'Masuk': 'Log In',
    'Keluar': 'Log Out',
    'Batal': 'Cancel',
    'Sesi Anda telah berakhir karena login di perangkat lain.':
        'Your session has ended because you logged in on another device.',

    // ─── Admin Navigation & Headers ─────────────────────────────────────────────
    'KYC Relawan': 'Volunteer KYC',
    'Manajemen Akun': 'Account Management',
    'Pendaftaran Akun': 'Account Registration',
    'Master Data Gamifikasi': 'Gamification Master Data',
    'Statistik & Analitik': 'Statistics & Analytics',
    'MANAJEMEN': 'MANAGEMENT',
    'SISTEM': 'SYSTEM',
    'Sistem Online': 'System Online',
    'KYC & Verifikasi Relawan': 'Volunteer KYC & Verification',
    'Pendaftaran Akun Khusus': 'Special Account Registration',
    'Gamifikasi': 'Gamification',
    'Administrator': 'Administrator',
    'Super Administrator': 'Super Administrator',

    // ─── Instansi Navigation & Headers ──────────────────────────────────────────
    'Dashboard Operasi': 'Operations Dashboard',
    'SOS Aktif': 'Active SOS',
    'Laporan Masuk': 'Incoming Reports',
    'Laporan Aktif': 'Active Reports',
    'Peta Operasional': 'Operational Map',
    'Riwayat': 'History',
    'SIAGAKITA INSTANSI': 'SIAGAKITA AGENCY',
    'Instansi Console': 'Agency Console',
    'WS Connected': 'WS Connected',
    'Realtime Connected': 'Realtime Connected',
    'Offline': 'Offline',
    'Profil Saya': 'My Profile',
    'Pengaturan': 'Settings',
    'Tutup': 'Close',
    'Simpan': 'Save',
    'Hapus': 'Delete',
    'Pilih': 'Select',
    'Filter': 'Filter',
    'Semua': 'All',
    'Status': 'Status',
    'Aksi': 'Action',
    'Detail': 'Details',
    'Terima': 'Accept',
    'Tolak': 'Reject',
    'Selesai': 'Completed',
    'Menunggu': 'Pending',
    'Dibatalkan': 'Canceled',
    'Lokasi': 'Location',
    'Waktu': 'Time',
    'Kategori': 'Category',
    'Pelapor': 'Reporter',
    'Relawan': 'Volunteer',
    'Instansi': 'Agency',
    'Tidak ada data': 'No data available',
    'Gagal memuat data': 'Failed to load data',
    'Coba Lagi': 'Try Again',
    'Konfirmasi': 'Confirmation',
    'Alasan': 'Reason',
    'SOS AKTIF': 'ACTIVE SOS',
    'TOTAL DISELESAIKAN': 'TOTAL RESOLVED',
    'RATA-RATA RESPONS': 'AVG RESPONSE TIME',
    'TINGKAT ALARM PALSU': 'FALSE ALARM RATE',
    'SOS Terbaru': 'Recent SOS',
    'Hentikan Alarm': 'Silence Alarm',
    'Sistem Terpantau Aman': 'System All Clear',
    'Distribusi Tipe SOS': 'SOS Type Distribution',
    'Belum ada data statistik': 'No statistical data yet',
    'Dilaporkan': 'Reported',
    'mnt': 'min',
    'Kebakaran': 'Fire',
    'Medis': 'Medical',
    'Kriminalitas': 'Crime',
    'Bencana': 'Disaster',
    'Kecelakaan': 'Accident',
    'Umum': 'General',
    'Tidak Diketahui': 'Unknown',

    // ─── Operations & Actions ──────────────────────────────────────────────────
    'SEMUA': 'ALL',
    'MASUK': 'INCOMING',
    'DITANGANI': 'HANDLED',
    'TOLAK': 'REJECT',
    'APPROVE RELAWAN': 'APPROVE VOLUNTEER',
    'TANGANI': 'HANDLE',
    'SELESAIKAN': 'COMPLETE',
    'Alarm Palsu': 'False Alarm',
    'Konfirmasi Alarm Palsu': 'Confirm False Alarm',
    'Pengguna akan mendapat 1 strike. Setelah 3 strike, akun SOS akan diblokir.':
        'User will receive 1 strike. After 3 strikes, the SOS account will be blocked.',
    'Alasan menandai alarm palsu (wajib)':
        'Reason for marking false alarm (required)',
    'Contoh: Foto KTP tidak jelas': 'Example: ID photo is unclear',
    'Status ditangani': 'Status set to in progress',
    'Tolak Pendaftaran': 'Reject Registration',
    'Rendah': 'Low',
    'Sedang': 'Medium',
    'Tinggi': 'High',
    'Deskripsi': 'Description',
    'Koordinat': 'Coordinates',
    'Belum ada riwayat': 'No history available',
    'KTP': 'ID Card',
    'Nama Lengkap': 'Full Name',
    'NIK': 'National ID (NIK)',
    'Alamat': 'Address',
    'Kontak Darurat': 'Emergency Contact',
    'Dokumen Identitas': 'Identity Documents',
    'Setujui': 'Approve',
  };

  static String _translateInternal(String languageCode, String text) {
    if (languageCode == localeEn.languageCode) {
      if (_idToEn.containsKey(text)) {
        return _idToEn[text]!;
      }
      final menuRegExp = RegExp(r'^Menu (.*) segera hadir$');
      if (menuRegExp.hasMatch(text)) {
        final match = menuRegExp.firstMatch(text);
        return 'Menu ${match?.group(1)} coming soon';
      }
      return _idToEn[text] ?? text;
    }
    return text;
  }

  static String tr(BuildContext context, String text) {
    final languageCode = Localizations.localeOf(context).languageCode;
    return _translateInternal(languageCode, text);
  }

  static String translate(String text) {
    return _translateInternal(currentLocale.languageCode, text);
  }
}

extension LocalizedString on String {
  String tr(BuildContext context) => AppLocalization.tr(context, this);
}
