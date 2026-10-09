# Component Mapping — SiagaKita Multi-Client Architecture

This document serves as the living single-source-of-truth matrix linking frontend user interfaces across Flutter Mobile and Flutter Windows Console with Go Fiber backend endpoints, PostgreSQL database operations, and real-time WebSocket events.

---

## 1. Authentication & Session Management

| Feature | Mobile Flutter (Citizen / Volunteer) | Windows Console Flutter (Agency / Admin) | Go Fiber Endpoint & Handler | DB Table & Query | State, WS & Security |
|---|---|---|---|---|---|
| **Citizen & Volunteer Login** | `mobile-flutter/lib/features/auth/login_screen.dart` | — | `POST /api/v1/auth/login` (`domain/user.Login`) | `users`, `user_profiles` (SELECT) | Single-device enforcement via Redis `SessionGuard` (JTI validation) |
| **Console Operator Login** | — | `windows_console_flutter/lib/features/auth/login_screen.dart` | `POST /api/v1/auth/console/login` (`domain/user.ConsoleLogin`) | `users` (SELECT WHERE role IN ('agency', 'admin')) | Multi-device console support; JWT role claims validation |
| **Citizen Registration** | `mobile-flutter/lib/features/auth/register_screen.dart` | — | `POST /api/v1/auth/register` (`domain/user.Register`) | `users`, `user_profiles` (INSERT transaction) | Default role: `civilian`; password hashed via bcrypt |
| **Token Refresh & Rotation** | `mobile-flutter/lib/core/services/session_service.dart` | `windows_console_flutter/lib/core/services/auth_service.dart` | `POST /api/v1/auth/refresh` (`domain/user.RefreshToken`) | Redis JTI store | Replay attack protection with grace period rotation |
| **User Profile & Biodata** | `mobile-flutter/lib/features/masyarakat/profile_screen.dart` | `windows_console_flutter/lib/features/admin/presentation/pages/user_management_page.dart` | `GET /api/v1/users/profile`, `PUT /api/v1/users/profile` (`domain/user.GetProfile`, `UpdateProfile`) | `users`, `user_profiles` (SELECT, UPDATE) | Synchronized profile changes |

---

## 2. Emergency Incident & SOS Lifecycle

| Feature | Mobile Flutter (Citizen / Volunteer) | Windows Console Flutter (Agency / Admin) | Go Fiber Endpoint & Handler | DB Table & Query | State, WS & Security |
|---|---|---|---|---|---|
| **Trigger SOS Alert** | `mobile-flutter/lib/features/masyarakat/home_screen.dart` | — | `POST /api/v1/incidents/trigger` (`domain/incident.TriggerSOS`) | `incidents` (INSERT) | WS: `SOS_ACKNOWLEDGED` to reporter; grace-period auto-promote |
| **Active SOS Accept (Volunteer)** | `mobile-flutter/lib/features/relawan/relawan_main_screen.dart` | `windows_console_flutter/lib/features/instansi/presentation/pages/sos_aktif_page.dart` | `POST /api/v1/incidents/:id/accept` (`domain/incident.AcceptSOS`) | `incident_responses` (INSERT) | WS: `RESCUE_ACCEPTED` to reporter with localized message |
| **SOS Cancel (Reporter)** | `mobile-flutter/lib/features/masyarakat/home_screen.dart` | — | `POST /api/v1/incidents/:id/canceled` (`domain/incident.CancelSOS`) | `incidents` (UPDATE status) | WS: `SOS_CANCELLED`; offline pending-cancel replay with 409 short-circuit |
| **Agency Handle / Resolve** | — | `windows_console_flutter/lib/features/instansi/presentation/pages/sos_aktif_page.dart` | `POST /api/v1/incidents/:id/handle`, `.../agency-resolve`, `.../mark-false-alarm` (`domain/incident.AgencyHandleSOS`, `AgencyResolveSOS`, `MarkFalseAlarm`) | `incidents` (UPDATE status) | Requires `X-Idempotency-Key`; strike/ban flow on false alarm |
| **Nearby SOS Feed (Volunteer)** | `mobile-flutter/lib/features/masyarakat/map_screen.dart` | `windows_console_flutter/lib/features/instansi/presentation/pages/peta_operasional_page.dart` | `GET /api/v1/incidents/nearby` (`domain/incident.GetNearby`) | Haversine SELECT | Redis GEOADD telemetry; WS `VOLUNTEER_LOCATION_UPDATE` |

