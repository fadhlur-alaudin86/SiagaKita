# SiagaKita Backend Architecture

This document provides a comprehensive technical overview of the SiagaKita backend core, including domain modeling, authentication mechanics, session guards, WebSocket real-time systems, and operational runtime design.

---

## Technical Stack Overview

| Component | Technology | Purpose |
|---|---|---|
| Language & Runtime | Go 1.26 | High-throughput backend runtime |
| Web Framework | Go Fiber v2 | HTTP router and middleware pipeline |
| JSON Engine | ByteDance Sonic | JIT-compiled high-performance JSON serialization |
| Logging | Zerolog | Structured, zero-allocation logging (Console + Disk persistence) |
| Relational Database | PostgreSQL 15 | Persistent relational storage via `pgx/v5` connection pool |
| Cache & Coordination | Redis 7 | Session storage, JTI tokens, OTP rate limits, and real-time state |
| Migrations | `golang-migrate` | Versioned, reversible database migrations (`cmd/migrate`) |
| Real-Time Engine | Gorilla WebSocket | Dedicated WebSocket server on port 8081 with Hub registry |
| API Contracts | OpenAPI 3.0 (Swagger) | Modular API specifications served at `/docs/*` |

---

## Directory Structure

```
backend-go/
├── cmd/
│   ├── api/
│   │   └── main.go              - Server entry point, domain routing, middleware wiring, superadmin seed
│   └── migrate/
│       └── main.go              - Database migration CLI (up, down, status, version)
├── internal/
│   ├── config/
│   │   └── config.go            - Environment variable loader and application configuration
│   ├── database/
│   │   ├── postgres.go          - PostgreSQL pgxpool initialization and connection management
│   │   ├── redis.go             - Redis client initialization and helper methods
│   │   └── migrate.go           - Programmatic migration runner wrapping golang-migrate
│   ├── domain/
│   │   ├── user/                - Authentication, profile management, KYC submission, session rotation
│   │   │   ├── handler.go       - HTTP transport handlers
│   │   │   ├── service.go       - Business logic, password hashing, JWT generation
│   │   │   ├── repository.go    - Raw SQL queries via pgxpool
│   │   │   └── model.go         - Data structures and request/response DTOs
│   │   ├── incident/            - Emergency SOS (Jalur A) and community reports (Jalur B)
│   │   │   ├── handler.go
│   │   │   ├── service.go
│   │   │   ├── repository.go
│   │   │   └── model.go
│   │   ├── admin/               - Admin operations, KYC approval, account bans, gamification, analytics
│   │   │   ├── handler.go
│   │   │   ├── service.go
│   │   │   ├── repository.go
│   │   │   └── model.go
│   │   ├── otp/                 - OTP distribution (Gmail REST API + Fonnte WhatsApp)
│   │   │   ├── handler.go
│   │   │   ├── service.go
│   │   │   └── gateway.go
│   │   └── telemetry/           - Real-time GPS location updates and SMS fallback gateway
│   │       ├── handler.go
│   │       ├── service.go
│   │       └── repository.go
│   ├── hub/
│   │   └── hub.go               - In-memory WebSocket connection registry and role broadcast engine
│   ├── middleware/
│   │   ├── auth.go              - JWT authentication and granular RBAC filters
│   │   ├── i18n.go              - Transparent locale negotiation via Accept-Language header
│   │   ├── logger.go            - HTTP access logger integrated with Zerolog
│   │   └── recover.go           - Panic recovery middleware
│   ├── utils/
│   │   ├── jwt.go               - Token generation, claims validation, and JTI creation
│   │   ├── logger.go            - Centralized Zerolog logger setup
│   │   └── response.go          - Standardized JSON responses with i18n message translation
│   └── ws/
│       ├── handler.go           - WebSocket connection upgrader and lifecycle handler
│       └── server.go            - Standalone WebSocket HTTP listener
└── migrations/
    ├── 001_init_schema.up.sql   - Sequential migration files (up/down pairs)
    └── ...                      - Migrations up to 020_add_analytics_indexes
```

---

## Domain-Driven Design & Layering

The backend enforces a strict 3-tier layering model across all domains:

