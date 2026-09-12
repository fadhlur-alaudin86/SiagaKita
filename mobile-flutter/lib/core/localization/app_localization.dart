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
    'Izin Lokasi Diperlukan': 'Location Permission Required',
    'SiagaKita membutuhkan akses lokasi agar bantuan dapat segera diarahkan ke tempat Anda secara akurat saat keadaan darurat.':
        'SiagaKita needs location access so that help can be immediately directed to you accurately during an emergency.',
    'Mohon aktifkan izin lokasi secara manual melalui pengaturan aplikasi.':
        'Please enable location permission manually through app settings.',
    'TAMPILAN & AKSESIBILITAS': 'DISPLAY & ACCESSIBILITY',
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
    'Lemah': 'Weak',
    'Kuat': 'Strong',
    'Hapus Permanen': 'Delete Permanently',
    'Selamat Datang': 'Welcome',
    'Masuk untuk mengakses sistem pelaporan darurat SiagaKita.':
        'Log in to access the SiagaKita emergency reporting system.',
    'Email Anda': 'Your Email',
    'Kata Sandi': 'Password',
    'Kata Sandi Baru': 'New Password',
    'Minimal 8 karakter': 'Minimum 8 characters',
    'OTP wajib diisi': 'OTP is required',
    'OTP harus 6 digit': 'OTP must be 6 digits',
    'Kode telah dikirim ke:\n': 'Code has been sent to:\n',
    'Terjadi kesalahan, coba lagi nanti': 'An error occurred, try again later',
    'Password berhasil diubah. Silakan login kembali.':
        'Password changed successfully. Please log in again.',
    'Kode OTP baru telah dikirim': 'New OTP code has been sent',
    'Gagal mengirim ulang OTP. Periksa koneksi.':
        'Failed to resend OTP. Please check your connection.',
    'Simpan Password Baru': 'Save New Password',
    'Belum menerima kode?': 'Didn\'t receive a code?',
    'Kirim ulang dalam': 'Resend in',
    'Masyarakat Umum': 'General Public',
    'Masyarakat': 'Public',
    'Agency': 'Agency',
    'Admin': 'Admin',
    'Pelaporan': 'Report',
    'Lupa sandi?': 'Forgot password?',
    'Masuk': 'Log In',
    'Belum punya akun?': 'Don\'t have an account?',
    'Bergabung dengan jejaring keselamatan SiagaKita.':
        'Join the SiagaKita safety network.',
    'Daftar di sini': 'Sign up here',
    'Tempat, Tanggal Lahir (Umur)': 'Place, Date of Birth (Age)',
    'Beranda': 'Home',
    'Panduan': 'Guide',
    'Operasi': 'Operations',
    'Map': 'Map',
    'Profil': 'Profile',
    'Ketuk 3× untuk mengirim SOS': 'Tap 3× to send SOS',
    'Ketuk 3× untuk batalkan': 'Tap 3× to cancel',
    'YA, KIRIMKAN SEKARANG': 'YES, SEND NOW',
    'KETUK 3×': 'TAP 3×',
    'SINYAL SOS TERKIRIM!': 'SOS SIGNAL SENT!',
    'Buat Akun Baru': 'Create New Account',
    'Lanjut': 'Continue',
    'Sudah punya akun?': 'Already have an account?',
    'Verifikasi Email': 'Verify Email',
    'Kirim Kode OTP': 'Send OTP Code',
    'Harus mengandung huruf besar': 'Must contain uppercase letter',
    'Harus mengandung angka': 'Must contain number',
    'Harus mengandung simbol': 'Must contain symbol',
    'Kami telah mengirimkan kode OTP ke': 'We have sent the OTP code to',
    'Kode berlaku 3 menit.': 'Code valid for 3 minutes.',
    'Verifikasi & Masuk': 'Verify & Login',
    'Masuk sekarang': 'Log in now',
    'Verifikasi Nomor': 'Verify Number',
    'Verifikasi Nomor WhatsApp': 'Verify Number WhatsApp',
    'Kode OTP': 'OTP Code',
    'Kirim ulang kode OTP': 'Resend OTP code',
    'Foto KTP': 'ID Card Photo',
    'Lengkapi Biodata': 'Complete Biodata',
    'Langkah Terakhir!': 'Final Step!',
    'Data kesehatan ini sangat penting untuk penanganan medis darurat yang tepat sasaran.':
        'This health data is essential for accurate emergency medical handling.',
    'Fisik & Kesehatan': 'Physical & Health',
    'Data ini mempermudah tim penolong mengetahui karakteristik fisik Anda.':
        'This helps responders understand your physical characteristics.',
    'Tanggal Lahir (DD-MM-YYYY)': 'Date of Birth (DD-MM-YYYY)',
    'Gol. Darah': 'Blood Type',
    'Riwayat Penyakit & Alergi': 'Medical History & Allergies',
    'Kosongkan jika tidak ada. Data ini krusial untuk menghindari pantangan obat darurat.':
        'Leave blank if none. This is crucial to avoid emergency medication contraindications.',
    'Alamat Tempat Tinggal': 'Home Address',
    'Sebagai acuan domisili terdekat jika evakuasi diperlukan.':
        'Used as nearest domicile reference if evacuation is needed.',
    'Alamat lengkap sesuai domisili...': 'Full address based on domicile...',
    'Kontak Darurat (Wali/Keluarga)': 'Emergency Contact (Guardian/Family)',
    'Orang yang akan dihubungi jika Anda dalam bahaya.':
        'Person to contact if you are in danger.',
    'Simpan & Selesai': 'Save & Finish',
    'Tahun': 'Years',
    'Relawan Terverifikasi': 'Verified Volunteer',
    'Menunggu Verifikasi': 'Pending Verification',
    'Bukan Relawan': 'Not a Volunteer',
    'PROFIL PENGGUNA': 'USER PROFILE',
    'EDIT PROFIL': 'EDIT PROFILE',
    'Edit Profil': 'Edit Profile',
    'INFORMASI PRIBADI': 'PERSONAL INFORMATION',
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
    'Panggil 112': 'Call 112',
    'PENGATURAN & BANTUAN': 'SETTINGS & HELP',
    'Tentang Aplikasi': 'About App',
    'DAFTAR MENJADI RELAWAN': 'REGISTER AS VOLUNTEER',
    'Form kontak baris ke': 'Contact form row',
    'belum lengkap!': 'is incomplete!',
    'Nomor pada kontak ke': 'Phone number on contact',
    'minimal 10 digit!': 'must be at least 10 digits!',
    'Profil berhasil diperbarui.': 'Profile updated successfully.',
    'Domisili Lengkap': 'Full Domicile Address',
    'Bio Singkat': 'Short Bio',
    'DATA MEDIS & KEAMANAN': 'MEDICAL & SAFETY DATA',
    'Belum Tahu': 'Unknown',
    'Berat (kg)': 'Weight (kg)',
    'Tinggi (cm)': 'Height (cm)',
    'Riwayat Penyakit (Opsional)': 'Medical History (Optional)',
    'Alergi Utama (Opsional)': 'Main Allergy (Optional)',
    'Tambah': 'Add',
    'Belum ada kontak darurat.': 'No emergency contacts yet.',
    'Belum ada kontak darurat ditambahkan.': 'No emergency contacts added yet.',
    'Bisa dilewati, data dapat dilengkapi nanti di dalam menu Profil.':
        'Can be skipped, data can be completed later in the Profile menu.',
    'Lewati': 'Skip',
    'Kontak Darurat': 'Emergency Contact',
    'Nama Lengkap': 'Full Name',
    'Hubungan': 'Relationship',
    'Orang Tua': 'Parent',
    'Suami / Istri': 'Spouse',
    'Anak': 'Child',
    'Saudara': 'Sibling',
    'Teman': 'Friend',
    'Lainnya': 'Other',
    'No Hp': 'Phone',
    'Simpan Perubahan': 'Save Changes',
    'PANDUAN DARURAT': 'EMERGENCY GUIDE',
    'Database Lokal Aktif (Offline/Online)':
        'Local Database Active (Offline/Online)',
    'Cari tindakan (mis: Luka Bakar)...':
        'Search actions (e.g. Burn injury)...',
    'Versi 1.0.0 (Build 20)': 'Version 1.0.0 (Build 20)',
    'SiagaKita adalah platform penanggulangan darurat terpadu yang menghubungkan masyarakat dengan relawan medis dan tim penyelamat dalam satu ekosistem waktu nyata (real-time).':
        'SiagaKita is an integrated emergency response platform connecting communities with medical volunteers and rescue teams in one real-time ecosystem.',
    'Syarat & Ketentuan': 'Terms & Conditions',
    'Kebijakan Privasi': 'Privacy Policy',
    'Lisensi Perangkat Lunak': 'Software Licenses',
    'Lokasi Otomatis Ditemukan': 'Automatic Location Found',
    'Kategori Darurat': 'Emergency Category',
    'Lampiran Foto & Audio': 'Photo & Audio Attachments',
    'Ringan': 'Low',
    'Sedang': 'Medium',
    'Kritis': 'Critical',
    'Kirim Laporan': 'Send Report',
    'Kebakaran': 'Fire',
    'Kecelakaan': 'Accident',
    'Bencana Alam': 'Natural Disaster',
    'Kriminalitas': 'Crime',
    'Medis': 'Medical',
    'Bencana': 'Disaster',
    'JEJARING KESELAMATAN LOKAL': 'LOCAL SAFETY NETWORK',
    'RADAR SIAGA & EVAKUASI': 'ALERT & EVACUATION RADAR',
    'Radius 5 KM': '5 KM Radius',
    'AKTIF': 'ACTIVE',
    'Relawan': 'Volunteer',
    'KETUK 3× BATALKAN': 'TAP 3× CANCEL',
    'Riwayat Laporan': 'Report History',
    'SOS Anda telah diselesaikan. Terima kasih!':
        'Your SOS has been resolved. Thank you!',
    'Tim penyelamat sedang dalam perjalanan ke lokasi Anda!':
        'Rescue team is on the way to your location!',
    'Sesi Anda telah berakhir karena login di perangkat lain.':
        'Your session has ended due to login on another device.',
    'Relawan sedang menuju lokasi Anda!':
        'Volunteer is on the way to your location!',
    'Misi diterima! Segera menuju ': 'Mission accepted! Proceed to ',
    'lokasi korban': 'victim\'s location',
    'SOS Terkunci': 'SOS Locked',
    'Selesaikan Misi?': 'Complete Mission?',
    'Bukti berhasil dikirim. Menunggu konfirmasi...':
        'Proof sent successfully. Waiting for confirmation...',
    'Koordinat': 'Coordinates',
    'Lokasi': 'Location',
    'Dilaporkan': 'Reported',
    'Instansi': 'Agency',
    'Kepercayaan': 'Trust Level',
    'Foto Bukti': 'Proof Photos',
    'Rekaman Audio Darurat Tersedia': 'Emergency Audio Recording Available',
    'TERIMA MISI': 'ACCEPT MISSION',
    'Lihat di Peta': 'View on Map',
    'RADAR SOS AKTIF': 'ACTIVE SOS RADAR',
    'insiden': 'incidents',
    'Aktifkan ON DUTY': 'Activate ON DUTY',
    'Untuk melihat panggilan darurat di sekitarmu':
        'To see emergency calls around you',
    'Tidak ada SOS aktif': 'No active SOS',
    'Belum ada panggilan darurat dalam radius 5 km':
        'No emergency calls within 5 km radius',
    'RIWAYAT MISI': 'MISSION HISTORY',
    'Belum ada riwayat misi': 'No mission history yet',
    'Riwayat SOS yang kamu tangani akan muncul di sini':
        'History of SOS you handled will appear here',
    'Halo, ': 'Hello, ',
    'Level Maksimal': 'Maximum Level',
    'Kamu sudah mencapai level tertinggi!':
        'You have reached the highest level!',
    'Selesaikan ': 'Complete ',
    ' XP lagi untuk naik ke level berikutnya': ' more XP to level up',
    'FITUR TERKUNCI': 'FEATURE LOCKED',
    'Dinonaktifkan saat SOS sedang aktif': 'Disabled while SOS is active',
    'Memantau SOS dalam radius 5 km': 'Monitoring SOS within 5 km radius',
    'Aktifkan untuk menerima panggilan darurat':
        'Activate to receive emergency calls',
    'MISI SEDANG BERJALAN': 'MISSION IN PROGRESS',
    'Penugasan Darurat dari Operator!': 'Emergency Dispatch from Operator!',
    'Operator menugaskan Anda untuk merespons insiden ini secara langsung.':
        'The operator has dispatched you directly to respond to this incident.',
    'Lokasi insiden': 'Incident location',
    'Terima Misi': 'Accept Mission',
    'Tolak': 'Decline',
    'Penugasan telah diambil oleh relawan lain atau waktu habis.':
        'Dispatch offer was claimed by another responder or timed out.',
    'Lokasi korban: ': 'Victim location: ',
    'SELESAIKAN MISI': 'COMPLETE MISSION',
    'Detail': 'Detail',
    'TERIMA': 'ACCEPT',
    'Selesai (+': 'Completed (+',
    ' XP)': ' XP)',
    'Ditolak': 'Rejected',
    'Ditangani': 'Handled',
    'Mengirim ulang...': 'Retrying...',
    'Streaming Real-time': 'Real-time Streaming',
    'Menunggu Review': 'Waiting Review',
    'Dibatalkan': 'Canceled',
    'Menu': 'Menu',
    'Segera Hadir': 'Coming Soon',
    'Keluar': 'Logout',
    'DALAM TUGAS': 'ON DUTY',
    'DI LUAR TUGAS': 'OFF DUTY',
    'Relawan Aktif': 'Active Volunteers',
    'Riwayat Misi': 'Mission History',
    'Harap centang persetujuan syarat dan ketentuan.':
        'Please check the terms and conditions agreement.',
    'Pengajuan Diterima. Status Anda kini Pending Review.':
        'Submission accepted. Your status is now Pending Review.',
    'Tersimpan': 'Saved',
    'Unggah': 'Upload',
    'PENDAFTARAN RELAWAN': 'VOLUNTEER REGISTRATION',
    'Misi Penyelamatan First Responder': 'First Responder Rescue Mission',
    'SiagaKita memanggil Anda yang memiliki kapabilitas medis / evakuasi gawat darurat. Pengajuan akan ditinjau oleh Admin daerah.':
        'SiagaKita is calling those with emergency medical/evacuation capability. Submission will be reviewed by regional Admin.',
    'PILIHAN SPESIALISASI': 'SPECIALIZATION OPTIONS',
    'PENGALAMAN MEDIS / ORGANISASI': 'MEDICAL / ORGANIZATIONAL EXPERIENCE',
    'Contoh: Mantan petugas medis PMI, Relawan Damkar...':
        'Example: Former PMI medic, Fire dept volunteer...',
    'Contoh: Asma, Hipertensi': 'Example: Asthma, Hypertension',
    'Contoh: Udang, Debu, Penisilin': 'Example: Shrimp, Dust, Penicillin',
    'Data Identitas & Kontak': 'Identity & Contact Data',
    'Konfirmasi Bantuan': 'Confirmation of Assistance',
    'Harap uraikan pengalaman Anda': 'Please describe your experience',
    'Saya menyatakan bahwa dokumen yang dilampirkan adalah benar, dan saya bersedia dipanggil dalam situasi darurat di area jangkauan saya sesuai standar operasional yang berlaku.':
        'I declare that attached documents are valid, and I agree to be called in emergencies within my coverage area according to applicable SOPs.',
    'SUBMIT PENGAJUAN': 'SUBMIT APPLICATION',
    'Lihat semua riwayat →': 'View all history →',
    'Selesaikan/batalkan misi yang sedang aktif':
        'Complete/cancel the currently active mission',
    'Sending...': 'Sending...',
    'Sent': 'Sent',
    'Retry...': 'Retry...',
    'SOS AKAN DIKIRIM DALAM': 'SOS WILL BE SENT IN',
    'Pilih tipe bantuan:': 'Choose type of assistance:',
    'Kriminal': 'Crime',
    'BATALKAN SEKARANG': 'CANCEL NOW',
    'Bantuan sedang dikoordinasikan.': 'Help is being coordinated.',
    'Pastikan Anda sudah aman atau bantuan sudah tiba.':
        'Make sure you are safe or help has arrived.',
    'Panggilan SOS telah dibatalkan.': 'SOS call has been canceled.',
    'Akses Ditolak': 'Access Denied',
    'Persyaratan Belum Lengkap': 'Prerequisites Incomplete',
    'Untuk mendaftar sebagai relawan, Anda wajib melengkapi verifikasi berikut:':
        'To register as a volunteer, you must complete the following verifications:',
    'Verifikasi NIK (KYC)': 'NIK Verification (KYC)',
    'Tanggal Lahir': 'Date of Birth',
    'Pilih minimal satu spesialisasi': 'Select at least one specialization',
    'Harap unggah sertifikat untuk setiap spesialisasi yang dipilih':
        'Please upload certificates for each selected specialization',
    'Sertifikat ': 'Certificate ',
    'Unggah Sertifikat': 'Upload Certificate',
    '(Mendukung PDF, JPG, PNG maks 2MB)': '(Supports PDF, JPG, PNG max 2MB)',
    'PILIHAN SPESIALISASI & SERTIFIKAT': 'SPECIALIZATION & CERTIFICATE OPTIONS',
    'Gagal mengirim pendaftaran: ': 'Failed to send registration: ',
    'Medis & First Aid': 'Medical & First Aid',
    'Evakuasi & SAR': 'Evacuation & SAR',
    'Logistik & Dapur Umum': 'Logistics & Field Kitchen',
    'Komunikasi & Operator': 'Communication & Operator',
    'REPUTASI RELAWAN': 'VOLUNTEER REPUTATION',
    'Menuju ': 'Towards ',
    'XP': 'XP',
    'Level': 'Level',
    'Perubahan NIK membutuhkan verifikasi ulang oleh admin (1-3 hari kerja). Status verifikasi saat ini akan direset ke "Menunggu Verifikasi".\n\nApakah Anda ingin melanjutkan?':
        'ID number changes require admin re-verification (1-3 working days). Current verification status will be reset to "Waiting for Verification".\n\nDo you want to continue?',
    'Pengubahan nomor WhatsApp memerlukan verifikasi ulang melalui OTP. Tingkat kepercayaan laporan Anda akan berkurang jika nomor belum diverifikasi.\n\nApakah Anda ingin melanjutkan?':
        'Changing WhatsApp number requires re-verification via OTP. Your report trust level will decrease if the number is not verified.\n\nDo you want to continue?',
    'Nomor minimal 10 digit': 'Number must be at least 10 digits',
    'Verifikasi WhatsApp': 'WhatsApp Verification',
    'Verifikasi': 'Verify',
    'Pengguna': 'User',
    'Belum diisi': 'Not filled',
    'Nomor WhatsApp': 'WhatsApp Number',
    'RIWAYAT': 'HISTORY',
    'Foto KTP wajib dilampirkan': 'KTP photo must be attached',
    'Foto profil (selfie) wajib dilampirkan':
        'Profile photo (selfie) must be attached',
    'Pengajuan sedang diproses oleh admin (1-3 hari kerja).':
        'Application is being processed by admin (1-3 working days).',
    'Terverifikasi': 'Verified',
    'Belum Diverifikasi': 'Not Verified',
    'Status: ': 'Status: ',
    'Mengapa perlu verifikasi?': 'Why is verification needed?',
    'Verifikasi NIK dan wajah meningkatkan kepercayaan responden terhadap laporan darurat Anda dan akan digunakan sebagai foto profil resmi Anda di aplikasi.':
        'Identity and face verification increases respondent trust in your emergency reports and will be used as your official profile photo in the app.',
    'NIK (16 digit)': 'ID Number (16 digits)',
    'Nama lengkap tidak boleh kosong': 'Full name cannot be empty',
    'Kata sandi tidak boleh kosong': 'Password cannot be empty',
    'Konfirmasi kata sandi tidak boleh kosong':
        'Password confirmation cannot be empty',
    'Masukkan email akun Anda. Kami akan mengirimkan kode OTP untuk mengatur ulang kata sandi.':
        'Enter your account email. We will send an OTP code to reset your password.',
    'Kata sandi tidak cocok': 'Password does not match',
    'Gagal terhubung ke server. Periksa koneksi.':
        'Failed to connect to server. Check connection.',
    'Registrasi berhasil': 'Registration successful',
    'Ulangi Kata Sandi': 'Repeat Password',
    'Masukkan 16 digit NIK KTP': 'Enter 16-digit ID number',
    'NIK KTP (16 Digit)': 'ID Number (16 Digits)',
    'No WhatsApp aktif': 'Active WhatsApp Number',
    'Tempat Lahir': 'Place of Birth',
    'Tempat lahir wajib diisi': 'Place of birth is required',
    'NIK wajib diisi': 'ID number is required',
    'NIK harus tepat 16 digit': 'ID number must be exactly 16 digits',
    'Nama Lengkap (sesuai KTP)': 'Full Name (as per ID card)',
    'Masukkan nama sesuai KTP': 'Enter name as per ID card',
    'Nama wajib diisi': 'Name is required',
    'Nama terlalu pendek': 'Name is too short',
    'Ambil / Pilih Foto KTP': 'Take / Choose ID Photo',
    'KTP terpilih': 'ID Photo selected',
    'Foto Profil (Selfie)': 'Profile Photo (Selfie)',
    'Ambil Selfie Wajah': 'Take Face Selfie',
    'Selfie terpilih': 'Selfie selected',
    'Mengirim...': 'Sending...',
    'Ajukan Verifikasi NIK': 'Submit ID Verification',
    'Kamera': 'Camera',
    'Ulang': 'Retake',
    'Memuat lokasi...': 'Loading location...',
    'Lokasi tidak tersedia': 'Location not available',
    'Gagal memuat alamat': 'Failed to load address',
    'Layanan GPS tidak aktif. Aktifkan GPS di pengaturan.':
        'GPS service is inactive. Enable GPS in settings.',
    'Izin GPS belum diberikan': 'GPS permission not granted',
    'Gagal mengambil lokasi: ': 'Failed to get location: ',
    'Izin mikrofon ditolak.': 'Microphone permission denied.',
    'Pilih kategori darurat terlebih dahulu.':
        'Please select an emergency category first.',
    'Foto bukti wajib dilampirkan.': 'Evidence photo must be attached.',
    'Konfirmasi Laporan': 'Confirm Report',
    'Kategori': 'Category',
    'Foto': 'Photo',
    'foto terlampir': 'photo(s) attached',
    'Audio': 'Audio',
    'Rekaman': 'Recording',
    'Kirim Sekarang': 'Send Now',
    'Laporan berhasil dikirim!': 'Report successfully sent!',
    'Ketik deskripsi tambahan jika ada...':
        'Type additional description if any...',
    'Laporan Warga': 'Citizen Report',
    'Mendeteksi lokasi...': 'Detecting location...',
    'Memuat ulang...': 'Reloading...',
    'Galeri': 'Gallery',
    'Gagal memuat riwayat laporan.': 'Failed to load report history.',
    'Gagal memuat riwayat SOS.': 'Failed to load SOS history.',
    'Laporan': 'Report',
    'SOS Darurat': 'SOS Emergency',
    'Coba Lagi': 'Try Again',
    'Belum ada laporan': 'No reports yet',
    'Laporan yang Anda kirim akan muncul di sini.':
        'Reports you send will appear here.',
    'Belum ada riwayat SOS': 'No SOS history yet',
    'foto': 'photo(s)',
    'audio': 'audio',
    'Batalkan': 'Cancel',
    'Batalkan Laporan?': 'Cancel Report?',
    'Gagal menyimpan biodata': 'Failed to save biodata',
    'Apakah Anda yakin ingin membatalkan laporan ini? Laporan yang dibatalkan tidak dapat dikembalikan.':
        'Are you sure you want to cancel this report? Canceled reports cannot be recovered.',
    'Apakah Anda yakin membutuhkan bantuan segera untuk tipe':
        'Are you sure you need immediate help for this type',
    'Tidak': 'No',
    'Ya, Batalkan': 'Yes, Cancel',
    'Laporan berhasil dibatalkan.': 'Report successfully canceled.',
    'Laporan berhasil dikirim ulang.': 'Report successfully resent.',
    'Palsu': 'False',
    'Selesai': 'Completed',
    'Merekam...': 'Recording...',
    '(Opsional, maksimal 1 menit)': '(Optional, max 1 minute)',
    'Tahan untuk rekam suara': 'Hold to record audio',
    'sedang dalam tahap pengembangan dan akan segera tersedia.':
        'is under development and will be available soon.',
    'Cabut Izin Lokasi': 'Revoke Location Permission',
    'Untuk mencabut izin lokasi, Anda perlu melakukannya secara manual melalui pengaturan OS perangkat Anda.':
        'To revoke location permission, you need to do it manually via your device\'s OS settings.',
    'Offline - Peta mungkin tidak tersedia':
        'Offline - Map may not be available',
    'DALAM TUGAS - Memantau': 'ON DUTY - Monitoring',
    'SOS dalam 5KM': 'SOS within 5KM',
    'DALAM TUGAS - Tidak ada SOS aktif dalam 5KM':
        'ON DUTY - No active SOS within 5KM',
    'DI LUAR TUGAS - Aktifkan di tab Operasi':
        'OFF DUTY - Activate in Operations tab',
    'Akurasi rendah: ±': 'Low accuracy: ±',
    'Koneksi Terputus - Peta Mungkin Tidak Tampil':
        'Connection Lost - Map May Not Display',
    'ONLINE': 'ONLINE',
    'OFFLINE': 'OFFLINE',
    'STATUS TRANSMISI': 'TRANSMISSION STATUS',
    'Buka tab Operasi untuk terima misi':
        'Open Operations tab to accept mission',
    'Pendarahan Hebat': 'Severe Bleeding',
    'Tekan luka kuat-kuat dengan kain bersih.':
        'Apply firm pressure on the wound with a clean cloth.',
    'Tinggikan posisi luka di atas jantung jika memungkinkan.':
        'Raise the injured area above heart level if possible.',
    'Jangan lepas kain pertama jika darah tembus, tumpuk dengan kain baru.':
        'Do not remove the first cloth if soaked; add another on top.',
    'Segera cari bantuan darurat.': 'Seek emergency help immediately.',
    'Luka Bakar': 'Burn Injury',
    'Aliri area luka dengan air mengalir (bukan es) selama 15-20 menit.':
        'Cool the burn under running water (not ice) for 15-20 minutes.',
    'Lepaskan pakaian atau perhiasan di sekitar luka sebelum membengkak.':
        'Remove clothing or jewelry around the area before swelling.',
    'Tutup luka secara longgar dengan plastik wrap atau kain bersih.':
        'Cover loosely with plastic wrap or a clean cloth.',
    'Jangan pernah memecahkan lepuhan.': 'Do not pop blisters.',
    'Tersedak (Dewasa)': 'Choking (Adult)',
    'Berdirilah di belakang korban dan peluk pinggangnya.':
        'Stand behind the victim and wrap your arms around the waist.',
    'Kepalkan satu tangan sedikit di atas pusarnya.':
        'Make a fist slightly above the navel.',
    'Genggam kepalan dengan tangan satunya, lalu hentakkan ke atas dan ke dalam (Heimlich Maneuver).':
        'Grab your fist with the other hand and thrust inward and upward (Heimlich maneuver).',
    'Ulangi sampai benda asing keluar.': 'Repeat until the object is expelled.',
    'Gempa Bumi': 'Earthquake',
    'Lakukan Drop, Cover, Hold On (Merunduk, Berlindung di bawah meja yang kuat, Berpegangan).':
        'Drop, Cover, and Hold On.',
    'Jauhi jendela, kaca, dan perabotan yang bisa jatuh.':
        'Stay away from windows, glass, and heavy furniture.',
    'Jika di luar, cari area terbuka jauh dari bangunan, pohon, dan tiang listrik.':
        'If outdoors, move to an open area away from buildings, trees, and power lines.',
    'Jangan gunakan lift saat evakuasi.':
        'Do not use elevators during evacuation.',
    'MEDIS': 'MEDICAL',
    'BENCANA': 'DISASTER',
    'Tim': 'Team',
    'SOS Anda ditandai palsu oleh tim penyelamat.':
        'Your SOS was marked as false by the rescue team.',
    // ─── SOS Cancellation & UI ───────────────────────────────────────────────
    'Batalkan SOS?': 'Cancel SOS?',
    'TIDAK': 'NO',
    'YA, BATALKAN': 'YES, CANCEL',
    'SOS sudah diselesaikan oleh instansi.':
        'SOS has been resolved by the agency.',
    'Panggilan darurat': 'Emergency call',
    'Panggilan darurat\nbebas pulsa': 'Toll-free\nemergency call',
    'Kirim bukti & titik\nlokasi': 'Send proof &\nlocation',
    'SOS AKTIF': 'SOS ACTIVE',
    'Transmitting': 'Transmitting',
    'Signal Lost': 'Signal Lost',
    'Riwayat': 'History',
    // KYC Screen
    'Verifikasi Identitas': 'Identity Verification',
    'Gagal': 'Failed',
    'Terkirim': 'Sent',
    'NIK harus 16 digit!': 'NIK must be 16 digits!',
    'NIK, No WhatsApp, Tempat Lahir, dan Tanggal Lahir wajib diisi!':
        'NIK, WhatsApp Number, Place of Birth, and Date of Birth are required!',
    'Masukkan kode OTP 6 digit': 'Enter 6-digit OTP code',
    'Konfirmasi Kata Sandi Baru': 'Confirm New Password',
    'Konfirmasi kata sandi wajib diisi': 'Password confirmation is required',
    '© 2026 Tim SiagaKita\nDibuat untuk Kemanusiaan':
        '© 2026 SiagaKita Team\nMade for Humanity',
    'Akun Anda diblokir dari fitur SOS. Hubungi admin.':
        'Your account is banned from the SOS feature. Contact admin.',
    'Gagal mengirim SOS: GPS perangkat Anda dimatikan.':
        'Failed to send SOS: Your device GPS is turned off.',
    'Gagal mengirim SOS: Izin akses lokasi belum diberikan.':
        'Failed to send SOS: Location permission not granted.',
    'Gagal mengirim SOS: Tidak dapat mengambil lokasi Anda.':
        'Failed to send SOS: Unable to retrieve your location.',
    'Panggilan SOS dibatalkan (Menunggu koneksi)...':
        'SOS call canceled (Waiting for connection)...',
    'Status SOS telah diselesaikan oleh instansi.':
        'SOS status has been resolved by the agency.',
    'Ambil Foto KTP': 'Take ID Card Photo',
    'Ambil Foto Profil (Selfie)': 'Take Profile Photo (Selfie)',
    'Sesuai KTP': 'As per ID Card',
    'Tanggal lahir wajib diisi': 'Date of birth is required',
    'NIK': 'NIK',
    'Perhatian': 'Attention',
    'Kirim Ulang': 'Resend',
    'Izin ditolak. Buka pengaturan untuk mengizinkan.':
        'Permission denied. Open settings to allow.',
    'Lokasi belum terdeteksi. Pastikan GPS aktif.':
        'Location not detected yet. Ensure GPS is active.',
    'Harap centang penggunaan WhatsApp di nomor tersebut.':
        'Please confirm WhatsApp usage on that number.',
    'Harap lengkapi NIK, No WhatsApp, dan Tempat Lahir':
        'Please complete NIK, WhatsApp Number, and Place of Birth',
    'Saya menggunakan WhatsApp di nomor di atas':
        'I use WhatsApp on the number above',
    'Gagal mengirim OTP:': 'Failed to send OTP:',
    'Gagal verifikasi OTP:': 'Failed to verify OTP:',
    'Kirim Kode Verifikasi': 'Send Verification Code',
    'Kode 6 digit telah dikirim ke:\n': '6-digit code has been sent to:\n',
    'Kode OTP telah dikirim ke WhatsApp:':
        'OTP code has been sent to WhatsApp:',
    'Masukkan Kode OTP': 'Enter OTP Code',
    'Nomor WhatsApp berhasil diverifikasi!':
        'WhatsApp number successfully verified!',
    'Ubah Nomor / Kirim Ulang': 'Change Number / Resend',
    'Offline': 'Offline',
    'Online': 'Online',
    'BANTUAN SEDANG MENUJU LOKASI': 'HELP IS ON THE WAY TO LOCATION',
    'Buka Kamera': 'Open Camera',
    'Foto Bukti Penyelesaian': 'Completion Proof Photo',
    'Standard': 'Standard',
    'Lokasi korban sedang diperbarui...': 'Victim location is being updated...',
    'MENUNGGU REVIEW INSTANSI': 'AWAITING AGENCY REVIEW',
    'Menunggu konfirmasi instansi': 'Awaiting agency confirmation',

    // Camera & UI
    'Ambil Foto': 'Take Photo',
    'Ganti Kamera': 'Switch Camera',
    'Posisikan wajah Anda di dalam area oval\ndan pastikan pencahayaan cukup':
        'Position your face within the oval area\nand ensure adequate lighting',
    'Posisikan KTP Anda di dalam area kotak\ndan pastikan tulisan terbaca jelas':
        'Position your ID card within the box\nand ensure details are clearly legible',
    'Kode OTP telah dikirim ke email Anda':
        'OTP code has been sent to your email',
    'Lupa Password': 'Forgot Password',
    'Reset Password': 'Reset Password',
    'OK': 'OK',

    // ─── Form Validations & Profile ──────────────────────────────────────────
    'Email wajib diisi': 'Email is required',
    'Format email tidak valid': 'Invalid email format',
    'Gagal memperbarui profil': 'Failed to update profile',

    // ─── FTUE Onboarding & Permission Priming (Plan 12) ─────────────────────────
    'RESPONS CEPAT': 'FAST RESPONSE',
    'SOS Darurat Seketika': 'Instant Emergency SOS',
    'Kirim sinyal bahaya seketika dalam hitungan detik dengan siaga countdown dan transmisi lokasi presisi ke pos komando.':
        'Send instant distress signals within seconds with countdown alert and precise location broadcast to command post.',
    'KOMUNITAS SIAGA': 'ALERT COMMUNITY',
    'Jaringan Relawan & Instansi': 'Volunteer & Agency Network',
    'Terhubung langsung dengan tim relawan terverifikasi serta armada instansi resmi (Damkar, Medis, Polisi) di sekitar Anda.':
        'Connect directly with verified volunteer teams and official agency fleets (Fire, Medical, Police) around you.',
    'KESELAMATAN KELUARGA': 'FAMILY SAFETY',
    'Zonasi & Perlindungan Keluarga': 'Family Zoning & Protection',
    'Pantau radius aman keluarga tercinta secara real-time dan dapatkan notifikasi otomatis saat terjadi insiden darurat.':
        'Monitor your loved ones\' safe radius in real-time and get automated notifications during emergency incidents.',
    'Mulai Sekarang': 'Get Started',
    'Izin Aplikasi SiagaKita': 'SiagaKita App Permissions',
    'Aktifkan izin berikut untuk memastikan fitur perlindungan darurat, notifikasi evakuasi, dan pelaporan bencana berfungsi optimal.':
        'Enable the following permissions to ensure emergency protection, evacuation alerts, and disaster reporting function optimally.',
    'Lokasi & GPS Presisi': 'Location & Precise GPS',
    'Wajib': 'Mandatory',
    'Menentukan titik koordinat akurat saat tombol SOS ditekan agar relawan dan armada bantuan dapat segera diarahkan ke lokasi Anda.':
        'Determines accurate coordinate points when the SOS button is pressed so volunteers and rescue fleets can be immediately routed to your location.',
    'Akses Mikrofon': 'Microphone Access',
    'Disarankan': 'Recommended',
    'Merekam audio darurat secara otomatis saat sinyal SOS aktif untuk memberikan bukti situasi bahaya kepada posko siaga.':
        'Automatically records emergency audio while the SOS signal is active to provide situational evidence to the alert post.',
    'Notifikasi Peringatan': 'Alert Notifications',
    'Menerima lansiran darurat seketika, peringatan perimeter keluarga, serta pembaruan status penanganan evakuasi.':
        'Receive instant emergency alerts, family perimeter warnings, and evacuation handling status updates.',
    'Kamera Foto': 'Photo Camera',
    'Opsional': 'Optional',
    'Mengambil foto bukti kejadian bencana di tempat saat Anda mengirimkan formulir pelaporan situasi darurat.':
        'Take on-site disaster evidence photos when submitting emergency situation reports.',
    'Aktif': 'Active',
    'Aktifkan': 'Enable',
    'Izin Ditolak Permanen': 'Permission Permanently Denied',
    'Izin ini telah dinonaktifkan secara permanen. Silakan aktifkan melalui Pengaturan Aplikasi pada perangkat Anda.':
        'This permission has been permanently disabled. Please enable it via App Settings on your device.',
    'Lanjutkan ke Aplikasi': 'Continue to Application',
    'Lewati untuk Sekarang': 'Skip for Now',
    'Izin Lokasi Belum Aktif': 'Location Permission Not Active',
    'SOS dan pelaporan membutuhkan akses lokasi. Ketuk untuk mengaktifkan.':
        'SOS and reporting require location access. Tap to activate.',
    'Akses Lokasi Wajib untuk SOS': 'Location Access Mandatory for SOS',
    'SiagaKita memerlukan koordinat GPS presisi untuk menyiarkan posisi darurat Anda kepada relawan dan pos komando tanggap bencana.':
        'SiagaKita requires high-precision GPS coordinates to broadcast your emergency position to volunteers and disaster response command post.',
    'Buka Layar Perizinan': 'Open Permissions Screen',
    'Buka Pengaturan Gawai': 'Open Device Settings',
    // Multi-level Gamification Badges & Volunteer Mission History
    'Memuat lencana...': 'Loading badges...',
    'Gagal memuat lencana': 'Failed to load badges',
    'Lencana Relawan': 'Volunteer Badges',
    'Belum Ada': 'None',
    'Maksimal': 'Max',
    'Respon Selesai': 'Responses Completed',
    'DAFTAR TINGKAT': 'TIER LIST',
    'Tutup': 'Close',
    'Respon': 'Responses',
    'Terbuka:': 'Unlocked:',
    'Terbuka': 'Unlocked',
    'Terkunci': 'Locked',
    'menit': 'minutes',
    'Gagal memuat gambar': 'Failed to load image',
    'Riwayat Misi Relawan': 'Volunteer Mission History',
    'Medis / Kesehatan': 'Medical / Health',
    'Kejahatan': 'Crime',
    'SAR / Penyelamatan': 'SAR / Rescue',
    'Umum': 'General',
    'Pahlawan Pertama': 'First Responder',
    'Bintang Relawan': 'Star Volunteer',
    'Penjaga Malam': 'Night Watch',
    'Respon Kilat': 'Rapid Response',
    'Medis Siaga': 'Guardian Healer',
  };

  static Locale currentLocale = localeId;
  static String get currentLocaleCode => currentLocale.languageCode;

  static String tr(BuildContext context, String text) {
    final languageCode = Localizations.localeOf(context).languageCode;
    if (languageCode == localeEn.languageCode) {
      return _idToEn[text] ?? text;
    }
    return text;
  }

  static String translate(String text) {
    if (currentLocale.languageCode == localeEn.languageCode) {
      return _idToEn[text] ?? text;
    }
    return text;
  }
}

extension LocalizedString on String {
  String tr(BuildContext context) => AppLocalization.tr(context, this);
}
