# F-137 & F-140: SOS Offline Cancellation Purge & UI Resilience

## Issue Metadata

| Field | Value |
|---|---|
| ID | F-137-F-140 |
| Title | SOS Offline Cancellation Purge & UI State Machine Resilience |
| Requestor | Fadhlurrahman Alaudin |
| Date Created | 2026-09-13 |
| GitHub Issues | [#137](https://github.com/fadhlur-alaudin86/SiagaKita/issues/137), [#140](https://github.com/fadhlur-alaudin86/SiagaKita/issues/140) |
| Parent Plan | `.planning/13-sos-offline-online-sync-resilience.md` ([#136](https://github.com/fadhlur-alaudin86/SiagaKita/issues/136)) |
| Status | In Progress |

---

## 1. Scope & Goals

- **Core Problems**:
  1. Offline SOS cancellation leak: when an SOS is triggered offline and cancelled while still offline, the pending SOS payload was not cleared from local storage. When reconnecting, the phone uploaded the ghost SOS to the server as an active incident.
  2. Background cancel loop spam: `_attemptSOSCancelBackground` attempted to send remote cancellations for local UUIDs and looped indefinitely upon receiving HTTP 409 Conflict.
  3. UI resurrect race condition on reconnect: when internet reconnected after an offline cancellation, active status sync retrieved the active incident before background cancellation finished, temporarily resurrecting the emergency UI and vibration.
  4. False agency cancellation notice: when the active incident disappeared after user-initiated cancellation, the polling loop unconditionally notified the user that an agency resolved the SOS.
  5. UI transition lag: `_sosUploadStatus` was coupled to a static 10-second polling timer, causing noticeable lag (up to 10 seconds) between `sending...` and `sent` during intermittent network conditions.
- **Boundaries**:
  - `mobile-flutter/lib/features/masyarakat/home_screen.dart`
  - `mobile-flutter/lib/core/services/offline_service.dart`
  - `mobile-flutter/lib/core/services/local_storage_service.dart`
  - `mobile-flutter/test/` unit and widget tests

---

## 2. Architectural Decisions Log (Resolved via `/grill-me`)

1. **Immediate Local Purge on Offline Cancellation**:
   - **Decision**: When cancelling an SOS that only possesses a local temporary UUID (`localId`), immediately purge `OfflineService.clearPendingSOS()`, `clearPendingIncidentType()`, and `clearPendingCancelSOS()`, and abort all upload retry timers.
   - **Rationale**: An SOS cancelled before it ever leaves the phone must never be transmitted to the server.
2. **Prioritizing Pending Cancellation on Reconnect**:
   - **Decision**: In `_onConnectivityChanged()`, check for pending cancellations and await their execution before invoking `_checkActiveIncident()`. If an active incident matches a pending cancellation, suppress setting active UI state.
   - **Rationale**: Prevents confusing UI flash where the SOS screen and alarm vibration turn back on for 5-10 seconds.
3. **Accurate User Cancellation Attribution**:
   - **Decision**: Track `_userInitiatedCancel` in memory and persistent storage. When `active == null`, display "Panggilan SOS telah dibatalkan." if user-initiated, and only display "Status SOS telah diselesaikan oleh instansi." if resolved externally.
   - **Rationale**: Replaces misleading notifications with truthful attribution.
4. **Adaptive 2-3s Status Synchronization & Loop Termination**:
   - **Decision**: Poll every 2-3 seconds during active SOS state transitions and update `_sosUploadStatus` reactively on periodic location pings. Terminate cancel retry loops immediately upon receiving HTTP 200 or 409 Conflict.
   - **Rationale**: Meets 1-2 second UI responsiveness tolerance and eliminates infinite background retry loops.

---

## 3. Step Progress

| Step | Action | Status | Date | Notes |
|---|---|---|---|---|
| -3 | Backlog Overview | Done | 2026-09-13 | Audited issues #137 & #140 under Plan 13 |
| -2 | Discovery & Grill-Me | Done | 2026-09-13 | Resolved 4 architectural decisions with user consensus |
| -1 | Resolve Backlog | Done | 2026-09-13 | Created feature spec and set labels to in-progress |
| 0 | Branch & Assign | Done | 2026-09-13 | Branch `fix/F-137-F-140-sos-cancellation-ui-resilience` |
| 1 | Offline Cancellation Purge | Done | 2026-09-13 | Purge queue, stop timers, terminate 409 loops |
| 2 | UI Resilience & Attribution | Done | 2026-09-13 | Cancellation priority, accurate attribution, adaptive polling |
| 3 | Unit & Regression Tests | Done | 2026-09-13 | Comprehensive test coverage in `mobile-flutter/test/` |
| 4 | Quality Verification | Done | 2026-09-13 | `verify_pipeline.py` pre-flight quality gates passed |
| 5 | CI + Review | Pending | 2026-09-13 | Pull request targeting `dev` |
