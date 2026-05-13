# 📋 SiagaKita - Laporan Kemajuan Pengembangan

> **Terakhir diperbarui:** 13 Mei 2026
> **Branch aktif:** `main`
> **Status keseluruhan:** 🟢 Stabil & Dioptimasi Performa

---

## 🗂️ Daftar Isi

1. [Gambaran Arsitektur](#1-gambaran-arsitektur)
2. [Status Per Komponen](#2-status-per-komponen)
3. [Changelog Per Sprint](#3-changelog-per-sprint)
4. [Struktur File Terkini](#4-struktur-file-terkini)
5. [API Endpoint Lengkap](#5-api-endpoint-lengkap)
6. [Schema Database (v12 - Aktif)](#6-schema-database-v12--aktif)
7. [Yang Belum Selesai](#7-yang-belum-selesai)
8. [Panduan Setup untuk Anggota Baru](#8-panduan-setup-untuk-anggota-baru)

---

## 1. Gambaran Arsitektur

```
┌──────────────────────────────────────────────────────────────────────┐
│                         SiagaKita System                             │
│                                                                      │
│  ┌─────────────────────┐   REST/WS   ┌───────────────────────────┐  │
│  │  Mobile Flutter      │◄───────────►│   Go Fiber Backend         │  │
│  │  (civilian/volunteer)│             │   Port :8080 (REST)        │  │
│  └─────────────────────┘             │   Port :8081 (WebSocket)   │  │
│                                      └─────────────┬─────────────┘  │
│  ┌─────────────────────┐                           │                │
│  │  Desktop Console     │             ┌─────────────▼─────────────┐  │
│  │  Flutter             │◄───────────►│   PostgreSQL 15            │  │
│  │  (admin/agency)      │             │   (Data Permanen)          │  │
│  └─────────────────────┘             └─────────────┬─────────────┘  │
│                                                    │                │
│  ┌─────────────────────┐             ┌─────────────▼─────────────┐  │
│  │  Mobile Responder    │             │   Redis                    │  │
│  │  Flutter (BELUM BUAT)│             │   (OTP TTL, WS Hub State)  │  │
│  │  (agency_personnel)  │             └───────────────────────────┘  │
│  └─────────────────────┘                                            │
└──────────────────────────────────────────────────────────────────────┘
```

**Stack teknologi:**
| Layer | Teknologi |
|-------|-----------|
| Mobile Citizen | Flutter (Dart) - `mobile-flutter/` |
| Desktop Console | Flutter Desktop - `windows_console_flutter/` |
| Mobile Responder | Flutter (belum dibuat) - `mobile-flutter-responder/` |
| Backend | Go 1.26 + Fiber v2 + Sonic + Zerolog |
| Database | PostgreSQL 15 (Schema v12) |
| Cache / Ephemeral | Redis |
| Email OTP | SMTP (Gmail) |
| WA OTP | Fonnte API |
| Container | Docker Compose (Persisten Log) |

---

## 2. Status Per Komponen

### 🟢 Backend - Go Fiber

| Domain | Status | Keterangan |
|--------|--------|-----------|
| `domain/user/` | ✅ v3 | Slim auth, 3 login endpoints, transaksi user+profil |
| `domain/otp/` | ✅ | Email OTP (SMTP) + WA OTP (Fonnte) |
| `domain/incident/` | ✅ v12| SOS trigger, fallback XP, volunteer completion, agency resolve, mission history |
| `domain/admin/` | ✅ v12| KYC, manajemen user, badges CRUD, statistik |
| `domain/telemetry/` | ✅ | Location update, SMS fallback |
| `internal/hub/` + `ws/` | ✅ | WebSocket persistent registry |
| `internal/middleware/` | ✅ v3 | JWT Auth + RBAC granular (AdminOnly, ConsoleOnly, dll.) |
| `config/config.go` | ✅ | + SuperAdminEmail, SuperAdminPass |
| `cmd/api/main.go` | ✅ | seedSuperAdmin(), login routes, admin & badges routes |
| `internal/utils/logger.go` | ✅ Baru | Zerolog + File Persistence Support |
| JSON Engine | ✅ Baru | Sonic (High Performance) |

### 🟢 Mobile Flutter - Citizen/Volunteer (`mobile-flutter/`)

| Layar / Modul | Status | Keterangan |
|-------|--------|-----------|
| Login | ✅ | `POST /auth/login` - hanya civilian/volunteer; simpan sesi lokal |
| Register | ✅ | 2-step: form → email OTP → JWT |
| Biodata | 🟡 | UI selesai, API belum terhubung |
| Home (SOS) | ✅ v2 | SOS instan (UUID lokal), retry background 5s, badge status upload |
| Home (Offline) | ✅ Baru | Auto-login dari sesi tersimpan; indikator ● Online/Offline di header |
| Profile | ✅ v2 | Tampilkan NIK (bukan UUID); badge verifikasi HP; tombol verifikasi identitas |
| Edit Profile | ✅ v2 | Fix save berhasil; OTP WhatsApp wajib sebelum ubah nomor HP |
| Map | ✅ v2 | Polling 10s, geocoding Nominatim, marker SOS nearby, status transmisi dinamis |
| Relawan Dashboard | ✅ v2 | Total redesign: Duty toggle, XP bar, radar SOS real-time, detail bottomsheet, riwayat misi |
| Session Management | ✅ Baru | `SessionService` (SharedPreferences) - login persist, logout clear |
| UI Responsiveness | ✅ Baru | **Scaling Utility (Normalization)**: lib/core/utils/responsive.dart |

### 🟢 Desktop Console (`windows_console_flutter/`)

| Layar | Status | Keterangan |
|-------|--------|-----------|
| Login Console | ✅ **Fix** | Sekarang pakai `POST /auth/console/login` |
| InstansiShell | ✅ | Sidebar + WS indicator |
| Dashboard Operasi | ✅ | KPI + live SOS list + pie chart |
| SOS Aktif | ✅ | Detail korban, false alarm, resolve |
| Performance | ✅ Baru | RepaintBoundary & Isolate parsing |
| Laporan Masuk | ✅ | Jalur B + filter status |
| Riwayat SOS | ✅ | Filter sejarah insiden per instansi |
| Peta Operasional | ✅ | OpenStreetMap + markers live |
| Dispatch Relawan | 🔴 | Placeholder (Sprint B.4) |
| Admin - KYC | ✅ | UI selesai, backend endpoint tersedia |
| Admin - User Mgmt | ✅ | UI selesai, backend endpoint tersedia |
| Admin - Gamifikasi | ✅ | UI selesai, backend endpoint tersedia |
| Admin - Statistik | ✅ | UI selesai, backend endpoint tersedia |

---

## 3. Changelog Per Sprint

---

### 🔖 Patch 1.0.20 - 13 Mei 2026 (UI Normalization & Scaling)

#### 🎨 Mobile Flutter (Citizen/Volunteer)
- **Responsive Scaling Utility**: Membuat modul `responsive.dart` untuk normalisasi ukuran font, padding, dan dimensi widget berdasarkan resolusi layar (referensi 390x844).
- **Home & SOS Normalization**: Redesign `SOSActionButton` dan `HomeHeader` agar tidak overflow pada layar kecil (misal: 320px width) dan tetap terlihat premium pada layar besar.
- **Form Scaling**: Mengintegrasikan scaling pada `KycScreen` untuk memastikan input field dan banner status terverifikasi tetap proporsional.
- **Typography Standardization**: Memastikan semua teks menggunakan unit `.sp(context)` agar mengikuti kepadatan pixel layar tanpa terpotong.

#### 🖥️ Desktop Console (Admin/Instansi)
- **Flexible Dropdown Layout**: Mengganti `width: 200` statis pada filter `RiwayatPage` dengan `BoxConstraints` agar filter tidak bertumpukan saat window diperkecil.
- **Detail Dialog Adaptability**: Menyesuaikan lebar dialog detail laporan agar menggunakan persentase layar dengan batas maksimal, mencegah UI terpotong pada monitor resolusi rendah (720p).

---

### 🔖 Patch 1.0.19 - 13 Mei 2026 (UI Audio Recording & Report Endpoint Consistency)

#### 📱 Mobile App (SiagaKita Warga)
- **Audio Recording UI**: Memperbaiki masalah tampilan teks "Tahan untuk rekam suara" yang sebelumnya terpotong pada layar pelaporan dengan mengimplementasikan widget `Flexible` dan properti `TextOverflow.ellipsis`.
- **Timezone Lokal**: Memperbarui riwayat laporan agar selalu menampilkan waktu dalam *timezone* lokal pengguna (`toLocal()`), bukan UTC, baik untuk Riwayat Laporan biasa maupun SOS.
- **Konsistensi Endpoint Pembatalan**: Mengubah *path* endpoint pembatalan (laporan dan SOS) di dalam `incident_service.dart` dan `report_service.dart` agar selaras dengan *backend* (dari `/cancel` menjadi `/canceled`).
- **Custom Camera Toggle**: Memperluas kapabilitas `CustomCameraView` dengan opsi untuk menonaktifkan *overlay* KYC (KTP/Wajah) ketika widget kamera dipanggil dari dalam konteks pelaporan biasa.

---

### 🔖 Patch 1.0.18 - 12 Mei 2026 (Environment Security & UI Consistency)

#### 🛡️ Keamanan & Konfigurasi
- **Environment Variable Abstraction**: IP server (`API_HOST`) kini dipisahkan dari kode sumber ke file `.env` di direktori `infrastructure/`.
- **Flutter Native Define**: Menggunakan fitur `--dart-define-from-file` untuk membaca variabel environment secara native saat *build/run*, menghilangkan ketergantungan pada package pihak ketiga (`flutter_dotenv`).
- **IP Protection**: Menghapus nilai *default* IP publik di dalam kode untuk meningkatkan keamanan server.

#### 🎨 Konsistensi UI Lintas Platform
- **Global Typography**: Mengintegrasikan `google_fonts` (Inter) sebagai standar tipografi di seluruh aplikasi (`mobile-flutter` dan `windows_console_flutter`) untuk memastikan tampilan teks identik di Android, iOS, Windows, dan Linux.
- **Explicit Platform Targeting**: 
  - Memaksa `TargetPlatform.android` pada aplikasi mobile agar perilaku interaksi konsisten.
  - Memaksa `TargetPlatform.linux` pada aplikasi konsol agar UI desktop mengikuti referensi desain utama (Linux).

---

### 🔖 Patch 1.0.17 - 12 Mei 2026 (Fitur Riwayat Instansi & Perbaikan Bug Inti)

#### 🛡️ Backend - Go Fiber & PostgreSQL
- **Endpoint Riwayat Instansi**: Menambahkan `GET /api/v1/incidents/agency/history` untuk mengambil data SOS yang telah selesai (`resolved`, `false_alarm`, `cancel`).
- **Real-Time Trust Label**: Mengubah logika `reporter_trust_label` dari berbasis JWT *Locals* menjadi kueri *real-time* ke tabel `user_profiles` (`GetTrustLabel`).
- **Fix Sinkronisasi Array PostgreSQL**: Memperbaiki fungsi `UploadEvidence` yang gagal menyimpan array gambar bukti (menggunakan konversi ke `pq.StringArray`).

#### 🖥️ Desktop Console (Instansi)
- **Halaman Riwayat SOS**: Membuat UI interaktif `riwayat_sos_page.dart` yang mendukung pemilahan insiden masa lalu menggunakan chip navigasi (Selesai Kami, Selesai Instansi Lain, Selesai Relawan, False Alarm, Dibatalkan).
- **Update Integrasi Model**: Modifikasi `IncidentModel` untuk membaca `reporter_trust_label` langsung dari API JSON, menghapus *workaround* logika yang kadaluarsa.

---

### 🔖 Patch 1.0.16 - 9 Mei 2026 (Fitur Operasi Relawan Real-Time & Pemetaan)

#### 🛡️ Backend - Go Fiber & PostgreSQL
- **Endpoint Nearby SOS**: Menambahkan `GET /api/v1/incidents/nearby` untuk mengambil daftar SOS aktif di sekitar relawan berdasarkan radius (Haversine formula).
- **Endpoint Accept SOS**: Menambahkan `POST /api/v1/incidents/:id/accept` dengan transaction SQL (`FindNearby()`, `AcceptIncident()`) untuk memvalidasi dan menerima misi SOS. Menyimpan ke tabel `incident_responses`.
- **Status Relawan**: Memperkenalkan turunan field `volunteer_status` (none, pending, approved) di `ProfileResponse` berbasiskan record `volunteer_certifications`.
- **Middleware**: Menambahkan RBAC `VolunteerOnly()`.

#### 📱 Mobile App (SiagaKita Warga/Relawan)
- **Relawan Dashboard Redesign**: Merombak total `RelawanMainScreen`. Menambahkan _XP progress bar_, _Duty toggle_, Radar SOS _real-time_ (polling 30s), _BottomSheet_ detail misi, tombol _Terima_, dan daftar Riwayat Misi.
- **Peta Interaktif Masyarakat & Relawan**: Memperbarui `MapScreen` secara masif:
  - Polling GPS setiap 10 detik.
  - _Reverse geocoding_ alamat menggunakan Nominatim API (di-_cache_).
  - Indikator status transmisi dinamis berdasarkan koneksi internet dan akurasi GPS.
  - Menampilkan _marker_ SOS di sekitar untuk relawan yang sedang _ON DUTY_.
- **Reputasi Relawan**: Menambahkan kartu Reputasi Relawan di layar profil (menampilkan XP, level, dan persentase _progress_) khusus pengguna _approved_.
- **Fix Data Type**: Menyempurnakan pembacaan tipe data `volunteer_reputation` dan perhitungan `volunteerLevel`.

#### 🖥️ Desktop Console (Instansi)
- **Auto-Refresh Data**:
  - Halaman `sos_aktif_page.dart` kini memiliki pewaktu 15 detik untuk memuat ulang data latar agar tampilan tersinkron. Jika SOS telah selesai/dibatalkan, detail pilihan akan tertutup otomatis.
  - Halaman `laporan_masuk_page.dart` kini menggunakan pewaktu 30 detik *auto-refresh* dan dilepas (_dispose_) dengan benar dari memori saat halaman ditutup.

---

### 🔖 Patch 1.0.15 - 8 Mei 2026 (Fitur Background Service & Pelacakan Online/GPS Real-time)

#### 📱 Mobile App (SiagaKita Warga)
- **Background Service**: Mengimplementasikan `flutter_background_service` untuk menjaga koneksi dan mengirim heartbeat setiap 30 detik tanpa campur tangan antarmuka UI. Menjamin fitur ini berjalan pada latar belakang walaupun aplikasi sedang terminimize.
- **Background Location**: Integrasi izin `ACCESS_BACKGROUND_LOCATION` serta permintaan pembatalan mode optimasi baterai (`ignoreBatteryOptimizations`).
- **Telemetry Broadcasting**: Aplikasi akan mengirim HTTP `PUT /api/v1/telemetry/location` untuk mengupdate kordinat GPS secara berkala di latar belakang, khusus ketika pengguna (relawan) mengaktifkan mode _"On Duty"_.

#### 🛡️ Backend - Go Fiber & Redis
- **True Online Status via Redis**: Mengganti status "Last Active" di database relasional menggunakan infrastruktur Redis TTL key (`user:online:{userId}`). Middleware `TouchLastActive` kini diinjeksi dengan klien Redis, memungkinkan deteksi status koneksi yang sangat efisien. Status *Online* kedaluwarsa secara otomatis dalam 90 detik setelah *heartbeat* terakhir gagal diterima.
- **Role-based Broadcast (Hub)**: Modul `Hub` WebSockets direfaktor untuk merekam `Role` setiap *client*. Memperkenalkan fungsi `BroadcastToRole` yang memungkinkan *backend* memancarkan data GPS secara *live* khusus ke administrator/agensi yang dituju.
- **Online-Status Bulk Fetching**: Endpoint baru `POST /api/v1/telemetry/online-status` untuk mendukung pengambilan data status kolektif melalui *Redis Pipeline*.

#### 🖥️ Desktop Console (Instansi)
- **Peta Operasional Real-time**: Layar *Peta Operasional* kini berlangganan *event* `VOLUNTEER_LOCATION_UPDATE` via WebSocket. Menampilkan markah (marker 🟢) hijau di peta yang melacak pergerakan dinamis relawan di lapangan layaknya radar navigasi sungguhan.
- **WebSocket Enum Patch**: Memperbaiki masalah kompiler terkait pencocokan eksklusif *Enum* di *Dart* karena hadirnya event *volunteer location* yang baru.

---

### 🔖 Patch 1.0.14 - 8 Mei 2026 (Bugfix Inti: Semua Tipe Laporan & Urgency Nullable)

#### 🛡️ Backend - Perbaikan Kritis

- **Fix "Semi-Simulasi" Pelaporan**: Menambahkan tipe insiden `accident` (Kecelakaan) dan `disaster` (Bencana Alam) ke daftar `validIncidentTypes` dan `incidentTypeMultiplier` di `incident/service.go`. Sebelumnya hanya tipe `fire`, `medical`, `crime`, `rescue`, dan `general` yang diterima backend - sehingga laporan kebakaran dan kecelakaan dari mobile selalu ditolak dengan error *"tipe insiden tidak valid"*. Multiplier XP untuk tipe baru: `accident` = 1.3×, `disaster` = 1.4×.
- **Hapus Dead Code**: Menghapus fungsi `parseInt()` yang tidak terpakai di `incident/handler.go` (setelah refactoring sebelumnya tidak ada pemanggil tersisa).
- **Fix Lint S1016** (`admin/repository.go`): Menyederhanakan fungsi `GetUsers()` dengan menghapus struct lokal `row` yang identik dengan `AdminUserItem`, lalu scan GORM langsung ke `[]AdminUserItem`. Mengurangi ~20 baris boilerplate.

#### 📱 Mobile App - Perbaikan Kompatibilitas

- **`urgencyLevel` Nullable** (`report_service.dart`): Field `urgencyLevel` di `ReportModel` diubah dari `required int` menjadi `int?` (nullable). Ini selaras dengan migrasi `011_reports_and_volunteer.sql` yang menghapus constraint `NOT NULL` pada kolom `urgency_level` di tabel `incident_reports`. Tingkat urgensi kini hanya ditentukan oleh agensi melalui Desktop Console, bukan oleh warga saat pelaporan. Default status parsing diperbarui dari `received` menjadi `sent`.
- **Fix Tampilan Urgency Chip** (`report_history_screen.dart`): Method `_urgencyColor()` diperbarui untuk menerima `int?` dan mengembalikan `Colors.grey` jika null. Chip urgensi di kartu riwayat laporan hanya ditampilkan jika `urgencyLevel` sudah diisi oleh agensi (tidak null) - mencegah chip kosong atau crash saat nilai masih null.

---

### 🔖 Patch 1.0.13 - 8 Mei 2026 (Refinement V5: Pendaftaran Relawan Asli & Offline Mode Pelaporan)

#### 📱 Perbaikan Mobile App (SiagaKita Warga)
- **File Upload Pendaftaran Relawan**: Fitur simulasi pendaftaran relawan kini telah diganti dengan fungsionalitas unggah file sungguhan menggunakan `file_picker`. Warga sekarang dapat memilih dan mengunggah dokumen PDF/JPG/PNG sebagai bukti sertifikasi keahlian medis atau evakuasi.
- **Offline Mode Pelaporan**: Menambahkan kemampuan aplikasi untuk menyimpan laporan (`status: failed`) secara lokal menggunakan `SharedPreferences` jika proses kirim ke server gagal akibat tidak ada koneksi internet.
- **Resend Laporan**: Pada tab Riwayat Laporan, warga kini dapat melihat laporan yang berstatus `failed` (Gagal/Offline) dan menekan tombol **"Kirim Ulang"** untuk mencoba mengirim laporan tersebut kembali setelah jaringan internet pulih.
- **Batal Laporan**: Warga dapat membatalkan laporan yang sudah terkirim (tetapi belum diproses) melalui tombol **"Batalkan"** di tab Riwayat Laporan.
- **Pemisahan UI Pelaporan**: Formulir "Buat Laporan" dan daftar "Riwayat Laporan" kini dipisahkan ke dalam dua buah *Tab* di layar "Pelaporan", memperbaiki navigasi serta membersihkan antarmuka utama. Menu Riwayat Laporan dari *Bottom Navigation Bar* telah digabungkan ke layar profil.

#### 🖥️ Perbaikan Desktop Console (Instansi)
- **Review Pengalaman Relawan**: UI KYC Relawan (`kyc_relawan_page.dart`) kini menampilkan riwayat **Pengalaman & Spesialisasi** yang dikirimkan calon relawan. Ini akan memudahkan Instansi dalam menilai kelayakan warga menjadi bagian dari tim First Responder.
- **Penyesuaian Model Admin**: Field `experience` telah diintegrasikan ke dalam `VolunteerModel` agar dapat di-_parse_ dari payload respons API `/admin/volunteers/pending`.

#### 🛡️ Backend & Migrasi
- **Constraint Level Urgensi**: Menghapus kewajiban pengisian (`not null constraint`) tingkat urgensi dari sisi pengguna dalam pembuatan laporan. Level urgensi sepenuhnya menjadi wewenang agensi peninjau di Desktop Console. Default status tabel laporan menjadi `sent`.
- **Integrasi File Relawan**: Modul `user_service` dan `handler` telah tersambung sepenuhnya dengan `file_picker`. Pengalaman relawan disimpan ke tabel profil, dan URL sertifikat dimasukkan secara terpisah ke dalam tabel relasional `volunteer_certifications`.

### 🔖 Patch 1.0.12 - 8 Mei 2026 (Refinement V4: Dispatch, Pelaporan & Manajemen Personil)

#### 📱 Perbaikan Mobile App (SiagaKita Warga)
- **Validasi Bukti Foto Pelaporan (Jalur B)**: Pelaporan insiden kini secara ketat mewajibkan unggahan minimal 1 foto sebelum laporan dapat dikirim.
- **Label Audio Opsional**: Form perekaman suara diberikan label eksplisit `(Opsional)` untuk menghindari kebingungan pengguna.

#### 🖥️ Perbaikan Desktop Console (Instansi)
- **Review Bukti Lapangan Terintegrasi**: Mengintegrasikan library `audioplayers` untuk menghadirkan pemutar rekaman suara (*slider*, *play/pause*) langsung di dalam dialog detail **Laporan Masuk** dan **SOS Aktif**. Bukti foto kini juga ditampilkan secara ringkas namun jelas.
- **Filter Status Laporan Lengkap**: Halaman **Laporan Masuk** kini dilengkapi filter tab komprehensif (`Sent`, `Accepted`, `Handled`, `Resolved`, `Rejected`, `Canceled`, dan `All`) untuk memudahkan triase insiden.
- **Simulasi Workflow Dispatch**: 
  - Dialog detail SOS dan Laporan Masuk sekarang menuntut pengguna untuk menugaskan personil melalui *dropdown* pilihan Agency Responder / Relawan (berlaku untuk status yang telah diterima / belum tertangani).
  - Mengubah fungsi penyelesaian laporan. Tombol *"Selesaikan Insiden"* dinonaktifkan sementara dan diganti dengan status *"MENUNGGU BUKTI"* setelah personil ditugaskan (status *Handled*), memastikan insiden hanya ditutup setelah validasi bukti lapangan (*field proof*).
- **Split-View Manajemen Personil**: Mengombak total UI **Manajemen Personil** menjadi layar terbelah (*split-view*). Sisi kiri berisi daftar Relawan & Personil simulasi dengan tombol untuk melakukan *Ban* (pemblokiran langsung pada akun personil agensi) atau pengajuan *Ban* (rekomendasi pemblokiran ke Admin Pusat untuk relawan publik).

#### 🛡️ Backend & Migrasi
- **Alur Status Default Laporan**: Logika *CreateReport* di `incident/service.go` diperbarui sehingga laporan warga yang baru dikirim akan masuk ke sistem dengan status `sent`, bukan `received`. Hal ini sesuai dengan standar penamaan alur triase `sent` -> `accepted`/`rejected` -> `handled` -> `resolved`.
- **Perbaikan Bug Golang**: Memperbaiki redeklarasi variabel `err` yang menyebabkan kegagalan _build_ pada fungsi `SubmitKYC`.

---

### 🔖 Patch 1.0.11 - 8 Mei 2026 (Refinement V2: Profile & Registration Flow)

#### 📱 Perbaikan Mobile App (SiagaKita Warga)
- **Biodata Pendaftaran Dinamis**: Layar pengisian biodata awal kini sepenuhnya terhubung ke endpoint backend. Pengguna dapat menambah banyak kontak darurat secara dinamis, serta memiliki opsi untuk "Lewati" yang diletakkan berdampingan dengan tombol Simpan. Layar ini juga telah mendukung lokalisasi `tr(context)`.
- **UX Kamera KTP**: Pilihan *upload* KTP dari galeri ditiadakan. Layar KYC kini memaksa pengguna mengambil foto secara langsung (*in-app*) melalui kamera belakang dengan overlay persegi panjang (*aspect ratio* proporsional KTP).
- **Profil Status Verifikasi**: Layar `ProfileScreen` menampilkan indikator visual (centang hijau atau tanda seru oranye/merah) untuk status verifikasi NIK, Email, dan WhatsApp secara instan tanpa perlu masuk ke layar edit.
- **Pemisahan Edit NIK & WhatsApp**: Menghilangkan pengaturan nomor telepon dari form `EditProfileScreen`. Pengubahan NIK dan Nomor WhatsApp (beserta pengiriman OTP-nya) dikhususkan melalui ikon tombol *edit* pada layar profil utama.

#### 🖥️ Perbaikan Desktop Console (Instansi)
- **Filter SOS Aktif**: Laporan insiden dengan status `cancel` (baik yang dibatalkan pada masa tunggi maupun dari sistem) tidak lagi diproses dan ditarik oleh Console, menghilangkan kerancuan penanganan SOS aktif.

#### 🛡️ Backend & Migrasi
- **Update Respon Profil**: API mereturn nilai sinkronisasi `nik_verification_status` ke antarmuka aplikasi.
- **Penyempurnaan Query Insiden**: Perubahan instruktural pada `FindAllActive` *repository* di Go untuk mengecualikan *row* insiden dengan nilai status `'cancel'`.

---

### 🔖 Patch 1.0.8 - 7 Mei 2026 (SOS Anti False-Alarm & Telemetri - Tahap 1-4)

#### 🛡️ Peningkatan Sistem Database & Backend
- **Migrasi SQL 008**: Menambahkan nilai `cancel` ke enum `incident_status`, menghapus `trigger_method`, dan menambahkan kolom array `photo_paths` serta `audio_path` ke tabel `incidents` untuk keperluan bukti penanganan SOS.
- **Locking Batal SOS**: Memodifikasi `MarkCancelled` di backend Go agar pengguna tidak dapat membatalkan insiden darurat yang sudah bersatus `handled`, `resolved`, atau `false_alarm`. Pembatalan dari sisi masyarakat kini menggunakan status `cancel`.
- **API Bukti SOS (Evidence)**: Membuat endpoint `POST /api/v1/incidents/:id/evidence` dengan tipe `multipart/form-data` untuk memfasilitasi pengambilan bukti lingkungan korban yang terjadi secara otomatis saat masuk fase penyiaran darurat (*broadcasting*).

#### 📱 Perbaikan Mobile App (SiagaKita Warga)
- **Otomatisasi Bukti SOS**: Mengimplementasikan background capture (1 foto kamera depan dan rekaman audio 5 detik) saat SOS beralih ke fase *broadcasting*. Jika pembatalan dilakukan di fase *grace period*, proses pembatalan tetap instan tanpa delay kamera.
- **Dashboard Telemetri Darurat**: Memperbarui banner SOS aktif untuk menampilkan telemetri waktu nyata:
  - Indikator koneksi transmisi khusus mode SOS (🟢 Transmitting / 🔘 Signal Lost).
  - Countdown timer (hitung mundur) menuju pembaruan lokasi berikutnya.
  - Timestamp waktu sukses terakhir lokasi diperbarui ke server instansi.
- **Panggilan Darurat Langsung**: Menambahkan blok `<queries>` untuk skema `tel` pada AndroidManifest.xml guna memperbaiki tombol "Telepon 112" yang sebelumnya tertahan oleh restriksi privasi Android terbaru.
- **Penyempurnaan Bahasa UI**: Melokalisasi string baru (Transmitting, Signal Lost, Next update) dan sisa string darurat yang formatnya Bahasa Inggris di dialog konfirmasi batal, teks "SOS AKTIF", dan peringatan.

---

### 🔖 Patch 1.0.9 - 7 Mei 2026 (Refactor Navbar, Telemetri Desktop & KYC Warga - Tahap 5-6)

#### 📱 Perbaikan Mobile App (SiagaKita Warga)
- **Navbar Riwayat**: Menggantikan tab "Panduan" di *bottom navigation bar* dengan tab "Riwayat" (`ReportHistoryScreen`) agar riwayat SOS dan laporan dapat diakses langsung tanpa harus masuk ke Profil terlebih dahulu.
- **KYC Screen**: Membuat layar baru `kyc_screen.dart` untuk warga mengajukan verifikasi identitas NIK. Fitur meliputi:
  - Upload foto KTP (kamera / galeri) dan selfie (opsional) menggunakan `image_picker`.
  - Status verification banner yang menampilkan status terkini (`none` / `pending` / `approved` / `rejected`).
  - Form validasi NIK 16 digit dan nama sesuai KTP.
- **Profile KYC Tile**: Menambahkan item "Verifikasi Identitas (KYC)" di halaman Profil dengan badge indikator status (✅ approved / ⏳ pending).
- **Lokalisasi**: Menambahkan string-string KYC dan "Riwayat" ke kamus English.

#### 🖥️ Perbaikan Desktop Console (Instansi)
- **Indikator Online/Offline Korban**: Menambahkan indikator real-time (🟢 Online / ⚫ Offline) pada panel detail dan baris daftar insiden SOS aktif. Status dihitung berdasarkan `updated_at` - korban dianggap **Online** jika lokasi diperbarui dalam 30 detik terakhir.
- **Timestamp Lokasi Terakhir**: Menampilkan pukul terakhir lokasi berhasil dikirim pada section "📡 TELEMETRI KORBAN" di panel detail insiden.
- **Auto-refresh**: Timer periodik 5 detik memperbarui status Online/Offline tanpa perlu memuat ulang seluruh daftar insiden.

#### 🛡️ Backend & Migrasi
- **Migrasi SQL 009** (`009_kyc_warga.sql`): Menambahkan kolom `kyc_ktp_url`, `profile_photo_url`, dan `nik_verification_status` (`none|pending|approved|rejected`) ke tabel `user_profiles`.

---

### 🔖 Patch 1.0.10 - 7 Mei 2026 (Refactor KYC, Profile & Volunteer)

#### 📱 Perbaikan Mobile App (SiagaKita Warga)
- **KYC & Foto Profil**: Memperbarui alur KYC. Foto KTP tetap wajib di-upload, namun porsi Selfie kini menggunakan widget in-app camera dan foto selfie tersebut otomatis dijadikan sebagai Foto Profil di dalam aplikasi.
- **In-App Camera**: Membuat widget `CustomCameraView` dengan overlay wajah berbentuk oval (khusus kamera depan) untuk KYC. Ini juga mengurangi ukuran/resolusi file sebelum di-upload ke server.
- **Navigasi Utama**: Mengembalikan tab "Panduan" ke urutan kedua *bottom navigation bar*, sehingga kini memiliki 5 tab menu.
- **Profile Screen**: 
  - Avatar profil menggunakan foto dari KYC.
  - Menampilkan informasi NIK di daftar info pribadi.
  - Badge KYC dipindah ke bawah nama pengguna dan dapat diklik untuk menuju layar verifikasi.
- **Pendaftaran Relawan**: Merombak layar `VolunteerRegistrationScreen`:
  - Menambahkan pengecekan *prerequisite* awal (NIK, nama, tgl lahir, nomor HP wajib terisi).
  - Mengubah spesialisasi relawan menjadi *multiple-selection* via Checkboxes.
  - Mewajibkan upload sertifikat untuk setiap spesialisasi yang dipilih.

#### 🛡️ Backend & Migrasi
- **Update Profil Schema**: Mengubah implementasi backend (DTO, repository, service) untuk menggunakan `kyc_ktp_url` untuk dokumen KTP, dan `profile_photo_url` untuk selfie wajah.
- **Fix Folder Upload**: Menambahkan pemanggilan `os.MkdirAll` di `SubmitKYC` agar server Go dapat membuat folder `/uploads/kyc` secara otomatis bila belum ada.
- **API KYC Warga**: Dua endpoint baru di bawah `/api/v1/users/`:
  - `POST /users/kyc` - Submit pengajuan verifikasi NIK (multipart: NIK, nama, foto KTP, selfie).
  - `GET /users/kyc/status` - Cek status pengajuan KYC.
- **Model Go**: Update `UserProfile` struct dengan field `KYCKtpURL`, `KYCSelfieURL`, `NIKVerificationStatus`.
- **IncidentModel (Desktop)**: Menambahkan field `updatedAt` ke `IncidentModel` serta computed getter `isOnline` dan `lastUpdateLabel`.

---

### 🔖 Patch 1.0.6 - 6 Mei 2026 (Perbaikan UX Izin Lokasi & GPS)

#### 🚀 Peningkatan UX Darurat (Location & GPS Handling)

- **Dialog Penjelasan Izin Kustom:** Saat aplikasi meminta akses lokasi dan user memilih "Jangan Izinkan" atau izin ditolak permanen, aplikasi tidak lagi sekadar membuka pengaturan perangkat secara buta. Kini muncul dialog penjelasan kustom mengenai mengapa SiagaKita membutuhkan akses lokasi untuk evakuasi darurat.
- **Pemisahan Error SOS (GPS Mati vs Izin Ditolak):** 
  - Jika GPS perangkat dimatikan: Tombol SOS akan gagal dengan pesan spesifik *"GPS perangkat Anda dimatikan"* dan otomatis membuka popup *Location Settings* dari OS.
  - Jika izin aplikasi belum diberikan: Pesan menjadi *"Izin akses lokasi belum diberikan"* dan dialog kustom perizinan lokasi akan otomatis muncul.
- **Menu Pengaturan Terintegrasi:** *Toggle* `Akses Lokasi Latar Belakang` di menu Pengaturan aplikasi tidak lagi berupa *mock state*. Toggle ini kini terkoneksi secara _real-time_ (dengan `WidgetsBindingObserver`) dengan status perizinan sesungguhnya di sistem operasi.
- **Refaktorisasi Exception:** `LocationService` kini memiliki exception yang spesifik: `LocationServiceDisabledException` dan `LocationPermissionException` untuk memfasilitasi integrasi UI yang lebih baik.

---

### 🔖 Patch 1.0.5 - 4 Mei 2026 (Sprint Stabilisasi)

#### 🔴 Fitur Baru: Offline Mode & Session Management

- **`SessionService`** (`lib/core/services/session_service.dart`) - menyimpan `token`, `userId`, dan data user (nama, email, role) ke `SharedPreferences`. Data tetap tersedia meski app ditutup.
- **`ConnectivityService`** (`lib/core/services/connectivity_service.dart`) - memantau status internet secara real-time via `connectivity_plus`. Exposes `ValueNotifier<bool> isOnline`.
- **`_AppStartup`** di `main.dart` - widget startup yang memeriksa sesi tersimpan. Jika valid → langsung ke `MainScreen` tanpa login ulang (meski offline).
- **Indikator Koneksi di Header** `HomeScreen` - dot ● berubah warna (hijau = Online, abu = Offline) plus label teks dinamis di bawah nama user.
- **Skip Fetch Profil saat Offline** (`MainScreen._fetchProfile`) - jika tidak ada koneksi, langsung gunakan data sesi ter-cache tanpa hit server.

#### 🔴 Fitur Baru: SOS Anti-Gagal (Robust SOS)

- **Grace Period Instan** - tombol SOS langsung memberikan feedback visual (UUID lokal) tanpa menunggu respon server. Ini mencegah user menekan SOS berulang kali karena dikira tidak berfungsi.
- **Background Retry Loop** - jika pengiriman SOS ke server gagal (jaringan tidak stabil), mekanisme retry otomatis setiap **5 detik** berjalan selama app terbuka dan user belum membatalkan.
- **Badge Status Upload** - UI menampilkan status `Mengirim...` → `Terkirim ✓` pada banner SOS aktif.
- **Local-to-Server ID Swap** - UUID lokal ditukar dengan Server ID begitu respon berhasil diterima.

#### 🔴 Fitur Baru: Profil & Verifikasi

- **Backend `PUT /api/v1/users/profile`** - endpoint baru untuk update profil (biodata + data medis + kontak darurat). Proses dilakukan dalam satu transaksi GORM (soft-delete kontak lama → insert baru).
- **NIK di Profile Screen** - menampilkan NIK pengguna (bukan UUID internal). Jika NIK belum ada, tampilkan tombol "Verifikasi Identitas (NIK)".
- **Badge Verifikasi HP** - icon ✅ (terverifikasi) atau ⚠️ (belum) di samping nomor WhatsApp.
- **OTP WhatsApp wajib** - jika user mengubah nomor HP di Edit Profile, maka OTP 6-digit dikirim ke nomor baru via WhatsApp sebelum data disimpan.
- **Label WhatsApp** - field nomor HP diubah label menjadi "Nomor WhatsApp Aktif" dengan prefix icon.

#### 🔑 Keamanan: Clear Session saat Logout

- Semua screen (masyarakat, relawan, admin, instansi) kini memanggil `SessionService.clearSession()` sebelum navigate ke `LoginScreen`. Sebelumnya sesi tersimpan tidak dihapus saat logout.

#### 📦 Dependencies Baru (`pubspec.yaml`)

| Package | Versi | Kegunaan |
|---------|-------|----------|
| `shared_preferences` | ^2.5.5 | Penyimpanan sesi lokal persisten |
| `connectivity_plus` | ^6.1.5 | Monitor status jaringan |
| `uuid` | ^4.5.3 | Generate UUID lokal untuk SOS sebelum server reply |

---

### 🔖 Patch 1.0.4 - 1 Mei 2026 (Sesi Ini)

#### 🐛 Bugfix & Arsitektur Auth

**[KRITIS] Ghost Account & Timeout Pendaftaran**
- **Masalah:** Jika server SMTP lambat atau gagal, aplikasi Flutter stuck (tidak ada timeout). Saat user menekan "kembali", request dibatalkan di client namun data `users` sudah terlanjur di-commit di backend, menghasilkan "Ghost Account" yang bisa login meskipun belum diverifikasi OTP.
- **Perbaikan Backend:**
  - `repo.CreateUserWithProfile()` - Operasi pembuatan `users` dan `user_profiles` digabung ke dalam satu transaksi atomik.
  - `Register()` diubah agar memanggil `DeleteUserByEmail` (menghapus user yang unverified) jika *email* sudah pernah gagal OTP sebelumnya, memungkinkan pendaftaran ulang dengan lancar.
  - `Login()` diubah: kini secara tegas memblokir akun yang `IsEmailVerified = false`.
- **Perbaikan Flutter:** Menambahkan timeout konfigurasi (10s untuk SOS, 15s untuk regular, 30s untuk auth) menggunakan helper function `_post` dan `_req`.
- **File Terdampak:** `auth_service.dart`, `incident_service.dart`, `backend-go/internal/domain/user/service.go`, `repository.go`.

---

### 🔖 Patch 1.0.3 - 1 Mei 2026

#### 🚀 Deployment Infrastruktur (VPS)

- **Masalah:** Aplikasi Flutter masih memakai IP lokal `10.0.2.2` dan `localhost`.
- **Penyelesaian:** 
  - Centralized IP configuration di `api_config.dart` (Mobile) dan `api_constants.dart` (Desktop). IP diubah menunjuk ke `139.59.99.230`.
  - Penyiapan `docker-compose.prod.yml` khusus VPS (dengan port `8080` dan `8081` diekspos).
  - Pembuatan skrip `setup_server.sh` untuk inisialisasi VPS awal dan dokumentasi lengkap di `DEPLOYMENT_GUIDE.md`.

---

### 🔖 Patch 1.0.2 - 1 Mei 2026


#### 🐛 Bugfix

**[KRITIS] Desktop console routing ke endpoint yang salah**
- **Masalah:** `windows_console_flutter` memanggil `POST /auth/login` (endpoint mobile) → backend menolak dengan error "akun ini bukan akun masyarakat atau relawan"
- **Perbaikan:** `api_constants.dart` diupdate: `/auth/login` → `/auth/console/login`
- **File:** `windows_console_flutter/lib/core/constants/api_constants.dart`

**[SECURITY] Pesan error `/auth/login` membocorkan role**
- **Masalah:** Jika akun admin/agency mencoba login di `/auth/login`, error message-nya adalah *"akun ini bukan akun masyarakat atau relawan"* - membocorkan informasi role enumeration
- **Perbaikan:** Pesan diubah menjadi generik: *"email atau password salah"*
- **File:** `backend-go/internal/domain/user/service.go` → `Login()`

---

### 🔖 Sprint G - 3 Mei 2026

#### Mobile Flutter: Report Screen - Implementasi Penuh

**Peta GPS Nyata (OpenStreetMap)**
- Mengganti simulasi peta palsu (grid kotak) dengan widget `FlutterMap` (tile OSM) yang sesungguhnya.
- Mengambil koordinat GPS pengguna via `LocationService.getCurrentPositionOrNull()` saat layar dibuka.
- Melakukan *reverse geocoding* ke Nominatim API untuk menampilkan nama jalan/alamat di bawah peta.
- Tombol refresh lokasi tersedia jika GPS tidak terdeteksi pertama kali.

**Lampiran Multi-Foto (Maks. 3)**
- Mengimplementasikan `image_picker` untuk memilih foto dari kamera atau galeri.
- Foto ditampilkan sebagai thumbnail grid dengan tombol ✕ untuk menghapus.
- Kompresi otomatis via `flutter_image_compress`: resolusi maks 1280×960px, kualitas JPEG 70% → target ~150–300 KB/foto.
- Antarmuka menampilkan penghitung `0/3`, `1/3`, dst.

**Perekaman Audio (Hold-to-Record)**
- Mengimplementasikan *hold-to-record* via `record`: rekam mulai saat jari ditekan (`onLongPressStart`), berhenti saat dilepas (`onLongPressEnd`).
- Konfigurasi rekaman: AAC/M4A, 22050 Hz, 64 kbps → target ~500 KB/menit.
- Menampilkan timer detik dan animasi pulsasi merah selama rekaman berlangsung.
- Setelah rekam selesai: tampilkan durasi + tombol ▶️ putar ulang dan 🗑️ hapus.

**Konfirmasi Sebelum Kirim**
- Menampilkan `showModalBottomSheet` ringkasan laporan (kategori, lokasi, urgensi, jumlah foto/audio) sebelum request dikirim ke API.
- Dua tombol: **Batal** (tutup sheet) dan **Kirim Sekarang** (eksekusi API).

**Pengiriman ke API (Multipart)**
- Membuat `ReportService` baru (`lib/core/services/report_service.dart`) dengan:
  - `submitReport()`: `POST /api/v1/reports` dengan `multipart/form-data` (foto + audio).
  - `getMyReports()`: `GET /api/v1/reports/my` untuk riwayat laporan.
- Loading indicator saat upload berlangsung; pesan error jika API gagal.

**Perbaikan Warna Tombol**
- Tombol "Kirim Laporan" sekarang selalu berwarna `primaryColor` (oranye), tidak lagi berubah merah saat urgensi Kritis dipilih.

**Halaman Riwayat Laporan**
- Membuat `ReportHistoryScreen` baru yang dapat diakses dari `ProfileScreen`.
- Menampilkan daftar laporan dengan status berwarna (Diterima/Diproses/Selesai), kategori, urgensi, dan lampiran.
- State kosong dan tombol retry jika API error.
- Dukungan pull-to-refresh.

**Perizinan Android**
- Menambahkan izin `CAMERA`, `RECORD_AUDIO`, `READ_MEDIA_IMAGES`, `READ/WRITE_EXTERNAL_STORAGE` ke `AndroidManifest.xml`.
- Menambahkan `FileProvider` dan `file_paths.xml` untuk kebutuhan `image_picker`.

#### Backend Go: Upload File & Report API v2

**Endpoint Upload Multipart**
- `POST /api/v1/reports` sekarang menerima `multipart/form-data`.
- Foto (maks. 3, maks. 2 MB/file) disimpan ke `$UPLOAD_DIR/reports/photos/{year}/{month}/{user_id}/`.
- Audio (maks. 1, maks. 5 MB) disimpan ke `$UPLOAD_DIR/reports/audio/{year}/{month}/{user_id}/`.
- URL publik file dikembalikan dalam response dan disimpan ke database.

**Static File Serving**
- Menambahkan route `GET /uploads/*` di Fiber untuk menyajikan file upload langsung dari backend Go (tanpa Nginx tambahan).

**Endpoint Riwayat Laporan**
- Menambahkan `GET /api/v1/reports/my` (protected, citizen/volunteer) untuk mengambil daftar laporan milik pengguna yang sedang login.

**Migrasi Database**
- Menambahkan `migrations/005_reports_v2.sql`: tabel `incident_reports` diperbarui dengan kolom `photo_paths TEXT[]`, `audio_path TEXT`, `urgency_level SMALLINT` (menggantikan `photo_url`, `audio_url`, dan `urgency VARCHAR`).
- Migrasi data lama secara otomatis dari tabel lama ke tabel baru.

**Konfigurasi**
- Menambahkan `UPLOAD_DIR` dan `UPLOAD_BASE_URL` ke `Config` dan `.env`.
- Menambahkan `volumes` mount di `docker-compose.prod.yml`: `/opt/siagakita/uploads:/app/uploads`.
- Menambahkan dependensi Go: `github.com/lib/pq` untuk dukungan `pq.StringArray` (kolom `TEXT[]` PostgreSQL).

---

### 🔖 Sprint F - 2 Mei 2026

#### Mobile Flutter: Masyarakat Role & SOS Refactoring

**User Profile & Settings API**
- Menambahkan `UserService` di `lib/core/services/user_service.dart` untuk memuat (`GET /users/profile`) dan memperbarui data profil pengguna (`PUT /users/profile`).
- Memperbarui `MainScreen` (`main_screen.dart`) untuk otomatis menarik data profil (*fetch*) pada saat inisialisasi awal aplikasi.
- Menyempurnakan `EditProfileScreen` dengan state *loading* dan mengintegrasikan fungsi ubah profil secara penuh dengan API `UserService.updateProfile`.
- Memperbaiki fitur *Logout* pada `ProfileScreen` untuk membersihkan otentikasi sesi (mengosongkan nilai *ValueNotifier* `UserModel.currentUser.value` ke state *default*) dan mengalihkan (_pushAndRemoveUntil_) ke `LoginScreen`.

**Dashboard Beranda & Refaktorisasi Alur Darurat SOS**
- Merombak Header pada `HomeScreen` untuk tidak hanya menampilkan teks generik, melainkan menampilkan secara dinamis **Nama Pengguna** (menggunakan `ValueListenableBuilder` pada `UserModel.currentUser`) beserta **Role Akun** mereka (mis. Masyarakat / Relawan) dalam badge warna hijau/merah.
- **Dihapus (Efisiensi UX Darurat):** Menghilangkan dialog pop-up konfirmasi tunggu 5 detik saat akan mengirimkan SOS (`_showSendConfirmation`). Sekarang ketukan 5 kali akan memicu API SOS seketika (*instant trigger*).
- **Dihapus (Efisiensi UX Darurat):** Menghilangkan dialog pop-up konfirmasi pembatalan SOS (`_showCancelConfirmation`). Mengetuk SOS 5 kali saat sudah _broadcasting_ langsung menghentikan sinyal tanpa intervensi pop-up.
- **Penggabungan UX Pembatalan & Grace Period:** Layar 10-detik _Grace Period_ (layar pemilihan tipe insiden pasca aktivasi SOS) kini murni berfungsi sebagai titik pembatalan (dengan tombol "Batalkan SOS" di layar) sehingga mengurangi langkah ekstra saat _False Alarm_.

---

### 🔖 Sprint E - 2 Mei 2026

#### Desktop Console: UI/UX Polish & Bug Fixes

**Superadmin Dashboard UI Improvements**
- Mengubah background `Scaffold` menjadi `Color(0xFF0F172A)` agar warna tema gelap (dark mode) konsisten secara keseluruhan dan teks tidak menghilang di atas background terang.
- Menyesuaikan _opacity_ ikon _placeholder_ dan teks pada halaman Gamifikasi agar mudah terlihat di atas background gelap.
- Perbaikan layout status pengguna di tab Manajemen Pengguna menggunakan `Align` agar lebar _background_ indikator status tidak melebar dan menutupi tombol _Aksi_.
- Memperbaiki indikator tab pada halaman Pendaftaran Akun (`TabBarIndicatorSize.tab`) sehingga garis _highlight_ mencakup keseluruhan lebar tab.

**Fungsionalitas Interaktif & Peta**
- Menambahkan input pencarian berbasis teks pada komponen peta Pendaftaran Akun Instansi, menggunakan API _reverse geocoding_ dari Nominatim (OpenStreetMap).
- Penerapan logika pengambilan data _reverse geocoding_ otomatis saat peta diklik/dicari untuk mengisi _field_ "Kode Kota" berupa 3 huruf (singkatan kota) berdasarkan lokasi kordinat.
- Menambahkan efek _hover_ (perubahan _cursor_ dan _highlight_) pada tombol navigasi (_FilterChip_) dan tombol _ActionBtn_ (Ban/Unban) di Manajemen Pengguna.

**Logika Pemblokiran (Ban/Unban)**
- Menyempurnakan _popup_ pemblokiran di Manajemen Pengguna:
  - Teks pada tombol "Ban Sekarang" dibuat tebal dan putih agar kontras.
  - Menambahkan _input text field_ khusus untuk "Rentang waktu ban (hari)".
  - Memberikan batasan validasi; jika alasan pemblokiran kosong, tombol "Ban Sekarang" dinonaktifkan (_disabled_).
  - Melakukan konversi API parameter `days` untuk dikirimkan secara langsung ke `AdminApiService.banUser()`.
- Menambahkan proses _popup_ konfirmasi ketika aksi unban dilakukan agar admin tidak sengaja membuka blokir pengguna.

**Code Quality & Linting**
- Telah menyelesaikan seluruh masalah pada kode Flutter (_flutter analyze_), seperti penambahan kurung kurawal pada blok struktur `if`, penggunaan *named variables* ketimbang *underscore parameter* `(_, __)`, menghapus variabel yang tidak terpakai, serta menjaga agar `BuildContext` sinkron tidak dijalankan setelah asynchronous gaps (_use_build_context_synchronously_).

---

### 🔖 Sprint D - 1 Mei 2026

#### Backend: Restructuring Database + Role Expansion

**Schema Database v3** (`migrations/003_schema_v3.sql`)
- Tabel `users` dipersempit → hanya `id`, `email`, `password_hash`, `role`, `created_at`, `deleted_at`
- Tabel `user_medical_profiles` dihapus → diganti `user_profiles` (menampung semua profil citizen/volunteer)
- Tabel baru `admin_profiles` (nama admin/superadmin)
- Tabel `agencies` + kolom `account_id` (FK ke `users`)
- Tabel `agency_personnels` diperbarui
- ENUM `user_role` baru: `superadmin | admin | agency | agency_personnel | volunteer | civilian`
- `agency_responder` dihapus

**Backend Go - user domain diperbarui total**
- `model.go`: Slim `User` + baru `UserProfile`, `AdminProfile`, `AgencyPersonnel`
- `repository.go`: Semua query profil → `user_profiles`; strike/ban juga → `user_profiles`
- `service.go`: 3 login method (`Login`, `ConsoleLogin`, `PersonnelLogin`); Register membuat `users` + `user_profiles` dalam 1 transaksi
- `handler.go`: + handler `ConsoleLogin`, `PersonnelLogin`

**Backend Go - middleware RBAC baru**
- `RequireRoles()` - generic, composable
- `AdminOnly()` - admin + superadmin
- `ConsoleOnly()` - superadmin + admin + agency
- `AgencyOnly()` - agency + admin + superadmin
- `CitizenVolunteer()` - civilian + volunteer saja
- `PersonnelOnly()` - agency_personnel saja

**Backend Go - domain admin baru** (`domain/admin/`)
- KYC: `GET /admin/volunteers/pending`, `POST /admin/volunteers/:id/approve`, `POST /admin/volunteers/:id/reject`
- User Management: `GET /admin/users`, ban, unban, reset strike
- Ranks: CRUD `GET/POST/PUT/DELETE /admin/ranks/:id`
- Stats: `GET /admin/stats` (aggregat per tipe, status, bulanan, avg respons)

**Superadmin auto-seed**
- `seedSuperAdmin()` dipanggil di startup `main.go`
- Baca `SUPERADMIN_EMAIL` + `SUPERADMIN_PASS` dari `.env`
- Buat atau update akun superadmin otomatis

**Mobile Flutter - `auth_service.dart`**
- `UserInfo.fullName` diubah ke `String?` (nullable, sesuai response backend baru)
- Field `isEmailVerified`, `isPhoneVerified`, `isVerifiedVolunteer` dihapus dari `UserInfo` (kini ada di `GET /users/profile`)

---

### 🔖 Sprint C - 30 April 2026

#### Desktop Console - Modul Admin

- `kyc_relawan_page.dart` - UI verifikasi relawan
- `user_management_page.dart` - Tabel user + strike/ban UI
- `gamifikasi_page.dart` - CRUD master rank
- `statistik_page.dart` - KPI + chart analitik
- `admin_shell.dart` - Sidebar untuk role admin/superadmin

---

### 🔖 Sprint: Performance & Reliability Refactor - 13 Mei 2026

#### Fokus: Optimalisasi Low-Latency & High-Throughput

- **Backend (Go):**
    - [x] Migrasi ke `Sonic` JSON engine (JIT Parsing).
    - [x] Implementasi `Zerolog` untuk logging terstruktur & asinkron.
    - [x] Dukungan log persistence ke `/opt/siagakita/logs/app.log`.
    - [x] Konfigurasi Connection Pool GORM (25 max connections).
- **Mobile (Flutter):**
    - [x] Optimalisasi `RepaintBoundary` pada tombol SOS & Telemetri.
    - [x] Offloading `jsonDecode` ke `Isolate.run()` pada `IncidentService`.
- **Console (Flutter Desktop):**
    - [x] Implementasi `RepaintBoundary` pada list insiden aktif.
    - [x] Offloading WebSocket parsing ke background Isolate di `WsService`.

---

### 🔖 Sprint B - 29–30 April 2026

#### Desktop Console - Modul Instansi

- `dashboard_operasi_page.dart` - KPI real-time + live SOS list + pie chart
- `sos_aktif_page.dart` - Detail korban, aksi false alarm/resolve, alarm control
- `laporan_masuk_page.dart` - Jalur B report management
- `peta_operasional_page.dart` - OpenStreetMap + SOS markers
- `ws_service.dart` - WebSocket singleton (auto-reconnect, event stream)
- `instansi_shell.dart` - Sidebar + WS connection indicator
- `app.dart` - SplashRouter: JWT session restore → route ke shell

---

### 🔖 Sprint A - 26–29 April 2026

#### Mobile - SOS Redesign & GPS Integration

- `home_screen.dart` - Mekanisme 5-ketukan, GPS tracking 1 menit, cancel SOS
- `auth_service.dart` - API client auth (register, login, OTP)
- `incident_service.dart` - SOS trigger, cancel, location update
- `location_service.dart` - GPS permission + position

#### Backend - OTP Domain

- `domain/otp/` - SMTP email OTP + Fonnte WA OTP
- Register: OTP ke email, rollback user jika SMTP gagal
- Login: Langsung JWT (tidak perlu OTP langkah dua)

---

## 4. Struktur File Terkini

```
siagakita/
├── backend-go/
│   ├── cmd/api/main.go              ✅ seedSuperAdmin, 3 login routes, admin routes
│   ├── internal/
│   │   ├── config/config.go         ✅ + SuperAdminEmail, SuperAdminPass
│   │   ├── middleware/auth.go       ✅ RBAC granular
│   │   └── domain/
│   │       ├── user/                ✅ v3 slim auth + user_profiles
│   │       │   ├── model.go         ✅ User, UserProfile, AdminProfile, AgencyPersonnel
│   │       │   ├── repository.go    ✅ query ke user_profiles
│   │       │   ├── service.go       ✅ 3 login method
│   │       │   └── handler.go       ✅ + ConsoleLogin, PersonnelLogin handler
│   │       ├── admin/               🆕 BARU
│   │       │   ├── model.go         🆕 VolunteerKYC, AdminUserItem, StatsResponse
│   │       │   ├── repository.go    🆕 KYC, ban/unban, rank CRUD, stats
│   │       │   ├── service.go       🆕 validasi bisnis
│   │       │   └── handler.go       🆕 semua handler Sprint D
│   │       ├── incident/            ✅ + strike/ban query → user_profiles
│   │       ├── otp/                 ✅
│   │       └── telemetry/           ✅
│   └── migrations/
│       ├── 001_init_schema.sql      (lama, tidak dipakai lagi)
│       └── 003_schema_v3.sql        ✅ Schema aktif saat ini
│
├── infrastructure/
│   ├── .env                         ✅ + SUPERADMIN_EMAIL, SUPERADMIN_PASS
│   └── .env-example                 ✅ + SUPERADMIN_EMAIL, SUPERADMIN_PASS template
│
├── mobile-flutter/
│   └── lib/
│        ├── core/services/
│        │   ├── auth_service.dart      ✅
│        │   ├── incident_service.dart  ✅
│        │   ├── user_service.dart      ✅ GET+PUT profile, OTP phone
│        │   ├── session_service.dart   🇨 BARU - simpan/baca/hapus sesi lokal
│        │   └── connectivity_service.dart 🇨 BARU - monitor online/offline
│        └── features/
│            ├── auth/                  ✅ + simpan sesi setelah login
│            ├── masyarakat/            ✅ SOS instan+retry; NIK di profil; OTP WA edit HP
│            ├── relawan/               ✅ + clearSession logout
│            ├── admin/                 ✅ + clearSession logout
│            └── instansi/              ✅ + clearSession logout
│
├── windows_console_flutter/
│   └── lib/
│       ├── core/constants/
│       │   └── api_constants.dart   ✅ Fix: login → /auth/console/login
│       ├── app.dart                 ✅ SplashRouter
│       └── features/
│           ├── instansi/            ✅ Semua halaman selesai
│           └── admin/               ✅ Semua halaman selesai
│
└── docs/
    ├── FRONTEND_STRUCTURE.txt       ✅ Diperbarui 4 Mei 2026
    └── DESKTOP_PLANNING_ADMIN_INSTANSI.txt  ✅ Diperbarui 1 Mei 2026
```

---

## 5. API Endpoint Lengkap

Base URL: `http://<host>:8080/api/v1`

### Auth (Public)

| Method | Endpoint | Untuk Role | Keterangan |
|--------|----------|------------|-----------|
| POST | `/auth/register` | civilian | Daftar → OTP email |
| POST | `/auth/verify-register-otp` | - | Verifikasi OTP → JWT |
| POST | `/auth/login` | civilian, volunteer | Login langsung → JWT |
| POST | `/auth/console/login` | admin, superadmin, agency | Login Desktop Console → JWT |
| POST | `/auth/personnel/login` | agency_personnel | Login Mobile Responder → JWT |
| POST | `/auth/request-otp` | - | Kirim OTP WA (phone verification) |
| POST | `/auth/verify-otp` | - | Verifikasi OTP WA |

### Users (Protected - CitizenVolunteer)

| Method | Endpoint | Keterangan |
|--------|----------|-----------|
| GET | `/users/profile` | Profil dari `user_profiles` |
| PUT | `/users/profile` | 🇨 Update profil + data medis + kontak darurat |
| POST | `/users/biodata` | Biodata awal (upsert, dipakai pasca-register) |
| POST | `/users/phone/request-otp` | Kirim OTP 6-digit via WhatsApp ke nomor baru |
| POST | `/users/phone/verify-otp` | Verifikasi OTP → update nomor + set is_phone_verified |

### Incidents (Protected - semua role)

| Method | Endpoint | RBAC | Keterangan |
|--------|----------|------|-----------|
| GET | `/incidents/active` | - | Cek SOS aktif |
| POST | `/incidents/trigger` | - | Kirim SOS |
| POST | `/incidents/:id/cancel` | - | Batalkan SOS |
| PUT | `/incidents/:id/location` | - | Update GPS tiap 1 menit |
| PATCH | `/incidents/:id/type` | - | Set tipe insiden |
| POST | `/incidents/:id/broadcast` | - | Broadcast SOS |
| GET | `/incidents/nearby` | VolunteerOnly | Daftar SOS di radius tertentu |
| POST | `/incidents/:id/accept` | VolunteerOnly | Relawan menerima misi SOS |
| POST | `/incidents/:id/mark-false-alarm` | ConsoleOnly | Tandai false alarm |
| POST | `/incidents/:id/resolve` | ConsoleOnly | Selesaikan insiden |
| GET | `/incidents/agency/history` | ConsoleOnly | Riwayat insiden khusus instansi |

### Reports - Jalur B (Protected)

| Method | Endpoint | RBAC | Keterangan |
|--------|----------|------|-----------|
| POST | `/reports` | - | Kirim laporan non-darurat |
| GET | `/reports` | ConsoleOnly | Daftar laporan |
| PATCH | `/reports/:id/status` | ConsoleOnly | Update status laporan |

### Admin (Protected - AdminOnly / ConsoleOnly)

| Method | Endpoint | RBAC | Keterangan |
|--------|----------|------|-----------|
| POST | `/admin/admins` | SuperAdminOnly | Buat akun admin baru |
| POST | `/admin/agencies` | AdminOnly | Mendaftarkan instansi baru |
| GET | `/admin/volunteers/pending` | AdminOnly | Antrian KYC |
| POST | `/admin/volunteers/:id/approve` | AdminOnly | Approve KYC |
| POST | `/admin/volunteers/:id/reject` | AdminOnly | Reject KYC |
| GET | `/admin/users` | AdminOnly | Daftar user + filter |
| POST | `/admin/users/:id/ban` | AdminOnly | Ban SOS user |
| POST | `/admin/users/:id/unban` | AdminOnly | Cabut ban |
| DELETE | `/admin/users/:id/strike` | AdminOnly | Reset strike count |
| GET | `/admin/ranks` | ConsoleOnly | Master data rank |
| POST | `/admin/ranks` | AdminOnly | Tambah rank |
| PUT | `/admin/ranks/:id` | AdminOnly | Edit rank |
| DELETE | `/admin/ranks/:id` | AdminOnly | Hapus rank |
| GET | `/admin/stats` | ConsoleOnly | Statistik & analitik |

### Agencies (Protected - AgencyOnly)

| Method | Endpoint | RBAC | Keterangan |
|--------|----------|------|-----------|
| POST | `/agencies/personnels` | AgencyOnly | Daftarkan petugas lapangan instansi |

### Telemetry & WebSocket

| Method | Endpoint | Keterangan |
|--------|----------|-----------|
| PUT | `/telemetry/location` | Update lokasi real-time |
| POST | `/incidents/sms-fallback` | SMS fallback (API Key) |
| WS | `ws://<host>:8081/ws/connect` | WebSocket persistent |

---

## 6. Schema Database (v3 - Aktif)

> **Migration aktif:** `backend-go/migrations/003_schema_v3.sql`
> **Dijalankan:** 1 Mei 2026

### Tabel Inti

| Tabel | Deskripsi | Role yang Terkait |
|-------|-----------|------------------|
| `users` | Auth gateway saja (id, email, password_hash, role) | Semua role |
| `user_profiles` | Profil lengkap citizen/volunteer | civilian, volunteer |
| `admin_profiles` | Nama admin/superadmin | admin, superadmin |
| `agencies` | Data instansi + link ke akun agency | agency |
| `agency_personnels` | Data personel instansi | agency_personnel |
| `emergency_contacts` | Kontak darurat | civilian, volunteer |
| `incidents` | SOS darurat (Jalur A) | semua |
| `incident_reports` | Laporan non-darurat (Jalur B) | civilian, volunteer |
| `incident_responses` | Dispatch respons | volunteer, agency_personnel |
| `sos_strikes` | Audit log false alarm | - |
| `m_ranks` | Master data rank XP | - |
| `m_badges` | Master data badge | - |
| `volunteer_reputation` | XP + rank relawan | volunteer |
| `volunteer_certifications` | Sertifikat KYC relawan | volunteer |
| `volunteer_badges_acquired` | Badge yang diperoleh | volunteer |

### ENUM `user_role`

```sql
'superadmin' | 'admin' | 'agency' | 'agency_personnel' | 'volunteer' | 'civilian'
```

> ⚠️ `agency_responder` sudah **DIHAPUS** sejak Schema v3.

---

## 7. Yang Belum Selesai

### Prioritas Tinggi

- [ ] **Deploy backend** setelah tiap perubahan:
  ```bash
  sudo docker compose -f infrastructure/docker-compose.yml up --build -d backend
  ```
- [ ] **Isi `.env`** - `SUPERADMIN_EMAIL` dan `SUPERADMIN_PASS` harus diisi untuk seed superadmin
- [x] **Biodata Screen → API** - Wire `BiodataScreen` ke `POST /users/biodata`
- [x] **Profile Screen → API** - Wire `ProfileScreen` ke `GET /users/profile`
- [x] **Environment Security** - Pindah IP hardcode ke `.env`
- [ ] **Desktop Console → Admin endpoints** - Hubungkan halaman KYC, User Mgmt, Gamifikasi, Statistik ke endpoint `/admin/...`
- [ ] **Backend Refactor Phase 2** - Migrasi GORM pool ke `pgx` driver asli untuk performa raw query yang lebih tinggi.
- [ ] **Frontend Refactor Phase 2** - Refactor `Provider` ke `Selector`/`context.select` di Console App untuk optimalisasi build widget.

### Prioritas Sedang

- [ ] **Dispatch Relawan** - Halaman masih placeholder (Sprint B.4)
- [ ] **Mobile Responder App** - Proyek baru `mobile-flutter-responder/` untuk role `agency_personnel`
- [ ] **Audio Alarm** - `assets/audio/alarm.mp3` masih placeholder, ganti dengan file sirine sungguhan
- [ ] **Refresh token** - Auto-refresh saat `access_token` expired

### Prioritas Rendah / Masa Depan

- [ ] Push notification (FCM) untuk alert darurat
- [ ] Riwayat insiden per pengguna
- [ ] Granular RBAC untuk agency di Flutter (hide menu yang tidak diizinkan)
- [ ] Fitur volunteer_badges_acquired (gamifikasi penuh)

---

## 8. Panduan Setup untuk Anggota Baru

### Prasyarat

```bash
go version       # Go 1.23+
flutter --version # Flutter 3.x+
docker --version && docker compose version
```

### Langkah Setup

**1. Clone repository:**
```bash
git clone https://github.com/SuperBypassUdinnn/siagakita.git
cd siagakita
```

**2. Buat file environment:**
```bash
cp infrastructure/.env-example infrastructure/.env
# Edit infrastructure/.env dan isi:
# DB_USER, DB_PASSWORD, REDIS_PASSWORD
# JWT_SECRET (buat string acak panjang)
# SMTP_USERNAME, SMTP_PASSWORD, SMTP_FROM (untuk email OTP)
# FONNTE_TOKEN (daftar di fonnte.com)
# SUPERADMIN_EMAIL, SUPERADMIN_PASS (akun superadmin pertama)
```

**3. Jalankan infrastruktur:**
```bash
sudo docker compose -f infrastructure/docker-compose.yml up -d postgres redis pgadmin
```

**4. Jalankan migrasi database (schema v3):**
```bash
sudo docker exec -i siagakita_postgres psql \
  -U siagakita_admin -d siagakita \
  < backend-go/migrations/003_schema_v3.sql
```

**5. Build dan jalankan backend:**
```bash
# Via Docker (rekomendasi)
sudo docker compose -f infrastructure/docker-compose.yml up --build -d backend

# Atau langsung (dev)
cd backend-go && go run ./cmd/api/
```

> Saat server start, cek log untuk baris:
> `[SuperAdmin] Akun superadmin berhasil dibuat: <email>`

**6. Jalankan Flutter mobile:**
```bash
cd mobile-flutter && flutter pub get && flutter run
```

**7. Jalankan Desktop Console:**
```bash
cd windows_console_flutter && flutter pub get && flutter run -d linux
```

### Cara Akses

| Layanan | URL |
|---------|-----|
| REST API | `http://localhost:8080` |
| Health Check | `http://localhost:8080/health` |
| WebSocket | `ws://localhost:8081/ws/connect` |
| pgAdmin | `http://localhost:5050` |

> **Emulator Android:** Gunakan `10.0.2.2` sebagai alamat backend (bukan `localhost`).

### Login Console (Desktop)

| Role | Endpoint |
|------|----------|
| superadmin / admin / agency | `POST /auth/console/login` |
| civilian / volunteer | `POST /auth/login` |
| agency_personnel | `POST /auth/personnel/login` |

---

> 💬 **Pertanyaan?** Hubungi @SuperBypassUdinnn atau buat issue di repository.
