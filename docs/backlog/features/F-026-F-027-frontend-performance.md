# F-026 & F-027: Frontend Performance Optimization & Hive Offline-First Storage

## Issue Metadata

| Field | Value |
|---|---|
| ID | F-026, F-027 |
| Title | State Selector Optimization (Desktop) & Hive Offline Cache (Mobile) |
| Requestor | Fadhlurrahman Alaudin |
| Date Created | 2026-09-11 |
| GitHub Issues | #26, #27 (Parent: #5) |
| Parent Plan | `.planning/07-frontend-performance-selector-offline-cache.md` |
| Status | Merged (PR #100) |
| Target PR | [#100](https://github.com/fadhlur-alaudin86/SiagaKita/pull/100) |

---

## Discovery (Step -2)

| Type | File / Component | Notes |
|---|---|---|
| Desktop Header & Shell | `windows_console_flutter/lib/features/instansi/presentation/instansi_shell.dart` | Generic `Consumer<WsService>` causes redundant header rebuilds during WebSocket telemetry |
| Desktop Dispatch Page | `windows_console_flutter/lib/features/instansi/presentation/pages/dispatch_relawan_page.dart` | High-frequency `volunteerLocationUpdate` calls `setState` on entire 1400+ line widget tree |
| Desktop Radar Map | `windows_console_flutter/lib/features/instansi/presentation/pages/peta_operasional_page.dart` | Volunteer coordinates update calls `setState` rebuilding status bar and static markers |
| Desktop Active SOS | `windows_console_flutter/lib/features/instansi/presentation/pages/sos_aktif_page.dart` | Civilian GPS updates trigger top-level state updates across forms and audio players |
| Mobile Offline Storage | `mobile-flutter/lib/core/services/offline_service.dart` | Currently serializes JSON strings into `SharedPreferences` |
| Mobile Incidents Cache | `mobile-flutter/lib/core/services/incident_service.dart` | Uses `SharedPreferences` string blobs for history caching |
| Mobile Reports Queue | `mobile-flutter/lib/core/services/report_service.dart` | Uses `SharedPreferences` string lists for offline failed reports |

---

## Step Progress

| Step | Action | Status | Date | Notes |
|---|---|---|---|---|
| -3 | Backlog Overview | Done | 2026-09-11 | Selected Parent #5, Sub-issues #26 and #27 |
| -2 | Discovery | Done | 2026-09-11 | Audited `windows_console_flutter` and `mobile-flutter` call sites |
| -1 | Resolve Backlog | Done | 2026-09-11 | Created feature specification log `F-026-F-027-frontend-performance.md` |
| 0 | Branch & Assign | Done | 2026-09-11 | Target branch `feature/F-026-F-027-frontend-performance` |
| 1 | Read Mapping | Done | 2026-09-11 | Architectural interview resolved via `/grill-me` |
| 2 | API Contract | Skipped | 2026-09-11 | Client performance and local storage refactoring; backend contracts unchanged |
| 3 | DB Migration | Skipped | 2026-09-11 | No server database schema changes required |
| 4 | Implementation | Done | 2026-09-11 | Implemented Hive storage, telemetry decimation, and Flutter desktop selectors |
| 5 | Tests | Done | 2026-09-11 | Unit tests for LocalStorageService (13/13 pass), full test suites pass, flutter analyze 0 issues |
| 6 | CI + Review | Done | 2026-09-11 | Pre-PR audit, checklist sync, CodeGraph sync |
| 7 | Close Log | Done | 2026-09-11 | Merged into `dev` via Pull Request #100 |

---

## Architectural Decisions Log (Resolved via /grill-me)

1. **Mobile Embedded Storage Engine**:
   - **Decision**: Use `hive` and `hive_flutter` with structured Map/JSON storage without compile-time code generation (`build_runner`).
   - **Rationale**: Keeps the implementation simple (KISS/YAGNI), eliminates CI build toolchain friction across Android and Linux environments, avoids C++ native runtime dependency issues associated with Isar, and delivers sub-millisecond synchronous in-memory read access.
2. **Offline SOS & Telemetry Queue Replay Strategy**:
   - **Decision**: Automatic reactive replay triggered by `ConnectivityService.isOnline` stream updates, accompanied by a cold-start check in `HomeScreen.initState`.
   - **Rationale**: Immediate and transparent to the user without requiring manual intervention, minimizing dispatch delay when connectivity resumes.
3. **Desktop Console High-Frequency Telemetry Isolation**:
   - **Decision**: Use `ValueNotifier<Map<String, LatLng>>` with `ValueListenableBuilder` scoped strictly to the `MarkerLayer` within `FlutterMap`, accompanied by `RepaintBoundary` wrappers around stationary panels (sidebar, incident tables, candidate lists).
   - **Rationale**: Decouples live GPS coordinate streams from page-level `setState()`, ensuring 60+ FPS stability and zero rebuilds on tables, forms, or text inputs.
4. **Offline Telemetry Buffer Policy & Cache TTL**:
   - **Decision**: Implement a 1,000-point ring buffer with distance/time decimation (only log points if displacement > 15m or delta > 30s) and a 24-hour TTL for the incident cache.
   - **Rationale**: Conserves mobile device battery and disk storage, while strictly bounding memory footprint during prolonged offline operations.
