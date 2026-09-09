# Plan 01: Authentication & Session Resilience

## 1. Overview & Problem Statement
- **Target Issues**: Sub-Issue [#28](https://github.com/fadhlur-alaudin86/SiagaKita/issues/28) & Sub-Issue [#29](https://github.com/fadhlur-alaudin86/SiagaKita/issues/29) (Parent Issue [#6](https://github.com/fadhlur-alaudin86/SiagaKita/issues/6))
- **Problem**: The backend issues short-lived JWT access tokens with a 15-minute TTL. Currently, the backend lacks a dedicated `POST /api/v1/auth/refresh-token` renewal endpoint, and both Flutter clients (`mobile-flutter` and `windows_console_flutter`) make direct HTTP requests without an automatic token refresh interceptor. Consequently, active volunteers, civilians, or agency dispatchers are abruptly logged out in the middle of active emergency responses or reporting workflows when the 15-minute window expires.
- **Goal**: Implement secure refresh token auto-rotation on the backend with Redis-backed JTI tracking, a 30-second network grace-period window, and transparent 401 retry interceptors with request queuing across Flutter clients.

---

## 2. Architectural Design & Security Model

### 2.1 Backend Token Lifecycle (`backend-go`)
1. **Token Generation**:
   - Access Token: TTL = 15 minutes (`JWTAccessTTL`), contains `sub` (user ID), `role`, `jti`, and `type = "access"`.
   - Refresh Token: TTL = 7 days (`JWTRefreshTTL`), contains `sub` (user ID), `role`, `jti`, and `type = "refresh"`.
2. **Redis JTI Guard & Rotation**:
   - Mobile roles (`civilian`, `volunteer`): Single active session. Key: `refresh_token:<userID>` stores active refresh token JTI with 7-day TTL.
   - Console roles (`admin`, `superadmin`, `agency`): Multi-device support. Key: `refresh_jti:<jti>` stores validity status with 7-day TTL.
3. **Replay Strategy with Disaster-Zone Grace Period (Aligned via `/grill-me`)**:
   - In disaster zones, cellular connections are volatile. If a mobile client rotates a token but the network drops before the response is acknowledged, the client will retry with the previous refresh token.
   - **Grace-Period Window (30 seconds)**:
     - When a refresh token is rotated, its previous JTI is placed into a short-lived Redis key: `refresh_grace:<jti>` with a TTL of 30 seconds, pointing to the newly generated token set.
     - If a refresh request arrives with an old JTI within the 30-second window, the backend returns the already generated active token pair instead of revoking the session.
     - If an old JTI arrives **after** 30 seconds, it is classified as a genuine token theft / replay attack: immediately revoke all sessions for that user in Redis (`session:<userID>`, `refresh_token:<userID>`) and return `401 Unauthorized` with code `ERR_TOKEN_REUSED`.

### 2.2 Frontend Transparent Interceptor (`mobile-flutter` & `windows_console_flutter`)
1. **Queued Request Handling**:
   - Multiple parallel network requests may encounter `401 Unauthorized` simultaneously when a token expires.
   - The HTTP interceptor introduces a concurrency lock and queue:
     - The first request to encounter 401 acquires the refresh lock and executes `POST /api/v1/auth/refresh-token`.
     - Subsequent 401 requests are paused in a pending queue.
     - When token refresh succeeds, update local secure storage and replay all queued requests transparently with the new bearer token.
     - If token refresh fails (refresh token expired or revoked), purge the queue, clear local storage, and navigate to `LoginScreen`.
2. **Storage**:
   - `mobile-flutter`: Persist tokens using `FlutterSecureStorage` (or encrypted shared preferences).
   - `windows_console_flutter`: Persist tokens in `FlutterSecureStorage`.

---

## 3. Tasks & Implementation Checklist

### 3.1 Backend Go Tasks ([#28](https://github.com/fadhlur-alaudin86/SiagaKita/issues/28))
- [x] Add `RefreshToken(ctx context.Context, refreshTokenStr string) (*AuthResponse, error)` in `backend-go/internal/domain/user/service.go`.
- [x] Store and rotate refresh token JTIs in Redis inside `buildAuthResponseWithName`.
- [x] Implement 30-second grace period caching (`refresh_grace:<jti>`) for rotated tokens to handle unstable mobile reconnects.
- [x] Implement hard session revocation when an old token is reused past the 30-second grace period.
- [x] Implement handler `RefreshToken(c *fiber.Ctx) error` in `backend-go/internal/domain/user/handler.go`.
- [x] Register public route `auth.Post("/refresh-token", userHandler.RefreshToken)` in `backend-go/cmd/api/main.go`.
- [x] Add unit tests in `backend-go/internal/domain/user/service_test.go` and `handler_test.go` verifying:
  - Successful token rotation.
  - Replay within 30s grace period returns active token set.
  - Replay after 30s triggers full session revocation.

### 3.2 Flutter Mobile Tasks ([#29](https://github.com/fadhlur-alaudin86/SiagaKita/issues/29))
- [x] Create `ApiClient` in `mobile-flutter/lib/core/services/api_client.dart` with transparent 401 retry and concurrency queue.
- [x] Add transparent 401 interception, concurrency locking, and request replay queue.
- [x] Update `SessionService` and `AuthService` to store and expose `refreshToken`.
- [x] Support transparent token refresh and session expiry handling.
- [x] Add unit tests in `mobile-flutter/test/session_service_test.dart` asserting token storage and refresh persistence.

### 3.3 Flutter Desktop Console Tasks ([#29](https://github.com/fadhlur-alaudin86/SiagaKita/issues/29))
- [x] Implement equivalent 401 retry interceptor in `windows_console_flutter/lib/core/services/auth_service.dart` and `api_services.dart`.
- [x] Update `IncidentApiService`, `AdminApiService`, and `AgencyApiService` to leverage auto-refresh token renewal.
- [x] Add unit tests in `windows_console_flutter/test/auth_service_test.dart` verifying token persistence and session restoration.
- [x] Verify console session continuity across long-running monitoring shifts.

---

## 4. Affected Components & Files

- `backend-go/internal/domain/user/service.go`
- `backend-go/internal/domain/user/handler.go`
- `backend-go/internal/domain/user/model.go`
- `backend-go/cmd/api/main.go`
- `backend-go/internal/domain/user/service_test.go`
- `mobile-flutter/lib/core/services/api_client.dart` [NEW]
- `mobile-flutter/lib/core/services/auth_service.dart`
- `mobile-flutter/lib/core/services/session_service.dart`
- `windows_console_flutter/lib/core/services/api_services.dart`
- `windows_console_flutter/lib/core/services/auth_service.dart`

---

## 5. Verification & Acceptance Criteria

1. **Automated Tests**:
   - `cd backend-go && go test -v -race -run TestRefreshToken ./...`
   - `cd mobile-flutter && flutter test`
   - `cd windows_console_flutter && flutter test`
2. **Acceptance Criteria**:
   - Calling `POST /api/v1/auth/refresh-token` with a valid refresh token yields new tokens and rotates the JTI.
   - Retrying with the same token within 30 seconds returns the active token pair without breaking the session.
   - Retrying with an old token after 30 seconds returns `401 Unauthorized` (`ERR_TOKEN_REUSED`) and revokes all active sessions.
   - Flutter clients smoothly continue background work without logging out users when the 15-minute access token expires.
