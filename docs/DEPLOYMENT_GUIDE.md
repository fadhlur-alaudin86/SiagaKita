# 🚀 SiagaKita — Panduan Deployment Production

> **Server:** `139.59.99.230` (DigitalOcean / VPS)
> **Diperbarui:** 1 Mei 2026

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
```

### 2c. Verifikasi infrastruktur berjalan

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
| `VPS_HOST` | `139.59.99.230` | IP server |
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

## 7. Reset Database (hati-hati!)

> ⚠️ **PERINGATAN:** Ini menghapus SEMUA data production. Lakukan hanya jika benar-benar perlu.

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

---

> 📌 Untuk konfigurasi environment variables lebih lengkap, lihat `infrastructure/.env-example`
> 📌 Untuk arsitektur backend, lihat `docs/BACKEND_ARCHITECTURE.md`
