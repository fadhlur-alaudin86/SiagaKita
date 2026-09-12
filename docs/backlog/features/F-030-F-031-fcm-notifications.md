# F-030 & F-031: Push Notification System (Firebase Cloud Messaging)

## Issue Metadata

| Field | Value |
|---|---|
| ID | F-030 / F-031 |
| Title | Push Notification System (Firebase Cloud Messaging) |
| Requestor | Fadhlurrahman Alaudin |
| Date Created | 2026-09-12 |
| GitHub Issues | [#7](https://github.com/fadhlur-alaudin86/SiagaKita/issues/7), [#30](https://github.com/fadhlur-alaudin86/SiagaKita/issues/30), [#31](https://github.com/fadhlur-alaudin86/SiagaKita/issues/31) |
| Parent Plan | `.planning/09-push-notifications-fcm.md` |
| Status | In Progress |

---

## 1. Scope & Goals

- **Core Problem**:
  - Emergency SOS alerts and dispatch assignments currently rely solely on active WebSocket connections.
  - When a citizen or volunteer locks their phone or the mobile application process is terminated by the operating system, they miss critical time-sensitive disaster alerts, severely degrading emergency response times.
- **Boundaries**:
  - Backend: Schema migration adding `fcm_token` to `user_profiles`, REST endpoints for registering and clearing tokens, FCM client interface with production Firebase Admin SDK and graceful dry-run logger fallback for CI/local development, multicast geofenced push dispatch upon SOS promotion to `broadcasting`, and automatic dead token pruning.
  - Mobile (`mobile-flutter` & `mobile-flutter-responder`): Dual-channel notification setup (`emergency_alerts` with maximum priority and loud alarm chime, `general_notifications` for normal updates), token registration on auth and refresh, foreground heads-up banner, background/terminated message handler, and deep linking directly to incident radar / mission detail.
- **Non-Goals**:
  - Custom web push for desktop browsers (Windows Console uses live WebSocket audio siren).
  - Third-party push providers (APNs direct or OneSignal); all traffic routes through standard Firebase Cloud Messaging (HTTP v1 / Admin SDK).

---

## 2. Architectural Decisions Log (Resolved via `/grill-me`)

1. **FCM Token Storage Schema**:
   - **Decision**: Add `fcm_token TEXT` column to `public.user_profiles` with index `idx_up_fcm_token`.
   - **Rationale**: Aligns with existing issue checklist and simplifies user profile entity without adding multi-table join overhead.
2. **Smart 2-Tier Target Audience Filtering**:
   - **Decision**:
     - *Verified Volunteers* (`mobile-flutter`): Geofenced push notification sent only to volunteers located within 10 km radius of the incident coordinates.
     - *Agency Responders* (`mobile-flutter-responder`): Sent only if the incident is within the operating radius of the agency (<= 20 km) matching the incident category, OR upon direct mission assignment (`ASSIGN_MISSION`) by the dispatcher console.
     - *Exclusion of Reporter*: The user who triggered the SOS is explicitly excluded from the loud siren broadcast to prevent redundant alarms and to protect victim safety in crime/hostage situations.
   - **Rationale**: Prevents notification flooding across nationwide deployments while ensuring relevant nearby helpers are immediately alerted.
3. **Dual-Channel Notification Configuration on Mobile**:
   - **Decision**:
     - Channel 1: `emergency_alerts` (Importance: Max, Priority: High, loud siren alarm chime, repeating SOS vibration pattern, heads-up display).
     - Channel 2: `general_notifications` (Importance: Default, standard system chime for badge unlocks and mission reviews).
   - **Rationale**: Separates life-or-death emergency alerts from casual updates, allowing the OS and user settings to prioritize appropriately.
4. **Backend FCM Service Architecture & CI/Local Fallback**:
   - **Decision**: Create `NotificationSender` interface implemented by `FirebaseAdminClient` (when `FIREBASE_CREDENTIALS_JSON` / `FIREBASE_CREDENTIALS_FILE` is configured) and `NoOpLoggerClient` (dry-run mode when credentials are not configured).
   - **Rationale**: Guarantees that unit tests, local test suites, and GitHub Actions CI pipelines pass 100% cleanly without external Google Cloud dependencies.
5. **Multi-Client Parity**:
   - **Decision**: Implement FCM token registration and notification handling across both `mobile-flutter` (civilian/volunteer) and `mobile-flutter-responder` (agency personnel).
   - **Rationale**: Upholds Rule A (Multi-Client API Contract Parity) across the entire mobile fleet.
6. **Complete Token Lifecycle & Auto-Pruning**:
   - **Decision**:
     - On login: Fetch FCM token and call `PUT /api/v1/users/profile/fcm-token`.
     - On logout: Call `DELETE /api/v1/users/profile/fcm-token` and execute `FirebaseMessaging.instance.deleteToken()`.
     - On rotation: Listen to `FirebaseMessaging.instance.onTokenRefresh` to automatically update backend.
     - On send failure: When FCM returns `registration-token-not-registered` or `unregistered`, backend automatically sets `fcm_token = NULL` for that user record.
   - **Rationale**: Prevents stale token accumulation and ensures zero cross-user message contamination on shared devices.

---

## 3. Database Schema & Migration Specification

### Migration: `023_add_fcm_token_to_user_profiles.up.sql`

```sql
-- Add fcm_token column to user_profiles
ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- Add partial index for fast lookup of active tokens
CREATE INDEX IF NOT EXISTS idx_up_fcm_token
ON public.user_profiles(fcm_token)
WHERE fcm_token IS NOT NULL;
```

### Migration: `023_add_fcm_token_to_user_profiles.down.sql`

```sql
DROP INDEX IF EXISTS public.idx_up_fcm_token;

ALTER TABLE public.user_profiles
DROP COLUMN IF EXISTS fcm_token;
```

---

## 4. API Specification & Contracts

### 4.1 Register / Update FCM Token
- **Endpoint**: `PUT /api/v1/users/profile/fcm-token`
- **Auth**: Bearer JWT (Roles: all authenticated users)
- **Request Body**:
  ```json
  {
    "fcm_token": "fcm_device_token_string..."
  }
  ```
- **Response `200 OK`**:
  ```json
  {
    "code": 200,
    "message": "FCM token berhasil diperbarui"
  }
  ```

### 4.2 Clear FCM Token (Logout)
- **Endpoint**: `DELETE /api/v1/users/profile/fcm-token`
- **Auth**: Bearer JWT (Roles: all authenticated users)
- **Response `200 OK`**:
  ```json
  {
    "code": 200,
    "message": "FCM token berhasil dihapus"
  }
  ```

### 4.3 FCM Push Payload Contract
- **Message Type**: Multicast Data + Notification Message
- **Data Payload**:
  ```json
  {
    "incident_id": "c62b5bf4-0f2c-4b68-9993-9c8644e45c47",
    "incident_type": "medical",
    "title": "DARURAT MEDIS TERDETEKSI",
    "body": "Insiden darurat di Jl. Merdeka No. 45 (~1.2 km). Ketuk untuk merespon.",
    "latitude": "-6.2088",
    "longitude": "106.8456",
    "channel_id": "emergency_alerts",
    "priority": "high",
    "click_action": "FLUTTER_NOTIFICATION_CLICK"
  }
  ```

---

## 5. Step Progress

| Step | Action | Status | Date | Notes |
|---|---|---|---|---|
| -3 | Backlog Overview | Done | 2026-09-12 | Identified Parent Issue #7 and Sub-Issues #30, #31 |
| -2 | Discovery & Grill-Me | Done | 2026-09-12 | Resolved 2-tier audience, dual channels, and token lifecycle |
| -1 | Resolve Backlog | Done | 2026-09-12 | Authored specification `F-030-F-031-fcm-notifications.md` |
| 0 | Branch & Assign | Done | 2026-09-12 | Topic branch `feature/F-030-F-031-fcm-notifications` |
| 1 | DB Migration | Done | 2026-09-12 | Migration 023 and `docs/DATABASE_SCHEMA.md` verified |
| 2 | Backend Implementation | Done | 2026-09-12 | FCM service, token routes, broadcast hook, and unit tests |
| 3 | Mobile Flutter Implementation | Done | 2026-09-12 | Dual channel, FCM listener, background handler, and deep link |
| 4 | Mobile Responder Implementation | Done | 2026-09-12 | FCM token sync and mission alert handler for personnel |
| 5 | Verification | Done | 2026-09-12 | `verify_pipeline.py` passed with 100% scorecard |
| 6 | CI + Review | In Progress | 2026-09-12 | Pull request targeting `dev` |
