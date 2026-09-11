# F-018 to F-020: Desktop Console Real-Time Dispatch MVP

## Issue Metadata

| Field | Value |
|---|---|
| ID | F-018, F-019, F-020 |
| Title | Real-Time Desktop Dispatch MVP |
| Requestor | Fadhlurrahman Alaudin |
| Date Created | 2026-09-10 |
| GitHub Issues | #18, #19, #20 (Parent: #37) |
| Status | Merged (PR #65) |

## Discovery (Step -2)

| Type | File / Name | Notes |
|---|---|---|
| Desktop Client | `windows_console_flutter/` | Windows Desktop Flutter Console |
| Dispatch Shell | `lib/features/instansi/presentation/instansi_shell.dart` | Menu enum, sidebar navigation, top header |
| Dispatch Page | `lib/features/instansi/presentation/pages/dispatch_relawan_page.dart` | [NEW] Split-view dispatch dashboard |
| WS Service | `lib/core/services/ws_service.dart` | WebSocket event stream for `VOLUNTEER_LOCATION_UPDATE` |
| API Services | `lib/core/services/api_services.dart` | Dispatch broadcast and incident services |
| Backend Incident | `backend-go/internal/domain/incident/` | Handlers, service, atomic claiming, FCFS |
| Backend Telemetry | `backend-go/internal/domain/telemetry/` | Redis GEO tracking, nearby volunteers fallback |
| Mobile Client | `mobile-flutter/` | Volunteer assignment offer modal & acceptance |
| Localization | `windows_console_flutter/lib/core/localization/app_localization.dart` | Bilingual English & Indonesian dictionary |

## Step Progress

| Step | Action | Status | Date | Notes |
|---|---|---|---|---|
| -3 | Backlog Overview | Done | 2026-09-10 | Plan 04 selected to build Real-Time Dispatch MVP |
| -2 | Discovery | Done | 2026-09-10 | Inspected Flutter maps, WS events, and Go incident domain |
| -1 | Resolve Backlog | Done | 2026-09-10 | Created feature log `F-018-F-020-desktop-dispatch-mvp.md` |
| 0 | Branch & Assign | Done | 2026-09-10 | Created branch `feature/F-018-F-020-desktop-dispatch-mvp` |
| 1 | Read Mapping | Done | 2026-09-10 | Review existing UI state management and WS message flow |
| 2 | API Contract | Done | 2026-09-10 | Defined `POST /api/v1/incidents/:id/dispatch-broadcast` and `GET /api/v1/telemetry/nearby-volunteers` |
| 3 | DB Migration | Skipped | 2026-09-10 | Existing `incident_responses` schema supports `en_route` status |
| 4 | Backend Implementation | Done | 2026-09-10 | Implemented dispatch broadcast, Redis GEO query, FCFS claiming, and 60s timeout |
| 5 | Flutter Implementation | Done | 2026-09-10 | Built split-view radar, live telemetry markers, active mission stepper, polyline layer, and mobile offer modal |
| 6 | Tests | Done | 2026-09-10 | Backend race tests, Flutter analyze (0 issues) and unit tests (6/6 passed) |
| 7 | CI + Review | Done | 2026-09-10 | Multi-client quality gates, CodeGraph sync, issues set to in-review |
| 8 | Close Log | Done | 2026-09-10 | PR to `dev` |

