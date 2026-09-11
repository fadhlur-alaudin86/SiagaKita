# F-021 - F-023: Mobile Responder Application (`mobile-flutter-responder`)

## Issue Metadata

| Field | Value |
|---|---|
| ID | F-021, F-022, F-023 |
| Title | Mobile Responder Application (Auth, Mission Board, Telemetry & Navigation) |
| Requestor | Fadhlurrahman Alaudin |
| Date Created | 2026-09-11 |
| GitHub Issues | #21, #22, #23 (Parent: #4) |
| Parent Plan | `.planning/08-mobile-responder-app.md` |
| Status | In Progress |

---

## 1. Scope & Goals

- **Core Problem**: Official emergency response units (firefighters, paramedic drivers, police patrol, SAR teams) operating under the `agency_personnel` role require a specialized, field-hardened mobile client to receive unit dispatches, stream telemetry back to command centers, and manage rapid on-scene lifecycle transitions.
- **Boundaries**:
  - `mobile-flutter-responder/` is a dedicated Flutter client engineered specifically for official agency field personnel.
  - Role-gated strictly to `agency_personnel` (rejects civilian/volunteer roles).
  - Background telemetry streaming to `PUT /api/v1/telemetry/location` with zero memory churn on the backend (`sync.Pool`).
  - Real-time two-way synchronization with the Desktop Console (`windows_console_flutter`) via WebSockets.
- **Non-Goals**:
  - Non-critical reporting (Jalur B community reporting is handled exclusively by the civilian client).
  - Gamification points / XP redemption (reserved for civilian volunteers).

---

## 2. Architectural Decisions Log (Resolved via `/grill-me`)

1. **Mission Assignment & Visibility**:
   - **Decision**: Field personnel can view all emergency dispatches assigned to their parent agency or within their agency's operational domain. Any personnel from the agency unit can claim and advance the mission collaboratively.
   - **Rationale**: Reflects real-world emergency dispatching where unit crews (e.g., Damkar squad, ambulance crew) act as a team on assigned incidents.
2. **Status Lifecycle Mapping & Accountability**:
   - **Decision**: Personnel status actions (*Terima Tugas*, *Dalam Perjalanan*, *Tiba di Lokasi*, *Selesai*) write directly to `incident_responses` with `responder_id = personnel_user_id` and transition through `en_route` -> `on_scene` -> `resolved`. State changes emit real-time WebSocket events to Desktop Console without requiring manual dispatcher review.
   - **Rationale**: Ensures complete audit trails of which officer responded, arrival timestamps, and completion proof, while eliminating unnecessary administrative bottlenecks during critical emergencies.
3. **Adaptive Background Telemetry Policy**:
   - **Decision**: Dual-mode adaptive GPS streaming: high-frequency (every 5-10 seconds) during active response missions (`en_route` / `on_scene`), and relaxed power-saving intervals (every 30-60 seconds or displacement > 25m) when in standby/idle status at station.
   - **Rationale**: Guarantees high-precision real-time tracking on dispatcher radar when lives are on the line while preserving battery life during 12-hour shifts.
4. **Dual Login Identifier Support**:
   - **Decision**: Login endpoint accepts either official Email OR Badge Number (`badge_number`). The backend resolves non-email inputs against `agency_personnels.badge_number` and validates the password.
   - **Rationale**: Tactical officers in the field memorize badge numbers (e.g. `DMK-042`, `POL-110`) faster than lengthy corporate email strings on touchscreens.
5. **Dual Navigation & Map Strategy**:
   - **Decision**: Integrated in-app tactical map (`flutter_map`) displaying live unit GPS, incident location pin, and route indicator, complemented by quick-action floating buttons to launch turn-by-turn guidance in Google Maps or Waze (`url_launcher`).
   - **Rationale**: Gives responders quick in-app situational awareness while allowing them to leverage professional turn-by-turn navigation engines for siren-equipped vehicle routing.

---

## 3. Step Progress

| Step | Action | Status | Date | Notes |
|---|---|---|---|---|
| -3 | Backlog Overview | Done | 2026-09-11 | Selected Plan 08 (Issues #21, #22, #23 under Parent #4) |
| -2 | Discovery | Done | 2026-09-11 | Audited backend auth, dispatch, telemetry routes and existing client patterns |
| -1 | Resolve Backlog | Done | 2026-09-11 | Created feature specification log `F-021-F-023-mobile-responder.md` |
| 0 | Branch & Assign | In Progress | 2026-09-11 | Target branch `feature/F-021-F-023-mobile-responder` |
| 1 | Read Mapping | Done | 2026-09-11 | Architectural interview resolved via `/grill-me` |
| 2 | API Contract | Done | 2026-09-11 | Contract extended for badge login & agency personnel incident operations |
| 3 | DB Migration | Skipped | 2026-09-11 | Schema already supports `agency_personnels` and `incident_responses` |
| 4 | Implementation | Pending | 2026-09-11 | Backend middleware update + Flutter mobile responder scaffolding |
| 5 | Tests | Pending | 2026-09-11 | Unit tests for auth, missions, telemetry, and client parity |
| 6 | CI + Review | Pending | 2026-09-11 | Pre-PR audit, checklist sync, CodeGraph sync |
| 7 | Close Log | Pending | 2026-09-11 | Pull Request to `dev` |

---

## 4. Verification Matrix

| Test Suite | Command | Target Criteria | Status |
|---|---|---|---|
| Backend Domain Incident | `go test -v -race ./internal/domain/incident/...` | All tests pass, 0 race | Pending |
| Backend Domain User | `go test -v -race ./internal/domain/user/...` | Badge login & role tests pass | Pending |
| Mobile Responder Analyze | `flutter analyze --no-pub` | 0 errors, 0 warnings, 0 lints | Pending |
| Mobile Responder Tests | `flutter test` | Unit tests pass | Pending |
| Localization Parity | Parity script / inspection | 100% key parity, zero orphaned | Pending |
