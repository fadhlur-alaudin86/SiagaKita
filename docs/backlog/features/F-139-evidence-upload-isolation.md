# F-139: Validate Incident ID Before Evidence Ingestion & Offline Evidence Spooling

## Issue Metadata

| Field | Value |
|---|---|
| ID | F-139 |
| Title | Validate Incident ID Before Evidence Ingestion & Offline Evidence Spooling |
| Requestor | Fadhlurrahman Alaudin |
| Date Created | 2026-09-13 |
| GitHub Issues | [#139](https://github.com/fadhlur-alaudin86/SiagaKita/issues/139) |
| Parent Plan | `.planning/13-sos-offline-online-sync-resilience.md` ([#136](https://github.com/fadhlur-alaudin86/SiagaKita/issues/136)) |
| Status | Done |

---

## 1. Scope & Goals

- **Core Problems**:
  1. Disk volume vs DB UUID mismatch: When an SOS was triggered offline or connection was intermittent, `home_screen.dart` invoked evidence capture using a temporary client-side UUID (`localId`).
  2. Premature file persistence in backend: `Handler.UploadEvidence` created directories on the Docker storage volume (`uploads/incidents/evidence/<yearMonth>/<incidentID>`) and wrote physical files to disk before validating whether the incident existed in PostgreSQL.
  3. Orphaned disk directories & missing paths: When `FindByID` subsequently failed with `record not found`, the database fields (`photo_paths`, `audio_path`) remained null, while the physical files and folders remained permanently orphaned on disk.
- **Goals**:
  - In `backend-go/internal/domain/incident/handler.go: UploadEvidence`, enforce database validation (`s.repo.FindByID`) before creating directories or saving files to disk. Return HTTP 404 immediately for non-existent incidents and 403 for unauthorized reporters with zero disk writes.
  - Implement cleanup rollback in `service.go` or `handler.go` if database update fails after file writes.
  - In `mobile-flutter`, prevent calling `/evidence` endpoint with temporary client UUIDs. Spool captured evidence locally in `LocalStorageService.savePendingEvidence` until server incident ID is confirmed.
  - Create `scripts/prune_orphaned_evidence.py` to scan `uploads/incidents/evidence/` against PostgreSQL and purge orphaned volume directories.
- **Boundaries**:
  - `backend-go/internal/domain/incident/handler.go`
  - `backend-go/internal/domain/incident/service.go`
  - `backend-go/internal/domain/incident/handler_test.go`
  - `mobile-flutter/lib/core/services/local_storage_service.dart`
  - `mobile-flutter/lib/core/services/offline_service.dart`
  - `mobile-flutter/lib/features/masyarakat/home_screen.dart`
  - `mobile-flutter/test/local_storage_service_test.dart`
  - `scripts/prune_orphaned_evidence.py`

---

## 2. Architectural Decisions Log

1. **Pre-Ingestion Existence & Ownership Validation**:
   - **Decision**: In `Handler.UploadEvidence`, query `h.svc.repo.FindByID(incidentID)` first.
   - **Rationale**: Rejecting non-existent incident IDs at the gateway ensures that no orphaned files or directories are created on disk.
2. **Local Evidence Spooling on Client**:
   - **Decision**: If `_sosUploadStatus != 'sent'` or `incidentId` is local UUID, spool evidence paths in `LocalStorageService`.
   - **Rationale**: Captured media must not be lost when triggered offline, but must only be transmitted once the backend has acknowledged and registered the incident.
3. **Orphan Pruning Maintenance Utility**:
   - **Decision**: Author `scripts/prune_orphaned_evidence.py` to inspect directory UUIDs in `uploads/incidents/evidence/` against `incidents` table in PostgreSQL.
   - **Rationale**: Resolves disk volume bloat and cleans existing orphaned folders left by previous bugs.

---

## 3. Step Progress

| Step | Action | Status | Date | Notes |
|---|---|---|---|---|
| -3 | Backlog Overview | Done | 2026-09-13 | Audited issue #139 under Plan 13 |
| -2 | Discovery & Grill-Me | Done | 2026-09-13 | Diagnosed root cause of volume vs DB UUID mismatch |
| -1 | Resolve Backlog | Done | 2026-09-13 | Created feature spec and labeled issue in-progress |
| 0 | Branch & Assign | Done | 2026-09-13 | Topic branch `fix/F-139-evidence-upload-isolation` |
| 1 | Backend Pre-Ingestion Validation | Done | 2026-09-13 | Validated incident before disk creation in `handler.go` with rollback |
| 2 | Client-Side Evidence Spooling | Done | 2026-09-13 | Spool offline evidence in Hive and sync on confirmed server ID |
| 3 | Orphan Evidence Pruning Script | Done | 2026-09-13 | Created `scripts/prune_orphaned_evidence.py` and purged 4 orphans |
| 4 | Unit & Integration Tests | Done | 2026-09-13 | Tested zero disk writes on 404/403, tested spooling in Flutter |
| 5 | Quality Gates & PR | Done | 2026-09-13 | `verify_pipeline.py` & PR #144 merged into `dev` |
