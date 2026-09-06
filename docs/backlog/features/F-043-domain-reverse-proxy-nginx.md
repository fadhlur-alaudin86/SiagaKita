# F-043: Migrasi Direct IP ke Domain, Reverse Proxy Nginx & Multi-Environment Configuration

## Issue Metadata

| Field | Value |
|-------|-------|
| ID | F-043 |
| Title | [Infra/Security] Migrasi Direct IP ke Domain, Reverse Proxy Nginx & Multi-Environment Configuration |
| Requestor | Fadhlurrahman Alaudin |
| Date Created | 2026-09-06 |
| GitHub Issue | #43 |
| Status | In Progress |

## Discovery (Step -2)

| Type | File / Name | Notes |
|------|-------------|-------|
| Infrastructure | `infrastructure/docker-compose.prod.yml` | Mengonfigurasi container backend, database postgres, redis, dan reverse proxy nginx |
| Reverse Proxy | `infrastructure/nginx/nginx.conf` | Routing HTTPS REST API dan WSS WebSocket upgrade dengan SSL termination |
| Multi-Env | `infrastructure/.env.dev`, `infrastructure/.env.prod` | Pemisahan konfigurasi environment lokal dan produksi |
| Mobile Config | `mobile-flutter/lib/core/constants/api_config.dart` | Refaktor pembacaan `API_BASE_URL` dan `WS_BASE_URL` |
| Desktop Config | `windows_console_flutter/lib/core/constants/api_constants.dart` | Refaktor pembacaan `API_BASE_URL` dan `WS_BASE_URL` |
| Documentation | `docs/DEPLOYMENT_GUIDE.md` | Pembaruan panduan deployment, SSL Cloudflare, dan firewall ufw |

## 5 Clarifying Questions

| # | Question | Answer |
|---|----------|--------|
| 1 | Apakah port backend 8080 dan 8081 masih boleh diekspos ke publik di production? | Tidak. Seluruh akses publik harus melalui Nginx (port 80 dan 443). Port backend hanya diexpose ke internal network. |
| 2 | Bagaimana routing traffic WebSocket di Nginx? | Path `/v1/ws/` dan `/ws/` di-proxy ke `backend:8081` dengan headers `Upgrade $http_upgrade` dan `Connection $connection_upgrade` serta timeout 86400s. |
| 3 | Bagaimana jika pengembang menjalankan klien lokal hanya dengan `API_HOST` lama? | `ApiConfig` dan `ApiConstants` mengimplementasikan fallback backward-compatible ke `http://$API_HOST:8080/api/v1` dan `ws://$API_HOST:8081/v1/ws/connect`. |
| 4 | Apa format sertifikat SSL yang digunakan Nginx di VPS? | Mendukung sertifikat Cloudflare Origin CA (`cert.pem` dan `key.pem`) atau Let's Encrypt. Disediakan script helper self-signed untuk local testing. |
| 5 | Port firewall VPS (ufw) apa saja yang dibuka? | Hanya port 22 (SSH), 80 (HTTP), dan 443 (HTTPS). Port 8080 dan 8081 ditutup dari akses luar. |

## Step Progress

| Step | Action | Status | Date | Notes |
|------|--------|--------|------|-------|
| -3 | Backlog Overview | ✅ Done | 2026-09-06 | Review Issue #43 dan dependensi arsitektur |
| -2 | Discovery | ✅ Done | 2026-09-06 | CodeGraph preview pada `ApiConfig`, `ApiConstants`, dan compose files |
| -1 | Resolve backlog | ✅ Done | 2026-09-06 | Dokumen F-043-domain-reverse-proxy-nginx.md dibuat |
| 0 | Branch | ✅ Done | 2026-09-06 | Branch `feature/F-043-domain-reverse-proxy-nginx` & label `status: in-progress` |
| 1 | Read mapping | ✅ Done | 2026-09-06 | Pemetaan port, env vars, dan routing upstream |
| 2 | Nginx & Docker Setup | ✅ Done | 2026-09-06 | Buat `nginx.conf`, placeholder SSL, dan update `docker-compose.prod.yml` |
| 3 | Multi-Env Configuration | ✅ Done | 2026-09-06 | Buat `.env.dev`, `.env.prod`, dan update `.env.example` |
| 4 | Client Refactoring | ✅ Done | 2026-09-06 | Refaktor `api_config.dart` dan `api_constants.dart` |
| 5 | Documentation Update | ✅ Done | 2026-09-06 | Update `DEPLOYMENT_GUIDE.md` |
| 6 | Verification | ✅ Done | 2026-09-06 | `nginx -t`, `flutter analyze`, `go test -v -race ./...` lulus tanpa kendala |
| 7 | CI + Review | ✅ Done | 2026-09-06 | Validasi dan persiapan status ready |
| 8 | Close Log | ✅ Done | 2026-09-06 | Finalisasi feature log F-043 |

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-09-06 | Menggunakan Nginx reverse proxy di `docker-compose.prod.yml` | Melindungi IP server asli, terminasi SSL/TLS, proteksi WAF headers, dan routing tunggal domain. |
| 2026-09-06 | Menutup port publik 8080 & 8081 pada container backend | Mencegah akses bypass langsung tanpa enkripsi dan tanpa filter reverse proxy. |
| 2026-09-06 | Menambahkan fallback backward-compatible di klien Flutter | Menjaga alur kerja developer lokal tetap lancar tanpa breaking change mendadak. |
