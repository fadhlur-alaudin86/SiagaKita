# Plan 02: Backend Admin API Finalization

## 1. Overview & Problem Statement
- **Target Issues**: Sub-Issue [#12](https://github.com/fadhlur-alaudin86/SiagaKita/issues/12) & Sub-Issue [#13](https://github.com/fadhlur-alaudin86/SiagaKita/issues/13) (completing Parent Issue [#36](https://github.com/fadhlur-alaudin86/SiagaKita/issues/36))
- **Problem**:
  1. The gamification ranks system (`m_ranks`) has basic CRUD methods, but lacks critical XP threshold validation to ensure tiers are strictly monotonically increasing, non-overlapping, and mathematically consistent.
  2. The `/api/v1/admin/stats` analytics endpoint exhibits inconsistency in its period query parameter (`period=weekly|monthly|yearly` vs `period=week|month|year`) and lacks targeted indexes, leading to sequential table scans and unbounded latency as incident volume scales.
- **Goal**: Harden the `m_ranks` CRUD API with robust domain validation, base rank protection, and auto-downgrade fallback, and optimize `/api/v1/admin/stats` query aggregation to guarantee sub-100ms response times.

---

## 2. Architectural Design & Domain Logic

### 2.1 Gamification Ranks Validation (`m_ranks`) (Aligned via `/grill-me`)
1. **Schema & Hierarchy**:
   - Table: `m_ranks (id serial, rank_name varchar, min_exp int, icon_url varchar)`.
   - **Base Rank Invariant**: There must always be exactly one immutable base rank with `min_exp = 0` (e.g. "Pemula" / "Rookie").
2. **CRUD Domain Rules**:
   - **Create / Update**:
     - `rank_name` must be non-empty and unique (case-insensitive).
     - `min_exp` must be $\ge 0$.
     - Duplicate `min_exp` values are strictly prohibited: no two ranks may share the same XP threshold.
   - **Delete with Base Protection & Auto-Downgrade**:
     - **Base Rank Protection**: Attempting to delete the base rank (`min_exp = 0`) returns `400 Bad Request` with code `ERR_CANNOT_DELETE_BASE_RANK`.
     - **Auto-Downgrade Volunteers**: If a higher or intermediate rank is deleted, all volunteers currently holding that rank in `volunteer_reputation` are atomically updated inside a database transaction to the next highest active rank below the deleted threshold (`SELECT id FROM m_ranks WHERE min_exp < ? ORDER BY min_exp DESC LIMIT 1`).
     - This guarantees foreign key integrity and ensures volunteers never lose rank status or experience data upon administrative rank deprecation.

### 2.2 Analytics Aggregation Optimization (`/admin/stats`)
1. **Parameter Harmonization**:
   - Standard parameter: `GET /api/v1/admin/stats?period=week|month|year` (with backward-compatible fallback for `weekly`, `monthly`, `yearly`).
2. **Metric Scoping**:
   - **Global Metric**: `active_volunteers` (`SELECT COUNT(*) FROM user_profiles WHERE is_verified_volunteer = true`). Must never be filtered by the date interval.
   - **Period-Scoped Metrics**:
     - `total_sos`: Total incidents created within the time window.
     - `total_resolved`: Incidents with `status = 'resolved'` within the window.
     - `total_false_alarm`: Incidents with `status = 'false_alarm'` within the window.
     - `false_alarm_rate`: Percentage of false alarms against total incidents in the window.
     - `avg_response_minutes`: Average duration from `created_at` to `completed_at` for resolved incidents.
     - `by_type`: Categorical count grouped by `incident_type`.
     - `by_status`: Categorical count grouped by `status`.
     - `monthly`: Time-series trend aggregation (daily buckets for `week` and `month`, monthly buckets for `year`).
3. **Database Performance & Indexes**:
   - Add targeted indexes in a new migration `020_add_analytics_indexes.up.sql`:
     - `CREATE INDEX idx_incidents_created_at ON incidents(created_at);`
     - `CREATE INDEX idx_incidents_status_created_at ON incidents(status, created_at);`
     - `CREATE INDEX idx_m_ranks_min_exp ON m_ranks(min_exp);`

---

## 3. Tasks & Implementation Checklist

### 3.1 Gamification Ranks Tasks ([#12](https://github.com/fadhlur-alaudin86/SiagaKita/issues/12))
- [ ] Implement XP boundary validation and uniqueness in `backend-go/internal/domain/admin/service.go`.
- [ ] Implement base rank deletion protection (`min_exp == 0`).
- [ ] Implement atomic volunteer auto-downgrade transaction in `backend-go/internal/domain/admin/repository.go` when a rank is deleted.
- [ ] Add unit tests in `backend-go/internal/domain/admin/handler_test.go` asserting:
  - Successful creation of valid rank.
  - Rejection of duplicate `min_exp`.
  - Rejection of base rank deletion.
  - Auto-downgrade of volunteers when their rank is deleted.

### 3.2 Analytics Optimization Tasks ([#13](https://github.com/fadhlur-alaudin86/SiagaKita/issues/13))
- [ ] Normalize `period` query parameter parsing in `backend-go/internal/domain/admin/handler.go` (`week`, `month`, `year`).
- [ ] Create migration `020_add_analytics_indexes.up.sql` and `020_add_analytics_indexes.down.sql`.
- [ ] Update `docs/DATABASE_SCHEMA.md` to document the new index definitions.
- [ ] Benchmark query execution times using `EXPLAIN ANALYZE` to verify <100ms execution on simulated incident volume.
- [ ] Add unit and integration tests verifying stats response contracts for all 3 time horizons.

---

## 4. Affected Components & Files

- `backend-go/internal/domain/admin/service.go`
- `backend-go/internal/domain/admin/repository.go`
- `backend-go/internal/domain/admin/handler.go`
- `backend-go/internal/domain/admin/handler_test.go`
- `backend-go/migrations/020_add_analytics_indexes.up.sql` [NEW]
- `backend-go/migrations/020_add_analytics_indexes.down.sql` [NEW]
- `docs/DATABASE_SCHEMA.md`

---

## 5. Verification & Acceptance Criteria

1. **Automated Tests**:
   - `cd backend-go && go test -v -race -run "TestRank|TestStats" ./internal/domain/admin/...`
   - `cd backend-go && go run ./cmd/migrate down 1 && go run ./cmd/migrate up`
2. **Acceptance Criteria**:
   - Deleting base rank fails with `400 Bad Request`.
   - Deleting a rank automatically reassigns all affected volunteers to the next lower active rank.
   - `GET /api/v1/admin/stats?period=week` executes with all query stages completing under 100ms.
   - Closing Issue #12 and Issue #13 fulfills all requirements to close Parent Issue #36.
