# Component Mapping — SiagaKita Multi-Client Architecture

This document serves as the living single-source-of-truth matrix linking frontend user interfaces across Flutter Mobile and Flutter Windows Console with Go Fiber backend endpoints, PostgreSQL database operations, and real-time WebSocket events.

---

## 1. Authentication & Session Management

| Feature | Mobile Flutter (Citizen / Volunteer) | Windows Console Flutter (Agency / Admin) | Go Fiber Endpoint & Handler | DB Table & Query | State, WS & Security |
|---|---|---|---|---|---|
| **Citizen & Volunteer Login** | `mobile-flutter/lib/features/auth/login_screen.dart` | — | `POST /auth/login` (`domain/user.Login`) | `users`, `user_profiles` (SELECT) | Single-device enforcement via Redis `SessionGuard` (JTI validation) |
| **Console Operator Login** | — | `windows_console_flutter/lib/features/auth/presentation/pages/login_page.dart` | `POST /auth/console/login` (`domain/user.ConsoleLogin`) | `users` (SELECT WHERE role IN ('agency', 'admin')) | Multi-device console support; JWT role claims validation |
| **Citizen Registration** | `mobile-flutter/lib/features/auth/register_screen.dart` | — | `POST /auth/register` (`domain/user.Register`) | `users`, `user_profiles` (INSERT transaction) | Default role: `civilian`; password hashed via bcrypt |
| **Token Refresh & Rotation** | `mobile-flutter/lib/core/services/session_service.dart` | `windows_console_flutter/lib/core/services/auth_service.dart` | `POST /auth/refresh` (`domain/user.RefreshToken`) | Redis JTI store | Replay attack protection with grace period rotation |
| **User Profile & Biodata** | `mobile-flutter/lib/features/profile/profile_screen.dart` | `windows_console_flutter/lib/features/admin/presentation/pages/admin_page.dart` | `GET /user/profile`, `PUT /user/profile` (`domain/user.GetProfile`, `UpdateProfile`) | `users`, `user_profiles` (SELECT, UPDATE) | Synchronized profile changes |

---

## 2. Emergency Incident & SOS Lifecycle

| Feature | Mobile Flutter (Citizen / Volunteer) | Windows Console Flutter (Agency / Admin) | Go Fiber Endpoint & Handler | DB Table & Query | State, WS & Security |
|---|---|---|---|---|---|
| **Trigger SOS Alert** | `mobile-flutter/lib/features/masyarakat/sos_screen.dart` | — | `POST /incident/sos` (`domain/incident.TriggerSOS`) | `incidents` (INSERT), `locations` (INSERT) | WS: `incident_created` broadcast to `agency` and `admin` roles |
| **Active Incidents Feed** | `mobile-flutter/lib/features/masyarakat/riwayat_laporan_screen.dart` | `windows_console_flutter/lib/features/dispatch/presentation/pages/dispatch_screen.dart` | `GET /incident/active` (`domain/incident.GetActiveIncidents`) | `incidents`, `users` (SELECT JOIN) | Console real-time map marker updates via WebSocket Hub |
| **Agency Incident Acceptance** | — | `windows_console_flutter/lib/features/dispatch/presentation/pages/dispatch_screen.dart` | `POST /incident/:id/accept` (`domain/incident.AcceptIncident`) | `incidents` (UPDATE status = 'in_progress', agency_id) | Requires `X-Idempotency-Key`; WS: `incident_accepted` |
| **Incident Resolution** | — | `windows_console_flutter/lib/features/dispatch/presentation/pages/dispatch_screen.dart` | `POST /incident/:id/resolve` (`domain/incident.ResolveIncident`) | `incidents` (UPDATE status = 'resolved', resolved_at) | WS: `incident_resolved` broadcast to reporter and responders |
| **False Alarm Strike Penalty** | — | `windows_console_flutter/lib/features/dispatch/presentation/pages/dispatch_screen.dart` | `POST /incident/:id/strike` (`domain/incident.MarkFalseAlarmStrike`) | `incident_strikes` (INSERT), `users` (UPDATE strike_count) | 3 strikes trigger automated ban per Strike System invariant |

---

## 3. Volunteer Dispatch & Coordination

| Feature | Mobile Flutter (Citizen / Volunteer) | Windows Console Flutter (Agency / Admin) | Go Fiber Endpoint & Handler | DB Table & Query | State, WS & Security |
|---|---|---|---|---|---|
| **Volunteer Discovery (Proximity)** | — | `windows_console_flutter/lib/features/dispatch/presentation/pages/dispatch_screen.dart` | `GET /incident/:id/nearby-volunteers` (`domain/incident.GetNearbyVolunteers`) | `users`, `locations` (SELECT with Haversine distance) | Filters active volunteers within configured dispatch radius |
| **Dispatch Volunteer Assignment** | — | `windows_console_flutter/lib/features/dispatch/presentation/pages/dispatch_screen.dart` | `POST /incident/:id/dispatch` (`domain/incident.DispatchVolunteer`) | `incident_responders` (INSERT status = 'dispatched') | Requires `X-Idempotency-Key`; WS: `dispatch_assigned` to volunteer |
| **Volunteer Response (Accept/Decline)** | `mobile-flutter/lib/features/relawan/relawan_screen.dart` | `windows_console_flutter/lib/features/dispatch/presentation/pages/dispatch_screen.dart` | `POST /incident/:id/volunteer-response` (`domain/incident.VolunteerResponse`) | `incident_responders` (UPDATE status = 'accepted'/'rejected') | WS: `volunteer_status_updated` streamed to agency console |
| **Mission Progression Stepper** | `mobile-flutter/lib/features/relawan/relawan_screen.dart` | `windows_console_flutter/lib/features/dispatch/presentation/pages/dispatch_screen.dart` | `PUT /incident/:id/responder-status` (`domain/incident.UpdateResponderStatus`) | `incident_responders` (UPDATE responder_status) | Steps: `on_the_way` -> `arrived_on_scene` -> `completed` |

