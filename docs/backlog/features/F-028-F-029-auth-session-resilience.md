# F-028 & F-029: Refresh Token Auto-Rotation & Multi-Client Session Resilience

## Issue Metadata

| Field | Value |
|---|---|
| ID | F-028 / F-029 |
| Title | Refresh Token Auto-Rotation & Multi-Client Session Resilience |
| Requestor | Fadhlurrahman Alaudin |
| Date Created | 2026-09-09 |
| GitHub Issues | #28 & #29 (Parent: #6) |
| Status | Merged (PR #60) |

## Discovery (Step -2)

| Type | File / Name | Notes |
|---|---|---|
| Go Domain | `backend-go/internal/domain/user` | Auth handlers, models, service token generation |
| Endpoint | `POST /api/v1/auth/refresh-token` | Public endpoint exchanging refresh token for new access+refresh token pair |
| Redis Keys | `refresh_token:<userID>`<br>`refresh_grace:<jti>`<br>`session:<userID>` | Session guard and single-use rotation with 30-second network grace period |
| Mobile Service | `mobile-flutter/lib/core/services/` | `ApiClient`, `AuthService`, `SessionService` |
| Desktop Service | `windows_console_flutter/lib/core/services/` | `AuthService`, `api_services.dart` |

## Decisions Aligned via /grill-me

| # | Topic | Decision |
|---|---|---|
| 1 | Replay Attack Strategy | Implement a **30-second network grace-period window** in Redis (`refresh_grace:<jti>`). If a mobile client retries rotation within 30s due to an unstable connection, the active token pair is re-returned. Old tokens reused past 30s trigger full session revocation. |
| 2 | Mobile vs Console Session Model | Mobile roles (`civilian`, `volunteer`) enforce single-session concurrency (`refresh_token:<userID>`). Console roles (`admin`, `superadmin`, `agency`) permit multi-device sessions (`refresh_jti:<jti>`). |
| 3 | Concurrency Lock on Frontend | Both Flutter clients wrap requests in an authenticated client that queues parallel 401s while a single token refresh executes, avoiding redundant rotation calls. |
| 4 | Clean Logout Fallback | If the refresh token itself has expired or been revoked, clear local storage and navigate cleanly to `LoginScreen` with localized feedback. |

## Step Progress

| Step | Action | Status | Date | Notes |
|---|---|---|---|---|
| -3 | Backlog Overview | Done | 2026-09-09 | Plan 01 selected as foundational blocker for Phase 1 MVP |
| -2 | Discovery & Grill-Me | Done | 2026-09-09 | Aligned on 30s grace period and client request queueing |
| -1 | Resolve Backlog | Done | 2026-09-09 | Created feature log `F-028-F-029-auth-session-resilience.md` |
| 0 | Branch & Assign | Done | 2026-09-09 | Created branch `feature/F-028-F-029-auth-session-resilience`, updated Issues #28 & #29 to `in-progress` |
| 1 | Read Mapping | Done | 2026-09-09 | Inspected token generation in `utils/jwt.go`, `user/service.go`, `middleware/auth.go` |
| 2 | API Contract | Done | 2026-09-09 | Updated `docs/api/paths/auth.yaml` with `/api/v1/auth/refresh-token` |
| 3 | DB Migration | Skipped | 2026-09-09 | No DB schema change needed; Redis handles token rotation state |
| 4 | Backend Implementation | Done | 2026-09-09 | Implemented `RefreshToken` service, handler, routes, 30s Redis grace window |
| 5 | Flutter Implementation | Done | 2026-09-09 | Implemented `ApiClient` interceptor in mobile and `AuthService`/`api_services.dart` in desktop |
| 6 | Tests | Done | 2026-09-09 | Unit tests added in Go (`service_test.go`, `handler_test.go`), Mobile (`session_service_test.dart`), Desktop (`auth_service_test.dart`) |
| 7 | CI + Review | Done | 2026-09-09 | Verified `go test -race` (all pass), Mobile `flutter test` + `flutter analyze` (clean), Desktop `flutter test` + `flutter analyze` (clean) |
| 8 | Close Log | Done | 2026-09-09 | Merged to dev via PR #60 |
