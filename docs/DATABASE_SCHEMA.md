# 🗄️ SiagaKita — Database Schema Reference

> **Versi Aktif:** Schema v3
> **Migration File:** `backend-go/migrations/003_schema_v3.sql`
> **Dijalankan:** 1 Mei 2026
> **Database:** PostgreSQL 15

---

## Daftar Isi

1. [Cara Reset Database](#1-cara-reset-database)
2. [ENUM Types](#2-enum-types)
3. [Tabel — Auth & Profil](#3-tabel--auth--profil)
4. [Tabel — Instansi & Personel](#4-tabel--instansi--personel)
5. [Tabel — Insiden & Respons](#5-tabel--insiden--respons)
6. [Tabel — Gamifikasi Relawan](#6-tabel--gamifikasi-relawan)
7. [Triggers](#7-triggers)
8. [Diagram Relasi](#8-diagram-relasi)
9. [Keputusan Desain](#9-keputusan-desain)
10. [Changelog Schema](#10-changelog-schema)

---

## 1. Cara Reset Database

> ⚠️ **PERINGATAN:** Perintah ini menghapus SEMUA data. Gunakan hanya untuk development/fresh setup.

```bash
sudo docker exec -i siagakita_postgres psql \
  -U siagakita_admin -d siagakita \
  < backend-go/migrations/003_schema_v3.sql
```

Output yang diharapkan di akhir:
```
           status
----------------------------
 Schema v3 berhasil dibuat.
(1 row)
```

---

## 2. ENUM Types

### `user_role`
```sql
'superadmin'       -- Satu akun, auto-seed dari .env
'admin'            -- Dibuat oleh superadmin
'agency'           -- Instansi penyelamat, dibuat oleh admin
'agency_personnel' -- Personel instansi, dibuat oleh agency
'volunteer'        -- Relawan, daftar mandiri
'civilian'         -- Masyarakat umum, daftar mandiri
```

> ⚠️ `agency_responder` sudah **DIHAPUS** sejak Schema v3.

### `agency_type`
```sql
'police' | 'fire' | 'medical' | 'sar'
```

### `blood_type_enum`
```sql
'A' | 'B' | 'AB' | 'O' | 'UNKNOWN'
```

### `cert_status`
```sql
'pending' | 'approved' | 'rejected' | 'expired'
```

### `incident_category`
```sql
'medical' | 'fire' | 'crime' | 'rescue' | 'general' | 'unknown'
```

### `incident_status`
```sql
'grace_period'   -- Jeda 30 detik sebelum broadcast
'broadcasting'   -- SOS aktif, disiarkan ke semua responder
'handled'        -- Ada responder yang menerima
'resolved'       -- Insiden selesai
'false_alarm'    -- Ditandai false alarm oleh admin/agency
```

### `response_status`
```sql
'en_route' | 'on_scene' | 'completed' | 'canceled'
```

---

## 3. Tabel — Auth & Profil

### `users` — Auth Gateway

```sql
CREATE TABLE public.users (
    id            uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    email         varchar(100) NOT NULL UNIQUE,
    password_hash varchar(255) NOT NULL,
    role          user_role NOT NULL DEFAULT 'civilian',
    created_at    timestamptz DEFAULT now() NOT NULL,
    deleted_at    timestamptz  -- NULL = aktif; NOT NULL = soft-deleted
);
```

> **Desain:** Tabel ini hanya menyimpan **kredensial autentikasi**. Tidak ada nama, HP, atau data profil di sini. Semua data profil ada di tabel terpisah berdasarkan role.

**Index:** `idx_users_email`, `idx_users_role`, `idx_users_del`

---

### `user_profiles` — Profil Citizen & Volunteer

```sql
CREATE TABLE public.user_profiles (
    user_id               uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    full_name             varchar(100),
    nik                   varchar(16) UNIQUE,
    date_of_birth         date,
    phone_number          varchar(20) UNIQUE,
    is_email_verified     boolean DEFAULT false,
    is_phone_verified     boolean DEFAULT false,
    is_verified_volunteer boolean DEFAULT false,
    sos_strike_count      int DEFAULT 0,
    is_sos_banned         boolean DEFAULT false,
    banned_until          timestamptz,
    blood_type            blood_type_enum DEFAULT 'UNKNOWN',
    allergies             text,
    medical_conditions    text,
    height_cm             int CHECK (height_cm > 0),
    weight_kg             int CHECK (weight_kg > 0),
    alamat                text,
    updated_at            timestamptz DEFAULT now()
);
```

> **Dibuat bersamaan dengan `users`** dalam satu transaksi saat registrasi. Hanya untuk role `civilian` dan `volunteer`.

**Index:** `idx_up_phone` (phone_number), `idx_up_nik` (nik)
**Trigger:** `trg_user_profiles_updated_at` — auto-update `updated_at`

---

### `admin_profiles` — Profil Admin & Superadmin

```sql
CREATE TABLE public.admin_profiles (
    user_id    uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    full_name  varchar(100),
    created_by uuid REFERENCES users(id),  -- UUID superadmin yang membuat
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);
```

> Dibuat saat superadmin membuat akun admin baru. Nama instansi untuk role `agency` ada di tabel `agencies`, bukan di sini.

**Trigger:** `trg_admin_profiles_updated_at`

---

### `emergency_contacts` — Kontak Darurat

```sql
CREATE TABLE public.emergency_contacts (
    id            uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id       uuid REFERENCES users(id) ON DELETE CASCADE,
    contact_name  varchar(100) NOT NULL,
    contact_phone varchar(20) NOT NULL,
    relation      varchar(50),
    created_at    timestamptz DEFAULT now(),
    deleted_at    timestamptz  -- soft-delete
);
```

**Index:** `idx_ec_user` (user_id)

---

## 4. Tabel — Instansi & Personel

### `agencies` — Data Instansi

```sql
CREATE TABLE public.agencies (
    id             uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name           varchar(100) NOT NULL,
    type           agency_type NOT NULL,
    city_code      varchar(50) NOT NULL,
    hotline_number varchar(20),
    account_id     uuid UNIQUE REFERENCES users(id),  -- FK ke akun agency di users
    created_at     timestamptz DEFAULT now()
);
```

> `account_id` menghubungkan akun login (di `users`) ke data instansi. Nama instansi (`name`) adalah pengganti `full_name` untuk role `agency`.

---

### `agency_personnels` — Personel Instansi

```sql
CREATE TABLE public.agency_personnels (
    user_id      uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    agency_id    uuid NOT NULL REFERENCES agencies(id) ON DELETE RESTRICT,
    full_name    varchar(100) NOT NULL,
    badge_number varchar(50) NOT NULL UNIQUE,
    is_active    boolean DEFAULT true,
    created_at   timestamptz DEFAULT now()
);
```

> Login via `POST /auth/personnel/login`. Digunakan oleh Mobile Responder App.

**Index:** `idx_ap_agency` (agency_id)

---

## 5. Tabel — Insiden & Respons

### `incidents` — SOS Darurat (Jalur A)

```sql
CREATE TABLE public.incidents (
    id                   uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    reporter_id          uuid REFERENCES users(id),
    incident_type        incident_category NOT NULL DEFAULT 'unknown',
    latitude             numeric(10,8) NOT NULL,
    longitude            numeric(11,8) NOT NULL,
    status               incident_status DEFAULT 'grace_period',
    urgency_level        varchar(10) DEFAULT 'unknown',
    reporter_trust_label varchar(20) DEFAULT 'standard',  -- 'verified'|'standard'|'unverified'
    address_detail       text,
    trigger_method       varchar(20) DEFAULT 'timeout',   -- 'user'|'timeout'
    created_at           timestamptz DEFAULT now() NOT NULL,
    updated_at           timestamptz DEFAULT now(),
    resolved_at          timestamptz
);
```

**Index:** `idx_incidents_reporter`, `idx_incidents_status`

---

### `incident_reports` — Laporan Warga (Jalur B)

```sql
CREATE TABLE public.incident_reports (
    id            uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    reporter_id   uuid REFERENCES users(id),
    incident_type incident_category NOT NULL DEFAULT 'general',
    urgency       varchar(10) DEFAULT 'low',
    latitude      numeric(10,8) NOT NULL,
    longitude     numeric(11,8) NOT NULL,
    description   text,
    photo_url     varchar(255),
    audio_url     varchar(255),
    status        varchar(20) DEFAULT 'pending',  -- pending|reviewed|actioned
    created_at    timestamptz DEFAULT now()
);
```

---

### `incident_responses` — Dispatch Responder

```sql
CREATE TABLE public.incident_responses (
    id           uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    incident_id  uuid REFERENCES incidents(id) ON DELETE CASCADE,
    responder_id uuid REFERENCES users(id),
    status       response_status DEFAULT 'en_route',
    accepted_at  timestamptz DEFAULT now(),
    arrived_at   timestamptz,
    UNIQUE (incident_id, responder_id)  -- satu responder hanya bisa assign sekali per insiden
);
```

---

### `sos_strikes` — Audit Log False Alarm

```sql
CREATE TABLE public.sos_strikes (
    id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id     uuid REFERENCES users(id) ON DELETE CASCADE,
    incident_id uuid REFERENCES incidents(id) ON DELETE SET NULL,
    reason      text,
    marked_by   uuid REFERENCES users(id),  -- UUID admin yang menandai
    created_at  timestamptz DEFAULT now()
);
```

> Counter strike (`sos_strike_count`) dan status ban (`is_sos_banned`) ada di `user_profiles`, bukan di tabel ini. Tabel ini hanya audit log.

---

## 6. Tabel — Gamifikasi Relawan

### `m_ranks` — Master Data Rank

```sql
CREATE TABLE public.m_ranks (
    id        serial PRIMARY KEY,
    rank_name varchar(50) NOT NULL,
    min_exp   int NOT NULL,
    icon_url  varchar(255)
);
```

### `m_badges` — Master Data Badge

```sql
CREATE TABLE public.m_badges (
    id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    badge_name  varchar(50) NOT NULL,
    description text,
    icon_url    varchar(255)
);
```

### `volunteer_reputation` — XP & Rank Relawan

```sql
CREATE TABLE public.volunteer_reputation (
    user_id       uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    exp_points    int DEFAULT 0,
    rank_id       int REFERENCES m_ranks(id),
    total_rescues int DEFAULT 0,
    updated_at    timestamptz DEFAULT now()
);
```

### `volunteer_certifications` — Sertifikat KYC

```sql
CREATE TABLE public.volunteer_certifications (
    id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id          uuid REFERENCES users(id) ON DELETE CASCADE,
    certificate_type varchar(50) NOT NULL,
    document_url     varchar(255) NOT NULL,
    status           cert_status DEFAULT 'pending',
    verified_by      uuid REFERENCES users(id),  -- UUID admin yang approve/reject
    expires_at       date,
    created_at       timestamptz DEFAULT now()
);
```

### `volunteer_badges_acquired` — Badge Dimiliki Relawan

```sql
CREATE TABLE public.volunteer_badges_acquired (
    id        uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id   uuid REFERENCES users(id) ON DELETE CASCADE,
    badge_id  uuid REFERENCES m_badges(id),
    earned_at timestamptz DEFAULT now()
);
```

---

## 7. Triggers

### `trg_user_profiles_updated_at`
**Tabel:** `user_profiles`
**Event:** `BEFORE UPDATE`
**Aksi:** Set `updated_at = NOW()`

### `trg_admin_profiles_updated_at`
**Tabel:** `admin_profiles`
**Event:** `BEFORE UPDATE`
**Aksi:** Set `updated_at = NOW()`

### `trg_sync_volunteer_verified`
**Tabel:** `volunteer_certifications`
**Event:** `AFTER UPDATE`
**Aksi:**
- Jika `status` berubah jadi `'approved'` → set `user_profiles.is_verified_volunteer = TRUE`
- Jika `status` berubah dari `'approved'` ke lain → cek apakah masih ada cert lain yang approved; jika tidak ada → set `is_verified_volunteer = FALSE`

---

## 8. Diagram Relasi

```
users (auth gateway)
  ├── user_profiles          [civilian, volunteer]
  ├── admin_profiles         [admin, superadmin]
  ├── agency_personnels      [agency_personnel] ── agencies (account_id)
  ├── emergency_contacts
  ├── incidents (reporter_id)
  │     └── incident_responses (responder_id → users)
  ├── incident_reports (reporter_id)
  ├── sos_strikes (user_id, marked_by)
  └── volunteer_reputation
        ├── volunteer_certifications (verified_by → users)
        └── volunteer_badges_acquired ── m_badges
              └── m_ranks (rank_id)
```

---

## 9. Keputusan Desain

### Mengapa `users` hanya berisi auth data?

Tujuannya agar tabel `users` berfungsi sebagai **unified auth gateway** untuk semua role. Role yang berbeda memiliki data profil yang sangat berbeda:
- Citizen/volunteer punya medis, NIK, gamifikasi
- Admin hanya butuh nama
- Agency punya nama instansi, tipe, kota
- Agency personnel punya badge number, agency ID

Memaksakan semua ke satu tabel akan menghasilkan banyak kolom NULL dan membingungkan.

### Mengapa tidak ada `user_profiles` untuk admin/agency?

- **Admin** → nama di `admin_profiles` (sederhana)
- **Agency** → nama di `agencies.name` (sudah ada tabel instansi)
- **Agency personnel** → nama di `agency_personnels.full_name`

### Mengapa `sos_strike_count` ada di `user_profiles` bukan `sos_strikes`?

Agar tidak perlu `COUNT(*)` query setiap kali cek strike. Counter di-increment langsung saat strike ditambah, membuat pengecekan O(1).

### Mengapa ada `soft-delete` di `users` dan `emergency_contacts`?

Untuk audit trail — jika ada laporan penyalahgunaan, data historis bisa dipulihkan. Akun yang di-soft-delete tidak bisa login (query selalu `WHERE deleted_at IS NULL`).

---

## 10. Changelog Schema

| Versi | Tanggal | Perubahan |
|-------|---------|-----------|
| v1 (`001_init_schema.sql`) | Apr 2026 | Schema awal: users dengan semua kolom, user_medical_profiles, agencies dengan agency_responder |
| v2 (patch manual) | Apr 2026 | + kolom `trigger_method` di incidents, beberapa kolom nullable |
| **v3** (`003_schema_v3.sql`) | **1 Mei 2026** | **Slim users, + user_profiles, + admin_profiles, ENUM baru (superadmin/agency/agency_personnel), agencies + account_id, hapus agency_responder** |
