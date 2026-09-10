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

    // ─── KYC Relawan & Verifikasi ──────────────────────────────────────────────
    'Antrian KYC': 'KYC Queue',
    'Tidak ada antrian': 'No queue',
    'Pilih relawan dari daftar untuk verifikasi':
        'Select a volunteer from the list to verify',
    'Foto KTP:': 'ID Card Photo:',
    'Gagal memuat foto': 'Failed to load photo',
    'Tidak ada foto KTP': 'No ID card photo',
    'Sertifikat:': 'Certifications:',
    'Tidak ada sertifikat': 'No certificates',
    'Pengalaman & Spesialisasi:': 'Experience & Specialization:',
    'Tidak ada pengalaman yang ditulis': 'No experience provided',
    'Buka Dokumen Eksternal': 'Open External Document',
    'Gagal membuka tautan dokumen': 'Failed to open document link',
    'Konfirmasi Persetujuan': 'Approval Confirmation',
    'Apakah Anda yakin ingin menyetujui relawan ini?':
        'Are you sure you want to approve this volunteer?',
    'Jumlah Sertifikat': 'Certificate Count',
    'Alasan penolakan untuk': 'Rejection reason for',
    'Alasan penolakan wajib diisi': 'Rejection reason is required',
    'Pendaftaran berhasil disetujui': 'Registration successfully approved',
    'Pendaftaran relawan ditolak': 'Volunteer registration rejected',
    'Gagal menyetujui. Coba lagi.': 'Failed to approve. Please try again.',
    'Gagal menolak. Coba lagi.': 'Failed to reject. Please try again.',

    // ─── User Management ──────────────────────────────────────────────────────
    'Masyarakat': 'Civilian',
    'NAMA & STATUS': 'NAME & STATUS',
    'KONTAK': 'CONTACT',
    'STRIKE': 'STRIKE',
    'AKSI': 'ACTION',
    'Status Akun': 'Account Status',
    'Koneksi': 'Connection',
    'Aktif': 'Active',
    'Banned': 'Banned',
    'Latar Belakang': 'Background',
    'Semua Strike': 'All Strikes',
    'Urutkan': 'Sort By',
    'Nama': 'Name',
    'Naik': 'Ascending',
    'Turun': 'Descending',
    'Cari nama atau email...': 'Search name or email...',
    'Pengguna tidak bisa menggunakan SOS.': 'User cannot use SOS.',
    'Alasan ban': 'Ban reason',
    'Durasi Ban': 'Ban Duration',
    '1 Hari': '1 Day',
    '3 Hari': '3 Days',
    '7 Hari': '7 Days',
    '30 Hari': '30 Days',
    'Permanen (365 Hari)': 'Permanent (365 Days)',
    'Pengguna dapat menggunakan SOS kembali.': 'User can use SOS again.',
    'Konfirmasi Reset Strike': 'Confirm Reset Strike',
    'Apakah Anda yakin ingin mereset strike untuk':
        'Are you sure you want to reset strikes for',
    'Tindakan ini akan mengembalikan strike ke 0/3.':
        'This action will reset strikes to 0/3.',
    'Reset Strike': 'Reset Strike',
    'Strike berhasil direset.': 'Strikes successfully reset.',
    'Gagal mereset strike.': 'Failed to reset strikes.',
    'Gagal melakukan ban.': 'Failed to ban user.',
    'Gagal mencabut ban.': 'Failed to unban user.',
    'Alasan ban wajib diisi': 'Ban reason is required',
    'telah dibanned.': 'has been banned.',
    'di-unban.': 'has been unbanned.',
    'Reset': 'Reset',
    'Strike': 'Strike',

    // ─── Gamifikasi: Ranks ───────────────────────────────────────────────────
    'Rank (XP Otomatis)': 'Ranks (Automatic XP)',
    'Badges (Pemberian Manual)': 'Badges (Manual Award)',
    'Relawan akan naik rank secara otomatis saat XP mereka mencapai batas minimum.':
        'Volunteers will rank up automatically when their XP reaches the minimum threshold.',
    'Tambah Rank': 'Add Rank',
    'Tambah Rank Baru': 'Add New Rank',
    'Edit Rank': 'Edit Rank',
    'Nama Rank': 'Rank Name',
    'Minimum XP': 'Minimum XP',
    'Icon URL / Emoji': 'Icon URL / Emoji',
    'Hapus Rank?': 'Delete Rank?',
    'Tindakan ini tidak bisa dibatalkan.': 'This action cannot be undone.',
    'Rank dasar (min_exp = 0) tidak dapat dihapus.':
        'Base rank (min_exp = 0) cannot be deleted.',
    'Rank dasar memiliki batas minimum 0 XP dan tidak dapat diubah.':
        'Base rank has a minimum threshold of 0 XP and cannot be changed.',
    'Relawan yang berada di rank ini akan otomatis di-downgrade ke rank di bawahnya.':
        'Volunteers at this rank will be automatically downgraded to the tier below.',
    'Belum ada data rank. Silakan tambah rank baru.':
        'No rank data available yet. Please add a new rank.',
    'Rank berhasil ditambahkan': 'Rank successfully added',
    'Rank berhasil diupdate': 'Rank successfully updated',
    'Rank dihapus.': 'Rank deleted.',
    'Nama rank wajib diisi': 'Rank name is required',
    'Minimum XP harus berupa angka': 'Minimum XP must be a valid number',
    'Minimum XP untuk rank baru harus lebih besar dari 0':
        'Minimum XP for new ranks must be greater than 0',
    'Tambah': 'Add',
    'Edit': 'Edit',
    'Hapus rank': 'Delete rank',
    'Gagal menambah rank': 'Failed to add rank',
    'Gagal memperbarui rank': 'Failed to update rank',
    'Gagal menghapus rank': 'Failed to delete rank',

    // ─── Statistik & Analytics ───────────────────────────────────────────────
    '1 Minggu': '1 Week',
    '1 Bulan': '1 Month',
    '1 Tahun': '1 Year',
    'Statistik Terakhir': 'Recent Statistics',
    'Tren SOS': 'SOS Trend',
    'Distribusi Tipe Insiden': 'Incident Type Distribution',
    'TOTAL SOS': 'TOTAL SOS',
    'SELESAI': 'RESOLVED',
    'RATA-RATA': 'AVERAGE',
    'ALARM PALSU': 'FALSE ALARM',
    'RELAWAN': 'VOLUNTEERS',
    'Gagal memuat statistik. Silakan coba lagi.':
        'Failed to load statistics. Please try again.',

    // ─── Dispatch Relawan ────────────────────────────────────────────────────
    'Dispatch Relawan': 'Volunteer Dispatch',
    'Antrean SOS Aktif': 'Active SOS Queue',
    'Pilih insiden SOS di sebelah kiri untuk melihat radar relawan dan melakukan penugasan.':
        'Select an SOS incident on the left to view volunteer radar and dispatch responders.',
    'Belum ada insiden SOS aktif': 'No active SOS incidents',
    'Kandidat Relawan Terdekat': 'Nearest Volunteer Candidates',
    'Tidak ada relawan online dalam radius':
        'No online volunteers within radius',
    'Broadcast ke 3 Terdekat': 'Broadcast to Top 3 Nearest',
    'Kirim Penugasan': 'Send Dispatch',
    'km dari lokasi': 'km from location',
    'ON DUTY': 'ON DUTY',
    'Tugaskan': 'Dispatch',
    'Misi Sedang Berjalan': 'Active Mission Tracking',
    'Diterima': 'Accepted',
    'Menuju Lokasi': 'En Route',
    'Tiba di Lokasi': 'On Scene',
    'Penugasan berhasil dikirim': 'Dispatch successfully sent',
    'Gagal mengirim penugasan': 'Failed to send dispatch',
    'Waktu penugasan habis (Timeout)': 'Dispatch offer timed out',
    'Belum ada relawan yang menerima panggilan dalam 60 detik.':
        'No volunteer has accepted the call within 60 seconds.',
    'Relawan Penanggung Jawab': 'Responding Volunteer',
    'Broadcast Ulang': 'Re-broadcast',
    'Tangani oleh Petugas Instansi': 'Handle by Agency Personnel',
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