---

## 3. Volunteer Dispatch & Coordination

| Feature | Mobile Flutter (Citizen / Volunteer) | Windows Console Flutter (Agency / Admin) | Go Fiber Endpoint & Handler | DB Table & Query | State, WS & Security |
|---|---|---|---|---|---|
| **Volunteer Discovery (Proximity)** | — | `windows_console_flutter/lib/features/instansi/presentation/pages/dispatch_relawan_page.dart` | `GET /api/v1/telemetry/nearby-volunteers` (`domain/telemetry.GetNearbyVolunteers`) | Redis GEO + `users` (Haversine) | Filters active volunteers within dispatch radius |
| **Dispatch Broadcast Assignment** | `mobile-flutter/lib/features/relawan/relawan_main_screen.dart` | `windows_console_flutter/lib/features/instansi/presentation/pages/dispatch_relawan_page.dart` | `POST /api/v1/incidents/:id/dispatch-broadcast` (`domain/incident.DispatchBroadcast`) | `incident_responses` (INSERT) | Requires `X-Idempotency-Key`; WS offer to nearby volunteers |
| **Volunteer Accept / Complete** | `mobile-flutter/lib/features/relawan/relawan_main_screen.dart` | `windows_console_flutter/lib/features/instansi/presentation/pages/sos_aktif_page.dart` | `POST /api/v1/incidents/:id/accept`, `POST /api/v1/incidents/:id/volunteer-complete` (`domain/incident.AcceptSOS`, `VolunteerCompleteSOS`) | `incident_responses` (UPDATE status) | Evidence upload on completion; WS status fan-out |
| **Mission History** | `mobile-flutter/lib/features/relawan/relawan_history_screen.dart` | `windows_console_flutter/lib/features/instansi/presentation/pages/riwayat_page.dart` | `GET /api/v1/incidents/my-history`, `.../missions/history`, `.../reporter-history` (`domain/incident`) | `incidents`, `incident_responses` (SELECT) | Offline cache fallback on mobile |

---

## 4. Volunteer Verification (KYC) & Gamification

| Feature | Mobile Flutter (Citizen / Volunteer) | Windows Console Flutter (Agency / Admin) | Go Fiber Endpoint & Handler | DB Table & Query | State, WS & Security |
|---|---|---|---|---|---|
| **Volunteer Registration & Cert Upload** | `mobile-flutter/lib/features/masyarakat/volunteer_registration_screen.dart` | — | `POST /api/v1/users/volunteer/register` (`domain/user.SubmitVolunteerRegistration`) | `user_profiles`, `volunteer_certifications` (INSERT) | File uploads handled via `file_picker` v12 with byte stream verification |
| **Admin KYC Verification** | — | `windows_console_flutter/lib/features/admin/presentation/pages/kyc_relawan_page.dart` | `POST /api/v1/admin/volunteers/:id/approve`, `.../reject` (`domain/admin.ApproveKYC`, `RejectKYC`) | `user_profiles` (UPDATE kyc_status, verified_at) | Roles elevated to `volunteer` upon KYC approval |
| **Rank Management (XP)** | `mobile-flutter/lib/features/masyarakat/profile_screen.dart` | `windows_console_flutter/lib/features/admin/presentation/pages/gamifikasi_page.dart` | `GET /admin/ranks`, `POST /admin/ranks` (`domain/admin.GetRanks`, `CreateRank`) | `ranks` (SELECT, INSERT, UPDATE) | Automatic level computation based on volunteer XP thresholds |
| **Badge Management & Upload** | `mobile-flutter/lib/features/masyarakat/profile_screen.dart` | `windows_console_flutter/lib/features/admin/presentation/pages/gamifikasi_page.dart` | `GET /admin/badges`, `POST /admin/badges` (`domain/admin.GetBadges`, `CreateBadge`) | `badges`, `user_badges` (SELECT, INSERT) | Badge icon uploaded via `file_picker` v12 `readAsBytes` API |

