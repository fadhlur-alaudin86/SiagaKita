# Plan 13: SOS Offline/Online State Machine Resilience & Evidence Sync Architecture

## 1. Overview & Problem Statement

- **Parent Epic**: [#136](https://github.com/fadhlur-alaudin86/SiagaKita/issues/136)
- **Target Sub-Issues**:
  - [#137](https://github.com/fadhlur-alaudin86/SiagaKita/issues/137) (Mobile Offline Cancellation Purge)
  - [#138](https://github.com/fadhlur-alaudin86/SiagaKita/issues/138) (Atomic SOS Trigger & Category Sync)
  - [#139](https://github.com/fadhlur-alaudin86/SiagaKita/issues/139) (Evidence Isolation & Offline Spooling)
  - [#140](https://github.com/fadhlur-alaudin86/SiagaKita/issues/140) (UI Resurrect Race Condition & Adaptive Status)
- **Priority**: P1 (High)
- **Status**: Backlog
- **Primary Stack**: Flutter Mobile (`mobile-flutter`), Go Fiber Backend (`backend-go`), OpenAPI, PostgreSQL
- **Problem**:
  - Complex offline/online state transitions in emergency SOS dispatch currently exhibit multiple race conditions and failure modes:
    1. Offline SOS cancelled before network connection still transmits to the backend as an active incident upon reconnecting.
    2. SOS triggered offline causes incidents to remain stuck in `grace_period` with `unknown` category even if the user selected a specific emergency type.
    3. Mobile uploads evidence using temporary local UUIDs before receiving server incident IDs, and Go backend creates physical folders on disk before verifying whether the incident exists in PostgreSQL, producing orphan folders on storage volumes and null database paths.
    4. Cancelling an SOS while offline causes the mobile UI and device vibration to resurrect into active mode for several seconds when internet reconnects, followed by an incorrect notification stating that the SOS was resolved by an agency.
    5. UI status between `sending...` and `sent` suffers from rigid 10-second polling delays during unstable network connectivity.

---

## 2. Technical Scope & Specifications

### 2.1 Offline SOS Cancellation & Queue Purge ([#137](https://github.com/fadhlur-alaudin86/SiagaKita/issues/137))
- **Local Cancellation Invariant**:
  - When a user cancels an SOS while the incident is still in local temporary state (`localId` exists, but no `serverId` was ever returned), the SOS must be treated as completely voided locally.
  - Purge `LocalStorageService.clearPendingSOS()`, `clearPendingIncidentType()`, and `clearPendingCancelSOS()`.
  - Abort all upload retry timers (`_sosRetryTimer`) and background sync tasks for this `localId`.
  - Under no circumstances will this cancelled SOS be transmitted to the backend.
- **Background Cancel Loop Guard**:
  - In `_attemptSOSCancelBackground(incidentId)`: if `incidentId` is a client-generated UUID, skip remote API calls.
  - Terminate the retry loop immediately upon receiving HTTP 200 OK or HTTP 409 Conflict (`SOSConflictException`), eliminating infinite 5-second background retry spam.

### 2.2 Atomic SOS Trigger & Category Synchronization ([#138](https://github.com/fadhlur-alaudin86/SiagaKita/issues/138))
- **OpenAPI & Backend Contract Expansion**:
  - Extend `POST /api/v1/incidents/sos` request body:
    ```yaml
    incident_type:
      type: string
      enum: [general, medical, fire, crime, natural_disaster, accident]
      description: Optional pre-selected category chosen while offline.
    skip_grace_period:
      type: boolean
      description: If true, transitions incident directly to broadcasting atomically.
    ```
- **Backend Atomic State Promotion**:
  - In `Service.TriggerSOS`:
    * If `req.SkipGracePeriod == true`, create the incident record with `status: "broadcasting"` and `incident_type: req.IncidentType` in a single atomic database insert.
    * Trigger immediate WebSocket broadcast (`s.OnBroadcast`) to dispatch consoles and nearby verified responders without scheduling the 15-second `autoPromoteGracePeriod`.
  - In `Service.UpdateType`:
    * Permit category updates even if the status transitioned to `broadcasting`, provided the request is within 30 seconds of creation and the existing type is `unknown`.
- **Mobile Atomic Sync**:
  - When syncing an offline incident that already completed countdown or had a category chosen, pass `incidentType` and `skipGracePeriod: true` directly in `IncidentService.triggerSOS`.
  - Eliminate sequential fragile HTTP chains (`trigger -> updateType -> broadcast`).

### 2.3 Evidence Upload Isolation, Offline Spooling & Volume Hygiene ([#139](https://github.com/fadhlur-alaudin86/SiagaKita/issues/139))
- **Backend Verification Guard**:
  - In `Handler.UploadEvidence`: query `s.repo.FindByID(incidentID)` before creating directories or saving files to disk.
  - If the incident does not exist in PostgreSQL or does not belong to the user, immediately return HTTP 404/403 without creating any folders or writing file chunks to the storage volume.
- **Mobile Offline Evidence Spooling**:
  - Enforce a strict invariant: `_captureAndUploadEvidence` must never execute an HTTP request using a `localId`.
  - If transitioning to broadcasting while offline or before `serverId` is returned, spool the local file paths (front photo, rear photo, audio) into `LocalStorageService.savePendingEvidence(...)`.
  - When `serverId` is confirmed and connectivity is active, upload the spooled files to `POST /api/v1/incidents/<serverId>/evidence` and delete local temporary cache files.
- **Volume Hygiene Maintenance**:
  - Provide a cleanup script `scripts/prune_orphaned_evidence.py` to audit `uploads/incidents/evidence/` against PostgreSQL and safely purge existing orphaned directories.

### 2.4 UI Resilience, Adaptive Polling & Cancellation Messaging ([#140](https://github.com/fadhlur-alaudin86/SiagaKita/issues/140))
- **Eliminate UI Resurrection on Reconnect**:
  - In `_onConnectivityChanged()`, check if `OfflineService.getPendingCancelSOS()` exists.
  - If a pending cancellation exists, execute the cancellation request before invoking `_checkActiveIncident()`.
  - In `_checkActiveIncident()`, do not set `_activeIncident` or reactivate vibration if the incident matches a local cancellation in flight.
- **Accurate Cancellation Attribution**:
  - Track user-initiated cancellation state.
  - In `_startStatusPolling()`, when `active == null`, verify if the disappearance was triggered by the user. If so, display "Panggilan SOS telah dibatalkan." and suppress "Status SOS telah diselesaikan oleh instansi."
- **Fast Adaptive Polling**:
  - Replace the static 10-second polling interval with an adaptive 2-3 second polling cycle during active transitions.
  - Reactively update `_sosUploadStatus` upon location update responses (every 3 seconds), targeting a transition latency under 1-2 seconds.

---

## 3. Tasks & Implementation Checklist

### 3.1 Mobile Offline Cancellation Purge ([#137](https://github.com/fadhlur-alaudin86/SiagaKita/issues/137))
- [ ] Purge offline queue on local cancellation in `home_screen.dart: _cancelSOS()`.
- [ ] Break infinite retry while-loop on HTTP 200 or 409 Conflict in `_attemptSOSCancelBackground`.
- [ ] Add unit tests for offline cancellation lifecycle in `mobile-flutter/test/`.

### 3.2 Atomic SOS Trigger & Category Sync ([#138](https://github.com/fadhlur-alaudin86/SiagaKita/issues/138))
- [ ] Update OpenAPI specification in `docs/api/paths/incidents.yaml` and `docs/api/openapi.yaml`.
- [ ] Update Go model `TriggerSOSRequest` and implement atomic broadcasting in `Service.TriggerSOS`.
- [ ] Update `Service.UpdateType` to permit updating category from `unknown` during early broadcasting.
- [ ] Update Flutter `IncidentService.triggerSOS` and `home_screen.dart` to send atomic payload.
- [ ] Add Go backend unit tests in `internal/domain/incident/incident_test.go`.

### 3.3 Evidence Upload Isolation & Offline Spooling ([#139](https://github.com/fadhlur-alaudin86/SiagaKita/issues/139))
- [ ] Validate incident existence in backend `Handler.UploadEvidence` before creating directories or saving files.
- [ ] Implement `LocalStorageService.savePendingEvidence` and offline evidence spooling in Flutter Mobile.
- [ ] Create `scripts/prune_orphaned_evidence.py` and purge orphaned volume folders.
- [ ] Add test cases asserting zero disk writes on invalid evidence upload attempts.

### 3.4 UI Resilience & Fast Adaptive Synchronization ([#140](https://github.com/fadhlur-alaudin86/SiagaKita/issues/140))
- [ ] Prioritize pending cancellation over active incident retrieval on reconnect in `_onConnectivityChanged()`.
- [ ] Differentiate cancellation attribution in `_startStatusPolling()` to show accurate user cancellation SnackBar.
- [ ] Implement adaptive 2-3 second status synchronization during active transitions.
- [ ] Add widget and regression tests for UI state transitions in `mobile-flutter/test/`.

---

## 4. Affected Components & Files

- `docs/api/paths/incidents.yaml`
- `docs/api/openapi.yaml`
- `backend-go/internal/domain/incident/model.go`
- `backend-go/internal/domain/incident/service.go`
- `backend-go/internal/domain/incident/handler.go`
- `backend-go/internal/domain/incident/incident_test.go`
- `mobile-flutter/lib/core/services/incident_service.dart`
- `mobile-flutter/lib/core/services/local_storage_service.dart`
- `mobile-flutter/lib/core/services/offline_service.dart`
- `mobile-flutter/lib/features/masyarakat/home_screen.dart`
- `mobile-flutter/test/local_storage_service_test.dart`
- `scripts/prune_orphaned_evidence.py` (new utility)

---

## 5. Verification & Acceptance Criteria

1. **Clean Offline Cancellation**:
   - An SOS triggered offline and cancelled offline writes 0 rows to PostgreSQL and generates 0 network traffic to the backend upon reconnecting.
2. **Atomic Category & Status**:
   - Reconnecting after selecting a category offline creates the incident immediately with `status: broadcasting` and the user's category in a single round-trip.
3. **Evidence Storage Parity**:
   - Storage volume contains strictly directories matching confirmed database incident IDs. All uploaded photo and audio files resolve to accessible HTTP endpoints.
4. **UI Seamlessness**:
   - UI status indicator transitions between sending and sent within 1-2 seconds of connection establishment.
   - Reconnecting after offline cancellation never reactivates the active SOS screen or alarm vibration.
