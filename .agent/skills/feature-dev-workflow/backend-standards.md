# Backend Development Standards — SiagaKita Go Fiber

Go Fiber + PostgreSQL standards for SiagaKita. Sub-file of [SKILL.md](SKILL.md).

## Standard 1 — No Overengineering (YAGNI & KISS)

- **YAGNI** — Do not add abstractions, interfaces, or patterns until required.
- **KISS** — Pick the simplest solution that works for current requirements.
- **No premature optimization** — Write clear code first; optimize only when profiler proves a bottleneck.
- **One way** — Choose a single pattern (e.g., raw SQL) and remain consistent.
- **Max 3 layers** — handler → service → repository. No deeper than this.

## Standard 2 — Domain Structure

```
backend-go/
  internal/
    domain/
      <name>/              ← One folder per domain
        handler.go         ← HTTP handlers (Fiber)
        service.go         ← Business logic
        repository.go      ← DB queries (raw SQL via pgx)
        model.go           ← Struct definitions
        route.go           ← Route registration for this domain
```

- **Single responsibility** — One function = one responsibility.
- **Small surface area** — Export only what is required by other files.
- **Simple dependency injection** — Pass dependencies as function parameters or struct fields.

## Standard 3 — Fiber Handler Pattern

```go
// FeatureAction handles POST /domain/action.
// Requires JWT Auth + role: volunteer/civilian/agency.
// Body: { field1: string, field2: int }
func FeatureAction(db *pgxpool.Pool, hub *hub.Hub) fiber.Handler {
    return func(c *fiber.Ctx) error {
        // 1. Parse & validate request body
        var req RequestStruct
        if err := c.BodyParser(&req); err != nil {
            return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
                "error": "invalid request body",
            })
        }

        // 2. Business logic / service call
        result, err := someService(db, req)
        if err != nil {
            return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
                "error": err.Error(),
            })
        }

        // 3. Return JSON response
        return c.Status(fiber.StatusOK).JSON(fiber.Map{
            "data": result,
        })
    }
}
```

## Standard 4 — Comments & Documentation

- Every handler receives a doc comment specifying: endpoint, HTTP method, required auth, and request body schema.
- Explain **why**, not just **what**: `// Retry because DB can deadlock during concurrent writes`
- Comment edge cases: empty list, null field, pagination boundary, auth failure.
- File header: single-line description of file purpose (`// Package incident handles SOS lifecycle.`).

## Standard 5 — Database Conventions (PostgreSQL + pgx)

- **No ORM** — Use raw SQL via `pgx/v5` for query transparency and control.
- **Connection pool** — Use `pgxpool.Pool` initialized in `main.go`.
- **Migration** — `.sql` files in `backend-go/migrations/` named `NNN_description.sql`.
- **Always read schema before creating migrations** — Read `docs/DATABASE_SCHEMA.md` (Schema v12).
- **Update schema after migrations** — Update `docs/DATABASE_SCHEMA.md` and log changes in the feature log.

### Migration Naming
```
Format : NNN_description.sql (3-digit zero-padded prefix)
Example:
  013_add_dispatch_table.sql
  014_add_volunteer_location_index.sql
```

## Standard 6 — Conventional Commits (MANDATORY)

All developers MUST use this format. GitHub Release changelogs are automatically generated from commit messages.

### Format
```
<type>(<scope>): <short description in imperative mood, lowercase>

[optional body — explain WHY, not WHAT]

[optional footer: BREAKING CHANGE: ..., Closes #N]
```

### Applicable Types

| Type | When to Use | Example |
|------|-------------|---------|
| `feat` | New feature | `feat(incident): add volunteer dispatch endpoint` |
| `fix` | Bugfix | `fix(incident): resolve SOS strike DB mapping on marked_by column` |
| `chore` | Maintenance, dependencies | `chore: bump fiber to v2.52.5` |
| `docs` | Documentation | `docs(api): update OpenAPI contract for SOS endpoint` |
| `refactor` | Refactoring (not fix/feat) | `refactor(hub): simplify WebSocket registry cleanup logic` |
| `test` | Add or update tests | `test(incident): add table-driven tests for SOS handler` |
| `ci` | Workflow changes | `ci: add golangci-lint step to ci-dev.yml` |
| `style` | Formatting, whitespace | `style: apply gofmt to internal/domain/user` |
| `perf` | Performance optimization | `perf(json): switch to Sonic for JSON encoding` |

### Scopes

| Scope | Component |
|-------|-----------|
| `auth` | JWT, auth middleware |
| `incident` | SOS, reports, volunteer |
| `user` | User, profile, biodata |
| `admin` | KYC, badges, statistics |
| `telemetry` | Location, telemetry |
| `otp` | Email & WhatsApp OTP |
| `ws` | WebSocket hub |
| `mobile` | mobile-flutter |
| `desktop` | windows_console_flutter |
| `infra` | Docker, compose |
| `ci` | GitHub Actions |
| `docs` | Documentation |

### Breaking Changes
```
feat(user)!: change login endpoint path from /auth/login to /auth/user/login

BREAKING CHANGE: endpoint path changed, update all clients.
Closes #42
```
