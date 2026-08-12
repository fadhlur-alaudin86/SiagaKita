# Feature Dev Stacks — SiagaKita

Specific stack reference for `feature-dev-workflow`. Read this step during Step -3 (Backlog Overview).

## Backend — Go Fiber

```
Path          : backend-go/
Framework     : Go Fiber v2
JSON Engine   : Sonic (high-performance)
Logger        : Zerolog + file persistence
DB Driver     : pgx v5 (PostgreSQL 15)
ORM           : None — Raw SQL
Migrations    : golang-migrate (raw SQL files in backend-go/migrations/)
Auth          : JWT (custom middleware)
WebSocket     : Custom Hub (internal/hub/ & ws/)
Architecture  : Domain-Driven (internal/domain/<name>/)
```

### Domain Structure (Backend)

```
backend-go/
  cmd/api/main.go              ← Entry point, route registration, seeding
  internal/
    domain/
      user/                    ← Auth, profile, biodata, KYC
      incident/                ← SOS, reports, volunteer, agency resolve
      admin/                   ← Admin management, badges, statistics
      otp/                     ← Email & WhatsApp OTP
      telemetry/               ← Location updates
    hub/                       ← WebSocket registry
    middleware/                ← JWT Auth & RBAC
    config/                    ← App config
    utils/                     ← Logger, helpers
  migrations/
    001_initial.sql            ← Format: NNN_description.sql
```

### Handler Pattern (Go Fiber)

```go
// FeatureAction handles POST /domain/action.
// Requires JWT Auth + specified role.
func FeatureAction(db *pgxpool.Pool, hub *hub.Hub) fiber.Handler {
    return func(c *fiber.Ctx) error {
        // 1. Parse & validate request body
        // 2. Business logic / service call
        // 3. DB query execution
        // 4. Return JSON response
    }
}
```

### Migration Naming

```
Format : NNN_description.sql (3-digit zero-padded prefix)
Example: 013_add_dispatch_table.sql
Path   : backend-go/migrations/
```

## Mobile — Flutter Citizen/Volunteer

```
Path          : mobile-flutter/
Framework     : Flutter (Dart)
State Mgmt    : Provider / setState (screen-dependent)
HTTP Client   : Dio
Storage       : SharedPreferences (sessions, offline state)
Maps          : OpenStreetMap (flutter_map)
Responsive    : lib/core/utils/responsive.dart
```

### File Structure (Mobile Flutter)

```
mobile-flutter/lib/
  core/
    utils/           ← responsive.dart, helpers
    services/        ← SessionService, ConnectivityService, OfflineService
  features/
    <feature>/
      <screen>_screen.dart
      <widget>_widget.dart
```

## Desktop — Flutter Console (Admin/Agency)

```
Path          : windows_console_flutter/
Framework     : Flutter Desktop (Dart)
State Mgmt    : Provider
HTTP Client   : Dio
Charts        : fl_chart
Maps          : OpenStreetMap
```

## API Contract & DB Schemas

```
API Spec Root  : docs/api/openapi.yaml         ← Root spec, $ref to all domain path files
API Paths      : docs/api/paths/<domain>.yaml  ← Per-domain endpoint definitions
                   auth.yaml, users.yaml, incidents.yaml,
                   admin.yaml, agencies.yaml, telemetry.yaml
API Components : docs/api/components/
                   schemas.yaml                ← Shared request/response schemas
                   securitySchemes.yaml        ← BearerAuth JWT definition
Swagger UI     : http://localhost:8080/docs    ← Dev only (GO_ENV=development)
DB Schema Path : docs/DATABASE_SCHEMA.md       ← Schema v12 active, read before migrations
```

> **Rule for Step 2:** Append new endpoints to `docs/api/paths/<domain>.yaml`.
> Add new schemas to `docs/api/components/schemas.yaml` via `$ref`.
> Never create a standalone per-feature YAML file.

## Database

```
Engine   : PostgreSQL 15
Schema   : docs/DATABASE_SCHEMA.md (Always read before creating migrations)
Version  : Schema v12 (Active)
```

## Feature Log

```
Path   : docs/backlog/features/F-XXX-name.md
Purpose: Single source of truth per feature (discovery, steps, decisions, tests)
```
