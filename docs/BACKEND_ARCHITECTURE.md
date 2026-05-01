# 🏗️ SiagaKita — Arsitektur Backend

> **Diperbarui:** 1 Mei 2026
> **Versi Schema:** v3
> **Stack:** Go 1.23 + Fiber v2 + PostgreSQL 15 + Redis

---

## Daftar Isi

1. [Struktur Folder](#1-struktur-folder)
2. [Domain-Driven Design](#2-domain-driven-design)
3. [Alur Autentikasi](#3-alur-autentikasi)
4. [RBAC — Role-Based Access Control](#4-rbac--role-based-access-control)
5. [WebSocket Architecture](#5-websocket-architecture)
6. [OTP System](#6-otp-system)
7. [Superadmin Seeding](#7-superadmin-seeding)
8. [Konfigurasi Environment](#8-konfigurasi-environment)

---

## 1. Struktur Folder

```
backend-go/
├── cmd/
│   └── api/
│       └── main.go          — Entry point, wiring semua domain, seedSuperAdmin()
├── internal/
│   ├── config/
│   │   └── config.go        — Struct Config, Load() dari env vars
│   ├── database/
│   │   ├── postgres.go      — GORM connection ke PostgreSQL
│   │   └── redis.go         — Redis client
│   ├── domain/
│   │   ├── user/            — Auth gateway + profile management
│   │   │   ├── model.go     — User, UserProfile, AdminProfile, AgencyPersonnel, DTOs
│   │   │   ├── repository.go — DB queries
│   │   │   ├── service.go   — Business logic (3 login methods)
│   │   │   └── handler.go   — HTTP handlers
│   │   ├── admin/           — Admin operations (KYC, ban, stats, ranks)
│   │   │   ├── model.go
│   │   │   ├── repository.go
│   │   │   ├── service.go
│   │   │   └── handler.go
│   │   ├── incident/        — SOS & laporan warga
│   │   │   ├── model.go
│   │   │   ├── repository.go
│   │   │   ├── service.go
│   │   │   └── handler.go
│   │   ├── otp/             — OTP via Email (SMTP) + WA (Fonnte)
│   │   │   ├── gateway.go
│   │   │   ├── service.go
│   │   │   └── handler.go
│   │   └── telemetry/       — GPS location update + SMS fallback
│   │       └── handler.go
│   ├── hub/
│   │   └── hub.go           — WebSocket connection registry (map[userID]conn)
│   ├── middleware/
│   │   └── auth.go          — JWT Auth + RBAC middleware
│   ├── utils/
│   │   ├── response.go      — SuccessResponse, ErrorResponse, CreatedResponse
│   │   └── jwt.go           — GenerateAccessToken, GenerateRefreshToken, ParseToken
│   └── ws/
│       └── server.go        — WebSocket server, event broadcasting
└── migrations/
    ├── 001_init_schema.sql  (deprecated — jangan dijalankan)
    └── 003_schema_v3.sql    ← Schema aktif, jalankan ini
```

---

## 2. Domain-Driven Design

Backend menggunakan pola **Repository → Service → Handler** per domain:

```
HTTP Request
    │
    ▼
Handler (HTTP layer)
    │  parsing body, validasi input dasar, return response
    ▼
Service (Business logic)
    │  validasi bisnis, transformasi data, transaksi
    ▼
Repository (Data access)
    │  query SQL via GORM
    ▼
PostgreSQL / Redis
```

### Domain Map

| Domain | Tanggung Jawab |
|--------|---------------|
| `user` | Autentikasi (register, login, JWT), manajemen profil citizen/volunteer, verifikasi phone |
| `admin` | KYC relawan, ban/unban user, master data rank, statistik sistem, buat akun admin |
| `incident` | SOS (Jalur A): trigger, cancel, GPS update, resolve, false alarm; Laporan (Jalur B): CRUD + status |
| `otp` | OTP via Gmail API (REST), OTP WA via Fonnte, rate limiting di Redis |
| `telemetry` | Location update real-time, SMS fallback untuk area tanpa internet |
| `agency` | Manajemen akun `agency_personnel` khusus untuk instansi terkait |

### 2.1 Hierarki Role & Akses
| Role | Keterangan |
|------|------------|
| **superadmin** | Akses root sistem (Web Console). **Hanya bertugas membuat akun admin.** Di-*seed* otomatis dari environment. |
| **admin** | Administrator aplikasi (Web Console). Mendaftarkan instansi (`agency`), verifikasi KYC relawan, memblokir pengguna, manajemen rank. |
| **agency** | Kantor Instansi (Polisi/Damkar/RS). Hanya dapat mengakses Web Console untuk manajemen dan mendaftarkan akun petugas lapangannya (**agency_personnel**). |
| **agency_personnel** | Petugas lapangan (Mobile App). Menerima dispatch insiden. Didaftarkan oleh *agency*. |
| **volunteer** | Relawan terlatih (Mobile App). Lolos KYC. Menerima dispatch. |
| **civilian** | Warga biasa (Mobile App). Mengirim SOS, melihat laporan. |


---

## 3. Alur Autentikasi

### 3.1 Register (civilian/volunteer)

```
POST /auth/register
  { full_name, email, password }
        │
        ├── Cek duplikasi email 
        │     └── [Email ada TAPI belum terverifikasi OTP] → Auto-hapus (cleanup ghost account)
        ├── bcrypt hash password (cost: 12)
        ├── [ATOMIC TRANSACTION MULAI]
        │     ├── INSERT INTO users (email, password_hash, role='civilian')
        │     └── INSERT INTO user_profiles (user_id, full_name)
        ├── [ATOMIC TRANSACTION SELESAI]
        └── kirim OTP ke email via SMTP
              │
              ├── [GAGAL/TIMEOUT] → Hapus akun (CASCADE) ← agar email bisa dipakai ulang
              └── [OK]    → return { message, email }

POST /auth/verify-register-otp
  { email, otp_code }
        │
        ├── verifyEmailOTP (Redis lookup)
        ├── UPDATE user_profiles SET is_email_verified = true
        └── return JWT (access_token + refresh_token)
### B. Otentikasi & Registrasi (Anti-Ghost Account)

Alur registrasi telah diperkuat untuk memastikan **integritas data** dan **mencegah kebocoran akun tak terverifikasi** (*Ghost Account*).

1. **Atomic Transaction (`domain/user/service.go:Register`)**
   - Pembuatan `users` (credentials) dan `user_profiles` dibungkus dalam **1 transaksi GORM**.
   - Jika ada langkah yang gagal, transaksi di-_rollback_ tanpa meninggalkan data sampah di database.

2. **Ghost Account Prevention & Auto-Cleanup**
   - Masalah: Terkadang server gagal mengirim OTP karena *network timeout* atau pemblokiran port SMTP.
   - Solusi: Jika terjadi kegagalan _setelah_ transaksi DB berhasil di-_commit_, server secara otomatis **menghapus kembali** (*hard-delete*) row yang baru saja dibuat.
   - Pengecekan Login: Fungsi `Login()` kini menolak akses untuk akun dengan `is_email_verified = false`. Akun seperti ini akan diminta melakukan registrasi ulang (yang akan menghapus akun rusak lama).

3. **Email Gateway via Gmail REST API**
   - VPS cloud modern (seperti DigitalOcean) secara default memblokir semua outbound *port* SMTP (25, 465, 587) untuk mencegah SPAM.
   - Untuk menghindari *infinite loop / timeout* yang membekukan aplikasi klien, gateway email dipindahkan menggunakan **Gmail REST API via HTTPS (Port 443)** di `domain/otp/gmail_api_gateway.go`.
   - Hal ini memastikan pengiriman email menggunakan protokol HTTPS yang aman dari pemblokiran firewall VPS, lengkap dengan implementasi *Refresh Token OAuth2* secara otomatis.


### 3.2 Login — 3 Endpoint Terpisah

| Endpoint | Role yang Diizinkan | App |
|----------|---------------------|-----|
| `POST /auth/login` | civilian, volunteer | Mobile Citizen |
| `POST /auth/console/login` | superadmin, admin, agency | Desktop Console |
| `POST /auth/personnel/login` | agency_personnel | Mobile Responder |

> **Keamanan & Konsistensi:** 
> 1. Jika role yang salah mencoba endpoint yang salah, semua endpoint mengembalikan "email atau password salah" — mencegah kebocoran informasi (role enumeration prevention).
> 2. Untuk civilian/volunteer, sistem secara ketat memblokir login jika `IsEmailVerified = false`. Pengguna akan diminta mendaftar ulang, yang akan memicu proses "cleanup ghost account".


### 3.3 JWT Token

```go
// Access Token — berumur pendek (default: 15 menit)
Claims: { user_id, role, exp }

// Refresh Token — berumur panjang (default: 168 jam / 7 hari)
Claims: { user_id, role, exp }
```

Token dilewatkan via header:
```
Authorization: Bearer <access_token>
```

Setelah JWT divalidasi, middleware menyimpan ke `c.Locals`:
- `c.Locals("userID")` — UUID user
- `c.Locals("userRole")` — role string

---

## 4. RBAC — Role-Based Access Control

Middleware ada di `internal/middleware/auth.go`.

### Komposisi Middleware

```go
// Pola umum:
route.Method("/path", authMw, middleware.AdminOnly(), handler)

// authMw harus selalu dijalankan SEBELUM RBAC middleware
```

### Daftar Middleware RBAC

| Middleware | Role yang Diizinkan | Digunakan untuk |
|-----------|---------------------|-----------------|
| `Auth(cfg)` | Semua (hanya validasi JWT) | Semua protected route |
| `RequireRoles("x","y")` | Custom | Kasus spesifik |
| `SuperAdminOnly()` | superadmin | Operasi paling sensitif |
| `AdminOnly()` | admin, superadmin | KYC, ban user, rank CRUD |
| `ConsoleOnly()` | superadmin, admin, agency | Stats, laporan, resolve SOS |
| `AgencyOnly()` | agency, admin, superadmin | Data instansi |
| `CitizenVolunteer()` | civilian, volunteer | Profile, biodata |
| `PersonnelOnly()` | agency_personnel | Mobile responder ops |
| `APIKeyGateway(cfg)` | — (API key) | SMS fallback endpoint |

---

## 5. WebSocket Architecture

### Server

WebSocket server berjalan terpisah di port `:8081`.

```
ws://<host>:8081/ws/connect?token=<jwt>
```

### Hub Pattern

```go
// hub.go — registry koneksi aktif
type Hub struct {
    clients map[string]*Client  // userID → connection
    mu      sync.RWMutex
}

// Broadcast ke semua koneksi yang terhubung
hub.BroadcastAll(event)

// Broadcast ke role tertentu
hub.BroadcastToRole("agency", event)
```

### Event dari Backend ke Client

| Event | Dikirim ke | Trigger |
|-------|-----------|---------|
| `INCOMING_EMERGENCY` | Semua agency | SOS baru masuk (status: broadcasting) |
| `SOS_CANCELLED` | Semua agency | User batalkan SOS |
| `RESCUE_ACCEPTED` | Reporter | Responder en_route |
| `LOCATION_UPDATE` | Agency | GPS reporter diperbarui |

### Event dari Client ke Backend

| Event | Dari | Keterangan |
|-------|------|-----------|
| `TRIGGER_SOS` | Mobile | (Legacy — kini via REST) |
| `LOCATION_PING` | Mobile | Koordinat GPS real-time |

---

## 6. OTP System

### Email OTP (Register & Login masa depan)

```
Redis key: otp:register:{email}    TTL: 180 detik
Redis key: otp_cooldown:{email}    TTL: 60 detik  ← rate limit

Flow:
  1. Cek cooldown → 429 jika masih aktif
  2. Generate kode 6 digit acak
  3. Simpan ke Redis (TTL 3 menit)
  4. Kirim via SMTP (Gmail / SMTP apapun)
  5. Rollback Redis jika SMTP gagal
```

### WA OTP (Phone Verification)

```
Redis key: otp:{phone}             TTL: 180 detik
Redis key: otp_cooldown:{phone}    TTL: 60 detik

Flow sama, tapi dikirim via Fonnte API ke WhatsApp.
Normalisasi nomor: 08xxx → 628xxx
```

### Verifikasi OTP

```
1. Ambil kode dari Redis
2. Bandingkan dengan input user (constant-time comparison)
3. DELETE kode dari Redis (anti-replay — tidak bisa dipakai dua kali)
4. Return error jika key tidak ada (berarti TTL habis)
```

---

## 7. Superadmin Seeding

Saat server start, `seedSuperAdmin()` di `main.go` dipanggil:

```
SUPERADMIN_EMAIL & SUPERADMIN_PASS di .env
        │
        ├── [Kosong] → skip, log WARNING
        ├── [Superadmin sudah ada] → update email + password hash dari env
        └── [Belum ada] → INSERT INTO users (role='superadmin')
                          + log "[SuperAdmin] Akun berhasil dibuat: <email>"
```

> **Penting:** Setiap kali server start, password superadmin di-sync dari env. Ini berarti jika env berubah, akun superadmin otomatis terupdate — tidak perlu query manual ke DB.

---

## 8. Konfigurasi Environment

File: `infrastructure/.env` (lihat `infrastructure/.env-example` sebagai template)

| Variable | Keterangan | Wajib |
|----------|-----------|-------|
| `DB_USER` | PostgreSQL username | ✅ |
| `DB_PASSWORD` | PostgreSQL password | ✅ |
| `DB_NAME` | Nama database (default: siagakita) | ✅ |
| `DB_HOST` | Host PostgreSQL (default: postgres untuk Docker) | ✅ |
| `DB_PORT` | Port PostgreSQL (default: 5432) | ✅ |
| `REDIS_HOST` | Host Redis | ✅ |
| `REDIS_PORT` | Port Redis (default: 6379) | ✅ |
| `REDIS_PASSWORD` | Redis password | ✅ |
| `JWT_SECRET` | Secret key JWT (buat string acak panjang) | ✅ |
| `JWT_ACCESS_TTL` | Durasi access token (default: 15m) | — |
| `JWT_REFRESH_TTL` | Durasi refresh token (default: 168h) | — |
| `EMAIL_FROM` | Alamat pengirim tampil untuk OTP (ex: no-reply@) | ✅ |
| `GMAIL_CLIENT_ID` | OAuth2 Client ID Gmail API | ✅ |
| `GMAIL_CLIENT_SECRET`| OAuth2 Client Secret Gmail API | ✅ |
| `GMAIL_REFRESH_TOKEN`| OAuth2 Refresh Token Gmail API | ✅ |
| `FONNTE_TOKEN` | Token API Fonnte (WhatsApp gateway) | ✅ |
| `HTTP_PORT` | Port REST API (default: 8080) | — |
| `WS_PORT` | Port WebSocket (default: 8081) | — |
| `SMS_GATEWAY_SECRET` | Secret key SMS fallback endpoint | — |
| `SUPERADMIN_EMAIL` | Email akun superadmin pertama | ✅ |
| `SUPERADMIN_PASS` | Password akun superadmin pertama | ✅ |
| `PGADMIN_EMAIL` | pgAdmin login email | — |
| `PGADMIN_PASSWORD` | pgAdmin login password | — |

---

> 📌 Untuk melihat semua endpoint API, lihat [PROGRESS_REPORT.md](./PROGRESS_REPORT.md#5-api-endpoint-lengkap)
