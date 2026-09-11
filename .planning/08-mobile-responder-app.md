# Plan 08: Mobile Responder Application (mobile-flutter-responder)

## 1. Overview & Problem Statement
- **Target Issues**: Sub-Issues [#21](https://github.com/fadhlur-alaudin86/SiagaKita/issues/21), [#22](https://github.com/fadhlur-alaudin86/SiagaKita/issues/22), & [#23](https://github.com/fadhlur-alaudin86/SiagaKita/issues/23) (completing Parent Issue [#4](https://github.com/fadhlur-alaudin86/SiagaKita/issues/4))
- **Priority**: P1 (High)
- **Status**: Ready for Backlog Execution
- **Problem**:
  - Currently, SiagaKita has clients for civilians/volunteers (`mobile-flutter`) and agency desktop dispatchers (`windows_console_flutter`).
  - Official emergency responders (firefighters, paramedic drivers, police patrol, SAR field teams) operating with the `agency_personnel` role do not have a dedicated mobile app to receive unit dispatches on the road, update response statuses, or stream vehicle GPS coordinates back to the agency command center.
- **Goal**:
  - Initialize and deliver the MVP for `mobile-flutter-responder/`, tailored specifically for official agency personnel.
  - Implement dedicated personnel authentication, interactive Mission Board with status progression, and continuous background GPS telemetry streaming.

---

## 2. Technical Scope & Specifications

### 2.1 Project Initialization & Personnel Auth ([#21](https://github.com/fadhlur-alaudin86/SiagaKita/issues/21))
- **Directory**: `mobile-flutter-responder/`
- **Architecture**:
  - Flutter 3.x with clean architecture: `core/` (network, localization, storage, theme), `features/` (auth, missions, telemetry, profile).
  - Localization parity: full Indonesian (`id`) and English (`en`) dictionary parity using `.tr(context)`.
- **Authentication**:
  - Endpoint: `POST /api/v1/auth/personnel/login` accepting `email`/`badge_number` and `password`.
  - Secure token storage using `flutter_secure_storage` with auto-refresh interceptors (aligned with Plan 01).
  - RBAC verification ensuring only users with `role: agency_personnel` can access the responder shell.

### 2.2 Mission Board & Dispatch Acceptance ([#22](https://github.com/fadhlur-alaudin86/SiagaKita/issues/22))
- **Mission Feed**:
  - Display emergency incidents assigned to the personnel's agency unit.
  - Show urgency badges, distance, reporter trust label, victim details, and multimedia situation evidence.
- **Status Lifecycle State Machine**:
  - Action buttons:
    1. *Terima Tugas (Accept Mission)* -> Updates backend status to `handling`.
    2. *Dalam Perjalanan (En Route)* -> Notifies dispatcher that unit is rolling.
    3. *Tiba di Lokasi (On Scene)* -> Confirms arrival; stops emergency siren.
    4. *Selesai (Completed)* -> Uploads situation resolution notes and evidence.
  - Real-time synchronization: Dispatcher console updates immediately via WebSocket events.

### 2.3 Background GPS Telemetry & Navigation Map ([#23](https://github.com/fadhlur-alaudin86/SiagaKita/issues/23))
- **Telemetry Ingestion**:
  - Stream responder GPS coordinates every 3–5 seconds using `geolocator` and background service.
  - Send updates via `PUT /api/v1/telemetry/location` to leverage the high-throughput `sync.Pool` backend hotpath.
- **Navigation Map**:
  - Interactive map using `flutter_map` (OpenStreetMap / CartoDB tiles).
  - Route plotting from current responder coordinates to the incident location with turn-by-turn guidance and ETA display.

---

## 3. Tasks & Implementation Checklist

### 3.1 Project Scaffolding & Auth Tasks ([#21](https://github.com/fadhlur-alaudin86/SiagaKita/issues/21))
- [ ] Initialize `mobile-flutter-responder/` with dependencies (`provider`, `dio`, `flutter_secure_storage`, `flutter_map`).
- [ ] Implement `AppLocalization` and bilingual dictionaries (`id` & `en`).
- [ ] Build `LoginScreen` and integrate `POST /api/v1/auth/personnel/login`.
- [ ] Implement session guard and role validation.

### 3.2 Mission Board Tasks ([#22](https://github.com/fadhlur-alaudin86/SiagaKita/issues/22))
- [ ] Build `MissionBoardScreen` displaying assigned emergency alerts.
- [ ] Implement mission detail view with victim profile, medical tags, and multimedia audio/photo evidence.
- [ ] Implement status transition buttons with optimistic UI updates and error rollbacks.
- [ ] Connect WebSocket listener to receive instant alerts when new dispatches are assigned.

### 3.3 Telemetry & Navigation Tasks ([#23](https://github.com/fadhlur-alaudin86/SiagaKita/issues/23))
- [ ] Configure background location permissions on Android (`ACCESS_FINE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`).
- [ ] Implement background location service streaming coordinates to `PUT /api/v1/telemetry/location`.
- [ ] Build `NavigationMapScreen` rendering responder position, incident pin, and route polyline.

---

## 4. Affected Components & Files

- `mobile-flutter-responder/` (new project directory)
  - `pubspec.yaml`
  - `lib/main.dart`
  - `lib/core/localization/app_localization.dart`
  - `lib/core/network/api_client.dart`
  - `lib/features/auth/`
  - `lib/features/missions/`
  - `lib/features/telemetry/`
- `docs/backlog/features/F-021-F-023-mobile-responder.md` (new)

---

## 5. Verification & Acceptance Criteria

1. **Authentication**:
   - Responders can successfully log in using agency badge credentials and land on `MissionBoardScreen`.
   - Unauthorized roles (civilian, volunteer) are rejected with clear localized errors.
2. **Dispatch Parity**:
   - Status transitions made on the mobile app instantly reflect on the agency Desktop Console dashboard.
3. **Location Tracking**:
   - Responder vehicle marker moves smoothly on the Desktop Console dispatch radar as the mobile device moves.
4. **Code Quality**:
   - `flutter analyze` passes with 0 warnings in `mobile-flutter-responder/`.
