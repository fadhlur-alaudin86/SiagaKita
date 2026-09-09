# PostgreSQL & Database Development Patterns — SiagaKita

PostgreSQL 15 architecture and query optimization standards with the `pgx/v5` driver for SiagaKita. Adapted from ECC (*Everything Claude Code*) high-performance engineering principles.  
Sub-file of [SKILL.md](SKILL.md).

---

## 1. Core Principles & Philosophy

SiagaKita is a disaster and emergency response system characterized by:
- **High Concurrency during Emergencies**: Sudden spikes in SOS incident reports, volunteer dispatch broadcasts, and real-time location telemetry.
- **Critical Temporal Integrity**: Chronological event ordering must remain precise across time zones (`timestamptz`).
- **No ORM**: Uses raw SQL via `pgxpool.Pool` for full query transparency, execution speed, and granular indexing control.

---

## 2. Indexing Strategy

Proper indexing differentiates millisecond response times from request timeouts during peak disaster events.

### A. Index Selection Guide

| Query Pattern | Index Type | SQL Syntax Example | SiagaKita Use Case |
|---|---|---|---|
| Equality (`col = 'val'`) | **B-Tree** (default) | `CREATE INDEX idx_users_phone ON users(phone);` | Account lookups by phone/email |
| Range / Order (`col > x`, `ORDER BY col DESC`) | **B-Tree** | `CREATE INDEX idx_incidents_created ON incidents(created_at DESC);` | Emergency incident feed ordering |
| JSONB Key-Value (`jsonb @> '{"status": "ok"}'`) | **GIN** | `CREATE INDEX idx_telemetry_payload ON volunteer_telemetry USING gin(payload);` | Dynamic telemetry payloads, incident metadata |
| Foreign Key references | **B-Tree** | `CREATE INDEX idx_responses_incident_id ON incident_responses(incident_id);` | Prevents sequential scans during JOINs and cascade deletes |

### B. Composite Index Column Ordering
When creating composite indexes on multiple columns `(col_a, col_b)`, follow the selectivity rule:
1. **Equality columns first**: Columns filtered with equality (`=`).
2. **Range / Sort columns last**: Columns filtered with range operators (`<`, `>`, `BETWEEN`) or used in `ORDER BY`.

```sql
-- Target Query:
-- SELECT * FROM incidents WHERE status = 'ACTIVE' AND created_at >= NOW() - INTERVAL '1 day' ORDER BY created_at DESC;

-- ✅ GOOD: equality (status) first, range/sort (created_at) second:
CREATE INDEX idx_incidents_status_created ON incidents (status, created_at DESC);

-- ❌ BAD: range column first makes the index inefficient for status filtering:
CREATE INDEX idx_incidents_created_status ON incidents (created_at DESC, status);
```

### C. Partial Indexes for Active Records
For high-volume tables where most rows are archived or resolved (e.g. dispatch queues or completed incidents), use **Partial Indexes** to conserve RAM and index size:

```sql
-- Indexes only unresolved incidents:
CREATE INDEX idx_active_incidents ON incidents (created_at DESC)
WHERE status IN ('PENDING', 'DISPATCHED', 'IN_PROGRESS');
```

---

## 3. Data Type Conventions

| Requirement | Mandatory Type | Avoid | Rationale |
|---|---|---|---|
| Timestamp | `timestamptz` | `timestamp` | Stores UTC offset; prevents time zone ambiguity in disaster audit logs. |
| Sequential ID | `bigint` / `BIGSERIAL` | `integer`, random `uuid` v4 | `bigint` avoids key exhaustion and maintains sequential B-tree locality without fragmentation. |
| Text / Strings | `text` | `varchar(255)` | In PostgreSQL, `text` and `varchar` have identical performance; enforce lengths at domain/application validation. |
| Monetary / Points | `numeric(10,2)` / `integer` (cents) | `float`, `double precision` | Prevents floating-point rounding errors. |
| Status Flags | `boolean` | `varchar(1)`, `int` | Clean 1-byte representation optimized for indexing. |
| Flexible Payloads | `jsonb` | `json` | Stored in decomposed binary format supporting GIN indexing and fast lookups. |

---

## 4. Transaction & Connection Standards (`pgx/v5`)

### A. Mandatory Context & Timeout
Never execute database queries without an explicit timeout bound to the request context:

```go
// ✅ GOOD: Timeout bound to request context
ctx, cancel := context.WithTimeout(c.Context(), 3*time.Second)
defer cancel()

row := db.QueryRow(ctx, "SELECT id, status FROM incidents WHERE id = $1", incidentID)
```

