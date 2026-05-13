# 📚 SiagaKita — Dokumentasi

> Folder ini berisi semua dokumentasi teknis proyek SiagaKita.
> **Selalu update docs ini setiap ada perubahan signifikan.**

---

## Dokumen yang Tersedia

| File | Deskripsi | Terakhir Diperbarui |
|------|-----------|---------------------|
| [PROGRESS_REPORT.md](./PROGRESS_REPORT.md) | Laporan kemajuan, changelog per sprint, status komponen, TODO | 13 Mei 2026 |
| [BACKEND_ARCHITECTURE.md](./BACKEND_ARCHITECTURE.md) | Struktur folder Go, DDD pattern, auth flow, RBAC, WebSocket, OTP, env vars | 1 Mei 2026 |
| [DATABASE_SCHEMA.md](./DATABASE_SCHEMA.md) | Schema v3 lengkap, semua tabel + SQL, triggers, ERD, keputusan desain | 1 Mei 2026 |
| [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) | Setup VPS, GitHub Secrets, alur CI/CD, troubleshooting, firewall | 1 Mei 2026 |
| [FRONTEND_STRUCTURE.txt](./FRONTEND_STRUCTURE.txt) | Struktur Flutter Mobile (citizen/volunteer), endpoint yang digunakan per screen | 13 Mei 2026 |
| [DESKTOP_PLANNING_ADMIN_INSTANSI.txt](./DESKTOP_PLANNING_ADMIN_INSTANSI.txt) | Struktur Flutter Desktop Console (admin/instansi), fitur per halaman | 1 Mei 2026 |


---

## Quick Reference

### Login Endpoints

| Role | Endpoint | App |
|------|----------|-----|
| civilian, volunteer | `POST /auth/login` | Mobile Citizen |
| superadmin, admin, agency | `POST /auth/console/login` | Desktop Console |
| agency_personnel | `POST /auth/personnel/login` | Mobile Responder *(belum dibuat)* |

### Deploy Backend

```bash
# Setelah perubahan kode Go:
sudo docker compose -f infrastructure/docker-compose.yml up --build -d backend

# Reset database (HAPUS SEMUA DATA):
sudo docker exec -i siagakita_postgres psql -U siagakita_admin -d siagakita \
  < backend-go/migrations/003_schema_v3.sql
```

### Cek Log Superadmin Seeding

```bash
sudo docker logs siagakita_backend 2>&1 | grep SuperAdmin
# Output: [SuperAdmin] Akun superadmin berhasil dibuat: <email>
```

---

## Panduan Kontribusi Docs

1. **Selalu update `PROGRESS_REPORT.md`** setiap sprint atau patch — catat di bagian Changelog
2. **Jika ada perubahan endpoint API** → update tabel di `PROGRESS_REPORT.md` dan `FRONTEND_STRUCTURE.txt`
3. **Jika ada perubahan schema DB** → update `DATABASE_SCHEMA.md` dan buat migration file baru (`backend-go/migrations/00X_...sql`)
4. **Jika ada perubahan arsitektur backend** → update `BACKEND_ARCHITECTURE.md`
5. **Format tanggal**: DD Bulan YYYY (contoh: 1 Mei 2026)
