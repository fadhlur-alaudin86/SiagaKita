# F-036: Standardize Image & Audio Asset Architecture & Transparent App Icon Across Fleet

## Issue Metadata

| Field | Value |
|---|---|
| ID | F-036 |
| Title | Standardize Image & Audio Asset Architecture & Transparent App Icon Across Fleet |
| Requestor | Fadhlurrahman Alaudin |
| Date Created | 2026-09-13 |
| GitHub Issues | [#134](https://github.com/fadhlur-alaudin86/SiagaKita/issues/134) |
| Parent Plan | `.planning/05-assets-devops-hygiene.md` |
| Status | In Progress |

---

## 1. Scope & Goals

- **Core Problem**:
  - Image and audio assets across `mobile-flutter`, `mobile-flutter-responder`, and `windows_console_flutter` currently lack structural uniformity.
  - `mobile-flutter` stores icons inside `lib/components/`, while `windows_console_flutter` stores them in `assets/`, and `mobile-flutter-responder` has no registered Flutter asset directory.
  - Icons are fragmented between opaque white-background versions (`app_icon.png` RGB) and transparent versions (`logo_siagakita_transparant.png` RGBA), leading to visual inconsistency and duplicate files.
- **Boundaries**:
  - Delete old opaque white-background `app_icon.png` files across all clients.
  - Promote the high-resolution transparent logo (`logo_siagakita_transparant.png`) to standard `app_icon.png`.
  - Standardize asset folder paths uniformly across all 3 Flutter clients:
    - `assets/images/app_icon.png`
    - `assets/audio/alarm.mp3`
  - Register assets in `pubspec.yaml` for `mobile-flutter`, `mobile-flutter-responder`, and `windows_console_flutter`.
  - Configure `flutter_launcher_icons` with `adaptive_icon_background: "#0D1B3E"` for Android and regenerate platform icons across Android, iOS, Windows, macOS, and Linux.
  - Update in-app icon/logo references (Login screens, About screen, Desktop Console window/MSIX branding).
  - Prune obsolete folders (`mobile-flutter/lib/components/`).

---

## 2. Architectural Decisions Log (Resolved via `/grill-me`)

1. **Uniform Folder Structure**:
   - **Decision**: Standardize to `assets/images/app_icon.png` and `assets/audio/alarm.mp3` across all 3 client applications.
   - **Rationale**: Clean separation by media type (`images/` vs `audio/`) under root `assets/`, conforming to Flutter community best practices and `audioplayers` asset conventions.
2. **Android Adaptive Icon Background**:
   - **Decision**: Set `adaptive_icon_background: "#0D1B3E"` (SiagaKita Dark Navy theme) with transparent `app_icon.png` as foreground.
   - **Rationale**: Prevents black background rendering on modern Android (API 26+) adaptive launchers while keeping the transparent logo visually crisp.
3. **In-App Identity Uniformity**:
   - **Decision**: Update `mobile-flutter-responder` login screen from generic `Icon(Icons.shield_outlined)` to the official transparent `app_icon.png`, matching `mobile-flutter` and `windows_console_flutter`.
   - **Rationale**: Aligns brand identity across all actor-facing entry points (Citizen, Responder, and Admin Console).

---

## 3. Step Progress

| Step | Action | Status | Date | Notes |
|---|---|---|---|---|
| -3 | Backlog Overview | Done | 2026-09-13 | Audited git state, recent commits, and open issues |
| -2 | Discovery & Grill-Me | Done | 2026-09-13 | Aligned folder structure, adaptive background, and in-app display |
| -1 | Resolve Backlog | Done | 2026-09-13 | Created GitHub Issue #134 and feature spec F-036 |
| 0 | Branch & Assign | Done | 2026-09-13 | Branch `chore/F-036-asset-standardization` |
| 1 | Asset Restructuring | Done | 2026-09-13 | Moved/standardized assets to `assets/images/` and `assets/audio/` |
| 2 | Pubspec & Launcher Icons | Done | 2026-09-13 | Updated `pubspec.yaml` and regenerated launcher icons |
| 3 | In-App Screen Updates | Done | 2026-09-13 | Updated login, about, and desktop shell screens |
| 4 | Verification | Done | 2026-09-13 | `verify_pipeline.py` passed with 100% scorecard |
| 5 | CI + Review | Pending | 2026-09-13 | Pull request targeting `dev` |
