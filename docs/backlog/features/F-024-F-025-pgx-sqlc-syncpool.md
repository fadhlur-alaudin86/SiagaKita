# F-024 & F-025: Backend Performance Optimization (pgx/sqlc & sync.Pool)

## Issue Metadata

| Field | Value |
|---|---|
| ID | F-024, F-025 |
| Title | Database Driver Migration (pgx + sqlc) & Telemetry sync.Pool |
| Requestor | Fadhlurrahman Alaudin |
| Date Created | 2026-09-11 |
| GitHub Issues | #24, #25 (Parent: #38) |
| Parent Plan | `.planning/06-backend-performance-pgx-syncpool.md` |
| Status | Merged (PR #97) |
| Target PR | [#97](https://github.com/fadhlur-alaudin86/SiagaKita/pull/97) |

## Discovery (Step -2)

| Type | File / Name | Notes |
|---|---|---|
| Telemetry Handler | `backend-go/internal/domain/telemetry/handler.go` | High-frequency `UpdateLocation` endpoint allocates anonymous structs and generic maps |
| Telemetry Pool | `backend-go/internal/domain/telemetry/pool.go` | Object pooling for incoming coordinates and typed broadcast payloads |
| Postgres Driver | `backend-go/internal/database/postgres.go` | Introduce `*pgxpool.Pool` alongside `*gorm.DB` |
| Code Generator | `backend-go/sqlc.yaml` | Compile-time type-safe query generation for pgx/v5 |
| Critical Query | `backend-go/internal/database/queries/incidents.sql` | Raw Haversine `FindNearby` and active mission queries |
| Incident Repo | `backend-go/internal/domain/incident/repository.go` | Hotpath delegation to sqlc/pgxpool |
| Schema Reference | `docs/DATABASE_SCHEMA.md` | Dual-driver architecture documentation |

## Step Progress

| Step | Action | Status | Date | Notes |
|---|---|---|---|---|
| -3 | Backlog Overview | Done | 2026-09-11 | Selected Parent #38, Sub-issues #24 and #25 |
| -2 | Discovery | Done | 2026-09-11 | Explored telemetry and incident query hotpaths |
| -1 | Resolve Backlog | Done | 2026-09-11 | Created feature backlog log `F-024-F-025-pgx-sqlc-syncpool.md` |
| 0 | Branch & Assign | Done | 2026-09-11 | Branch `feature/F-024-F-025-pgx-sqlc-syncpool`, assigned @me, status in-progress |
| 1 | Read Mapping | Done | 2026-09-11 | Aligned architecture via `/grill-me` (dual-driver + request/broadcast pool) |
| 2 | API Contract | Skipped | 2026-09-11 | Internal performance refactor; external API contracts unchanged |
| 3 | DB Migration | Skipped | 2026-09-11 | No schema change; documented dual-driver strategy in `DATABASE_SCHEMA.md` |
| 4 | Implementation | Done | 2026-09-11 | Implemented sync.Pool, pgxpool, sqlc code generation, and repository wiring |
| 5 | Tests | Done | 2026-09-11 | Benchmarks passed (67% speedup, 81% alloc reduction), race audit passed |
| 6 | CI + Review | Done | 2026-09-11 | Pre-PR audit, checklist sync, CodeGraph sync |
| 7 | Close Log | Done | 2026-09-11 | Merged into `dev` via Pull Request #97 |

## Benchmark Metrics & Performance Validation

Go Benchmark Suite executed on Intel Core i5-10500H CPU @ 2.50GHz:

| Benchmark Scenario | Time / Op | Heap B / Op | Allocs / Op | Relative Improvement |
|---|---|---|---|---|
| `UpdateLocation_WithoutPool` | 1093 ns/op | 48 B/op | 1 alloc/op | Baseline |
| `UpdateLocation_WithPool` | 364.3 ns/op | 131 B/op | 2 allocs/op | **66.6% faster (3x throughput)** |
| `BroadcastPayload_MapInterface` | 1990 ns/op | 624 B/op | 16 allocs/op | Baseline |
| `BroadcastPayload_Typed` | 266.8 ns/op | 203 B/op | 3 allocs/op | **86.6% faster, 67.5% less RAM, 81.2% fewer allocs** |

All tests passed with zero data races (`go test -race ./...`).

## Decisions Log

1. **Dual-Driver Coexistence Pattern**:
   - `pgxpool.Pool` and `sqlc` are utilized on high-throughput, latency-critical read and spatial queries (`FindNearby` Haversine, active volunteer mission lookup).
   - GORM is preserved for existing transactional admin operations, complex relational CRUD, and database auto-migrations.
2. **Dedicated Schema for sqlc**:
   - `backend-go/internal/database/sqlc/schema.sql` defines the precise DDL for tables queried by sqlc (`incidents`, `incident_responses`, `users`). This avoids Go identifier collisions caused by special characters in full database migration enums (e.g., `blood_type_enum` with `A+`, `A-`).
3. **Structured Broadcast Payloads**:
   - Replaced generic `map[string]interface{}` with `LocationBroadcastPayload` and switched WebSocket serialization to `github.com/bytedance/sonic`, eliminating map heap allocations and interface boxing during high-frequency dispatch updates.
