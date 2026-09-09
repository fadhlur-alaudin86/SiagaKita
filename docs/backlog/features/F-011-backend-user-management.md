# F-011: Backend Implementasi Endpoint Manajemen User (List, Ban, Unban, & Reset Strike)

## Issue Metadata

| Field | Value |
|-------|-------|
| ID | F-011 |
| Title | [Backend] Implementasi Endpoint Manajemen User (List, Ban, Unban, & Reset Strike) |
| Requestor | Fadhlurrahman Alaudin |
| Date Created | 2026-09-09 |
| GitHub Issue | #11 (Parent: #36) |
| Status | In Progress |

## Discovery (Step -2)

| Type | File / Name | Notes |
|------|-------------|-------|
| Go Domain | `backend-go/internal/domain/admin` | Berisi handler, service, repository, model admin |
| Endpoint | `GET /api/v1/admin/users`<br>`POST /api/v1/admin/users/:id/ban`<br>`POST /api/v1/admin/users/:id/unban`<br>`DELETE /api/v1/admin/users/:id/strike`<br>`GET /api/v1/admin/users/:id/detail` | RBAC `AdminOnly()` |
| DB Table | `users`, `user_profiles`, `sos_strikes`, `incidents`, `incident_reports` | Status ban, strike count, dan audit log false alarm |
| Desktop Screen | `windows_console_flutter/lib/features/admin/presentation/pages/user_management_page.dart` | Antarmuka pengawasan dan moderasi akun pengguna |

## Decisions Aligned via /grill-me

| # | Topic | Decision |
|---|-------|----------|
| 1 | Audit Log Target | Moderation actions (Ban & Strike Reset) dicatat pada tabel `sos_strikes` (`user_id`, `reason`, `marked_by`, `incident_id = NULL`) tanpa membuat tabel baru. |
| 2 | Ban Duration Mechanism | Mendukung ban sementara dan permanen: jika `days > 0`, set `banned_until = NOW() + days` dan `is_sos_banned = true`. Jika `days <= 0` / tidak dikirim, set `banned_until = NULL` (permanen). `BanCheck` middleware memeriksa kedaluwarsa ban secara otomatis. |
| 3 | Reset Strike Data Policy | Riwayat lama di `sos_strikes` dipertahankan demi jejak audit (*audit trail*). Reset hanya mereset counter `sos_strike_count = 0` dan `is_sos_banned = false` di `user_profiles`, serta mencatat entri log reset baru. |
| 4 | Query Filtering | `GET /api/v1/admin/users` mendukung filter `role` (`civilian`/`volunteer`), `banned` (true/false), `high_strike` (>= 2), dan `search` (email, full_name, NIK). |

## Step Progress

| Step | Action | Status | Date | Notes |
|------|--------|--------|------|-------|
| -3 | Backlog Overview | ✅ Done | 2026-09-09 | Opsi A dipilih untuk menuntaskan sisa fitur Admin Backend |
| -2 | Discovery & Grill-Me | ✅ Done | 2026-09-09 | Interview `/grill-me` menyepakati 3 keputusan desain utama |
| -1 | Resolve backlog | ✅ Done | 2026-09-09 | Dokumen F-011-backend-user-management.md dibuat |
| 0 | Branch & Assign | ✅ Done | 2026-09-09 | Branch `feature/F-011-backend-user-management` dibuat, issue #11 assigned `@me` & `status: in-progress` |
| 1 | Read mapping | ✅ Done | 2026-09-09 | Pemetaan skema `user_profiles` dan `sos_strikes` |
| 2 | API Contract | ✅ Verified | 2026-09-09 | Kontrak endpoint `/api/v1/admin/users/*` di `docs/api/paths/admin.yaml` diverifikasi |
| 3 | DB Migration | ✅ Skipped | 2026-09-09 | Kolom `banned_until`, `is_sos_banned`, `sos_strike_count`, dan tabel `sos_strikes` sudah ada |
| 4 | Backend Implementation | ✅ Done | 2026-09-09 | Implementasi logic audit logging, temporary ban duration, dan role filtering |
| 5 | Flutter Verification | ✅ Verified | 2026-09-09 | Verifikasi payload request dari `user_management_page.dart` |
| 6 | Tests | ✅ Done | 2026-09-09 | Unit tests di `handler_test.go` dan `auth_test.go` lulus 100% |
| 7 | CI + Review | ⏳ Ready | 2026-09-09 | Pre-PR review checklist & tests passing |
| 8 | Close Log | ⬜ Pending | 2026-09-09 | Menunggu PR review dan merge |

## Test Cases

| Layer | Test Name | Scenario | Run Command | Last Run | Status |
|-------|-----------|----------|-------------|----------|--------|
| handler | `TestUserManagement_RBAC_Unauthorized` | 401 on missing token across all user endpoints | `go test -v -race ./internal/domain/admin/...` | 2026-09-09 | ✅ PASS |
| handler | `TestUserManagement_RBAC_Forbidden_Roles` | 403 on non-admin roles (civilian, volunteer, agency) | `go test -v -race ./internal/domain/admin/...` | 2026-09-09 | ✅ PASS |
| handler | `TestUserManagement_BanUser_BadRequest_InvalidJSON` | 400 on malformed body | `go test -v -race ./internal/domain/admin/...` | 2026-09-09 | ✅ PASS |
| handler | `TestUserManagement_WithLiveDB/GET_Users_Success` | 200 OK + filter role, banned, search | `go test -v -race ./internal/domain/admin/...` | 2026-09-09 | ✅ PASS |
| handler | `TestUserManagement_WithLiveDB/POST_Ban_NotFound` | 404 on unknown target user | `go test -v -race ./internal/domain/admin/...` | 2026-09-09 | ✅ PASS |
| handler | `TestUserManagement_WithLiveDB/POST_Unban_NotFound` | 404 on unknown target user | `go test -v -race ./internal/domain/admin/...` | 2026-09-09 | ✅ PASS |
| handler | `TestUserManagement_WithLiveDB/DELETE_ResetStrike_NotFound` | 404 on unknown target user | `go test -v -race ./internal/domain/admin/...` | 2026-09-09 | ✅ PASS |
| handler | `TestUserManagement_WithLiveDB/GET_UserDetail_NotFound` | 404 on unknown target user | `go test -v -race ./internal/domain/admin/...` | 2026-09-09 | ✅ PASS |
| middleware | `TestBanCheck_NoUser` | 200 OK passes unauthenticated request | `go test -v -race ./internal/middleware/...` | 2026-09-09 | ✅ PASS |
