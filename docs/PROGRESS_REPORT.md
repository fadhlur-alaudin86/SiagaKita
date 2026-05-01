# 📋 SiagaKita — Laporan Kemajuan Pengembangan

> **Terakhir diperbarui:** 1 Mei 2026
> **Branch aktif:** `main`
> **Status keseluruhan:** 🟡 Dalam Pengembangan Aktif

---

## 🗂️ Daftar Isi

1. [Gambaran Arsitektur](#1-gambaran-arsitektur)
2. [Status Per Komponen](#2-status-per-komponen)
3. [Changelog Per Sprint](#3-changelog-per-sprint)
4. [Struktur File Terkini](#4-struktur-file-terkini)
5. [API Endpoint Lengkap](#5-api-endpoint-lengkap)
6. [Schema Database (v3 — Aktif)](#6-schema-database-v3--aktif)
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
| Mobile Citizen | Flutter (Dart) — `mobile-flutter/` |
| Desktop Console | Flutter Desktop — `windows_console_flutter/` |
| Mobile Responder | Flutter (belum dibuat) — `mobile-flutter-responder/` |
| Backend | Go 1.26 + Fiber v2 |
| Database | PostgreSQL 15 (Schema v3) |
| Cache / Ephemeral | Redis |
| Email OTP | SMTP (Gmail) |
| WA OTP | Fonnte API |
| Container | Docker Compose |

---

## 2. Status Per Komponen

### 🟢 Backend — Go Fiber

| Domain | Status | Keterangan |
|--------|--------|-----------|
| `domain/user/` | ✅ v3 | Slim auth, 3 login endpoints, transaksi user+profil |
| `domain/otp/` | ✅ | Email OTP (SMTP) + WA OTP (Fonnte) |
| `domain/incident/` | ✅ | SOS trigger, cancel, GPS update, resolve, false alarm |
| `domain/admin/` | ✅ Baru | KYC, manajemen user, rank CRUD, statistik |
| `domain/telemetry/` | ✅ | Location update, SMS fallback |
| `internal/hub/` + `ws/` | ✅ | WebSocket persistent registry |
| `internal/middleware/` | ✅ v3 | JWT Auth + RBAC granular (AdminOnly, ConsoleOnly, dll.) |
| `config/config.go` | ✅ | + SuperAdminEmail, SuperAdminPass |
| `cmd/api/main.go` | ✅ | seedSuperAdmin(), 3 login routes, admin routes |

### 🟡 Mobile Flutter — Citizen/Volunteer (`mobile-flutter/`)

| Layar | Status | Keterangan |
|-------|--------|-----------|
| Login | ✅ | `POST /auth/login` — hanya civilian/volunteer |
| Register | ✅ | 2-step: form → email OTP → JWT |
| Biodata | 🟡 | UI selesai, API belum terhubung |
| Home (SOS) | ✅ | 5-ketukan, GPS tracking, cancel SOS |
| Profile | 🟡 | UI selesai, query ke `user_profiles` (belum terhubung) |
| Map | 🔴 | Mock/static |
| Relawan Dashboard | 🟡 | UI selesai, data mock |

### 🟢 Desktop Console (`windows_console_flutter/`)

| Layar | Status | Keterangan |
|-------|--------|-----------|
| Login Console | ✅ **Fix** | Sekarang pakai `POST /auth/console/login` |
| InstansiShell | ✅ | Sidebar + WS indicator |
| Dashboard Operasi | ✅ | KPI + live SOS list + pie chart |
| SOS Aktif | ✅ | Detail korban, false alarm, resolve |
| Laporan Masuk | ✅ | Jalur B + filter status |
| Peta Operasional | ✅ | OpenStreetMap + markers live |
| Dispatch Relawan | 🔴 | Placeholder (Sprint B.4) |
| Admin — KYC | ✅ | UI selesai, backend endpoint tersedia |
| Admin — User Mgmt | ✅ | UI selesai, backend endpoint tersedia |
| Admin — Gamifikasi | ✅ | UI selesai, backend endpoint tersedia |
| Admin — Statistik | ✅ | UI selesai, backend endpoint tersedia |

---

## 3. Changelog Per Sprint

---

### 🔖 Patch 1.0.2 — 1 Mei 2026 (Sesi Ini)

#### 🐛 Bugfix

**[KRITIS] Desktop console routing ke endpoint yang salah**
- **Masalah:** `windows_console_flutter` memanggil `POST /auth/login` (endpoint mobile) → backend menolak dengan error "akun ini bukan akun masyarakat atau relawan"
- **Perbaikan:** `api_constants.dart` diupdate: `/auth/login` → `/auth/console/login`
- **File:** `windows_console_flutter/lib/core/constants/api_constants.dart`

**[SECURITY] Pesan error `/auth/login` membocorkan role**
- **Masalah:** Jika akun admin/agency mencoba login di `/auth/login`, error message-nya adalah *"akun ini bukan akun masyarakat atau relawan"* — membocorkan informasi role enumeration
- **Perbaikan:** Pesan diubah menjadi generik: *"email atau password salah"*
- **File:** `backend-go/internal/domain/user/service.go` → `Login()`

---

### 🔖 Sprint D — 1 Mei 2026

#### Backend: Restructuring Database + Role Expansion

**Schema Database v3** (`migrations/003_schema_v3.sql`)
- Tabel `users` dipersempit → hanya `id`, `email`, `password_hash`, `role`, `created_at`, `deleted_at`
- Tabel `user_medical_profiles` dihapus → diganti `user_profiles` (menampung semua profil citizen/volunteer)
- Tabel baru `admin_profiles` (nama admin/superadmin)
- Tabel `agencies` + kolom `account_id` (FK ke `users`)
- Tabel `agency_personnels` diperbarui
- ENUM `user_role` baru: `superadmin | admin | agency | agency_personnel | volunteer | civilian`
- `agency_responder` dihapus

**Backend Go — user domain diperbarui total**
- `model.go`: Slim `User` + baru `UserProfile`, `AdminProfile`, `AgencyPersonnel`
- `repository.go`: Semua query profil → `user_profiles`; strike/ban juga → `user_profiles`
- `service.go`: 3 login method (`Login`, `ConsoleLogin`, `PersonnelLogin`); Register membuat `users` + `user_profiles` dalam 1 transaksi
- `handler.go`: + handler `ConsoleLogin`, `PersonnelLogin`

**Backend Go — middleware RBAC baru**
- `RequireRoles()` — generic, composable
- `AdminOnly()` — admin + superadmin
- `ConsoleOnly()` — superadmin + admin + agency
- `AgencyOnly()` — agency + admin + superadmin
- `CitizenVolunteer()` — civilian + volunteer saja
- `PersonnelOnly()` — agency_personnel saja

**Backend Go — domain admin baru** (`domain/admin/`)
- KYC: `GET /admin/volunteers/pending`, `POST /admin/volunteers/:id/approve`, `POST /admin/volunteers/:id/reject`
- User Management: `GET /admin/users`, ban, unban, reset strike
- Ranks: CRUD `GET/POST/PUT/DELETE /admin/ranks/:id`
- Stats: `GET /admin/stats` (aggregat per tipe, status, bulanan, avg respons)

**Superadmin auto-seed**
- `seedSuperAdmin()` dipanggil di startup `main.go`
- Baca `SUPERADMIN_EMAIL` + `SUPERADMIN_PASS` dari `.env`
- Buat atau update akun superadmin otomatis

**Mobile Flutter — `auth_service.dart`**
- `UserInfo.fullName` diubah ke `String?` (nullable, sesuai response backend baru)
- Field `isEmailVerified`, `isPhoneVerified`, `isVerifiedVolunteer` dihapus dari `UserInfo` (kini ada di `GET /users/profile`)

---

### 🔖 Sprint C — 30 April 2026

#### Desktop Console — Modul Admin

- `kyc_relawan_page.dart` — UI verifikasi relawan
- `user_management_page.dart` — Tabel user + strike/ban UI
- `gamifikasi_page.dart` — CRUD master rank
- `statistik_page.dart` — KPI + chart analitik
- `admin_shell.dart` — Sidebar untuk role admin/superadmin

---

### 🔖 Sprint B — 29–30 April 2026

#### Desktop Console — Modul Instansi

- `dashboard_operasi_page.dart` — KPI real-time + live SOS list + pie chart
- `sos_aktif_page.dart` — Detail korban, aksi false alarm/resolve, alarm control
- `laporan_masuk_page.dart` — Jalur B report management
- `peta_operasional_page.dart` — OpenStreetMap + SOS markers
- `ws_service.dart` — WebSocket singleton (auto-reconnect, event stream)
- `instansi_shell.dart` — Sidebar + WS connection indicator
- `app.dart` — SplashRouter: JWT session restore → route ke shell

---

### 🔖 Sprint A — 26–29 April 2026

#### Mobile — SOS Redesign & GPS Integration

- `home_screen.dart` — Mekanisme 5-ketukan, GPS tracking 1 menit, cancel SOS
- `auth_service.dart` — API client auth (register, login, OTP)
- `incident_service.dart` — SOS trigger, cancel, location update
- `location_service.dart` — GPS permission + position

#### Backend — OTP Domain

- `domain/otp/` — SMTP email OTP + Fonnte WA OTP
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
│       ├── core/services/
│       │   └── auth_service.dart    ✅ UserInfo.fullName → String? (nullable)
│       └── features/
│           ├── auth/                ✅
│           └── masyarakat/          🟡 Profile, Biodata belum terhubung API
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
    ├── FRONTEND_STRUCTURE.txt       ✅ Diperbarui 1 Mei 2026
    └── DESKTOP_PLANNING_ADMIN_INSTANSI.txt  ✅ Diperbarui 1 Mei 2026
```

---

## 5. API Endpoint Lengkap

Base URL: `http://<host>:8080/api/v1`

### Auth (Public)

| Method | Endpoint | Untuk Role | Keterangan |
|--------|----------|------------|-----------|
| POST | `/auth/register` | civilian | Daftar → OTP email |
| POST | `/auth/verify-register-otp` | — | Verifikasi OTP → JWT |
| POST | `/auth/login` | civilian, volunteer | Login langsung → JWT |
| POST | `/auth/console/login` | admin, superadmin, agency | Login Desktop Console → JWT |
| POST | `/auth/personnel/login` | agency_personnel | Login Mobile Responder → JWT |
| POST | `/auth/request-otp` | — | Kirim OTP WA (phone verification) |
| POST | `/auth/verify-otp` | — | Verifikasi OTP WA |

### Users (Protected — CitizenVolunteer)

| Method | Endpoint | Keterangan |
|--------|----------|-----------|
| GET | `/users/profile` | Profil dari `user_profiles` |
| POST | `/users/biodata` | Update `user_profiles` (upsert) |
| POST | `/users/phone/request-otp` | OTP WA ke HP baru |
| POST | `/users/phone/verify-otp` | Konfirmasi OTP HP |

### Incidents (Protected — semua role)

| Method | Endpoint | RBAC | Keterangan |
|--------|----------|------|-----------|
| GET | `/incidents/active` | — | Cek SOS aktif |
| POST | `/incidents/trigger` | — | Kirim SOS |
| POST | `/incidents/:id/cancel` | — | Batalkan SOS |
| PUT | `/incidents/:id/location` | — | Update GPS tiap 1 menit |
| PATCH | `/incidents/:id/type` | — | Set tipe insiden |
| POST | `/incidents/:id/broadcast` | — | Broadcast SOS |
| POST | `/incidents/:id/mark-false-alarm` | ConsoleOnly | Tandai false alarm |
| POST | `/incidents/:id/resolve` | ConsoleOnly | Selesaikan insiden |

### Reports — Jalur B (Protected)

| Method | Endpoint | RBAC | Keterangan |
|--------|----------|------|-----------|
| POST | `/reports` | — | Kirim laporan non-darurat |
| GET | `/reports` | ConsoleOnly | Daftar laporan |
| PATCH | `/reports/:id/status` | ConsoleOnly | Update status laporan |

### Admin (Protected — AdminOnly / ConsoleOnly)

| Method | Endpoint | RBAC | Keterangan |
|--------|----------|------|-----------|
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

### Telemetry & WebSocket

| Method | Endpoint | Keterangan |
|--------|----------|-----------|
| PUT | `/telemetry/location` | Update lokasi real-time |
| POST | `/incidents/sms-fallback` | SMS fallback (API Key) |
| WS | `ws://<host>:8081/ws/connect` | WebSocket persistent |

---

## 6. Schema Database (v3 — Aktif)

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
| `sos_strikes` | Audit log false alarm | — |
| `m_ranks` | Master data rank XP | — |
| `m_badges` | Master data badge | — |
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
- [ ] **Isi `.env`** — `SUPERADMIN_EMAIL` dan `SUPERADMIN_PASS` harus diisi untuk seed superadmin
- [ ] **Biodata Screen → API** — Wire `BiodataScreen` ke `POST /users/biodata`
- [ ] **Profile Screen → API** — Wire `ProfileScreen` ke `GET /users/profile`
- [ ] **Desktop Console → Admin endpoints** — Hubungkan halaman KYC, User Mgmt, Gamifikasi, Statistik ke endpoint `/admin/...`

### Prioritas Sedang

- [ ] **Dispatch Relawan** — Halaman masih placeholder (Sprint B.4)
- [ ] **Mobile Responder App** — Proyek baru `mobile-flutter-responder/` untuk role `agency_personnel`
- [ ] **Audio Alarm** — `assets/audio/alarm.mp3` masih placeholder, ganti dengan file sirine sungguhan
- [ ] **Refresh token** — Auto-refresh saat `access_token` expired

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