### B. Atomic Transaction Pattern (`pgx.Tx`)
Any workflow mutating multiple tables (e.g., incident creation + volunteer assignment + audit log) MUST run inside an atomic transaction with `defer tx.Rollback(ctx)`:

```go
tx, err := db.Begin(ctx)
if err != nil {
    return fmt.Errorf("begin transaction: %w", err)
}
// Safe: Rollback is a no-op if tx has already been committed
defer tx.Rollback(ctx)

// 1. First mutation
if _, err := tx.Exec(ctx, "UPDATE incidents SET status = $1 WHERE id = $2", newStatus, id); err != nil {
    return fmt.Errorf("update incident: %w", err)
}

// 2. Second mutation
if _, err := tx.Exec(ctx, "INSERT INTO incident_logs (incident_id, action) VALUES ($1, $2)", id, action); err != nil {
    return fmt.Errorf("insert incident log: %w", err)
}

// 3. Commit
if err := tx.Commit(ctx); err != nil {
    return fmt.Errorf("commit transaction: %w", err)
}
return nil
```

---

## 5. Database Migration Standards

Migration files live in `backend-go/migrations/` with format `NNN_description.sql`.

### Zero-Downtime Migration Rules:
1. **DDL Idempotency**: Always use `CREATE TABLE IF NOT EXISTS`, `DROP TABLE IF EXISTS`, or `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`.
2. **Lock Avoidance**:
   - When adding new columns to existing large tables, avoid `NOT NULL` without a default value or apply changes in staged migrations.
3. **Mandatory Documentation Sync**:
   - Any SQL migration modifying schema MUST update [`docs/DATABASE_SCHEMA.md`](../../docs/DATABASE_SCHEMA.md) AND the Mermaid ERD in [`docs/design/database-erd.md`](../../docs/design/database-erd.md).

---

## 6. Prohibited Anti-Patterns

1. **SQL Injection via String Interpolation**:
   ```go
   // ❌ PROHIBITED: Vulnerable to SQL Injection
   query := fmt.Sprintf("SELECT * FROM users WHERE phone = '%s'", phone)
   
   // ✅ MANDATORY: Use parameterized placeholders ($1, $2, ...)
   query := "SELECT * FROM users WHERE phone = $1"
   ```
2. **Foreign Keys Without Indexes**:
   - Adding `REFERENCES other_table(id)` without a corresponding B-Tree index causes sequential table locks when the parent record is modified or deleted.
3. **Ignoring Scan Errors**:
   ```go
   // ❌ PROHIBITED: Swallowing scan errors
   _ = rows.Scan(&id, &name)
   
   // ✅ MANDATORY: Always check and wrap scan errors
   if err := rows.Scan(&id, &name); err != nil {
       return fmt.Errorf("scan incident row: %w", err)
   }
   ```

---

## 7. Reversible Migrations & Rollback Safety Architecture

Every migration file in `backend-go/migrations/` MUST strictly comply with the reversible migration standard:

### 1. Mandatory Paired `.up.sql` and `.down.sql` Scripts
- Every migration must be authored as a pair:
  - `NNN_title.up.sql`: Applies the forward DDL mutation.
  - `NNN_title.down.sql`: Performs the exact inverse DDL operation (e.g. `DROP TABLE IF EXISTS`, `DROP INDEX IF EXISTS`, `ALTER TABLE ... DROP COLUMN IF EXISTS`).
- Numbering must be sequentially zero-padded: `001_...`, `002_...`, `019_...`. Version collisions are strictly forbidden.

### 2. Expand & Contract (Parallel Run) Pattern
- **Forward-Compatible Schema Changes**: All schema modifications MUST be designed backward-compatible with the immediately preceding backend release.
- **Phase 1 (Expand)**: Add new nullable columns or tables with default values. Both old and new backend code can execute concurrently against the same schema.
- **Phase 2 (Contract)**: Deprecated columns or tables are purged in a subsequent migration only after the new code release has stabilized in production.

### 3. Production Rollback Safety Rule
- **Prohibition of Blind Automated Down-Migrations**: Deployment workflows in CI/CD (e.g. `release-deploy.yml`) rollback the Docker image on health check failure, but MUST NOT blindly execute `down.sql`. Executing destructive DDL (such as `DROP COLUMN` or `DROP TABLE`) against production databases that accepted live traffic risks irreversible customer data loss.
- **Manual Emergency Rollback**: Schema rollbacks are executed intentionally by engineers using `siagakita-migrate down 1` via terminal after inspecting data integrity.
