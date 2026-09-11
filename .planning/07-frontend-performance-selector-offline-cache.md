# Plan 07: Frontend Performance (State Selector Optimization & Local Cache)

## 1. Overview & Problem Statement
- **Target Issues**: Sub-Issues [#26](https://github.com/fadhlur-alaudin86/SiagaKita/issues/26) & [#27](https://github.com/fadhlur-alaudin86/SiagaKita/issues/27) (completing Parent Issue [#5](https://github.com/fadhlur-alaudin86/SiagaKita/issues/5))
- **Priority**: P1 (High)
- **Status**: Merged | Implemented & Verified in PR #100
- **Problem**:
  1. In `windows_console_flutter`, emergency dispatch tables, radar maps, and header status widgets consume state using generic `Consumer<WsService>` or broad `Provider.of` listeners. When high-frequency volunteer GPS updates stream in over WebSocket (multiple updates per second), entire views undergo redundant rebuilds, degrading rendering performance below 60 FPS on dispatch consoles.
  2. In `mobile-flutter`, offline SOS queueing and cached incident feeds rely on `SharedPreferences` with stringified JSON blobs. Serializing and deserializing arrays of incidents across disk creates UI thread pauses and lacks indexed queries during low-connectivity disaster scenarios.
- **Goal**:
  1. Refactor Desktop Console state subscriptions to fine-grained `Selector` and `context.select()` patterns to isolate widget rebuilds strictly to modified fields, maintaining a stable 60/120 FPS.
  2. Migrate mobile offline caching from `SharedPreferences` to a high-speed embedded NoSQL database (`Hive` or `Isar`) for sub-millisecond offline storage and retrieval.

---

## 2. Technical Scope & Specifications

### 2.1 State Selector Optimization in Desktop Console ([#26](https://github.com/fadhlur-alaudin86/SiagaKita/issues/26))
- **Scope**: `windows_console_flutter/lib/features/` (Dashboard, Dispatch Map, Incident Table, Header Bar).
- **Architecture**:
  - Replace broad `Consumer<WsService>` wrappers with `Selector<WsService, T>` or `context.select<WsService, T>((s) => s.targetField)`.
  - Isolate live volunteer coordinate updates to radar map overlays without triggering rebuilds of tabular incident rows.
  - Isolate incident lifecycle transitions (`broadcasting`, `handled`, `resolved`) to specific list item widgets using `ValueKey(incident.id)`.
  - Wrap stationary UI components (Sidebars, Top Navbar, Metric Cards) with `const` constructors and `RepaintBoundary` barriers.

### 2.2 Embedded NoSQL Offline Cache Migration in Mobile ([#27](https://github.com/fadhlur-alaudin86/SiagaKita/issues/27))
- **Scope**: `mobile-flutter/lib/core/services/` (`OfflineService`, `IncidentCacheService`).
- **Database Selection**:
  - Integrate `hive_flutter` / `hive` (or `isar` if complex queries are required; `hive` is recommended for pure key-value and typed boxes without native build toolchain dependencies).
- **Offline Capabilities**:
  - Offline SOS Queue: Persist failed outbound SOS alerts with automatic replay when network connectivity returns.
  - Cached Incident Feed: Store the last known active and nearby emergency alerts for immediate instant-load rendering upon app restart in airplane mode or disaster blackout zones.
  - Local Telemetry Logs: Buffer offline volunteer GPS breadcrumbs up to 1,000 points and bulk-sync upon reconnecting.

---

## 3. Tasks & Implementation Checklist

### 3.1 Desktop Selector Tasks ([#26](https://github.com/fadhlur-alaudin86/SiagaKita/issues/26))
- [ ] Audit all `Consumer` and `Provider.of` call sites in `windows_console_flutter`.
- [ ] Refactor incident table rows to subscribe only to individual incident status changes.
- [ ] Refactor map markers to update coordinates without triggering whole-canvas re-renders.
- [ ] Wrap stationary views in `RepaintBoundary` and verify widget rebuild counts in Flutter DevTools.

### 3.2 Mobile Local Cache Tasks ([#27](https://github.com/fadhlur-alaudin86/SiagaKita/issues/27))
- [ ] Add `hive_flutter` to `mobile-flutter/pubspec.yaml` and initialize boxes in `main.dart`.
- [ ] Create `OfflineStorageService` with typed adapters for `IncidentModel` and `TelemetryBreadcrumb`.
- [ ] Migrate `OfflineService` from `SharedPreferences` to the new Hive storage layer.
- [ ] Implement automatic sync daemon that flushes queued offline requests when internet resumes.

---

## 4. Affected Components & Files

- `windows_console_flutter/lib/features/dashboard/dashboard_screen.dart`
- `windows_console_flutter/lib/features/dispatch/dispatch_screen.dart`
- `windows_console_flutter/lib/features/dispatch/widgets/`
- `mobile-flutter/pubspec.yaml`
- `mobile-flutter/lib/core/services/offline_service.dart`
- `mobile-flutter/lib/core/services/local_storage_service.dart` (new)
- `mobile-flutter/lib/core/models/offline_queue_item.dart` (new)
- `docs/backlog/features/F-026-F-027-frontend-performance.md` (new)

---

## 5. Verification & Acceptance Criteria

1. **Desktop Performance**:
   - Flutter DevTools Widget Rebuild Tracker confirms zero rebuilds on table rows when incoming WebSocket telemetry events are emitted.
   - Smooth 60+ FPS during intense live location broadcast streaming.
2. **Mobile Offline Resilience**:
   - Triggering SOS with WiFi and Mobile Data turned off caches the request into Hive without errors.
   - Re-enabling network connectivity flushes the queued SOS to the backend and triggers standard broadcasting within 5 seconds.
   - `flutter analyze` and `flutter test` pass with zero warnings across both clients.
