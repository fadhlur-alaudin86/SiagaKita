# F-107: Mobile FTUE Visual Onboarding Flow & Contextual Permission Management Screen

## Issue Metadata

| Field | Value |
|---|---|
| ID | F-107 |
| Title | Mobile FTUE Visual Onboarding Flow & Contextual Permission Management Screen |
| Requestor | Fadhlurrahman Alaudin |
| Date Created | 2026-09-12 |
| GitHub Issues | [#107](https://github.com/fadhlur-alaudin86/SiagaKita/issues/107) |
| Parent Plan | `.planning/12-mobile-ftue-onboarding-permissions.md` |
| Status | Merged (PR #108) |

---

## 1. Scope & Goals

- **Core Problem**:
  - Unprimed, stacked permission dialogs (Location, Camera, Microphone) upon authentication cause distrust, confusion, and high rejection rates among new users.
  - Denying permissions and entering the application offline causes the emergency SOS button to superficially trigger `gracePeriod` countdown before failing or popping delayed dialogs upon network reconnect.
  - The application lacks an introductory first-launch visual walkthrough to educate newly onboarded civilians and volunteers on core life-saving capabilities.
- **Boundaries**:
  - Implemented strictly within `mobile-flutter/`.
  - First-launch visual carousel with persistent local flag `has_completed_onboarding`.
  - Contextual permission primer screen with per-item status cards, explanation rationales, and `AppLifecycleState.resumed` auto-sync.
  - Instant zero-state-transition pre-flight guard on the SOS button preventing state machine entry when location permissions are missing in online/offline modes.
- **Non-Goals**:
  - Modifying backend APIs or database schemas (client-only UX and local state resilience enhancement).
  - Removing permissions altogether (emergency response strictly depends on GPS, audio notes, and push notifications).

---

## 2. Architectural Decisions Log (Resolved via `/grill-me`)

1. **Modular Screen Placement**:
   - **Decision**: The permission primer (`PermissionPrimerScreen`) is architected as an independent, modular screen positioned between onboarding and authentication/dashboard.
   - **Rationale**: Decouples feature presentation from permission granting and allows the permission screen to be invoked anytime from settings, warning banners, or SOS pre-flight modals without replaying the onboarding carousel.
2. **Soft Gating Policy with Feature Guards**:
   - **Decision**: Users who decline some permissions are permitted to proceed into `MainScreen` (preventing app drop-off and complying with app store guidelines). However, an amber warning banner is rendered on `HomeScreen`, and features requiring missing permissions (SOS, report photo capture) are strictly guarded.
   - **Rationale**: Balances user trust and conversion with safety invariants.
3. **Instant SOS Pre-Tap Guard (Zero State Transition)**:
   - **Decision**: Before incrementing tap counts or entering `gracePeriod`, the SOS button synchronously validates `await LocationService.hasPermission()`. If false, execution halts with haptic error, and a modal bottom sheet opens directly.
   - **Rationale**: Eliminates misleading fake transmissions and prevents UI state desynchronization in offline scenarios.
4. **Interactive Cards with Lifecycle Resumed Synchronization**:
   - **Decision**: Each permission card has an interactive toggle/button triggering native prompts. If permanently denied, it redirects to OS App Settings. When the user returns to the app (`AppLifecycleState.resumed`), all cards automatically re-query permission statuses and update badges.
   - **Rationale**: Frictionless permission resolution without needing app restarts.
5. **Smart Skip Transition**:
   - **Decision**: Tapping `Skip` or `Mulai Sekarang` marks onboarding as complete, checks permission states, and routes to `PermissionPrimerScreen` if permissions are missing, or directly to `LoginScreen`/`MainScreen` if already granted.
   - **Rationale**: Respects power users while ensuring mandatory permissions are primed.

---

## 3. Step Progress

| Step | Action | Status | Date | Notes |
|---|---|---|---|---|
| -3 | Backlog Overview | Done | 2026-09-12 | Created issue #107 and Plan 12 |
| -2 | Discovery | Done | 2026-09-12 | Audited `main.dart`, `login_screen.dart`, `location_service.dart`, and `home_screen.dart` |
| -1 | Resolve Backlog | Done | 2026-09-12 | Plan 12 cataloged in `.planning/12-mobile-ftue-onboarding-permissions.md` |
| 0 | Branch & Assign | Done | 2026-09-12 | Topic branch `feature/F-107-ftue-onboarding-permissions` checked out |
| 1 | Read Mapping | Done | 2026-09-12 | Alignment confirmed via `/grill-me` |
| 2 | Code Implementation | Done | 2026-09-12 | OnboardingScreen, PermissionPrimerScreen, SOS guard, and localization dictionaries |
| 3 | Verification | Done | 2026-09-12 | 100% localization audit passed (0 orphans), flutter analyze clean (0 issues), unit & widget tests passed (25/25), verify_pipeline passed |
| 4 | CI + Review | Done | 2026-09-12 | PR #108 opened targeting dev; all GitHub Actions CI checks green |
| 5 | Close Log | Done | 2026-09-12 | Merged to dev via PR #108 |
