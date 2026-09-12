# Plan 09: Push Notification System (Firebase Cloud Messaging)

## 1. Overview & Problem Statement
- **Target Issues**: Sub-Issues [#30](https://github.com/fadhlur-alaudin86/SiagaKita/issues/30) & [#31](https://github.com/fadhlur-alaudin86/SiagaKita/issues/31) (completing Parent Issue [#7](https://github.com/fadhlur-alaudin86/SiagaKita/issues/7))
- **Priority**: P2 (Normal)
- **Status**: Merged | Verified and closed
- **Problem**:
  - Emergency SOS broadcasts and dispatch assignments currently rely solely on active WebSocket connections.
  - When a volunteer or citizen locks their phone or the mobile application process is terminated by the OS, they miss critical time-sensitive disaster alerts, severely impacting emergency response response times.
- **Goal**:
  - Implement a dual-channel alert system integrating Firebase Cloud Messaging (FCM) on backend and mobile.
  - Ensure high-priority, wake-up push notifications ring device alarms even when the app is backgrounded or terminated.

---

## 2. Technical Scope & Specifications

### 2.1 Backend FCM SDK Integration & Dispatch Broadcast ([#30](https://github.com/fadhlur-alaudin86/SiagaKita/issues/30))
- **Database Schema**:
  - Create table `user_device_tokens` (or store in `user_profiles`): `user_id`, `fcm_token`, `platform` (android/ios), `updated_at`.
- **API Endpoint**:
  - `POST /api/v1/notifications/register-token` [Auth Required] to register/update device FCM tokens upon app launch.
- **Push Dispatch Service**:
  - Integrate `firebase.google.com/go/v4` with service account credentials (`FIREBASE_CREDENTIALS_JSON`).
  - Send multicast high-priority data messages when `broadcastEmergency` fires in `telemetry.Handler` or `incident.Service`.
  - Payload: `{ "incident_id": "...", "type": "SOS", "category": "medical", "latitude": "...", "longitude": "...", "priority": "high" }`.

### 2.2 Mobile FCM Background Handler & Local Notifications ([#31](https://github.com/fadhlur-alaudin86/SiagaKita/issues/31))
- **Dependencies**:
  - `firebase_core`, `firebase_messaging`, `flutter_local_notifications`.
- **Lifecycle Handling**:
  1. *Foreground*: Display heads-up banner with siren chime and vibrate pattern.
  2. *Background*: System tray notification with custom action buttons (*Lihat Peta*, *Abaikan*).
  3. *Terminated*: Wake up device, display high-importance notification channel with persistent alarm sound.
- **Deep Linking**:
  - Clicking the notification navigates directly to the Incident Detail / Radar Screen with camera centered on incident coordinates.

---

## 3. Tasks & Implementation Checklist

### 3.1 Backend Notification Tasks ([#30](https://github.com/fadhlur-alaudin86/SiagaKita/issues/30))
- [x] Add `firebase-admin-go` to `backend-go/go.mod`.
- [x] Create database migration for `user_device_tokens`.
- [x] Implement `NotificationService` with FCM multicast batching.
- [x] Wire notification trigger into incident broadcast flow.

### 3.2 Mobile Notification Tasks ([#31](https://github.com/fadhlur-alaudin86/SiagaKita/issues/31))
- [x] Configure `google-services.json` and Android notification channels.
- [x] Implement top-level `firebaseMessagingBackgroundHandler`.
- [x] Implement local notifications wrapper with custom emergency ringtone.
- [x] Register FCM token on auth login and handle token refresh.

---

## 4. Affected Components & Files

- `backend-go/internal/domain/notification/` (new domain)
- `backend-go/migrations/` (new device tokens table)
- `backend-go/internal/domain/telemetry/handler.go`
- `mobile-flutter/lib/core/services/notification_service.dart` (new)
- `mobile-flutter/android/app/src/main/AndroidManifest.xml`
- `docs/backlog/features/F-030-F-031-fcm-notifications.md` (new)

---

## 5. Verification & Acceptance Criteria

1. **Deliverability**:
   - High-priority FCM messages reach target devices within 2 seconds of incident broadcast.
2. **Terminated State Wake-Up**:
   - When the mobile app is force-closed, an incoming broadcast wakes the screen, displays a heads-up banner, and sounds the alarm.
3. **Deep Link Navigation**:
   - Tapping the notification opens the app directly to the relevant incident without landing on the default home screen.
