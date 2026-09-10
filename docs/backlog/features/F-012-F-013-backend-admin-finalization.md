# F-012 & F-013: Backend Admin Gamification Ranks & Analytics Endpoint Finalization

## Issue Metadata

| Field | Value |
|---|---|
| ID | F-012 / F-013 |
| Title | Backend Admin Gamification Ranks & Analytics Endpoint Finalization |
| Requestor | Fadhlurrahman Alaudin |
| Date Created | 2026-09-10 |
| GitHub Issues | #12 & #13 (Parent: #36) |
| Status | Ready for Review |

## Discovery (Step -2)

| Type | File / Name | Notes |
|---|---|---|
| Go Domain | `backend-go/internal/domain/admin` | Admin handlers, service, repository |
| Gamification Ranks | `backend-go/internal/domain/admin/model.go` | `m_ranks` domain model, validation rules |
| Analytics Endpoint | `GET /api/v1/admin/stats` | Aggregated metrics for `week`, `month`, `year` |
| DB Migrations | `backend-go/migrations/` | Adding index optimizations for analytics queries |

## Decisions Aligned via /grill-me

| # | Topic | Decision |
|---|---|---|
| 1 | Gamification Ranks Rules | Base rank (`min_exp = 0`) deletion is strictly forbidden (`ERR_CANNOT_DELETE_BASE_RANK`). Deleting higher ranks automatically downgrades affected volunteers in `volunteer_reputation` to the next highest active rank below the deleted threshold within a DB transaction. |
| 2 | XP Boundary & Uniqueness | XP thresholds (`min_exp`) must be non-negative and strictly unique; no two ranks may share the same `min_exp` or duplicate names. |
| 3 | Analytics Query Normalization | The `period` parameter in `/api/v1/admin/stats` standardizes on `week`, `month`, and `year` with backward-compatible aliases (`weekly`, `monthly`, `yearly`). Global metrics (`active_volunteers`) are never filtered by time windows. |
| 4 | Index Optimization | Introduce migration `020_add_analytics_indexes.up.sql` (`idx_incidents_created_at`, `idx_incidents_status_created_at`, `idx_m_ranks_min_exp`) to guarantee sub-100ms execution times. |

## Step Progress

| Step | Action | Status | Date | Notes |
|---|---|---|---|---|
| -3 | Backlog Overview | ✅ Done | 2026-09-10 | Plan 02 selected to finalize Admin APIs |
| -2 | Discovery & Grill-Me | ✅ Done | 2026-09-10 | Aligned on base rank protection, volunteer auto-downgrade, and query indexing |
| -1 | Resolve Backlog | ✅ Done | 2026-09-10 | Created feature log `F-012-F-013-backend-admin-finalization.md` |
| 0 | Branch & Assign | ✅ Done | 2026-09-10 | Created branch `feature/F-012-F-013-backend-admin-finalization`, assigned Issues #12 & #13 |
| 1 | Read Mapping | ✅ Done | 2026-09-10 | Inspected existing admin domain models, repository, service, and handler |
| 2 | API Contract | ✅ Done | 2026-09-10 | Updated `docs/api/paths/admin.yaml` |
| 3 | DB Migration | ✅ Done | 2026-09-10 | Added migration `020_add_analytics_indexes` and updated `DATABASE_SCHEMA.md` |
| 4 | Backend Implementation | ✅ Done | 2026-09-10 | Implemented rank domain validations, auto-downgrade transaction, and stats normalization |
| 5 | Flutter Implementation | ⏩ Skipped | 2026-09-10 | Desktop UI already built; backend contract parity verified |
| 6 | Tests | ✅ Done | 2026-09-10 | Unit and live DB tests for ranks CRUD and stats analytics in `handler_test.go` and `migrate_test.go` |
| 7 | CI + Review | ✅ Done | 2026-09-10 | Format checks (`gofmt`), `golangci-lint`, and test suite verification (`go test -race ./...`) |
| 8 | Close Log | ✅ Done | 2026-09-10 | All quality gates pass; ready for PR |
