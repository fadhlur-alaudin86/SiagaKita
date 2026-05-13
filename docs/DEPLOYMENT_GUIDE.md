# 🚀 SiagaKita — Panduan Deployment Production

> **Server:** `139.59.99.230` (DigitalOcean / VPS)
> **Diperbarui:** 13 Mei 2026

---

## Daftar Isi

1. [Prasyarat](#1-prasyarat)
2. [Setup Awal VPS (sekali saja)](#2-setup-awal-vps-sekali-saja)
3. [GitHub Secrets yang Diperlukan](#3-github-secrets-yang-diperlukan)
4. [Alur CI/CD Otomatis](#4-alur-cicd-otomatis)
5. [Deploy Manual (darurat)](#5-deploy-manual-darurat)
6. [Monitoring & Troubleshooting](#6-monitoring--troubleshooting)
7. [Reset Database (hati-hati!)](#7-reset-database-hati-hati)

---

## 1. Prasyarat

- Akun Docker Hub dengan repository `siagakita-api` (public atau private)
- SSH key untuk akses ke VPS
- GitHub repository dengan akses ke Settings → Secrets

---

## 2. Setup Awal VPS (sekali saja)

### 2a. Jalankan script setup dari mesin lokal

```bash
# Salin script ke server
scp infrastructure/setup_server.sh root@139.59.99.230:/tmp/

# Salin file yang dibutuhkan server
scp infrastructure/docker-compose.prod.yml root@139.59.99.230:/opt/siagakita/
scp infrastructure/.env                    root@139.59.99.230:/opt/siagakita/
scp backend-go/migrations/003_schema_v3.sql root@139.59.99.230:/opt/siagakita/

# SSH ke server dan jalankan setup
ssh root@139.59.99.230
chmod +x /tmp/setup_server.sh
/tmp/setup_server.sh
```

### 2b. Isi `.env` di server

File `/opt/siagakita/.env` harus berisi semua nilai yang terisi (tidak boleh kosong untuk field wajib):

```env
DB_USER=siagakita_admin
DB_PASSWORD=<password_kuat>
DB_NAME=siagakita
DB_HOST=postgres
DB_PORT=5432

REDIS_PASSWORD=<password_kuat>
REDIS_HOST=redis
REDIS_PORT=6379

API_HOST=[IP_ADDRESS]
HTTP_PORT=8080
WS_PORT=8081

JWT_SECRET=<string_acak_panjang_min_32_char>
JWT_ACCESS_TTL=15m
JWT_REFRESH_TTL=168h

FONNTE_TOKEN=<token_dari_fonnte.com>

SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=<email@gmail.com>
SMTP_PASSWORD=<app_password_gmail>
SMTP_FROM=<email@gmail.com>

SUPERADMIN_EMAIL=<email_superadmin>
SUPERADMIN_PASS=<password_kuat>

SMS_GATEWAY_SECRET=<string_acak>

DOCKERHUB_USERNAME=<username_dockerhub>

# Upload Storage (wajib untuk fitur laporan foto & audio)
UPLOAD_DIR=/app/uploads
UPLOAD_BASE_URL=http://[IP_ADDRESS]:8080/uploads

# Performance & Logging
GO_ENV=production
LOG_PATH=logs/app.log
```

### 2c. Setup direktori upload & log

```bash
# Di VPS — buat direktori penyimpanan file laporan
sudo mkdir -p /opt/siagakita/uploads/reports/photos
sudo mkdir -p /opt/siagakita/uploads/reports/audio
sudo mkdir -p /opt/siagakita/logs

# Set permission agar bisa ditulis oleh container
sudo chown -R 1000:1000 /opt/siagakita/uploads
sudo chown -R 1000:1000 /opt/siagakita/logs
chmod -R 755 /opt/siagakita/uploads
chmod -R 755 /opt/siagakita/logs
```

> [!NOTE]
> Volume ini sudah di-mount di `docker-compose.prod.yml` sebagai:
> - `/opt/siagakita/uploads:/app/uploads`
> - `/opt/siagakita/logs:/app/logs`
> File yang ditulis backend akan persisten di VPS meski container di-restart. Log dapat diakses langsung di `/opt/siagakita/logs/app.log`.

### 2d. Verifikasi infrastruktur berjalan

```bash
# Cek semua container
docker ps

# Output yang diharapkan:
# siagakita_postgres  → Up (healthy)
# siagakita_redis     → Up (healthy)
```

---

## 3. GitHub Secrets yang Diperlukan

Buka: **GitHub → Repository → Settings → Secrets and variables → Actions**

Tambahkan secret berikut:

| Secret Name | Nilai | Keterangan |
|-------------|-------|-----------|
| `DOCKERHUB_USERNAME` | Username Docker Hub kamu | Untuk login & tag image |
| `DOCKERHUB_TOKEN` | Access token Docker Hub | Buat di hub.docker.com → Account Settings → Security |
| `VPS_HOST` | `[IP_ADDRESS]` | IP server |
| `VPS_USERNAME` | `root` | User SSH di server |
| `VPS_SSH_KEY` | Isi private key SSH | Gunakan `cat ~/.ssh/id_rsa` atau key khusus deploy |

### Cara buat SSH key khusus deploy (opsional tapi rekomendasi)

```bash
# Di mesin lokal
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/siagakita_deploy -N ""

# Salin public key ke server
ssh-copy-id -i ~/.ssh/siagakita_deploy.pub root@139.59.99.230

# Isi VPS_SSH_KEY dengan konten private key:
cat ~/.ssh/siagakita_deploy
```

---

## 4. Alur CI/CD Otomatis

```
[Push ke branch main]
        │
        ▼
GitHub Actions (.github/workflows/deploy.yml)
        │
        ├── Job 1: build-and-push
        │     ├── Checkout code
        │     ├── Login ke Docker Hub
        │     └── Build image Go → push ke DockerHub
        │           tag: <username>/siagakita-api:latest
        │
        └── Job 2: deploy-to-vps (setelah Job 1 selesai)
              ├── SSH ke 139.59.99.230
              ├── cd /opt/siagakita
              ├── docker compose pull backend   ← ambil image baru
              ├── docker compose up -d --no-deps backend
              ├── docker image prune -f
              └── Verifikasi health status container
```

**Waktu rata-rata:** ~3–5 menit dari push hingga backend live.

---

## 5. Deploy Manual (darurat)

Jika GitHub Actions gagal atau perlu deploy cepat tanpa push:

```bash
# SSH ke server
ssh root@139.59.99.230
cd /opt/siagakita

# Pull image terbaru dari Docker Hub
docker compose -f docker-compose.prod.yml pull backend

# Restart backend
docker compose -f docker-compose.prod.yml up -d --no-deps backend

# Cek status
docker ps
curl http://localhost:8080/health
```

---

## 6. Monitoring & Troubleshooting

### Cek health API

```bash
curl http://139.59.99.230:8080/health
# Response: {"service":"SiagaKita REST API","status":"ok"}
```

### Lihat log backend

```bash
ssh root@139.59.99.230
docker logs siagakita_backend -f --tail=100
```

### Log yang perlu diperhatikan saat startup

```
[SuperAdmin] Akun superadmin berhasil dibuat: <email>   ← OK
[API] Starting REST API on :8080                         ← OK
[WS] Starting WebSocket server on :8081                  ← OK
```

### Masalah umum

| Masalah | Penyebab | Solusi |
|---------|---------|--------|
| Backend tidak start | `.env` tidak lengkap | `docker logs siagakita_backend` cek error |
| Superadmin tidak ter-seed | `SUPERADMIN_EMAIL`/`PASS` kosong | Isi .env lalu restart backend |
| Tidak bisa connect WebSocket | Port 8081 tidak terbuka | Cek firewall: `ufw allow 8081/tcp` |
| Database connection refused | postgres belum healthy | Tunggu 30 detik, cek `docker ps` |
| Image pull gagal di GitHub Actions | `DOCKERHUB_TOKEN` expired | Buat token baru di Docker Hub |
| Upload foto/audio gagal | Direktori `/opt/siagakita/uploads` belum ada atau permission salah | `mkdir -p /opt/siagakita/uploads && chmod 755 ...` |
| File upload tidak bisa diakses publik | `UPLOAD_BASE_URL` salah di `.env` | Sesuaikan dengan IP/domain VPS, restart backend |
| Volume tidak ter-mount | `docker-compose.prod.yml` belum memiliki `volumes` | Cek section `volumes` di service `backend`, lakukan `up -d --force-recreate backend` |

### Buka port di firewall VPS

```bash
ssh root@139.59.99.230

ufw allow 22/tcp    # SSH
ufw allow 8080/tcp  # REST API
ufw allow 8081/tcp  # WebSocket
ufw enable
ufw status
```

---

## 7. Setup Aplikasi Mobile & Console (Client Side)

Aplikasi mobile (`mobile-flutter`) dan console (`windows_console_flutter`) tidak menggunakan hardcode IP server. Sebagai gantinya, IP server diambil dari file `.env` di direktori `infrastructure/` menggunakan fitur native Flutter `--dart-define-from-file`.

### Cara Menjalankan (Development)
```bash
# Untuk Mobile (Masyarakat & Relawan)
cd mobile-flutter
flutter run --dart-define-from-file=../infrastructure/.env

# Untuk Console (Instansi & Admin)
cd windows_console_flutter
flutter run --dart-define-from-file=../infrastructure/.env
```

### Cara Membangun (Build)
```bash
# Build Android APK
flutter build apk --dart-define-from-file=../infrastructure/.env

# Build Windows EXE
flutter build windows --dart-define-from-file=../infrastructure/.env
```

> [!CAUTION]
> Pastikan variabel `API_HOST` sudah ada di `infrastructure/.env` sebelum menjalankan build/run. Jangan menggunakan default value di kode untuk menyembunyikan IP publik.

---

## 8. Menjalankan Migrasi Database

> ⚠️ **PERINGATAN:** Migrasi `003_schema_v3.sql` menghapus SEMUA data. Migrasi `005_reports_v2.sql` bersifat *additive* dan aman dijalankan di production.

### Reset database (fresh setup / dev):

```bash
# Dari mesin lokal, kirim file migrasi
scp backend-go/migrations/003_schema_v3.sql root@139.59.99.230:/tmp/

# SSH ke server
ssh root@139.59.99.230

# Jalankan migrasi
docker exec -i siagakita_postgres psql \
  -U siagakita_admin -d siagakita \
  < /tmp/003_schema_v3.sql

# Hapus file setelah dipakai
rm /tmp/003_schema_v3.sql

# Restart backend (agar superadmin ter-seed ulang)
docker restart siagakita_backend
```

### Migrasi incremental — Reports v2 (005):

```bash
# Dari mesin lokal
scp backend-go/migrations/005_reports_v2.sql root@139.59.99.230:/opt/siagakita/

# SSH ke server
ssh root@139.59.99.230
cd /opt/siagakita

# Jalankan migrasi (aman, tidak menghapus data lama)
docker exec -i siagakita_postgres psql \
  -U $DB_USER -d siagakita \
  < /opt/siagakita/005_reports_v2.sql
```

---

> 📌 Untuk konfigurasi environment variables lebih lengkap, lihat `infrastructure/.env-example`
> 📌 Untuk arsitektur backend, lihat `docs/BACKEND_ARCHITECTURE.md`