```
HTTP Request
    │
    ▼
Handler (HTTP Layer)
    │  - Parse and validate request payloads
    │  - Extract authenticated identity from fiber.Ctx Locals
    │  - Call appropriate service method
    │  - Return standardized JSON response via utils.SuccessResponse / utils.ErrorResponse
    ▼
Service (Business Logic Layer)
    │  - Enforce domain rules, state transitions, and role constraints
    │  - Coordinate transactional boundaries
    │  - Trigger external gateways (SMS, WhatsApp, Gmail)
    │  - Broadcast real-time events via WebSocket Hub
    ▼
Repository (Data Access Layer)
    │  - Execute raw SQL queries using pgxpool.Pool
    │  - Scan rows into domain structs
    │  - Manage explicit database transactions (pgx.Tx)
    ▼
PostgreSQL / Redis
```

---

## Role-Based Access Control (RBAC)

SiagaKita defines six discrete roles in the PostgreSQL `user_role` ENUM:

| Role | Target Platform | Scope & Capabilities |
|---|---|---|
| `superadmin` | Desktop Console | System initialization, admin provisioning. Created via startup environment seeding. |
| `admin` | Desktop Console | Volunteer KYC validation, user moderation (bans/strikes), master rank management, system statistics. |
| `agency` | Desktop Console | Emergency monitoring, dispatch management, report triage, live responder tracking. |
| `agency_personnel` | Mobile Responder | Field responder personnel. Receives dispatches, updates mission status, streams GPS. |
| `volunteer` | Mobile Citizen App | Verified civilian responders. Receives nearby SOS alerts, earns XP, and completes rescue missions. |
| `civilian` | Mobile Citizen App | General public. Triggers instant SOS alerts, submits community reports, manages personal medical biodata. |

### Middleware Hierarchy

Authentication and authorization middleware are defined in `internal/middleware/auth.go`:

```go
// Authentication precedes RBAC middleware:
app.Get("/api/v1/admin/users", middleware.Auth(cfg), middleware.AdminOnly(), handler)
```

- `Auth(cfg)`: Validates JWT signature, expiration, and extracts claims (`userID`, `userRole`, `jti`) into `c.Locals`.
- `SessionGuard(redis)`: Enforces single-device mobile sessions by validating active JTI against Redis.
- `Idempotency(redis)`: Blocks duplicate state-altering requests for Console users using `X-Idempotency-Key`.
- `SuperAdminOnly()`: Restricts access to `superadmin`.
- `AdminOnly()`: Permits `admin` and `superadmin`.
- `ConsoleOnly()`: Permits `superadmin`, `admin`, and `agency`.
- `AgencyOnly()`: Permits `agency`, `admin`, and `superadmin`.
- `CitizenVolunteer()`: Permits `civilian` and `volunteer`.
- `PersonnelOnly()`: Permits `agency_personnel`.
- `APIKeyGateway(cfg)`: Authenticates third-party or SMS gateway fallback requests via static API key.

---

## Authentication & Session Security

### Multi-App Login Endpoints

To prevent credential abuse and cross-platform access leakage, login endpoints are segmented by role group:

1. `POST /api/v1/auth/login`: Restricted to `civilian` and `volunteer` (Mobile Citizen App).
2. `POST /api/v1/auth/console/login`: Restricted to `superadmin`, `admin`, and `agency` (Desktop Console).
3. `POST /api/v1/auth/personnel/login`: Restricted to `agency_personnel` (Mobile Responder App).

All login endpoints return identical generic error messages (`invalid email or password`) upon mismatch to prevent role enumeration.

### Atomic Registration & Ghost Account Prevention

1. User registration creates credentials in `users` and an empty profile in `user_profiles` inside a single atomic database transaction.
2. If the email gateway fails to deliver the verification OTP, the newly created records are immediately cleaned up.
3. Login is strictly rejected for accounts with `is_email_verified = false`.

### Single-Device Mobile Sessions (SessionGuard)

1. Each issued access and refresh token contains a unique `jti` (UUID v4) claim.
2. Upon login, the active `jti` is stored in Redis under `session:{userID}`.
3. Mobile requests processed by `SessionGuard` verify that the token's `jti` matches Redis.
4. When a user logs in on a second device, the Redis key is overwritten with the new `jti`, immediately invalidating the previous session with error code `ERR_SESSION_REPLACED`.
5. The server broadcasts a `FORCE_LOGOUT` event to the displaced client over WebSockets.

### Console Idempotency Guard

1. State-changing requests (POST, PATCH, DELETE) from Desktop Consoles include an `X-Idempotency-Key` header (UUID v4).
2. The middleware hashes the key and checks Redis:
   - If present, returns the cached response directly, preventing duplicate dispatches or status updates.
   - If absent, executes the handler and caches the serialized response in Redis with a 60-second TTL.

---

