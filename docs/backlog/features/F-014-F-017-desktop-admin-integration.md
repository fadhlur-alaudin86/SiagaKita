# F-014 to F-017: Desktop Console Admin Shell & Analytics Integration

## Issue Metadata

| Field | Value |
|---|---|
| ID | F-014, F-015, F-016, F-017 |
| Title | Desktop Console Admin Shell & Analytics Integration |
| Requestor | Fadhlurrahman Alaudin |
| Date Created | 2026-09-10 |
| GitHub Issues | #14, #15, #16, #17 (Parent: #3) |
| Status | In Progress |

## Discovery (Step -2)

| Type | File / Name | Notes |
|---|---|---|
| Desktop Client | `windows_console_flutter/` | Windows Desktop Flutter Console |
| API Services | `lib/core/services/api_services.dart` | `AdminApiService` methods for volunteers, users, ranks, stats |
| Volunteer KYC | `lib/features/admin/presentation/pages/kyc_relawan_page.dart` | Queue, KTP preview, cert viewer with `url_launcher`, approve/reject |
| User Management | `lib/features/admin/presentation/pages/user_management_page.dart` | Query filters, strike badges, ban modal with days/reason, unban & reset strike |
| Gamification Ranks | `lib/features/admin/presentation/pages/gamifikasi_page.dart` | Rank list, add/edit modal, base rank deletion protection (`min_exp = 0`) |
| Statistics | `lib/features/admin/presentation/pages/statistik_page.dart` | `week`, `month`, `year` periods, KPI cards, line & pie charts |
| Localization | `lib/core/localization/app_localization.dart` | Bilingual English & Indonesian dictionary parity |

## Step Progress

| Step | Action | Status | Date | Notes |
|---|---|---|---|---|
| -3 | Backlog Overview | Done | 2026-09-10 | Plan 03 selected to finalize Desktop Admin Shell |
| -2 | Discovery | Done | 2026-09-10 | Inspected Flutter pages, model serialization, and API services |
| -1 | Resolve Backlog | Done | 2026-09-10 | Created feature log `F-014-F-017-desktop-admin-integration.md` |
| 0 | Branch & Assign | Done | 2026-09-10 | Created branch `feature/F-014-F-017-desktop-admin-integration`, assigned Issues #14-#17 |
| 1 | Read Mapping | Done | 2026-09-10 | Reviewed existing UI state management and endpoint parameter contracts |
| 2 | API Contract | Done | 2026-09-10 | Verified multi-client API contract parity with backend Go Fiber |
| 3 | DB Migration | Skipped | 2026-09-10 | No schema changes needed (frontend integration) |
| 4 | Backend Implementation | Skipped | 2026-09-10 | Backend admin endpoints already finalized in Plan 02 |
| 5 | Flutter Implementation | Done | 2026-09-10 | Implemented UI dialogs, parameter queries, url_launcher/pdfrx, base rank rules, and localization |
| 6 | Tests | Done | 2026-09-10 | flutter analyze (0 issues), 16/16 test suites passed |
| 7 | CI + Review | Done | 2026-09-10 | Format checks (dart format) and static analysis verification passed |
| 8 | Close Log | Done | 2026-09-10 | Ready for PR to dev |
