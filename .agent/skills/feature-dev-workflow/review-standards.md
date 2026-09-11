# Pre-PR Review Standards & Verification Checklists — SiagaKita

Mandatory code quality, security, and stability verification checklists prior to opening a Pull Request targeting `dev`. Adapted from ECC (*security-reviewer*, *database-reviewer*, *silent-failure-hunter*, and *refactor-cleaner*) specializations.  
Sub-file of [SKILL.md](SKILL.md).

---

## Step 7 Verification Flow (Pre-PR Gate)

Before the agent opens a Pull Request to `dev`, the agent MUST conduct a self-review covering the four critical dimensions below:

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
 ├────────────────────────────────────────┤
 │ 4. Clean Code & Dead Code Elimination  │
 └────────────────────────────────────────┘
              │
      (All Passed?)
       ├── Findings Found ──► Fix code & rerun tests
       └── Passed          ──► Sync Issue Checklists ──► Open PR to dev
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
| **Directory Permissions** | File & directory creation mode | Mode bits restricted to `0750` or `0700` (`gosec G301`) | Using `os.ModePerm` (0777) or permissive world-write modes on uploads |
| **Server Timeouts** | HTTP / WebSocket server hardening | `ReadHeaderTimeout`, `ReadTimeout`, `WriteTimeout` set | Slowloris vulnerability from unconfigured server timeouts |

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

## 4. Clean Code & Dead Code Elimination Checklist

Adapted from ECC's *refactor-cleaner* role. Ensures that unused symbols, obsolete routes, orphaned widgets, dead fields, and abandoned translation keys are completely eradicated before code reaches `dev`.

### Pragmatic Elimination Principle
- **Private & Internal Symbols (Mandatory Purge)**: Uncalled private functions (`func helper`), unread private struct fields, unreferenced class members, private Dart helpers (`_helper`), and orphaned widgets/screens MUST be removed immediately upon refactoring or feature completion.
- **Exported & Public Symbols (Cross-Domain Verification)**: Before removing any exported public function, struct, or API model, verify cross-domain calls in `backend-go` and client-backend contract references across `mobile-flutter` and `windows_console_flutter`.
- **Automated Verification**: Use static analysis tooling to catch undetected dead code (`golangci-lint run --enable unused` for Go, `dart analyze` for Flutter/Dart).

| Category | Verification Item | PASS Criteria | FAIL Criteria |
|---|---|---|---|
| **Go Unused Functions** | Private functions & methods | Every private function/method has at least one active caller in its package | Retaining unused private functions/helpers post-refactoring |
| **Go Unread Struct Fields** | Domain & model struct fields | All struct fields are populated and read in handlers, services, or DB queries | Retaining dead struct fields following schema or API migrations |
| **Go Dead Constants & Errors** | Enums, constants, custom errors | Defined error variables (`var ErrX = ...`) and constants are actively referenced | Abandoned error variables or obsolete status constants left in code |
| **Dart Orphaned Widgets** | Widget and screen files | Every widget and screen file in `lib/features/` is imported and used | Leaving abandoned screen/widget files whose routes or callers have been removed |
| **Dart Uncalled Methods** | Private class methods & helpers | Private members (`_foo()`, `_bar`) are actively invoked within their declaring class | Declaring private helper methods or controllers that are never invoked |
| **Flutter Unused Assets** | Asset declarations in `pubspec.yaml` | Declared assets under `assets:` are referenced via `AssetImage` or `SvgPicture` | Retaining unused image/icon files or obsolete asset paths in `pubspec.yaml` |
| **Localization Hygiene** | Active translation key references | `python3 scripts/check_localization_orphans.py --all` passes cleanly with 0 orphaned keys | Retaining orphaned dictionary entries per Invariant 5 of `localization.md` |
| **Go Cyclomatic Complexity** | Function structural complexity | All domain functions have complexity <= 16 (`cyclop`), helpers <= 6 | Monolithic functions (> 16 branches/loops) lacking modular decomposition |
| **Go String Constants** | Domain string literal repetition | String literals repeated 4+ times extracted to `constants.go` (`goconst`) | Scattering duplicate status, field, or event strings across handlers |
| **Dependency Hygiene** | Lockfile & package determinism | Uses `flutter pub get` and `go mod download` only | Running `flutter pub upgrade` or `go get -u` inside feature PRs |

---

## 5. Karpathy Behavioral Review Checklist

Ensures that code changes remain strictly scoped, surgical, free of speculative abstractions, and conform to coding hygiene.

| Category | Verification Item | PASS Criteria | FAIL Criteria |
|---|---|---|---|
| **Surgical Scope** | Diff lines traceability | 100% of modified lines trace directly to the requirement | "Improving" or reformatting adjacent untouched functions or lines |
| **Simplicity & YAGNI** | Code complexity | Minimal direct implementation without speculative interfaces/generics | Adding speculative configuration options or unused helper wrappers |
| **Orphan Cleanup** | Self-created dead code | All imports, variables, and helpers made obsolete by the change are pruned | Leaving self-created orphaned imports or unused symbols |
| **Architecture Headers** | File documentation | Newly added/refactored files start with Purpose, Data Flow, and Components header | Creating source files without architectural header comments |
| **Visual Breathing Room** | Code formatting spacing | 2 blank lines between major functions, structs, and handlers | Cramped code lacking visual breathing room between execution phases |

---

## 6. Verification Report Format in Feature Log

After completing the self-review at Step 7, record the summary in the feature log (`docs/backlog/features/F-XXX-name.md`):

```markdown
### Pre-PR Review Gate
- [x] Security Review: PASS (No SQL injection, secrets sanitized, role check verified, 0750 permissions, WS timeouts set)
- [x] Database Review: PASS (Migrations idempotent, FK indexed, ERD updated)
- [x] Silent Failure Audit: PASS (No ignored errors, context.mounted checked, defer cancel present)
- [x] Clean Code & Hygiene: PASS (No uncalled private symbols, cyclop <= 16, goconst extracted, 0 orphaned localization keys)
- [x] Karpathy & Surgical Review: PASS (Diff is 100% surgical, no speculative over-engineering, architecture headers present)
- [x] Dependency Determinism: PASS (No unapproved dependency upgrades, lockfiles intact)
```