## WebSocket Hub Architecture

The WebSocket subsystem operates on a dedicated port (`:8081`) to isolate real-time event traffic from standard REST API workloads.

### Endpoint & Connection Flow

```
ws://<host>:8081/ws/connect?token=<access_token>
```

1. Client initiates HTTP upgrade request with valid JWT passed as a query parameter.
2. `ws.Handler` parses token, extracts user ID and role, and upgrades connection to WebSocket.
3. Client connection is registered into `hub.Hub`.

### Multi-Connection Registry Pattern

- **Console Users (`admin`, `superadmin`, `agency`)**: The Hub permits multiple concurrent connections per `userID`. This allows operators to run synchronized sessions across desktop workstations and field tablets simultaneously.
- **Mobile Users (`civilian`, `volunteer`, `agency_personnel`)**: New connections automatically terminate previous connections for that user, reinforcing single-device usage.

### Event Broadcasting

The Hub provides methods for targeted broadcasting:

- `hub.BroadcastToUser(userID, event)`: Sends event to all active connections of a specific user.
- `hub.BroadcastToRole(role, event)`: Broadcasts event to all active clients of a given role (e.g., notifying all agencies of incoming SOS alerts).
- `hub.Broadcast(event)`: Emits event to all connected clients globally.

### Standard Server-to-Client Events

| Event | Target Audience | Trigger Condition |
|---|---|---|
| `INCOMING_EMERGENCY` | Agency, Admin | A civilian triggers an active SOS alert |
| `SOS_CANCELLED` | Agency, Admin | Reporter cancels SOS during grace period |
| `RESCUE_ACCEPTED` | Reporter | Responder accepts mission and begins transit |
| `INCIDENT_UPDATED` | Agency, Admin | Incident state transition (handled, resolved, false alarm) |
| `LOCATION_UPDATE` | Agency, Responder | Real-time GPS coordinate stream from active SOS reporter |
| `VOLUNTEER_LOCATION_UPDATE` | Agency, Admin | GPS telemetry stream from on-duty volunteers |
| `FORCE_LOGOUT` | Displaced User | Session replaced by login from another device |

---

## OTP & External Gateways

### Email OTP (Gmail REST API)

Due to modern cloud VPS providers blocking outbound SMTP ports (25, 465, 587) by default, SiagaKita delivers email OTPs via the **Gmail REST API (HTTPS port 443)** using OAuth2 service tokens:

- Redis storage: `otp:register:{email}` (TTL: 180 seconds).
- Rate limit: `otp_cooldown:{email}` (TTL: 60 seconds).
- Token verification employs constant-time comparison to prevent timing attacks.

### WhatsApp OTP (Fonnte Gateway)

- Phone verification OTPs are transmitted via Fonnte REST API to verified WhatsApp numbers.
- Phone numbers are automatically normalized to E.164 standard (converting `08...` to `628...`).

---

## Database Migrations

Database schema management is governed by `backend-go/cmd/migrate` using `golang-migrate`:

- Migrations reside in `backend-go/migrations/` as paired SQL files (`NNN_name.up.sql` and `NNN_name.down.sql`).
- Running migrations locally:
  ```bash
  cd backend-go
  go run cmd/migrate/main.go up
  go run cmd/migrate/main.go down
  go run cmd/migrate/main.go status
  ```
- Application startup executes pending migrations programmatically via `database.NewMigrator()`.

---

## Superadmin Startup Auto-Seeding

During server initialization (`cmd/api/main.go`), the system invokes `seedSuperAdmin()`:

1. Inspects `SUPERADMIN_EMAIL` and `SUPERADMIN_PASS` from environment variables.
2. If absent, logs a warning and proceeds without seeding.
3. If an account with the specified email exists, updates password hash to reflect current configuration.
4. If the account does not exist, inserts a new user with role `superadmin`.

---

## Related Documentation

- **Living Visual Design & Mermaid Diagrams**: [`docs/design/README.md`](./design/README.md)
- **Database ERD (Schema v12)**: [`docs/design/database-erd.md`](./design/database-erd.md)
- **Database Schema Reference**: [`docs/DATABASE_SCHEMA.md`](./DATABASE_SCHEMA.md)
- **API Contracts & Swagger Documentation**: [`docs/api/openapi.yaml`](./api/openapi.yaml) (Interactive UI at `/docs/*`)
- **Production Deployment Guide**: [`docs/DEPLOYMENT_GUIDE.md`](./DEPLOYMENT_GUIDE.md)