---

## 5. Telemetry & GPS Tracking

| Feature | Mobile Flutter (Citizen / Volunteer) | Windows Console Flutter (Agency / Admin) | Go Fiber Endpoint & Handler | DB Table & Query | State, WS & Security |
|---|---|---|---|---|---|
| **Location Update (Volunteer)** | Background service in `mobile-flutter` | — | `PUT /api/v1/telemetry/location` (`domain/telemetry.UpdateLocation`) | Redis GEOADD + WS broadcast | Request-scoped 3s timeout; detached retry documented |
| **Online Status Board** | — | `windows_console_flutter/lib/features/instansi/presentation/pages/peta_operasional_page.dart` | `POST /api/v1/telemetry/online-status` (`domain/telemetry.GetOnlineStatus`) | Redis TTL reads | Console-only RBAC |
| **Console Live Tracking Map** | — | `windows_console_flutter/lib/features/instansi/presentation/pages/peta_operasional_page.dart` | `WS /v1/ws/connect` (`hub.Hub` + `ws.Handler`) | In-memory registry with per-connection locale | WS events: `CONNECTED`, `VOLUNTEER_LOCATION_UPDATE`, `REPORTER_LOCATION_UPDATE` |

---

## 6. Official Agency Responder Tactical Operations

| Feature | Mobile Responder Flutter (Agency Personnel) | Windows Console Flutter (Agency Dispatcher) | Go Fiber Endpoint & Handler | DB Table & Query | State, WS & Security |
|---|---|---|---|---|---|
| **Personnel Authentication** | `mobile-flutter-responder/lib/features/auth/presentation/login_screen.dart` | — | `POST /api/v1/auth/login` (`domain/user.Login`) | `users`, `user_profiles` (SELECT) | Enforces role `agency`; validates badge number or official email |
| **Tactical Mission Board** | `mobile-flutter-responder/lib/features/missions/presentation/mission_board_screen.dart` | `windows_console_flutter/lib/features/instansi/presentation/pages/dispatch_relawan_page.dart` | `GET /api/v1/incidents/assigned` (`domain/incident.GetAssignedIncidents`) | `incidents`, `users`, `locations` (SELECT JOIN) | WS: `MISSION_ASSIGNED` broadcast on dispatcher unit assignment |
| **Mission Progression Workflow** | `mobile-flutter-responder/lib/features/missions/presentation/mission_detail_screen.dart` | `windows_console_flutter/lib/features/instansi/presentation/pages/dispatch_relawan_page.dart` | `PUT /api/v1/incidents/:id/status` (`domain/incident.UpdateIncidentStatus`) | `incidents` (UPDATE status, timestamps) | Sequential status states: `assigned` -> `en_route` -> `on_scene` -> `resolved` |
| **High-Frequency GPS Telemetry** | Background location streamer in `mobile-flutter-responder` | `windows_console_flutter/lib/features/instansi/presentation/pages/dispatch_relawan_page.dart` | `PUT /api/v1/telemetry/location` (`domain/telemetry.UpdateLocation`) | Redis geospatial cache (`GEOADD`), `sync.Pool` | Low memory churn payload reuse; WS broadcast to victim and dispatcher |
| **Tactical Map & External Navigation** | `mobile-flutter-responder/lib/features/navigation/presentation/navigation_map_screen.dart` | — | OpenStreetMap / External Map Launcher | — | Deep-linking to Google Maps / Waze with coordinates handoff |

---

## 7. Living Maintenance Rules
1. **Contract Parity**: When modifying an endpoint in `docs/api/*.yaml`, update corresponding rows in this table.
2. **Client Symmetry**: Check whether a newly added backend feature requires a mobile citizen interface, a responder interface, a console interface, or all three.
3. **Database Integrity**: Ensure every DB table documented here matches `docs/DATABASE_SCHEMA.md`.
