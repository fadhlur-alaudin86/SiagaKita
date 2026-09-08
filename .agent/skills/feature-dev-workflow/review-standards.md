# Pre-PR Review Standards & Verification Checklists — SiagaKita

Mandatory code quality, security, and stability verification checklists prior to opening a Pull Request targeting `dev`. Adapted from ECC (*security-reviewer*, *database-reviewer*, and *silent-failure-hunter*) specializations.  
Sub-file of [SKILL.md](SKILL.md).

---

## Step 7 Verification Flow (Pre-PR Gate)

Before the agent opens a Pull Request to `dev`, the agent MUST conduct a self-review covering the three critical dimensions below:

```
[Code Complete & Tests Pass]
              │
              ▼
 ┌────────────────────────────────────────┐
 │ 1. Security Review Checklist           │
 ├────────────────────────────────────────┤
 │ 2. Database & Migration Review         │
 ├────────────────────────────────────────┤
 │ 3. Silent Failure Hunter Audit         │
 └────────────────────────────────────────┘
              │
      (All Passed?)
       ├── ❌ Findings Found ──► Fix code & rerun tests
       └── ✅ Passed          ──► Sync Issue Checklists ──► Open PR to dev
```

---

## 1. Security Review Checklist

Ensures the codebase is free of injection vulnerabilities, credential leakage, and unauthorized access.

| Category | Verification Item | PASS Criteria | FAIL Criteria |
|---|---|---|---|
| **SQL Injection** | `pgx` query parameterization | Uses `$1, $2, ...` placeholders | Uses `fmt.Sprintf` or string concatenation `+` in SQL strings |
| **Secrets & Keys** | Credentials & configuration | Read from environment variables (`os.Getenv`) | Hardcoded API keys (Fonnte, SMTP, JWT secrets) in Go/Dart source |
| **Log Sanitization** | Logger output (Zerolog) | Passwords, OTPs, and tokens are redacted/unlogged | Logging raw request payloads containing plaintext passwords or JWTs |
| **Auth & RBAC** | Authentication middleware | Verifies user role (`civilian`, `volunteer`, `agency`, `admin`) | Sensitive endpoints accessible without JWT middleware or role validation |
| **Mobile Storage** | Client-side session storage | Tokens stored in `flutter_secure_storage` | JWT tokens stored in plain `SharedPreferences` without hardware encryption |
| **Network Security** | HTTP client configuration | HTTPS enforced with explicit `connectTimeout` / `receiveTimeout` | Allowing cleartext HTTP or unconfigured timeout defaults on Dio |

---

## 2. Database & Migration Review Checklist

Ensures query performance, relational integrity, and zero-downtime schema evolution.

| Category | Verification Item | PASS Criteria | FAIL Criteria |
|---|---|---|---|
| **FK Indexing** | Foreign key index coverage | Every `REFERENCES table(id)` column has a supporting B-Tree index | Adding foreign key columns without an index |
| **JSONB Indexing** | Query performance on dynamic data | GIN index created on `jsonb` columns queried with `@>` | Querying unindexed JSONB payloads on high-traffic tables |
| **DDL Idempotency** | Migration SQL scripts | Uses `CREATE TABLE IF NOT EXISTS`, `ADD COLUMN IF NOT EXISTS` | Migration fails when re-executed because tables or columns already exist |
| **Living Documentation** | ERD and schema documentation | Both `docs/DATABASE_SCHEMA.md` and `docs/design/database-erd.md` updated | Merging database migrations without updating the ERD & schema docs |
| **Atomic Transactions** | Multi-table mutations | Wrapped in `pgx.Tx` with `defer tx.Rollback(ctx)` and `tx.Commit(ctx)` | Running sequential multi-table mutations without a transaction |
| **N+1 Queries** | Database query loops | Relationships fetched via batch queries or SQL `JOIN` | Executing `QueryRow` inside a `for rows.Next()` loop |

---

## 3. Silent Failure Hunter Checklist

Ensures errors are explicitly handled and failures are never silently swallowed.

| Category | Verification Item | PASS Criteria | FAIL Criteria |
|---|---|---|---|
| **Go Ignored Errors** | Error return value inspection | Every error is checked (`if err != nil`) and wrapped with `%w` | Using `_ = fn()` on I/O, DB, JSON parsing, or cryptography calls |
| **Go Context Leaks** | Timed context cancellation | Every `context.WithTimeout` / `WithCancel` has an immediate `defer cancel()` | Context created without `defer cancel()`, leaking timers/goroutines |
| **Dart Empty Catch** | Async exception handling | `catch (e, stack)` logs the error and surfaces user feedback | Empty `try { ... } catch (e) {}` blocks without logs or UI state updates |
| **Flutter Mounted Check** | Post-await `BuildContext` safety | Verifies `if (!context.mounted) return;` before navigation or Snackbars | Calling `Navigator.of(context)` across an `await` boundary without mounted check |
| **Goroutine Safety** | Background worker lifecycle | Goroutines monitor `ctx.Done()` for graceful termination | Background goroutines launched without cancellation channels (*orphan workers*) |

---

## 4. Verification Report Format in Feature Log

After completing the self-review at Step 7, record the summary in the feature log (`docs/backlog/features/F-XXX-name.md`):

```markdown
### Pre-PR Review Gate
- [x] Security Review: PASS (No SQL injection, secrets sanitized, role check verified)
- [x] Database Review: PASS (Migrations idempotent, FK indexed, ERD updated)
- [x] Silent Failure Audit: PASS (No ignored errors, context.mounted checked, defer cancel present)
```
