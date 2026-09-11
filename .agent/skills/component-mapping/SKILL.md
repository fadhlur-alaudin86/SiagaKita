---
name: component-mapping
description: Maps UI components and screens across Flutter Mobile (Citizen/Volunteer) and Flutter Desktop (Console/Admin) to Go Fiber backend routes, database tables/queries, and WebSocket events in docs/COMPONENT_MAPPING.md to enforce Multi-Client Parity.
---

# Component Mapping Skill — SiagaKita

The `component-mapping` skill enforces **Rule A (Multi-Client API Contract Parity)** by maintaining a unified, living architecture matrix in `docs/COMPONENT_MAPPING.md`.

---

## The Multi-Client Challenge

SiagaKita operates two distinct frontend client applications powered by a single Go Fiber backend:
1. **`mobile-flutter`**: Used by Citizens (triggering SOS, reporting emergencies, volunteer onboarding) and Field Volunteers (accepting dispatches, reporting status, submitting telemetry).
2. **`windows_console_flutter`**: Used by Agency Dispatchers (monitoring incoming SOS on maps, dispatching nearby volunteers) and Superadmins (KYC verification, badge and rank gamification, system stats).

Whenever an API route, DTO model, database query, or WebSocket event is added or modified, the developer and AI assistant must verify how the change impacts **both** client applications.

---

## Workflow

### Step 1 — Inspect Affected Endpoints and Screens
Identify:
- Which Flutter Mobile screen/service is involved.
- Which Flutter Desktop Console screen/service is involved.
- The corresponding Go Fiber HTTP handler and WebSocket broadcast in `backend-go/internal/domain/`.
- The target database tables, migrations, and queries in PostgreSQL.
- Idempotency (`X-Idempotency-Key`) or WebSocket event requirements.

### Step 2 — Update `docs/COMPONENT_MAPPING.md`
Maintain the living matrix table following the standardized multi-client schema:

```markdown
| Domain / Feature | Mobile Screen / Service | Desktop Console Screen / Service | Go Fiber Route & Handler | DB Table & Query | WS Event / Idempotency |
|---|---|---|---|---|---|
| SOS Alert Dispatch | `mobile-flutter/.../sos_screen.dart` | `windows_console_flutter/.../dispatch_screen.dart` | `POST /incident/sos` (`TriggerSOS`) | `incidents (INSERT)` | WS: `incident_created`, Key: Required |
```

### Step 3 — Ensure Parity Invariants
- **No Orphan Endpoints**: Every backend handler must serve at least one client, documented in the matrix.
- **Contract Parity**: If an incident status enum changes in Go Fiber, update models in both `mobile-flutter/lib/core/models/` and `windows_console_flutter/lib/core/models/`.
- **Idempotency Gate**: Ensure critical actions (e.g. dispatch acceptance, status resolution, badge awards) utilize `X-Idempotency-Key` headers on console requests.

---

## Rules
1. **Always Update When Touching Contracts**: Any change to `docs/api/*.yaml` or domain handlers must be accompanied by an update to `docs/COMPONENT_MAPPING.md`.
2. **Path Verification**: Ensure file paths listed in the table accurately reflect the repository structure.
3. **Clean Text**: Use standard Markdown tables without decorative icons or emojis.
