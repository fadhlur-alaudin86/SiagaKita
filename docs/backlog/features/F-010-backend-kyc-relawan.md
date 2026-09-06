# F-010: Backend Implementasi Endpoint KYC Relawan (Pending Queue, Approve & Reject)

## Issue Metadata

| Field | Value |
|-------|-------|
| ID | F-010 |
| Title | [Backend] Implementasi Endpoint KYC Relawan (Pending Queue, Approve & Reject) |
| Requestor | Fadhlurrahman Alaudin |
| Date Created | 2026-09-06 |
| GitHub Issue | #10 |
| Status | In Progress |

## Discovery (Step -2)

| Type | File / Name | Notes |
|------|-------------|-------|
| Go Domain | `backend-go/internal/domain/admin` | Berisi handler, service, repository, model admin |
| Endpoint | `GET /api/v1/admin/volunteers/pending`<br>`POST /api/v1/admin/volunteers/:id/approve`<br>`POST /api/v1/admin/volunteers/:id/reject` | RBAC `AdminOnly()` |
| DB Table | `volunteer_certifications`, `user_profiles`, `users`, `volunteer_reputation` | Status certs, relawan role & reputation |
| Mobile Screen | N/A (Registrasi relawan ada di `mobile-flutter/lib/features/masyarakat/volunteer_registration_screen.dart`) | Pengguna warga mendaftar relawan |
| Desktop Screen | `windows_console_flutter/lib/features/admin/presentation/pages/kyc_relawan_page.dart` | Shell verifikasi KYC Relawan oleh Admin |

## 5 Clarifying Questions

| # | Question | Answer |
|---|----------|--------|
| 1 | Siapa saja role yang berhak mengakses endpoint KYC Relawan? | Hanya `admin` dan `superadmin` (`AdminOnly()`). Non-admin harus menerima HTTP 403 Forbidden. |
| 2 | Apa yang terjadi saat admin menyetujui KYC relawan? | Status semua sertifikat pending relawan diubah ke `approved` (`verified_by` dicatat), `is_verified_volunteer` diset `true`, role di-upgrade ke `volunteer`, dan entri `volunteer_reputation` diinisialisasi jika belum ada. |
| 3 | Apa yang terjadi saat admin menolak KYC relawan? | Status sertifikat pending relawan diubah ke `rejected` (`verified_by` dicatat). Role user tetap `civilian`. |
| 4 | Format payload apa yang dibutuhkan untuk penolakan KYC? | JSON payload `{"reason": "..."}`. Jika reason kosong, fallback ke default alasan penolakan. |
| 5 | Atribut profil apa yang dibutuhkan oleh UI Desktop Console pada data antrian KYC? | `user_id`, `full_name`, `email`, `nik`, `phone_number`, `nik_photo_url`, `volunteer_experience`, `certifications`, dan `submitted_at`. |

## Step Progress

| Step | Action | Status | Date | Notes |
|------|--------|--------|------|-------|
| -3 | Backlog Overview | ✅ Done | 2026-09-06 | 36 issues diidentifikasi, Issue #10 terpilih sebagai P0 blocker |
| -2 | Discovery | ✅ Done | 2026-09-06 | CodeGraph preview pada domain admin dan console UI |
| -1 | Resolve backlog | ✅ Done | 2026-09-06 | Dokumen F-010-backend-kyc-relawan.md dibuat |
| 0 | Branch | ✅ Done | 2026-09-06 | Branch `feature/F-010-backend-kyc-relawan` & label `status: in-progress` |
| 1 | Read mapping | ✅ Done | 2026-09-06 | Pemetaan field DTO vs skema DB user_profiles |
| 2 | API Contract | ✅ Done | 2026-09-06 | Update `docs/api/paths/admin.yaml` dengan phone_number dan nik_photo_url |
| 3 | DB Migration | ✅ Skipped | 2026-09-06 | Kolom `phone_number` dan `kyc_ktp_url` sudah ada di tabel `user_profiles` |
| 4 | Backend Implementation | ✅ Done | 2026-09-06 | DTO, query SQL, pagination headers, dan 404 handling |
| 5 | Flutter Implementation | ✅ Verified | 2026-09-06 | `windows_console_flutter` siap mengonsumsi field DTO yang diperbarui |
| 6 | Tests | ✅ Done | 2026-09-06 | Test suite `handler_test.go` lulus 100% |
| 7 | CI + Review | ✅ Done | 2026-09-06 | Unit test dan golangci-lint lolos dengan 0 issue |
| 8 | Close Log | ⬜ Pending | 2026-09-06 | Menunggu PR review dan merge |

## Test Cases

| Layer | Test Name | Scenario | Run Command | Last Run | Status |
|-------|-----------|----------|-------------|----------|--------|
| handler | `TestKYC_RBAC_Unauthorized` | 401 on missing token | `go test -v -race ./internal/domain/admin/...` | 2026-09-06 | ✅ PASS |
| handler | `TestKYC_RBAC_Forbidden_Roles` | 403 on non-admin roles | `go test -v -race ./internal/domain/admin/...` | 2026-09-06 | ✅ PASS |
| handler | `TestKYC_Reject_BadRequest_InvalidJSON` | 400 on malformed body | `go test -v -race ./internal/domain/admin/...` | 2026-09-06 | ✅ PASS |
| handler | `TestKYC_WithLiveDB/GET_Pending_KYC_Success` | 200 OK pending queue | `go test -v -race ./internal/domain/admin/...` | 2026-09-06 | ✅ PASS |
| handler | `TestKYC_WithLiveDB/GET_Pending_KYC_Pagination` | 200 OK + pagination headers | `go test -v -race ./internal/domain/admin/...` | 2026-09-06 | ✅ PASS |
| handler | `TestKYC_WithLiveDB/POST_Approve_NotFound` | 404 on unknown target | `go test -v -race ./internal/domain/admin/...` | 2026-09-06 | ✅ PASS |
| handler | `TestKYC_WithLiveDB/POST_Reject_NotFound` | 404 on unknown target | `go test -v -race ./internal/domain/admin/...` | 2026-09-06 | ✅ PASS |

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-09-06 | Menambahkan `phone_number` dan `nik_photo_url` ke `VolunteerKYC` | Memungkinkan Desktop Console menampilkan KTP dan kontak relawan secara lengkap tanpa breaking changes. |
| 2026-09-06 | Inisialisasi `volunteer_reputation` pada `ApproveKYC` | Mencegah inkonsistensi data ketika relawan baru disetujui pertama kali. |