---

## 4. Volunteer Verification (KYC) & Gamification

| Feature | Mobile Flutter (Citizen / Volunteer) | Windows Console Flutter (Agency / Admin) | Go Fiber Endpoint & Handler | DB Table & Query | State, WS & Security |
|---|---|---|---|---|---|
| **Volunteer Registration & Cert Upload** | `mobile-flutter/lib/features/masyarakat/volunteer_registration_screen.dart` | — | `POST /user/volunteer/register` (`domain/user.RegisterVolunteer`) | `user_profiles`, `volunteer_certifications` (INSERT) | File uploads handled via `file_picker` v12 with byte stream verification |
| **Admin KYC Verification** | — | `windows_console_flutter/lib/features/admin/presentation/pages/admin_page.dart` | `PUT /admin/kyc/:id/review` (`domain/admin.ReviewKYC`) | `user_profiles` (UPDATE kyc_status, verified_at) | Roles elevated to `volunteer` upon KYC approval |
| **Rank Management (XP)** | `mobile-flutter/lib/features/profile/profile_screen.dart` | `windows_console_flutter/lib/features/admin/presentation/pages/gamifikasi_page.dart` | `GET /admin/ranks`, `POST /admin/ranks` (`domain/admin.GetRanks`, `CreateRank`) | `ranks` (SELECT, INSERT, UPDATE) | Automatic level computation based on volunteer XP thresholds |
| **Badge Management & Upload** | `mobile-flutter/lib/features/profile/profile_screen.dart` | `windows_console_flutter/lib/features/admin/presentation/pages/gamifikasi_page.dart` | `GET /admin/badges`, `POST /admin/badges` (`domain/admin.GetBadges`, `CreateBadge`) | `badges`, `user_badges` (SELECT, INSERT) | Badge icon uploaded via `file_picker` v12 `readAsBytes` API |
| **Manual Badge Assignment** | — | `windows_console_flutter/lib/features/admin/presentation/pages/gamifikasi_page.dart` | `POST /admin/badges/award` (`domain/admin.AwardBadge`) | `user_badges` (INSERT) | Admin reward dispatch; triggers volunteer push notification |

---

## 5. Telemetry & GPS Tracking

| Feature | Mobile Flutter (Citizen / Volunteer) | Windows Console Flutter (Agency / Admin) | Go Fiber Endpoint & Handler | DB Table & Query | State, WS & Security |
|---|---|---|---|---|---|
| **Location Update (Volunteer)** | Background service in `mobile-flutter` | — | `POST /telemetry/location` (`domain/telemetry.UpdateLocation`) | `locations` (INSERT ON CONFLICT UPDATE) | Redis geospatial cache + WebSocket broadcast |
| **Console Live Tracking Map** | — | `windows_console_flutter/lib/features/dispatch/presentation/pages/dispatch_screen.dart` | `WS /ws` (`hub.Hub`) | In-memory connection registry | Periodic 90s telemetry anti-memory leak eviction |

---

## 6. Official Agency Responder Tactical Operations

| Feature | Mobile Responder Flutter (Agency Personnel) | Windows Console Flutter (Agency Dispatcher) | Go Fiber Endpoint & Handler | DB Table & Query | State, WS & Security |
|---|---|---|---|---|---|
| **Personnel Authentication** | `mobile-flutter-responder/lib/features/auth/login_screen.dart` | — | `POST /api/v1/auth/login` (`domain/user.Login`) | `users`, `user_profiles` (SELECT) | Enforces role `agency`; validates badge number or official email |
| **Tactical Mission Board** | `mobile-flutter-responder/lib/features/mission/mission_board_screen.dart` | `windows_console_flutter/lib/features/dispatch/presentation/pages/dispatch_screen.dart` | `GET /api/v1/incidents/assigned` (`domain/incident.GetAssignedIncidents`) | `incidents`, `users`, `locations` (SELECT JOIN) | WS: `MISSION_ASSIGNED` broadcast on dispatcher unit assignment |
| **Mission Progression Workflow** | `mobile-flutter-responder/lib/features/mission/mission_detail_screen.dart` | `windows_console_flutter/lib/features/dispatch/presentation/pages/dispatch_screen.dart` | `PUT /api/v1/incidents/:id/status` (`domain/incident.UpdateIncidentStatus`) | `incidents` (UPDATE status, timestamps) | Sequential status states: `assigned` -> `en_route` -> `on_scene` -> `resolved` |
| **High-Frequency GPS Telemetry** | Background location streamer in `mobile-flutter-responder` | `windows_console_flutter/lib/features/dispatch/presentation/pages/dispatch_screen.dart` | `PUT /api/v1/telemetry/location` (`domain/telemetry.UpdateLocation`) | Redis geospatial cache (`GEOADD`), `sync.Pool` | Low memory churn payload reuse; WS broadcast to victim and dispatcher |
| **Tactical Map & External Navigation** | `mobile-flutter-responder/lib/features/mission/tactical_map_screen.dart` | — | OpenStreetMap / External Map Launcher | — | Deep-linking to Google Maps / Waze with coordinates handoff |

---

## 7. Living Maintenance Rules
1. **Contract Parity**: When modifying an endpoint in `docs/api/*.yaml`, update corresponding rows in this table.
2. **Client Symmetry**: Check whether a newly added backend feature requires a mobile citizen interface, a responder interface, a console interface, or all three.
3. **Database Integrity**: Ensure every DB table documented here matches `docs/DATABASE_SCHEMA.md`.
