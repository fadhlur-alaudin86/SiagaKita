# F-138: Atomic SOS Trigger with Pre-Selected Category & Instant Broadcasting

## Issue Metadata

| Field | Value |
|---|---|
| ID | F-138 |
| Title | Atomic SOS Trigger with Pre-Selected Category & Instant Broadcasting |
| Requestor | Fadhlurrahman Alaudin |
| Date Created | 2026-09-13 |
| GitHub Issues | [#138](https://github.com/fadhlur-alaudin86/SiagaKita/issues/138) |
| Parent Plan | `.planning/13-sos-offline-online-sync-resilience.md` ([#136](https://github.com/fadhlur-alaudin86/SiagaKita/issues/136)) |
| Status | In Progress |

---

## 1. Scope & Goals

- **Core Problems**:
  1. Multi-step fragile chain: When an SOS is triggered offline and the user selects a category during the local countdown, synchronizing upon reconnection previously required three separate HTTP requests: `POST /trigger` (creates `grace_period` with `unknown`), `PATCH /type` (updates category), and `POST /broadcast` (promotes to broadcasting).
  2. Stuck in `grace_period` with `unknown`: If network connectivity fluctuates after the initial `POST /trigger`, or if the server auto-promotion timer (15s) fires before `PATCH /type` arrives, the incident remained permanently stuck in `grace_period` with category `unknown`.
  3. Delayed dispatch notification: Dispatch consoles and nearby responders did not receive real-time alerts until the secondary promotion calls finished.
- **Goals**:
  - Extend OpenAPI contract and Go backend `TriggerSOSRequest` to accept optional `incident_type` and `skip_grace_period`.
  - In backend `Service.TriggerSOS`, if `skip_grace_period` is true or valid `incident_type` is provided, instantiate the incident directly with `status: broadcasting` and the requested `incident_type`, trigger immediate WebSocket broadcast to dispatch consoles, and bypass the grace period auto-promote timer.
  - In backend `Service.UpdateType`, permit updating `incident_type` if status transitioned to `broadcasting` provided it is within 30 seconds of creation and the current type is `unknown`.
  - Update Flutter `IncidentService.triggerSOS` and `home_screen.dart` to send the atomic payload on reconnect or expired countdown.
- **Boundaries**:
  - `docs/api/paths/incidents.yaml`
  - `backend-go/internal/domain/incident/model.go`
  - `backend-go/internal/domain/incident/service.go`
  - `backend-go/internal/domain/incident/handler.go`
  - `backend-go/internal/domain/incident/incident_test.go`
  - `mobile-flutter/lib/core/services/incident_service.dart`
  - `mobile-flutter/lib/features/masyarakat/home_screen.dart`

---

## 2. Architectural Decisions Log

1. **Contract Extension (`TriggerSOSRequest`)**:
   - `incident_type`: string, optional (enum: `general`, `medical`, `fire`, `crime`, `rescue`, `disaster`, `accident`).
   - `skip_grace_period`: boolean, optional.
2. **Atomic Instantiation & Immediate WebSocket Broadcast**:
   - If `skip_grace_period == true` (or `incident_type` is valid and not empty), `TriggerSOS` sets `Status: StatusBroadcasting` and `IncidentType: req.IncidentType`.
   - The auto-promote timer is not scheduled.
   - Immediate WebSocket notification `s.OnBroadcast(inc.ID)` is invoked so dispatch consoles receive the incident alert without latency.
3. **Graceful Type Upgrades in Early Broadcasting**:
   - `UpdateType` relaxes its precondition: allows updating category if `inc.Status == "grace_period" || (inc.Status == "broadcasting" && inc.IncidentType == IncidentTypeUnknown && time.Since(inc.CreatedAt) <= 30*time.Second)`.
4. **Client-Side Atomic Synchronization**:
   - In `home_screen.dart`, when syncing an offline queued SOS, pass `incidentType: pendingCategory` and `skipGracePeriod: true` in a single `triggerSOS` call, eliminating secondary requests.

---

## 3. Step Progress

| Step | Action | Status | Date | Notes |
|---|---|---|---|---|
| -3 | Backlog Overview | Done | 2026-09-13 | Audited issue #138 under Plan 13 |
| -2 | Discovery & Grill-Me | Done | 2026-09-13 | Evaluated architecture and atomic trigger pipeline |
| -1 | Resolve Backlog | Done | 2026-09-13 | Created feature spec and updated issue status |
| 0 | Branch & Assign | Done | 2026-09-13 | Topic branch `feat/F-138-atomic-sos-trigger-category` |
| 1 | OpenAPI Contract Update | Done | 2026-09-13 | Updated `docs/api/paths/incidents.yaml` and `schemas.yaml` |
| 2 | Backend Go Implementation | Done | 2026-09-13 | Updated `model.go`, `service.go`, `constants.go`, `i18n.go`, unit tests |
| 3 | Mobile Client Implementation | Done | 2026-09-13 | Updated `incident_service.dart` and `home_screen.dart` |
| 4 | Verification & Quality Gates | Done | 2026-09-13 | Pre-flight quality gates verified |
| 5 | CI + Review | Pending | 2026-09-13 | Pull request targeting `dev` |
