# Plan 12: Mobile FTUE Visual Onboarding & Contextual Permission Management

## 1. Overview & Problem Statement
- **Target Issue**: [#107](https://github.com/fadhlur-alaudin86/SiagaKita/issues/107)
- **Priority**: P1 (High)
- **Status**: Merged | Verified and closed
- **Problem**:
  - Newly authenticated users in `mobile-flutter` face unprimed, stacked permission dialogs (Location, Camera, Microphone) without contextual explanations, creating distrust and high denial rates.
  - When permissions are denied and the device is offline, tapping the SOS button prematurely enters the `gracePeriod` state and simulates transmission, only to fail or trigger delayed permission prompts once network connectivity resumes.
  - The application lacks an introductory first-launch walkthrough explaining core capabilities (instant SOS, volunteer responder dispatch, family safety radar) to new civilians and volunteers.
- **Goal**:
  - Implement a visual, swipeable first-launch onboarding carousel with a smart skip mechanism.
  - Establish a modular, reusable contextual permission management screen featuring rationale cards, interactive toggles, and automatic state synchronization on app resume.
  - Enforce a strict pre-flight guard on the SOS button preventing state machine entry without location permissions in both online and offline environments.

---

## 2. Technical Scope & Architecture

### 2.1 First-Launch Visual Onboarding Flow
- **Screen**: `lib/features/onboarding/presentation/onboarding_screen.dart`
- **Routing & Persistence**:
  - Add `has_completed_onboarding` boolean flag stored in `SharedPreferences` / `LocalStorageService`.
  - In `main.dart` (`_AppStartup`), inspect `has_completed_onboarding`. If `false`, route immediately to `OnboardingScreen`.
  - Once completed or skipped, persist `has_completed_onboarding = true`.
- **Slide Specifications**:
  - Slide 1: **SOS Darurat Seketika** — Panic button with instant grace period countdown and live location broadcast.
  - Slide 2: **Jaringan Relawan & Instansi** — Verified volunteer dispatch and agency rescue deployment radar.
  - Slide 3: **Zonasi & Perlindungan Keluarga** — Real-time family safety zones and perimeter breach alerts.
- **Navigation Controls**:
  - Header `Skip` / `Lewati` button and footer animated page indicator dots.
  - Slide 3 primary action: `Mulai Sekarang` (Get Started).
  - Smart Transition Check: Upon tapping `Skip` or `Mulai Sekarang`, inspect current permission status. If critical permissions (Location) are missing, transition to `PermissionPrimerScreen`. If already granted, route to `LoginScreen` (or `MainScreen` if session is active).

### 2.2 Contextual Permission Management Screen
- **Screen**: `lib/features/permissions/presentation/permission_primer_screen.dart`
- **Modular Placement**:
  - Placed between onboarding and authentication/dashboard.
  - Reusable as an independent route callable from settings, warning banners, or SOS pre-flight modals.
- **Interactive Permission Cards**:
  - **Izin Lokasi (GPS & Background)**: Rationale for dispatch routing and emergency radius calculations.
  - **Izin Mikrofon**: Rationale for emergency ambient voice recording during active SOS.
  - **Izin Notifikasi**: Rationale for real-time dispatch alerts and family safety notices.
  - **Izin Kamera**: Rationale for disaster situation photo evidence uploads.
- **State Machine & Lifecycle Handling**:
  - Each card displays an interactive toggle / action button.
  - Tapping a card requests native OS permissions via `permission_handler`.
  - Detects `isPermanentlyDenied`: Displays a dialog with direct navigation to device application settings via `openAppSettings()`.
  - Implements `WidgetsBindingObserver` with `didChangeAppLifecycleState(AppLifecycleState.resumed)` to automatically re-verify and update all card statuses when the user returns from OS settings.
- **Soft Gating Policy**:
  - Users are allowed to proceed by tapping `Lanjutkan ke Aplikasi` (or `Lewati untuk Sekarang`) even with incomplete permissions.
  - A persistent non-intrusive warning card renders on `HomeScreen` if critical permissions remain ungranted.

### 2.3 SOS Offline & Permission Pre-Flight Guard
- **Widget**: `lib/features/masyarakat/home_screen.dart`
- **Zero State Transition Guard**:
  - Before incrementing `_tapCount` or transitioning `_sosPhase = 'gracePeriod'`, execute an immediate synchronous pre-check:
    ```dart
    final hasLocation = await LocationService.hasPermission();
    if (!hasLocation) {
      HapticFeedback.vibrate();
      _showPermissionRequiredModal();
      return;
    }
    ```
  - Eliminates fake local incident generation and corrupted state when offline.
- **Actionable Permission Modal**:
  - Bottom sheet explaining that GPS location is strictly mandatory to broadcast coordinates to emergency responders.
  - Provides two actions: `Buka Layar Perizinan` (opens `PermissionPrimerScreen`) and `Buka Pengaturan Gawai` (`openAppSettings()`).

---

## 3. Tasks & Implementation Checklist

### 3.1 Onboarding Module
- [x] Implement `OnboardingScreen` with `PageView`, custom declarative illustrations, and page indicator dots.
- [x] Implement `OnboardingService` / local preference persistence for `has_completed_onboarding`.
- [x] Integrate startup routing logic in `_AppStartup` (`main.dart`).

### 3.2 Permission Management Module
- [x] Create `PermissionPrimerScreen` with permission explanation cards and live status badges.
- [x] Implement per-permission request triggers and permanent denial redirect handling.
- [x] Add `WidgetsBindingObserver` lifecycle sync to refresh statuses upon app resume.
- [x] Remove abrupt sequential permission calls from `LoginScreen`, `RegisterScreen`, and `_AppStartup`.
- [x] Implement warning banner on `HomeScreen` when permissions are incomplete.

### 3.3 SOS Pre-Flight Guard & Offline Resilience
- [x] Add instant permission validation before tap progression and grace period countdown in `home_screen.dart`.
- [x] Implement `_showPermissionRequiredModal` bottom sheet.
- [x] Validate offline SOS behavior: tapping without permissions displays modal cleanly without glitching UI.

### 3.4 Localization & Quality Verification
- [x] Register all new UI strings in `mobile-flutter/lib/core/localization/app_localization.dart` with 100% bilingual parity (`id` and `en`).
- [x] Run `python3 scripts/check_localization_orphans.py --mobile` and ensure 0 orphaned keys.
- [x] Run `flutter analyze --fatal-infos` and ensure 0 static analysis errors.
- [x] Author widget and unit tests for onboarding navigation and SOS pre-flight checks.

---

## 4. Affected Components & Files

- `mobile-flutter/lib/`
  - `main.dart` (startup routing flow)
  - `core/localization/app_localization.dart` (bilingual dictionaries)
  - `core/services/permission_service.dart` (refactor from burst prompts to modular inspection)
  - `features/auth/login_screen.dart` (remove unprimed permission bursts)
  - `features/auth/register_screen.dart` (remove unprimed permission bursts)
  - `features/masyarakat/home_screen.dart` (SOS pre-flight guard & permission warning banner)
  - `features/onboarding/presentation/onboarding_screen.dart` (new)
  - `features/permissions/presentation/permission_primer_screen.dart` (new)
- `docs/backlog/features/F-107-ftue-onboarding-permissions.md` (new feature log)

---

## 5. Verification & Acceptance Criteria

1. **First-Launch Experience**:
   - Fresh installation immediately displays `OnboardingScreen`.
   - Tapping `Skip` or completing the final slide executes the Smart Transition Check and marks onboarding as completed.
   - Returning or authenticated users launch directly into `LoginScreen` or `MainScreen`.
2. **Contextual Permission Priming**:
   - Each permission displays clear technical and situational rationale.
   - Enabling a permission natively updates its card status to active.
   - Returning from OS Settings automatically synchronizes card states without requiring app restarts.
3. **SOS Button Integrity**:
   - Tapping the SOS button when location permissions are missing immediately halts execution, sounds error haptic, and presents the resolution modal.
   - The UI never enters `gracePeriod` or fake transmission states, even in total offline mode.
4. **Localization Governance**:
   - Zero hardcoded strings; all user text uses `.tr(context)`.
   - Automated check `python3 scripts/check_localization_orphans.py --mobile` passes cleanly.
