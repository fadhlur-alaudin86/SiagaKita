# Plan 06: Backend Performance Optimization (pgx/sqlc & sync.Pool)

## 1. Overview & Problem Statement
- **Target Issues**: Sub-Issues [#24](https://github.com/fadhlur-alaudin86/SiagaKita/issues/24) & [#25](https://github.com/fadhlur-alaudin86/SiagaKita/issues/25) (completing Parent Issue [#38](https://github.com/fadhlur-alaudin86/SiagaKita/issues/38))
- **Status**: Implemented & In Review via Pull Request [#97](https://github.com/fadhlur-alaudin86/SiagaKita/pull/97)
- **Problem**:
  1. High-frequency GPS telemetry ingestion (`PUT /api/v1/telemetry/location`) creates severe memory churn in the Go runtime. Every incoming update allocates anonymous request structs and untyped `map[string]interface{}` envelopes for WebSocket broadcasting, triggering frequent Garbage Collection (GC) pauses and increasing tail latency (p99) during emergency spikes.
  2. Latency-critical read queries, specifically geospatial proximity searches (`FindNearby` Haversine bounding distance) and volunteer active mission lookups, executed through GORM's reflection-based raw query interface (`r.db.Raw().Scan()`), introducing runtime reflection overhead and connection locking on top of `database/sql`.
- **Goal**:
  1. Eliminate heap allocation churn in the telemetry path using `sync.Pool` object recycling, Sonic direct unmarshaling, and typed broadcast payloads.
  2. Implement a dual-driver database pattern: establish native `pgxpool.Pool` connection pooling alongside GORM, and compile spatial queries into type-safe, zero-reflection Go code via `sqlc` v2.

---

## 2. Technical Scope & Specifications

### 2.1 Telemetry Object Pooling & Sonic Serialization ([#25](https://github.com/fadhlur-alaudin86/SiagaKita/issues/25))
- Create thread-safe `sync.Pool` in `backend-go/internal/domain/telemetry/pool.go` for `LocationUpdateRequest` with safe `Reset()` routines.
- Replace `c.BodyParser(&body)` with direct `sonic.Unmarshal(c.Body(), req)`.
- Replace untyped `map[string]interface{}` broadcast envelopes with concrete `LocationBroadcastPayload` structs.
- Switch WebSocket message serialization in `internal/hub/hub.go` from standard `encoding/json` to `github.com/bytedance/sonic`.

### 2.2 Dual-Driver Connection Pooling & sqlc Query Compilation ([#24](https://github.com/fadhlur-alaudin86/SiagaKita/issues/24))
- **Connection Pool**: Implement `database.NewPgxPool(ctx, cfg)` using `github.com/jackc/pgx/v5/pgxpool` with configurable pool limits (`DBMaxConns`, `DBMinConns`, `DBMaxConnLifetime`, `DBMaxConnIdleTime`) in `internal/config/config.go`.
- **Compile-Time Queries (`sqlc`)**:
  - Configure `backend-go/sqlc.yaml` and dedicated table DDL at `internal/database/sqlc/schema.sql`.
  - Author parameterized queries for `FindNearbyIncidents` (Haversine calculation) and `GetActiveResponseByVolunteer` in `internal/database/queries/incidents.sql`.
  - Wire `*sqlc.Queries` into `incident.Repository`, delegating hotpath lookups to pgx binary protocol while retaining GORM for admin relational mutations.

---

## 3. Tasks & Implementation Checklist

### 3.1 Object Pooling Tasks ([#25](https://github.com/fadhlur-alaudin86/SiagaKita/issues/25))
- [x] Create struct buffer pool and lifecycle management in `domain/telemetry/pool.go`.
- [x] Integrate `AcquireLocationUpdateRequest` and `ReleaseLocationUpdateRequest` in `handler.go`.
- [x] Replace map broadcast payloads with `LocationBroadcastPayload` and optimize `hub.go`.
- [x] Measure memory allocations via Go benchmark suite with `b.ReportAllocs()`.

### 3.2 Database Migration Tasks ([#24](https://github.com/fadhlur-alaudin86/SiagaKita/issues/24))
- [x] Configure `pgxpool.Pool` side-by-side with GORM in `internal/database/postgres.go`.
- [x] Author parameterized SQL queries and compile via `sqlc generate`.
- [x] Route `FindNearby` and `GetActiveResponse` through `sqlc.Queries` in `incident.Repository`.
- [x] Document dual-driver architecture in `docs/DATABASE_SCHEMA.md`.

---

## 4. Affected Components & Files

- `backend-go/internal/domain/telemetry/pool.go` (new)
- `backend-go/internal/domain/telemetry/pool_test.go` (new)
- `backend-go/internal/domain/telemetry/handler.go`
- `backend-go/internal/hub/hub.go`
- `backend-go/internal/config/config.go`
- `backend-go/internal/database/postgres.go`
- `backend-go/internal/database/queries/incidents.sql` (new)
- `backend-go/internal/database/sqlc/` (new)
- `backend-go/internal/domain/incident/repository.go`
- `backend-go/internal/domain/incident/repository_test.go` (new)
- `backend-go/sqlc.yaml` (new)
- `backend-go/cmd/api/main.go`
- `docs/DATABASE_SCHEMA.md`
- `docs/backlog/features/F-024-F-025-pgx-sqlc-syncpool.md` (new)

---

## 5. Verification & Acceptance Criteria

1. **Benchmark Results (Intel Core i5-10500H @ 2.50GHz)**:
   - `UpdateLocation_WithPool`: 364.3 ns/op (66.6% speedup, 3x throughput improvement).
   - `BroadcastPayload_Typed`: 266.8 ns/op (86.6% speedup).
   - Memory allocation reduction: 67.5% reduction in heap bytes (624 B/op down to 203 B/op) and 81.2% fewer allocations (16 allocs/op down to 3 allocs/op), surpassing the >= 40% criteria.
2. **Race Safety & Quality**:
   - `go test -race ./...` passed across all packages with zero data races.
   - `golangci-lint run` reports 0 issues.
   - GitHub Actions CI on PR #97 passed 100% green.
