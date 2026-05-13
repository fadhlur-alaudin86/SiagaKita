import 'package:flutter/material.dart';

class AppLocalization {
  AppLocalization._();

  static const Locale localeId = Locale('id');
  static const Locale localeEn = Locale('en');

  static const Map<String, String> _idToEn = {
    'Pengaturan': 'Settings',
    'Bahasa Indonesia': 'Indonesian',
    'Pilih Bahasa': 'Choose Language',
    'NOTIFIKASI & LANSIRAN': 'NOTIFICATIONS & ALERTS',
    'Notifikasi Push (Aplikasi)': 'Push Notifications (App)',
    'Peringatan darurat via aplikasi': 'Emergency alerts via app',
    'Lansiran SMS': 'SMS Alerts',
    'Kirim pesan SMS jika tidak ada koneksi internet':
        'Send SMS when internet is unavailable',
    'PRIVASI & LOKASI': 'PRIVACY & LOCATION',
    'Akses Lokasi Latar Belakang': 'Background Location Access',
    'Sangat disarankan untuk evakuasi cepat':
        'Highly recommended for faster evacuation',
    'Izin Akses Kamera & Galeri': 'Camera & Gallery Permissions',
    'Izin kamera & galeri sudah diberikan.':
        'Camera & gallery permissions already granted.',
    'Izin Diperlukan': 'Permission Required',
    'Izin kamera atau galeri ditolak. Buka pengaturan perangkat untuk mengaktifkannya secara manual.':
        'Camera or gallery permission denied. Open device settings to enable it manually.',
    'Buka Pengaturan': 'Open Settings',
    'Mengerti': 'Understood',
    'TAMPILAN & AKSESIBILITAS': 'DISPLAY & ACCESSIBILITY',
    'Mode Gelap (Dark Mode)': 'Dark Mode',
    'Tema dikendalikan oleh sistem saat ini.':
        'Theme is currently controlled by system settings.',
    'Bahasa': 'Language',
    'AKUN & KEAMANAN': 'ACCOUNT & SECURITY',
    'Ubah Kata Sandi': 'Change Password',
    'Autentikasi Dua Langkah (2FA)': 'Two-Factor Authentication (2FA)',
    'Nonaktif': 'Disabled',
    'Hapus Akun': 'Delete Account',
    'Hapus Akun?': 'Delete Account?',
    'Tindakan ini tidak dapat dibatalkan. Seluruh riwayat donasi darah, poin relawan, dan rekam medis darurat akan dihapus permanen.':
        'This action cannot be undone. All blood donation history, volunteer points, and emergency medical records will be permanently deleted.',
    'Batal': 'Cancel',
    'Hapus Permanen': 'Delete Permanently',
    'Selamat Datang': 'Welcome',
    'Masuk untuk mengakses sistem pelaporan darurat dan jejaring relawan.':
        'Sign in to access emergency reporting and the volunteer network.',
    'Email Anda': 'Your Email',
    'Kata Sandi': 'Password',
    'Masyarakat Umum': 'General Public',
    'Relawan (Terverifikasi)': 'Volunteer (Verified)',
    'Instansi Penyelamat': 'Rescue Agency',
    'Admin Sistem': 'System Admin',
    // Role labels (short form used in header)
    'Masyarakat': 'Public',
    'Agency': 'Agency',
    'Admin': 'Admin',
    'Superadmin': 'Superadmin',
    'Lupa sandi?': 'Forgot password?',
    'Masuk': 'Sign In',
    'Belum punya akun?': 'Don\'t have an account?',
    'Daftar di sini': 'Sign up here',
    'Login sebagai': 'Login as',
    'Dasbor sedang dalam pengembangan':
        'Dashboard is currently under development',
    'Beranda': 'Home',
    'Panduan': 'Guide',
    'Operasi': 'Operations',
    'Map': 'Map',
    'Profil': 'Profile',
    'Tekan dan tahan untuk bantuan': 'Press and hold for help',
    'TAHAN 10 DETIK': 'HOLD 10 SECONDS',
    'Ketuk 5× untuk mengirim SOS': 'Tap 5× to send SOS',
    'KETUK 5×': 'TAP 5×',
    'Laporkan': 'Report',
    'Kirim bukti & titik\nlokasi': 'Send proof & location\npoint',
    'Edukasi': 'Education',
    'Panduan\npenyelamatan': 'Rescue\nguide',
    'SINYAL SOS TERKIRIM!': 'SOS SIGNAL SENT!',
    'Bantuan sedang diarahkan ke lokasi Anda.':
        'Help is being directed to your location.',
    'Buat Akun Baru': 'Create New Account',
    'Mari bergabung ke dalam jejaring keselamatan kami.':
        'Join our safety network.',
    'Lanjut Isi Biodata': 'Continue to Biodata',
    'Lanjut': 'Continue',
    'Sudah punya akun?': 'Already have an account?',
    'Masuk sekarang': 'Sign in now',
    'Verifikasi Nomor': 'Verify Number',
    'nomor telepon Anda': 'your phone number',
    'Kode OTP': 'OTP Code',
    'Kirim ulang kode OTP': 'Resend OTP code',
    'Foto KTP': 'ID Card Photo',
    'Mohon berikan foto KTP asli Anda untuk keperluan verifikasi keamanan.':
        'Please provide your original ID card photo for security verification.',
    'Ketuk untuk mengambil foto KTP': 'Tap to capture ID card photo',
    'Foto Wajah': 'Face Photo',
    'Ambil foto wajah (selfie) untuk pencocokan biometrik.':
        'Take a selfie for biometric matching.',
    'Ketuk untuk\nSelfie': 'Tap for\nSelfie',
    'Lengkapi Biodata': 'Complete Biodata',
    'Langkah Terakhir!': 'Final Step!',
    'Data kesehatan ini sangat penting untuk penanganan medis darurat yang tepat sasaran.':
        'This health data is essential for accurate emergency medical handling.',
    'Fisik & Kesehatan': 'Physical & Health',
    'Data ini mempermudah tim penolong mengetahui karakteristik fisik Anda.':
        'This helps responders understand your physical characteristics.',
    'Tanggal Lahir (DD-MM-YYYY)': 'Date of Birth (DD-MM-YYYY)',
    'Gol. Darah': 'Blood Type',
    'Berat Badan (kg)': 'Weight (kg)',
    'Tinggi Badan (cm)': 'Height (cm)',
    'Riwayat Penyakit & Alergi': 'Medical History & Allergies',
    'Kosongkan jika tidak ada. Data ini krusial untuk menghindari pantangan obat darurat.':
        'Leave blank if none. This is crucial to avoid emergency medication contraindications.',
    'Riwayat Medis (Misal: Asma, Hipertensi)':
        'Medical History (e.g. Asthma, Hypertension)',
    'Alergi Utama (Misal: Kacang, Penisilin)':
        'Main Allergies (e.g. Peanut, Penicillin)',
    'Alamat Tempat Tinggal': 'Home Address',
    'Sebagai acuan domisili terdekat jika evakuasi diperlukan.':
        'Used as nearest domicile reference if evacuation is needed.',
    'Alamat lengkap sesuai domisili...': 'Full address based on domicile...',
    'Kontak Darurat (Wali/Keluarga)': 'Emergency Contact (Guardian/Family)',
    'Orang yang akan dihubungi jika Anda dalam bahaya.':
        'Person to contact if you are in danger.',
    'Nama Kontak Darurat': 'Emergency Contact Name',
    'Nomor Telepon Darurat': 'Emergency Contact Phone',
    'Simpan & Selesai': 'Save & Finish',
    'Tahun': 'Years',
    'Relawan Terverifikasi': 'Verified Volunteer',
    'Menunggu Verifikasi': 'Pending Verification',
    'Bukan Relawan': 'Not a Volunteer',
    'Profil Pengguna': 'User Profile',
    'Edit Profil': 'Edit Profile',
    'INFORMASI PRIBADI': 'PERSONAL INFORMATION',
    'Nomor Telepon': 'Phone Number',
    'Tanggal Lahir / Umur': 'Date of Birth / Age',
    'Domisili Terkini': 'Current Domicile',
    'Bio / Deskripsi Profil': 'Bio / Profile Description',
    'Belum ada biodata': 'No biodata yet',
    'MEDIS & KEAMANAN': 'MEDICAL & SAFETY',
    'Golongan Darah': 'Blood Type',
    'Berat & Tinggi': 'Weight & Height',
    'Alergi Utama': 'Main Allergy',
    'Riwayat Penyakit': 'Medical History',
    'KONTAK DARURAT': 'EMERGENCY CONTACTS',
    'Tidak ada kontak terdaftar': 'No registered contacts',
    'Memanggil': 'Calling',
    'PENGATURAN & BANTUAN': 'SETTINGS & HELP',
    'Tentang Aplikasi': 'About App',
    'DAFTAR MENJADI RELAWAN': 'REGISTER AS VOLUNTEER',
    'Keluar Aplikasi': 'Exit App',
    'Edit Profil Utama': 'Edit Main Profile',
    'Nomor telepon pengguna minimal 10 digit':
        'User phone number must be at least 10 digits',
    'Form kontak baris ke': 'Contact form row',
    'belum lengkap!': 'is incomplete!',
    'Nomor pada kontak ke': 'Phone number on contact',
    'minimal 10 digit!': 'must be at least 10 digits!',
    'Profil berhasil diperbarui.': 'Profile updated successfully.',
    'Nomor Telepon Utama': 'Primary Phone Number',
    'Domisili Lengkap': 'Full Domicile Address',
    'Bio Singkat': 'Short Bio',
    'DATA MEDIS & KEAMANAN': 'MEDICAL & SAFETY DATA',
    'Belum Tahu': 'Unknown',
    'Berat (kg)': 'Weight (kg)',
    'Tinggi (cm)': 'Height (cm)',
    'Riwayat Penyakit (Opsional)': 'Medical History (Optional)',
    'Tambah': 'Add',
    'Belum ada kontak darurat.': 'No emergency contacts yet.',
    'Kontak Darurat': 'Emergency Contact',
    'Nama Lengkap': 'Full Name',
    'Hubungan': 'Relationship',
    'No Hp': 'Phone',
    'Simpan Perubahan': 'Save Changes',
    'Panduan Darurat': 'Emergency Guide',
    'Database Lokal Aktif (Offline/Online)':
        'Local Database Active (Offline/Online)',
    'Cari tindakan (mis: Luka Bakar)...':
        'Search actions (e.g. Burn injury)...',
    'Versi 1.0.0 (Build 20)': 'Version 1.0.0 (Build 20)',
    'SiagaKita adalah platform penanggulangan darurat terpadu yang menghubungkan masyarakat dengan relawan medis dan instansi penyelamat dalam satu ekosistem waktu nyata (real-time).':
        'SiagaKita is an integrated emergency response platform connecting communities with medical volunteers and rescue agencies in one real-time ecosystem.',
    'Syarat & Ketentuan': 'Terms & Conditions',
    'Kebijakan Privasi': 'Privacy Policy',
    'Lisensi Perangkat Lunak': 'Software Licenses',
    '© 2026 Tim SiagaKita\nDibuat dengan ❤️ untuk Kemanusiaan':
        '© 2026 SiagaKita Team\nBuilt with ❤️ for Humanity',
    'Buat Laporan': 'Create Report',
    'Lokasi Otomatis Ditemukan': 'Automatic Location Found',
    'Kategori Darurat': 'Emergency Category',
    'Lampiran Foto & Audio': 'Photo & Audio Attachments',
    'Ketuk ambil foto': 'Tap to take photo',
    'Tahan rekaman suara': 'Hold to record voice',
    'Ketik deksripsi tambahan jika ada...':
        'Type additional description if any...',
    'Tingkat Urgensi': 'Urgency Level',
    'Ringan': 'Low',
    'Sedang': 'Medium',
    'Kritis': 'Critical',
    'Laporan Berhasil Dikirim!': 'Report sent successfully!',
    'Kirim Laporan': 'Send Report',
    'Kebakaran': 'Fire',
    'Kecelakaan': 'Accident',
    'Bencana Alam': 'Natural Disaster',
    'Kriminalitas': 'Crime',
    'Medis': 'Medical',
    'Bencana': 'Disaster',
    'BENCANA ALAM': 'NATURAL DISASTER',
    'JEJARING KESELAMATAN LOKAL': 'LOCAL SAFETY NETWORK',
    'RADAR SIAGA & EVAKUASI': 'ALERT & EVACUATION RADAR',
    'Radius 5KM': '5KM Radius',
    'AKTIF': 'ACTIVE',
    'Relawan': 'Volunteer',
    'Titik Kumpul': 'Assembly Point',
    'Klinik': 'Clinic',
    'SOS AKTIF — Lokasi diperbarui tiap 10 detik':
        'SOS ACTIVE — Location updated every 10 seconds',
    'SOS AKTIF — Ketuk 5× untuk batalkan': 'SOS ACTIVE — Tap 5× to cancel',
    'KETUK 5× BATALKAN': 'TAP 5× CANCEL',
    'Riwayat Laporan': 'Report History',
    'LOKASI ANDA': 'YOUR LOCATION',
    'RELAWAN SIAGA': 'ON-STANDBY VOLUNTEERS',
    '12 di sekitar': '12 nearby',
    'STATUS TRANSMISI (SIMULASI SOS)': 'TRANSMISSION STATUS (SOS SIMULATION)',
    'Koordinat GPS Terkunci (Akurasi 3m)':
        'GPS Coordinates Locked (3m accuracy)',
    'Menyiarkan ke relawan radius 5KM...':
        'Broadcasting to volunteers within 5KM...',
    'Menunggu respons Command Center 112':
        'Waiting for Command Center 112 response',
    'Menu': 'Menu',
    'Segera Hadir': 'Coming Soon',
    'Keluar': 'Logout',
    'Komando Operasi': 'Operations Command',
    'ON DUTY (Siap Tugas)': 'ON DUTY (Ready)',
    'OFF DUTY (Istirahat)': 'OFF DUTY (Rest)',
    'Poin Misi': 'Mission Points',
    'RADAR INSIDEN': 'INCIDENT RADAR',
    'PANGGILAN DARURAT!': 'EMERGENCY CALL!',
    'Kecelakaan lalu lintas ganda, butuh evakuasi medis segera.':
        'Multiple traffic accident, immediate medical evacuation needed.',
    '1.2 KM (Simpang Lima)': '1.2 KM (Simpang Lima)',
    'Barusan': 'Just now',
    'Mengalihkan ke Navigasi Misi...': 'Redirecting to mission navigation...',
    'TERIMA MISI INI': 'ACCEPT THIS MISSION',
    'Radar Misi Nonaktif': 'Mission Radar Inactive',
    'Hidupkan ON DUTY untuk melihat panggilan darurat di sekitar Anda.':
        'Enable ON DUTY to view nearby emergency calls.',
    'KOORDINASI & ALAT': 'COORDINATION & TOOLS',
    'Live Chat Posko': 'Command Post Live Chat',
    'Panduan Medis': 'Medical Guide',
    'Relawan Aktif': 'Active Volunteers',
    'Riwayat Misi': 'Mission History',
    'Anda wajib mengunggah KTP dan Sertifikat Keahlian (atau simulasikan dengan menekan kotak upload)':
        'You must upload ID card and skill certificate (or simulate by tapping the upload box)',
    'Harap centang persetujuan syarat dan ketentuan.':
        'Please check the terms and conditions agreement.',
    'Pengajuan Diterima. Status Anda kini Pending Review.':
        'Submission accepted. Your status is now Pending Review.',
    'Tersimpan': 'Saved',
    'Unggah': 'Upload',
    '(Tekan untuk simulasi unggah file)': '(Tap to simulate file upload)',
    'PENDAFTARAN RELAWAN': 'VOLUNTEER REGISTRATION',
    'Misi Penyelamatan First Responder': 'First Responder Rescue Mission',
    'SiagaKita memanggil Anda yang memiliki kapabilitas medis / evakuasi gawat darurat. Pengajuan akan ditinjau oleh Admin daerah.':
        'SiagaKita is calling those with emergency medical/evacuation capability. Submission will be reviewed by regional Admin.',
    'PILIHAN SPESIALISASI': 'SPECIALIZATION OPTIONS',
    'Keahlian Relawan': 'Volunteer Expertise',
    'Wajib memilih spesialisasi': 'Specialization is required',
    'PENGALAMAN MEDIS / ORGANISASI': 'MEDICAL / ORGANIZATIONAL EXPERIENCE',
    'Contoh: Mantan petugas medis PMI, Relawan Damkar...':
        'Example: Former PMI medic, Fire dept volunteer...',
    'Harap uraikan pengalaman Anda': 'Please describe your experience',
    'VERIFIKASI DOKUMEN': 'DOCUMENT VERIFICATION',
    'Sertifikat Keahlian': 'Skill Certificate',
    'Saya menyatakan bahwa dokumen yang dilampirkan adalah benar, dan saya bersedia dipanggil dalam situasi darurat di area jangkauan saya sesuai standar operasional yang berlaku.':
        'I declare that attached documents are valid, and I agree to be called in emergencies within my coverage area according to applicable SOPs.',
    'SUBMIT PENGAJUAN': 'SUBMIT APPLICATION',
    'Halaman ini sedang dalam pengembangan':
        'This page is currently under development',
    'Statistik': 'Statistics',
    'Statistik Sistem': 'System Statistics',
    'Pantau data dan tren kejadian seluruh wilayah.':
        'Monitor incident data and trends across all regions.',
    'Kelola Pengguna': 'Manage Users',
    'Verifikasi, aktifkan, atau nonaktifkan akun pengguna.':
        'Verify, activate, or deactivate user accounts.',
    'Kelola Laporan': 'Manage Reports',
    'Tinjau dan moderasi semua laporan masuk.':
        'Review and moderate all incoming reports.',
    'Setting': 'Settings',
    'Pengaturan Sistem': 'System Settings',
    'Konfigurasi sistem dan parameter aplikasi.':
        'Configure system and application parameters.',
    'Administrator': 'Administrator',
    'Ringkasan statistik kejadian aktif di wilayah Anda.':
        'Summary of active incident statistics in your area.',
    'Laporan Masuk': 'Incoming Reports',
    'Kelola laporan darurat yang masuk dari masyarakat.':
        'Manage emergency reports submitted by the public.',
    'Tim': 'Team',
    'Tim Lapangan': 'Field Team',
    'Kelola penugasan tim dan sumber daya lapangan.':
        'Manage team assignments and field resources.',
    'Profil Instansi': 'Agency Profile',
    'Informasi dan pengaturan instansi Anda.':
        'Your agency information and settings.',
    // ─── SOS Cancellation & UI ───────────────────────────────────────────────
    'Batalkan SOS?': 'Cancel SOS?',
    'Apakah Anda yakin situasi sudah aman dan ingin membatalkan laporan SOS ini?':
        'Are you sure the situation is safe and you want to cancel this SOS report?',
    'TIDAK': 'NO',
    'YA, BATALKAN': 'YES, CANCEL',
    'SOS berhasil dibatalkan.': 'SOS successfully canceled.',
    'Gagal membatalkan SOS:': 'Failed to cancel SOS:',
    'SOS sudah diselesaikan oleh instansi.':
        'SOS has been resolved by the agency.',
    'Tidak dapat membuka telepon.': 'Cannot open phone app.',
    'Telepon 112': 'Call 112',
    'Panggilan darurat': 'Emergency call',
    'Panggilan\\ndarurat': 'Emergency\\ncall',
    'Kirim bukti & titik\\nlokasi': 'Send proof &\\nlocation',
    'SOS AKTIF': 'SOS ACTIVE',
    'Lokasi diperbarui tiap 10 detik': 'Location updated every 10s',
    'Terkirim ✓': 'Sent ✓',
    'Mengirim...': 'Sending...',
    'Gagal menelpon 112:': 'Failed to call 112:',
    'Transmitting': 'Transmitting',
    'Signal Lost': 'Signal Lost',
    'Next update: ': 'Next update: ',
    // Navbar
    'Riwayat': 'History',
    // KYC Screen
    'Verifikasi Identitas (KYC)': 'Identity Verification (KYC)',
    'Verifikasi Identitas NIK Warga': 'Civilian NIK Identity Verification',
    'Status: Belum Diverifikasi': 'Status: Unverified',
    'Status: Menunggu Verifikasi': 'Status: Pending Verification',
    'Status: Terverifikasi': 'Status: Verified',
    'Status: Ditolak': 'Status: Rejected',
    'Mengapa perlu verifikasi?': 'Why verify?',
    'NIK (16 digit)': 'NIK (16 digits)',
    'Nama Lengkap (sesuai KTP)': 'Full Name (as on ID card)',
    'Selfie dengan KTP (opsional)': 'Selfie with ID card (optional)',
    'Ambil / Pilih Foto KTP': 'Take / Choose ID Photo',
    'KTP terpilih ✓': 'ID Photo selected ✓',
    'Ambil Selfie': 'Take Selfie',
    'Selfie terpilih ✓': 'Selfie selected ✓',
    'Foto KTP wajib dilampirkan': 'ID card photo is required',
    'Ajukan Verifikasi NIK': 'Submit NIK Verification',
    'Mengirim pengajuan...': 'Submitting...',
    // Profile KYC tile label
    'Masukkan 16 digit NIK KTP': 'Enter 16-digit NIK',
    'Masukkan nama sesuai KTP': 'Enter name as on ID card',
  };

  static String tr(BuildContext context, String text) {
    final languageCode = Localizations.localeOf(context).languageCode;
    if (languageCode == localeEn.languageCode) {
      return _idToEn[text] ?? text;
    }
    return text;
  }
}

extension LocalizedString on String {
  String tr(BuildContext context) => AppLocalization.tr(context, this);
}
